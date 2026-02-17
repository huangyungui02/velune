import { entrypoint } from "@langchain/langgraph";
import {
  matchSoulers,
  parseSouler,
  soulerAnswer,
  soulerProfile,
  soulerPrompt,
} from "./nodes/index.ts";
import { detectLang } from "./prompts.ts";
import {
  createEcho,
  createOrUpdateResonance,
  getOrCreateSoulerByName,
  updateSouler,
} from "./supabase.ts";

const graph = entrypoint(
  { name: "agent" },
  async (
    { userId, glimmerId, glimmerContent, num, onEcho }: {
      userId: string;
      glimmerId: string;
      glimmerContent: string;
      num: number;
      onEcho?: (echo: {
        id: string;
        glimmer_id: string;
        souler_id: string;
        content: string;
      }) => void | Promise<void>;
    },
  ) => {
    const lang = detectLang(glimmerContent);
    const soulers = await matchSoulers(glimmerContent, num, lang);
    const results = await Promise.allSettled(
      soulers.map(async (item) => {
        const { name } = await parseSouler(item.souler, item.content, lang);
        const soulerData = await getOrCreateSoulerByName(name);
        await createOrUpdateResonance(userId, soulerData.id);

        if (!soulerData.bio) {
          const bio = await soulerProfile(name, lang);
          soulerData.bio = bio;
          await updateSouler(soulerData.id, { bio });
        }

        if (!soulerData.prompt) {
          const prompt = await soulerPrompt(name, lang);
          soulerData.prompt = prompt;
          await updateSouler(soulerData.id, { prompt });
        }

        const answer = await soulerAnswer(
          glimmerContent,
          soulerData.prompt,
          lang,
        );
        const echo = await createEcho(glimmerId, soulerData.id, answer);
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
