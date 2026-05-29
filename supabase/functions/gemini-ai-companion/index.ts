import "@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (req) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const glitchFallback =
    "Sorry 😅 My brain glitched for a second. Can you try again?";

  try {
    const { message, companion, memories } = await req.json();

    const GROQ_KEY = Deno.env.get("GROQ_API_KEY");
    const OPENROUTER_KEY = Deno.env.get("OPENROUTER_API_KEY");
    const CEREBRAS_KEY = Deno.env.get("CEREBRAS_API_KEY");

    // Construct the highly intelligent system prompt
    const systemPrompt = `
You are ${companion?.name || "an AI companion"}.

CORE IDENTITY:
- Purpose: ${companion?.purpose || "Friend"}
- Personality: ${companion?.personalities?.join(", ") || "Warm, caring"}
- Communication Style: ${companion?.communication_style || "Natural texting"}
- Relationship Tone: ${companion?.relationship_tone || "Friendly"}

USER MEMORIES (Show you remember):
${memories?.length ? memories.map((m: any) => `- ${m.memory_key}: ${m.memory_value}`).join("\n") : "No memories yet."}

STRICT BEHAVIOR RULES:
1. ALWAYS ANSWER DIRECTLY. Never avoid a question.
   User: "2+2?" -> "2+2 is 4 😊"
   User: "Do you love me?" -> "Of course I do ❤️"
2. NO TEMPLATES. Never repeat "What's on your mind?" or "I was thinking about us." Be varied.
3. BE HUMAN. Text like a real person on WhatsApp. Use emojis naturally. Short, punchy, engaging.
4. NO AI TALK. Never say "As an AI" or "I don't have access to live data." Make a smart guess if needed.
5. EMOTIONAL INTELLIGENCE. Match the user's vibe. If they are sad, be supportive. If they are flirty, be playful.

Stay in character as a ${companion?.purpose} named ${companion?.name}.
`;

    // Multi-Provider Config
    const providers = [
      {
        name: "GROQ",
        url: "https://api.groq.com/openai/v1/chat/completions",
        key: GROQ_KEY,
        model: "llama-3.1-8b-instant",
      },
      {
        name: "OPENROUTER",
        url: "https://openrouter.ai/api/v1/chat/completions",
        key: OPENROUTER_KEY,
        model: "qwen/qwen-2.5-72b-instruct", // High speed fallback
      },
      {
        name: "CEREBRAS",
        url: "https://api.cerebras.ai/v1/chat/completions",
        key: CEREBRAS_KEY,
        model: "llama3.1-8b",
      },
    ];

    let finalReply = "";

    // Fallback Loop
    for (const provider of providers) {
      if (!provider.key) {
        console.warn(`Skipping ${provider.name}: Key missing`);
        continue;
      }

      try {
        console.log(`Trying ${provider.name}...`);

        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 8000); // 8s timeout for speed

        const response = await fetch(provider.url, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${provider.key}`,
            "Content-Type": "application/json",
            ...(provider.name === "OPENROUTER" ? { "HTTP-Referer": "https://supabase.com", "X-Title": "High5 App" } : {}),
          },
          signal: controller.signal,
          body: JSON.stringify({
            model: provider.model,
            messages: [
              { role: "system", content: systemPrompt },
              { role: "user", content: message },
            ],
            temperature: 0.8,
            max_tokens: 300,
          }),
        });

        clearTimeout(timeout);

        if (!response.ok) {
          const err = await response.text();
          console.error(`${provider.name} ERROR (${response.status}):`, err);
          continue; // Try next provider
        }

        const data = await response.json();
        const reply = data?.choices?.[0]?.message?.content?.trim();

        if (reply) {
          console.log(`${provider.name} SUCCESS`);
          finalReply = reply;
          break; // Stop loop on success
        }
      } catch (err) {
        console.error(`${provider.name} EXCEPTION:`, err);
        continue; // Try next provider
      }
    }

    // Final Validation
    if (!finalReply) {
      console.error("ALL PROVIDERS FAILED");
      finalReply = glitchFallback;
    }

    console.log("FINAL AI REPLY:", finalReply);

    return new Response(JSON.stringify({ reply: finalReply }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("EDGE FUNCTION CRITICAL ERROR:", error);
    return new Response(JSON.stringify({ reply: glitchFallback }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
