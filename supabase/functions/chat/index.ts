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

type SessionContext = {
  id: string;
  soulerId: string;
  souler: {
    id: string;
    name: string;
    bio: string | null;
    prompt: string | null;
  };
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

const toSouler = (raw: unknown) => {
  const souler = Array.isArray(raw) ? raw[0] : raw;
  if (!souler || typeof souler !== "object") {
    throw new Error("Souler not found");
  }

  const id = String((souler as Record<string, unknown>).id ?? "").trim();
  const name = String((souler as Record<string, unknown>).name ?? "").trim();
  if (!id || !name) {
    throw new Error("Souler not found");
  }

  return {
    id,
    name,
    bio: ((souler as Record<string, unknown>).bio ?? null) as string | null,
    prompt: ((souler as Record<string, unknown>).prompt ?? null) as string | null,
  };
};

const getSessionById = async (
  userId: string,
  sessionId: string,
): Promise<SessionContext> => {
  const { data, error } = await supabase
    .from("sessions")
    .select("id, user_id, souler_id, title, soulers(id, name, bio, prompt)")
    .eq("id", sessionId)
    .eq("user_id", userId)
    .single();

  if (error || !data) {
    throw new Error("Session not found");
  }

  return {
    id: data.id as string,
    soulerId: data.souler_id as string,
    souler: toSouler(data.soulers),
  };
};

const getSoulerById = async (soulerId: string) => {
  const { data, error } = await supabase
    .from("soulers")
    .select("id, name, bio, prompt")
    .eq("id", soulerId)
    .single();
  if (error || !data) {
    throw new Error("Souler not found");
  }
  return toSouler(data);
};

const createSession = async (userId: string, soulerId: string) => {
  const { data, error } = await supabase
    .from("sessions")
    .insert({
      user_id: userId,
      souler_id: soulerId,
      title: "",
    })
    .select("id")
    .single();
  if (error || !data?.id) {
    throw error ?? new Error("Failed to create session");
  }
  return String(data.id);
};

const updateSessionTitle = async (
  userId: string,
  sessionId: string,
  title: string,
) => {
  const { error } = await supabase
    .from("sessions")
    .update({ title })
    .eq("id", sessionId)
    .eq("user_id", userId);
  if (error) {
    throw error;
  }
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

const sanitizeTitle = (raw: string) => {
  const trimmed = raw.trim().replace(/^["'`]+|["'`]+$/g, "");
  if (!trimmed) {
    return "New Chat";
  }

  if (/[\p{Script=Han}]/u.test(trimmed)) {
    return trimmed.slice(0, 16);
  }

  return trimmed
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 8)
    .join(" ");
};

const generateSessionTitle = async (userContent: string, replyContent: string) => {
  const response = await model.invoke([
    new SystemMessage(
      "Create a concise chat title based on the user message and assistant reply. Keep it under 8 words, no punctuation, no quotes, and return only title text.",
    ),
    new HumanMessage(`User:\n${userContent}\n\nAssistant:\n${replyContent}`),
  ] as unknown as Parameters<typeof model.invoke>[0]);
  return sanitizeTitle(contentToText(response.content));
};

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
        const soulerId = String(body?.soulerId ?? "").trim();
        const content = String(body?.content ?? "").trim();

        if (!content) {
          throw new Error("Missing content");
        }

        const isNewSession = !sessionId;
        let session: SessionContext;
        if (sessionId) {
          session = await getSessionById(userId, sessionId);
        } else {
          if (!soulerId) {
            throw new Error("Missing soulerId for new conversation");
          }
          const souler = await getSoulerById(soulerId);
          const createdSessionId = await createSession(userId, souler.id);
          session = {
            id: createdSessionId,
            soulerId: souler.id,
            souler,
          };
        }
        const souler = session.souler;

        const history = await getRecentMessages(userId, session.id);

        await insertMessage(userId, session.soulerId, session.id, "user", content);

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
          session.id,
          "assistant",
          finalContent,
        );

        let generatedTitle: string | null = null;
        if (isNewSession) {
          generatedTitle = await generateSessionTitle(content, finalContent);
          await updateSessionTitle(userId, session.id, generatedTitle);
        }

        await touchSession(userId, session.id);
        await createOrUpdateResonance(userId, session.soulerId);
        send({
          type: "done",
          sessionId: session.id,
          title: generatedTitle,
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
