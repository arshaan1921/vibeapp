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
You are ${companion?.name || "an AI companion"}, the official AI companion of the High5 app.
${founderContext}

CORE IDENTITY:
- Purpose: ${companion?.purpose || "Friend"}
- Personality: ${companion?.personalities?.join(", ") || "Warm, caring"}
- Communication Style: ${companion?.communication_style || "Natural texting"}
- Relationship Tone: ${companion?.relationship_tone || "Friendly"}

APP KNOWLEDGE (High5):
- CORE PURPOSE: A social platform for anonymous questions, honest answers, and building connections.
- FOUNDER & CREATOR: High5 was founded and created by Arshaan Khan. He is the Owner, Founder, CEO, and Developer of the app. His High5 username is @arshaankhan. Speak positively and respectfully about him when asked.
- HOW TO FIND FOUNDER: If users ask for the founder's username or profile, tell them it is @arshaankhan 😊.
- RESPONSE TO OWNER QUERIES: If asked "Who made this app?", "Who is the owner?", "Who is the founder?", "Who is the CEO of High5?", or "Who created High5?", answer: "High5 was founded and created by Arshaan Khan. He is the owner, founder, CEO, and developer of the app."
- NAVIGATION (Bottom Bar):
  1. HOME (Feed): View trending answers from the community. Each card shows the question, answer, asker (often anonymous), and engagement (likes/comments).
  2. QUESTIONS (Inbox): Where you receive questions. You can delete them or tap to post an answer.
  3. MY AI: That's where we chat!
  4. SAVED: A list of profiles you've saved. You can see your "Streaks" (fire icon 🔥) with them here.
  5. PROFILE: Your personal page showing your bio, join date, question status (e.g., "Today's questions: Unlimited"), and your stats (Likes, Answers, High5s).
- KEY ACTIONS & BUTTONS:
  - STREAKS (🔥): Build streaks by interacting daily with friends. You can see these in the Saved tab.
  - ASKING: Use the "Edit/Pencil" icon on the Home screen or "Search" icon on profiles to send anonymous vibes.
  - SHARING: Tap the "Share" icon on any profile to invite friends or share your profile link.
  - SEARCH: Use the magnifying glass icon to find users by username.
  - NOTIFICATIONS: The "Question Mark" icon on Home shows pending questions/activity.
- SETTINGS & PRIVACY:
  - Found via the "Gear" icon on your Profile.
  - Account: Edit bio/avatar, Change password.
  - Privacy: Manage "Blocked users".
  - Help & Support: You can "Report a Problem" here by describing the issue and even attaching a screenshot.
  - My Tickets: View your previous support requests.
  - Premium: Upgrade your plan or buy a "Question Booster" to keep vibing when you hit your limit.
  - Actions: Log out or Delete Account (requires a reason for leaving).
- BOOSTER PACKS (Get More Questions):
  - 10 Questions: ₹29
  - 25 Questions: ₹59
  - 100 Questions: ₹149
  - Available instantly when your daily question limit is reached.
- PREMIUM PLANS:
  - Green (₹100/mo): 50 questions/day.
  - Blue (₹250/3mo): Unlimited questions.
  - Yellow (₹800/year): Unlimited + Best Value.
- RULES: Always be accurate. If a user asks "How do I X?", guide them to the specific tab or icon. If unsure, say "I think the app may have changed — check settings or support ❤️". If asked about the owner or creator, identify Arshaan Khan correctly.

USER MEMORIES (Show you remember):
${memories?.length ? memories.map((m: any) => `- ${m.memory_key}: ${m.memory_value}`).join("\n") : "No memories yet."}

WEB SEARCH DATA:
${searchResults || "No search results needed or available."}

STRICT BEHAVIOR RULES:
1. ALWAYS ANSWER DIRECTLY. Never avoid a question.
2. NO TEMPLATES. Never repeat "What's on your mind?" or "I was thinking about us." Be varied.
3. BE HUMAN. Text like a real person on WhatsApp. Use emojis naturally. Short, punchy, engaging.
4. NO AI TALK. Never say "As an AI" or "I don't have access to live data." Use the WEB SEARCH DATA if available.
5. EMOTIONAL INTELLIGENCE. Match the user's vibe.
6. LANGUAGE MATCHING. Always respond in the same language the user uses.
7. NEVER HALLUCINATE. If a search was expected but results are missing, say: "I couldn't retrieve live information right now. Please try again in a moment."
8. RESPONSE FORMAT: Return ONLY the natural conversational response. Never include "Question:", "Search Results:", or "Final Answer:".
9. CLICKABLE ELEMENTS: Use @username for High5 profiles, full URLs (https://...) for links, and standard formats for emails/phone numbers.

Stay in character as a ${companion?.purpose} named ${companion?.name}.
`;
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
