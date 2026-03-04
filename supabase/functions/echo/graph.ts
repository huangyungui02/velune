import { entrypoint } from "@langchain/langgraph";
import {
  fetchWikipediaCanonicalName,
  matchSoulers,
  parseSouler,
  sessionTitle,
  soulerAnswer,
  soulerProfile,
  soulerPrompt,
} from "./nodes/index.ts";
import { type Lang } from "./prompts.ts";
import {
  appendSoulerAlias,
  createSession,
  createSouler,
  createEcho,
  createOrUpdateResonance,
  getSoulerByAlias,
  getSoulerByWikiId,
  insertSessionMessage,
  updateSouler,
} from "./supabase.ts";

const graph = entrypoint(
  { name: "agent" },
  async (
    { userId, glimmerId, glimmerContent, num, lang, onEcho }: {
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
    },
  ) => {
    const soulers = await matchSoulers(glimmerContent, num, lang);
    const results = await Promise.allSettled(
      soulers.map(async (item) => {
        const { name: parsedName } = await parseSouler(item.souler, item.content, lang);
        let soulerData = await getSoulerByAlias(parsedName);
        if (!soulerData) {
          const wikiResolved = await fetchWikipediaCanonicalName(parsedName, lang);
          const canonicalName = wikiResolved.name;
          const wikiId = wikiResolved.wikiId;
          if (!wikiId) {
            throw new Error(
              `Missing wikiId for parsedName: ${parsedName}, canonicalName: ${canonicalName}`,
            );
          }
          soulerData = await getSoulerByWikiId(wikiId);
          if (soulerData) {
            soulerData = await appendSoulerAlias(soulerData.id, parsedName);
          } else {
            const aliases = canonicalName === parsedName
              ? [canonicalName]
              : [canonicalName, parsedName];
            soulerData = await createSouler(
              canonicalName,
              aliases,
              wikiId,
            );
          }
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
        const echo = await createEcho(glimmerId, soulerData.id, answer, session.id);
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
