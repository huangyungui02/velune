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
  createSession,
  createSouler,
  createEcho,
  createOrUpdateResonance,
  getSoulerByAlias,
  insertSessionMessage,
  updateSouler,
} from "./supabase.ts";

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

        await createOrUpdateResonance(userId, soulerData.id);

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
        if (onEcho) {
          await onEcho(echo);
        }
      }),
    );

    const errors: Error[] = [];
    let completed = true;
    for (const result of results) {
      if (result.status === "rejected") {
        errors.push(result.reason);
      }
    }
    if (errors.length === num) {
      throw new Error(`Errors when creating echoes: ${JSON.stringify(errors)}`);
    }
    if (errors.length > 0) {
      console.error(`Errors when creating echoes: ${JSON.stringify(errors)}`);
      completed = false;
    }
    return completed;
  },
);

export default graph;
