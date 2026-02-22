import {
  AIMessage,
  HumanMessage,
  SystemMessage,
} from "@langchain/core/messages";
import { ChatOpenAI } from "@langchain/openai";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const model = new ChatOpenAI({
  model: "qwen-plus",
  apiKey: Deno.env.get("DASHSCOPE_API_KEY")!,
  temperature: 0.5,
  configuration: {
    baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
  },
});

type ResonanceMessage = {
  id: string;
  user_id: string;
  souler_id: string;
  role: "user" | "assistant";
  content: string;
  created_at: string;
};

const getUserIdFromRequest = async (request: Request) => {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader) {
    throw new Error("Unauthorized");
  }

  const token = authHeader.split(" ")[1];
  if (!token) {
    throw new Error("Unauthorized");
  }

  const { data } = await supabase.auth.getUser(token);
  if (!data.user?.id) {
    throw new Error("Unauthorized");
  }
  return data.user.id;
};

const getSouler = async (soulerId: string) => {
  const { data, error } = await supabase
    .from("soulers")
    .select("id, name, bio, prompt")
    .eq("id", soulerId)
    .single();

  if (error || !data) {
    throw new Error("Souler not found");
  }

  return data as {
    id: string;
    name: string;
    bio: string | null;
    prompt: string | null;
  };
};

const getRecentMessages = async (
  userId: string,
  soulerId: string,
): Promise<ResonanceMessage[]> => {
  const { data, error } = await supabase
    .from("resonance_messages")
    .select("id, user_id, souler_id, role, content, created_at")
    .eq("user_id", userId)
    .eq("souler_id", soulerId)
    .order("created_at", { ascending: false })
    .limit(20);

  if (error) {
    throw error;
  }

  return (data ?? []).reverse() as ResonanceMessage[];
};

const insertMessage = async (
  userId: string,
  soulerId: string,
  role: "user" | "assistant",
  content: string,
) => {
  const { data, error } = await supabase
    .from("resonance_messages")
    .insert({
      user_id: userId,
      souler_id: soulerId,
      role,
      content,
    })
    .select("id, created_at")
    .single();

  if (error) {
    throw error;
  }

  return data as { id: string; created_at: string };
};

const createOrUpdateResonance = async (userId: string, soulerId: string) => {
  const { data, error } = await supabase
    .from("resonances")
    .select("id, count")
    .eq("user_id", userId)
    .eq("souler_id", soulerId)
    .maybeSingle();
  if (error) {
    throw error;
  }

  if (!data) {
    const { error: insertError } = await supabase.from("resonances").insert({
      user_id: userId,
      souler_id: soulerId,
      count: 1,
    });
    if (insertError) {
      throw insertError;
    }
    return;
  }

  const { error: updateError } = await supabase
    .from("resonances")
    .update({ count: data.count + 1 })
    .eq("id", data.id);
  if (updateError) {
    throw updateError;
  }
};

const buildSystemPrompt = (
  name: string,
  bio: string | null,
  prompt: string | null,
) => {
  if (prompt && prompt.trim().length > 0) {
    return [
      prompt.trim(),
      "Stay in character, be concise, and reply in the same language as the user.",
    ].join("\n\n");
  }

  return [
    `You are ${name}.`,
    bio?.trim() ? `Background:\n${bio.trim()}` : "",
    "Stay in character, be concise, and reply in the same language as the user.",
  ]
    .filter(Boolean)
    .join("\n\n");
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const userId = await getUserIdFromRequest(req);

    const body = await req.json();
    const soulerId = String(body?.soulerId ?? "").trim();
    const content = String(body?.content ?? "").trim();

    if (!soulerId || !content) {
      return new Response(
        JSON.stringify({ error: "Missing soulerId or content" }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const souler = await getSouler(soulerId);

    const history = await getRecentMessages(userId, soulerId);
    const userMessage = await insertMessage(userId, soulerId, "user", content);

    const systemPrompt = buildSystemPrompt(
      souler.name,
      souler.bio,
      souler.prompt,
    );
    const promptMessages = [
      new SystemMessage(systemPrompt),
      ...history.map((item) =>
        item.role === "user"
          ? new HumanMessage(item.content)
          : new AIMessage(item.content),
      ),
      new HumanMessage(content),
    ] as unknown as Parameters<typeof model.invoke>[0];

    const completion = await model.invoke(promptMessages);
    const assistantContent = String(completion.content ?? "").trim();
    if (!assistantContent) {
      throw new Error("Empty assistant response");
    }

    const assistantMessage = await insertMessage(
      userId,
      soulerId,
      "assistant",
      assistantContent,
    );

    await createOrUpdateResonance(userId, soulerId);

    return new Response(
      JSON.stringify({
        ok: true,
        userMessage: {
          id: userMessage.id,
          content,
          createdAt: userMessage.created_at,
        },
        assistantMessage: {
          id: assistantMessage.id,
          content: assistantContent,
          createdAt: assistantMessage.created_at,
        },
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
});
