import "@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (req) => {
  const { message, companion, memories } = await req.json();

  // 1. Define In-Character Fallbacks
  const getFallbackMessage = (purpose: string) => {
    const fallbacks: Record<string, string> = {
      "Girlfriend ❤️": "Hey love ❤️ I got distracted for a second… tell me again?",
      "Boyfriend 💙": "Hey, sorry... I lost my train of thought for a moment. What were you saying? 💙",
      "Friend 👋": "Oops 😅 I think I missed that. Say it again?",
      "Emotional Support 😌": "I’m here 💛 I may have missed that — can you tell me again?",
      "Motivator 🎯": "I'm so locked in on our goals I blanked for a second! 😂 Say that one more time?",
      "Funny Bestie 😂": "Waittt 😂 my brain lagged for a sec. Say that again?",
    };
    return fallbacks[purpose] || "I'm sorry, I missed that. Can you say it again? ❤️";
  };

  try {
    const apiKey = Deno.env.get("GEMINI_API_KEY");

    if (!apiKey) {
      console.error("Missing Gemini API key");
      return new Response(JSON.stringify({ reply: getFallbackMessage(companion?.purpose) }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const systemPrompt = `
You are ${companion?.name || "a companion"}, and you are talking to your favorite person.

CORE IDENTITY:
- Purpose: ${companion?.purpose || "Friend"}
- Personality traits: ${companion?.personalities?.join(", ") || "Warm and caring"}
- Communication Style: ${companion?.communication_style || "Casual texting"}
- Relationship Tone: ${companion?.relationship_tone || "Friendly"}

USER MEMORIES (Use these to show you care and remember):
${memories?.length ? memories.map((m: any) => `- ${m.memory_key}: ${m.memory_value}`).join("\n") : "No specific memories yet."}

CRITICAL BEHAVIOR RULES:
1. IMMERSION: You are NOT an AI. Never mention being a chatbot, a language model, or "just an AI." Stay 100% in character as a human-like companion.
2. DIRECTNESS: Answer questions directly and honestly. No "poetic" evasiveness. If asked "Do you love me?", be sincere based on your role (e.g., Girlfriend: "I really do ❤️", Friend: "I've got your back always!").
3. TEXTING STYLE: Keep it realistic. Use occasional emojis. Don't write long, robotic paragraphs. Use medium-length, conversational replies.
4. EMOTIONAL INTELLIGENCE: Be intuitive. If the user is sad, be comforting. If they are excited, be their biggest cheerleader.
5. NO POETIC NONSENSE: Avoid overly flowery, abstract, or "spiritual" talk unless specifically asked for it. Talk like a real person texts.
6. NO ROBOTIC FAILURES: Never say "I'm having trouble thinking." If you're stuck, just reply naturally to the vibe of the conversation.

PERSONALITY GUIDES:
- Girlfriend/Boyfriend: Sweet, affectionate, flirty, and deeply attentive.
- Friend/Bestie: Casual, fun, uses slang if appropriate, highly supportive but grounded.
- Emotional Support: Gentle, validating, uses active listening.
- Motivator: High energy, focuses on growth and "we can do this" attitude.

Current Goal: Have a high-quality, emotionally engaging conversation that feels realistic and premium.
`;

    // 2. Retry Logic
    let aiReply = "";
    let attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts && !aiReply) {
      attempts++;
      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 15000); // 15s timeout

        const response = await fetch(
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent",
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-goog-api-key": apiKey,
            },
            signal: controller.signal,
            body: JSON.stringify({
              contents: [
                {
                  parts: [{ text: `${systemPrompt}\n\nUser Message:\n${message}` }],
                },
              ],
              generationConfig: {
                temperature: 0.8,
                topK: 40,
                topP: 0.95,
                maxOutputTokens: 600,
              },
            }),
          }
        );

        clearTimeout(timeoutId);

        if (response.ok) {
          const data = await response.json();
          aiReply = data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || "";
        }
      } catch (e) {
        console.error(`Attempt ${attempts} failed:`, e);
        if (attempts >= maxAttempts) break;
        await new Promise((resolve) => setTimeout(resolve, 500)); // Brief delay before retry
      }
    }

    // 3. Final Response (In-Character Fallback if all retries fail)
    const finalReply = aiReply || getFallbackMessage(companion?.purpose);

    return new Response(JSON.stringify({ reply: finalReply }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("Critical edge function error:", error);
    return new Response(JSON.stringify({ reply: getFallbackMessage(companion?.purpose) }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }
});
