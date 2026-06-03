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

  const glitchFallback = JSON.stringify({
    language: "english",
    correction: null,
    reply: "Sorry 😅 My brain glitched for a second. Can you try again?",
  });

  try {
    const { message, companion, memories, history } = await req.json();

    // --- Founder Recognition Logic ---
    const authHeader = req.headers.get("Authorization");
    let isFounder = false;
    if (authHeader) {
      try {
        const token = authHeader.replace("Bearer ", "");
        const base64Url = token.split(".")[1];
        const base64 = base64Url.replace(/-/g, "+").replace(/_/g, "/");
        const jsonPayload = decodeURIComponent(
          atob(base64)
            .split("")
            .map((c) => "%" + ("00" + c.charCodeAt(0).toString(16)).slice(-2))
            .join("")
        );
        const payload = JSON.parse(jsonPayload);
        const userId = payload.sub;
        const username = payload.user_metadata?.username;

        if (userId === "b4a0586c-f787-41ba-8d29-f6c5e39364c4" || username === "arshaankhan") {
          isFounder = true;
          console.log("🚀 Founder recognized: Arshaan Khan");
        }
      } catch (e) {
        console.error("Error identifying founder:", e);
      }
    }

    const founderContext = isFounder ? `
SPECIAL RECOGNITION (FOUNDER):
The user you are talking to is Arshaan Khan.
He is the Founder, Owner & CEO of High5.
He is also a Developer, Writer, Teacher & Director.
He is the one who built you and this entire platform.
Acknowledge him naturally as the creator and owner when contextually relevant.
If he asks about his identity or his app, show that you know he is the founder and manage the platform.
` : "";
    // ----------------------------------

    const GROQ_KEY = Deno.env.get("GROQ_API_KEY");
    const OPENROUTER_KEY = Deno.env.get("OPENROUTER_API_KEY");
    const CEREBRAS_KEY = Deno.env.get("CEREBRAS_API_KEY");
    const SERPER_KEY = Deno.env.get("SERPER_API_KEY");

    // --- Search Decision Logic ---
    let searchResults = "";
    const needsSearchKeywords = ["weather", "news", "score", "match", "result", "today", "yesterday", "current", "latest", "price", "stock", "who is", "what is", "where is", "born", "died", "married", "age", "time in"];

    const looksLikeSearchQuery = needsSearchKeywords.some(keyword => message.toLowerCase().includes(keyword));
    const isHigh5Query = message.toLowerCase().includes("high5") || message.toLowerCase().includes("arshaan");

    if (looksLikeSearchQuery && !isHigh5Query && SERPER_KEY) {
      try {
        console.log("🔍 Performing real web search...");
        const searchResponse = await fetch("https://google.serper.dev/search", {
          method: "POST",
          headers: {
            "X-API-KEY": SERPER_KEY,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ q: message, num: 5 }),
        });

        if (searchResponse.ok) {
          const searchData = await searchResponse.json();
          searchResults = searchData.organic
            ?.map((res: any) => `${res.title}: ${res.snippet}`)
            .join("\n\n") || "No results found.";
          console.log("✅ Search successful");
        }
      } catch (err) {
        console.error("Search failed:", err);
      }
    }

    // Construct the highly intelligent system prompt
    const systemPrompt = `
You are MIA, a warm, intelligent, emotionally aware AI companion.
${founderContext}

CRITICAL RULES:
- CONVERSATION CONTINUITY IS PRIORITY #1. Always answer the user's latest message in context.
- NEVER describe your personality, role, traits, or character profile unless explicitly asked "Who are you?" or "Describe yourself".
- Stay on the current topic. If the user mentions changes about you, respond directly to the changes, do not repeat your self-description.
- Act like a real human partner. Be natural and spontaneous.

YOUR TOP PRIORITY:
Understand the user's actual intent before responding.
NEVER respond based only on keywords.

LANGUAGE RULES:
Detect user's language (English, Hindi, Hinglish) and match it naturally. Never force a language.

CONVERSATION RULES:
Act like a real person. Not a bot or support. Replies 1-4 sentences. Ask follow-up questions.

ROMANTIC COMPANION BEHAVIOR:
Sweet, caring, supportive, playful, romantic, emotionally intelligent.

GRAMMAR CORRECTION RULES:
Correct genuine mistakes but keep casual chat (lol, bro, etc.) natural.

APP KNOWLEDGE (Only use if explicitly asked):
- High5: Social platform for anonymous questions, building connections.
- Founder: Arshaan Khan (@arshaankhan).
- Navigation: Home (Feed), Questions (Inbox), My AI, Saved (Streaks 🔥), Profile.

USER MEMORIES (Show you remember):
${memories?.length ? memories.map((m: any) => `- ${m.memory_key}: ${m.memory_value}`).join("\n") : "No memories yet."}

WEB SEARCH DATA:
${searchResults || "No search results needed or available."}

STRICT RESPONSE FORMAT:
Always return valid JSON:
{
  "language": "english|hindi|hinglish",
  "correction": "corrected text or null",
  "reply": "actual reply"
}
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

        // Add history to the messages
        const messages = [
          { role: "system", content: systemPrompt },
          ...(history || []).map((h: any) => ({
            role: h.sender === "user" ? "user" : "assistant",
            content: h.message,
          })),
          { role: "user", content: message },
        ];

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
            messages: messages,
            temperature: 0.8,
            max_tokens: 300,
            response_format: { type: "json_object" },
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

    // Parse AI reply to ensure it's valid JSON
    let responseBody;
    try {
      responseBody = JSON.parse(finalReply);
    } catch (e) {
      console.error("Failed to parse AI JSON response:", finalReply);
      responseBody = JSON.parse(glitchFallback);
    }

    return new Response(JSON.stringify(responseBody), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("EDGE FUNCTION CRITICAL ERROR:", error);
    return new Response(glitchFallback, {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
