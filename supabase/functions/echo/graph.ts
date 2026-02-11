import { entrypoint } from "@langchain/langgraph";
import {
  matchSoulers,
  parseSouler,
  soulerAnswer,
  soulerProfile,
  soulerPrompt,
} from "./nodes/index.ts";
import {
  createEcho,
  createOrUpdateResonance,
  getOrCreateSoulerByName,
  updateSouler,
} from "./supabase.ts";

const graph = entrypoint(
  { name: "agent" },
  async (
    { userId, inspirationId, inspirationContent, num, onEcho }: {
      userId: string;
      inspirationId: string;
      inspirationContent: string;
      num: number;
      onEcho?: (echo: {
        id: string;
        inspiration_id: string;
        souler_id: string;
        content: string;
      }) => void | Promise<void>;
    },
  ) => {
    const soulers = await matchSoulers(inspirationContent, num);
    const results = await Promise.allSettled(
      soulers.map(async (item) => {
        // Query or create souler
        const { name } = await parseSouler(item.souler, item.content);
        const soulerData = await getOrCreateSoulerByName(name);
        // Create or update resonance
        await createOrUpdateResonance(userId, soulerData.id);

        // Query or create souler profile
        if (!soulerData.bio) {
          const bio = await soulerProfile(name);
          soulerData.bio = bio;
          await updateSouler(soulerData.id, { bio });
        }

        // Query or create souler prompt
        if (!soulerData.prompt) {
          const prompt = await soulerPrompt(name);
          soulerData.prompt = prompt;
          await updateSouler(soulerData.id, { prompt });
        }

        // Answer the question
        const answer = await soulerAnswer(
          inspirationContent,
          soulerData.prompt,
        );
        const echo = await createEcho(inspirationId, soulerData.id, answer);
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
