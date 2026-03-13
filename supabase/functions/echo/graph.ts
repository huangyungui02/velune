import { entrypoint } from "@langchain/langgraph";
import {
  generateSoulerAliases,
  matchSoulers,
  sessionTitle,
  soulerAnswer,
  soulerProfile,
  soulerPrompt,
} from "./nodes/index.ts";
import { type Lang } from "./lang.ts";
import {
  appendSoulerAlias,
  consumeUserCredit,
  CreditLimitError,
  createSession,
  createSouler,
  createEcho,
  createOrUpdateResonance,
  getSoulerByAlias,
  insertSessionMessage,
  updateSouler,
} from "./supabase.ts";

const safeJsonStringify = (value: unknown) => {
  try {
    return JSON.stringify(value);
  } catch {
    return undefined;
  }
};

const reasonToMessage = (reason: unknown) => {
  if (reason instanceof Error && reason.message.trim()) {
    return reason.message;
  }
  if (typeof reason === "string" && reason.trim()) {
    return reason;
  }
  if (reason && typeof reason === "object") {
    const record = reason as Record<string, unknown>;
    const candidate = [
      record.message,
      record.error,
      record.details,
      record.hint,
    ].find((value) => typeof value === "string" && value.trim().length > 0);
    if (typeof candidate === "string") {
      return candidate;
    }

    const serialized = safeJsonStringify(reason);
    if (serialized && serialized !== "{}") {
      return serialized;
    }
  }
  return "Unknown failure";
};

type GraphCreditState = {
  plan: string;
  monthlyLimit: number;
  creditsRemaining: number;
};

const graph = entrypoint(
  { name: "agent" },
  async ({
    userId,
    glimmerId,
    glimmerContent,
    num,
    lang,
    onEcho,
  }: {
    userId: string;
    glimmerId: string;
    glimmerContent: string;
    num: number;
    lang: Lang;
    onEcho?: (echo: {
      id: string;
      glimmer_id: string;
      souler_id: string;
      session_id: string | null;
      content: string;
    }) => void | Promise<void>;
  }) => {
    const soulers = (await matchSoulers(glimmerContent, num, lang)) as Array<{
      souler: string;
      content: string;
    }>;
    console.log(`soulers: ${JSON.stringify(soulers)}`);
    const results = await Promise.allSettled(
      soulers.map(async (item) => {
        const matchedName = item.souler.trim();
        if (!matchedName) {
          throw new Error("Matched souler name cannot be empty");
        }
        let soulerData = await getSoulerByAlias(matchedName);
        if (!soulerData) {
          const aliases = await generateSoulerAliases(matchedName, lang);
          soulerData = await createSouler(matchedName, aliases);
        } else {
          soulerData = await appendSoulerAlias(soulerData.id, matchedName);
        }

        if (!soulerData.bio) {
          const bio = await soulerProfile(soulerData.name, lang);
          soulerData.bio = bio;
          await updateSouler(soulerData.id, { bio });
        }

        if (!soulerData.prompt) {
          const prompt = await soulerPrompt(soulerData.name, lang);
          soulerData.prompt = prompt;
          await updateSouler(soulerData.id, { prompt });
        }

        const creditState = await consumeUserCredit(userId);
        const answer = await soulerAnswer(
          glimmerContent,
          soulerData.prompt,
          lang,
        );
        const title = await sessionTitle(glimmerContent, answer, lang);
        const session = await createSession(userId, soulerData.id, title);
        await insertSessionMessage(
          userId,
          soulerData.id,
          session.id,
          "user",
          glimmerContent,
        );
        await insertSessionMessage(
          userId,
          soulerData.id,
          session.id,
          "assistant",
          answer,
        );
        const echo = await createEcho(
          glimmerId,
          soulerData.id,
          answer,
          session.id,
        );
        await createOrUpdateResonance(userId, soulerData.id);
        if (onEcho) {
          await onEcho(echo);
        }
        return creditState;
      }),
    );

    const errors: string[] = [];
    let firstCreditLimitError: CreditLimitError | null = null;
    let finalCreditState: GraphCreditState | null = null;
    let completed = true;
    for (const result of results) {
      if (result.status === "rejected") {
        errors.push(reasonToMessage(result.reason));
        if (
          !firstCreditLimitError &&
          result.reason instanceof CreditLimitError
        ) {
          firstCreditLimitError = result.reason;
        }
        continue;
      }

      if (!finalCreditState) {
        finalCreditState = result.value;
        continue;
      }

      finalCreditState = {
        plan: result.value.plan,
        monthlyLimit: result.value.monthlyLimit,
        creditsRemaining: Math.min(
          finalCreditState.creditsRemaining,
          result.value.creditsRemaining,
        ),
      };
    }

    if (errors.length === num) {
      if (firstCreditLimitError) {
        throw firstCreditLimitError;
      }
      throw new Error(`Errors when creating echoes: ${errors.join(" | ")}`);
    }
    if (errors.length > 0) {
      console.error(`Errors when creating echoes: ${errors.join(" | ")}`);
      completed = false;
    }
    return {
      completed,
      creditState: finalCreditState,
    };
  },
);

export default graph;
