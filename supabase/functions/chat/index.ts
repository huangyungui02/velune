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

type MessageRow = {
  id: string;
  user_id: string;
  souler_id: string;
  session_id: string | null;
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

const getSession = async (userId: string, sessionId: string) => {
  const { data, error } = await supabase
    .from("sessions")
    .select("id, user_id, souler_id, title, soulers(id, name, bio, prompt)")
    .eq("id", sessionId)
    .eq("user_id", userId)
    .single();

  if (error || !data) {
    throw new Error("Session not found");
  }

  const souler = Array.isArray(data.soulers) ? data.soulers[0] : data.soulers;
  if (!souler?.id || !souler?.name) {
    throw new Error("Souler not found");
  }

  return {
    id: data.id as string,
    soulerId: data.souler_id as string,
    souler: {
      id: souler.id as string,
      name: souler.name as string,
      bio: (souler.bio ?? null) as string | null,
      prompt: (souler.prompt ?? null) as string | null,
    },
  };
};

const getRecentMessages = async (
  userId: string,
  sessionId: string,
): Promise<MessageRow[]> => {
  const { data, error } = await supabase
    .from("messages")
    .select("id, user_id, souler_id, session_id, role, content, created_at")
    .eq("user_id", userId)
    .eq("session_id", sessionId)
    .order("created_at", { ascending: false })
    .limit(20);

  if (error) {
    throw error;
  }

  return (data ?? []).reverse() as MessageRow[];
};

const insertMessage = async (
  userId: string,
  soulerId: string,
  sessionId: string,
  role: "user" | "assistant",
  content: string,
) => {
  const { data, error } = await supabase
    .from("messages")
    .insert({
      user_id: userId,
      souler_id: soulerId,
      session_id: sessionId,
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

const touchSession = async (userId: string, sessionId: string) => {
  const { error } = await supabase
    .from("sessions")
    .update({ updated_at: new Date().toISOString() })
    .eq("id", sessionId)
    .eq("user_id", userId);

  if (error) {
    throw error;
  }
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

const isChineseName = (name: string) => /[\p{Script=Han}]/u.test(name);

const buildSystemPrompt = (
  name: string,
  bio: string | null,
  prompt: string | null,
) => {
  const useChinesePrompt = isChineseName(name);
  const localeInstruction = useChinesePrompt
    ? "保持角色设定，表达简洁。"
    : "Stay in character and be concise.";
  const languageRule = useChinesePrompt
    ? "使用与用户相同的语言回复。"
    : "reply in the same language as the user.";

  if (prompt && prompt.trim().length > 0) {
    return [prompt.trim(), localeInstruction, languageRule].join("\n\n");
  }

  const profileIntro = useChinesePrompt ? `你是${name}。` : `You are ${name}.`;
  const profileBio = bio?.trim()
    ? useChinesePrompt
      ? `背景：\n${bio.trim()}`
      : `Background:\n${bio.trim()}`
    : "";

  return [profileIntro, profileBio, localeInstruction, languageRule]
    .filter(Boolean)
    .join("\n\n");
};

const contentToText = (content: unknown): string => {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";

  return content
    .map((part) => {
      if (typeof part === "string") return part;
      if (part && typeof part === "object" && "text" in part) {
        const text = (part as { text?: unknown }).text;
        return typeof text === "string" ? text : "";
      }
      return "";
    })
    .join("");
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const headers = {
    "Content-Type": "text/event-stream; charset=utf-8",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
  };

  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();
      const send = (payload: Record<string, unknown>) => {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(payload)}\n\n`));
      };

      try {
        const userId = await getUserIdFromRequest(req);

        const body = await req.json();
        const sessionId = String(body?.sessionId ?? "").trim();
        const content = String(body?.content ?? "").trim();

        if (!sessionId || !content) {
          throw new Error("Missing sessionId or content");
        }

        const session = await getSession(userId, sessionId);
        const souler = session.souler;

        const history = await getRecentMessages(userId, sessionId);

        await insertMessage(userId, session.soulerId, sessionId, "user", content);

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
              : new AIMessage(item.content)
          ),
          new HumanMessage(content),
        ] as unknown as Parameters<typeof model.stream>[0];

        let assistantContent = "";
        const completionStream = await model.stream(promptMessages);
        for await (const chunk of completionStream) {
          const delta = contentToText(chunk.content);
          if (!delta) continue;
          assistantContent += delta;
          send({ type: "delta", delta });
        }

        const finalContent = assistantContent.trim();
        if (!finalContent) {
          throw new Error("Empty assistant response");
        }

        const assistantMessage = await insertMessage(
          userId,
          session.soulerId,
          sessionId,
          "assistant",
          finalContent,
        );

        await touchSession(userId, sessionId);
        await createOrUpdateResonance(userId, session.soulerId);
        send({
          type: "done",
          assistantMessage: {
            id: assistantMessage.id,
            createdAt: assistantMessage.created_at,
          },
        });
      } catch (error) {
        send({
          type: "error",
          message: error instanceof Error ? error.message : String(error),
        });
      } finally {
        controller.close();
      }
    },
  });

  return new Response(stream, { headers });
});
