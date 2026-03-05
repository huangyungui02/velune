import graph from "./graph.ts";
import { type Lang } from "./lang.ts";
import {
  checkStatusBeforeProcessing,
  getGlimmer,
  updateGlimmerStatus,
} from "./supabase.ts";
import { getUserIdFromRequest } from "./utils.ts";

Deno.serve(async (req) => {
  let glimmerId: string | undefined;
  let lang: Lang | undefined;
  try {
    const body = await req.json();
    glimmerId = body?.glimmerId;
    lang = body?.lang;
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!glimmerId) {
    return new Response(JSON.stringify({ error: "Missing glimmerId" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (lang !== "en" && lang !== "zh") {
    return new Response(JSON.stringify({ error: "Missing or invalid lang" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  console.log(`Received glimmer: ${glimmerId}`);

  const headers = {
    "Content-Type": "text/event-stream; charset=utf-8",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
  };

  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();
      const send = (payload: Record<string, unknown>) => {
        controller.enqueue(
          encoder.encode(`data: ${JSON.stringify(payload)}\n\n`),
        );
      };

      try {
        // Get the user ID from the request
        const userId = await getUserIdFromRequest(req);

        // Check if the glimmer exists and is owned by the user
        const glimmer = await getGlimmer(glimmerId, userId);

        // Check if the glimmer is pending
        await checkStatusBeforeProcessing(glimmerId);

        // Mark as processing
        await updateGlimmerStatus(glimmerId, "processing");

        const num = 5;
        // Invoke the graph and stream echoes as they are created
        const completed = await graph.invoke({
          userId: userId,
          glimmerId: glimmerId,
          glimmerContent: glimmer.content,
          num: num,
          lang: lang,
          onEcho: (echo: {
            id: string;
            glimmer_id: string;
            souler_id: string;
            session_id: string | null;
            content: string;
          }) => {
            send({
              type: "echo",
              echo: {
                id: echo.id,
                glimmerId: echo.glimmer_id,
                soulerId: echo.souler_id,
                sessionId: echo.session_id,
                content: echo.content,
              },
            });
          },
        });

        if (completed) {
          await updateGlimmerStatus(glimmerId, "complete");
          console.log(`Successfully processed glimmer: ${glimmer.id}`);
        } else {
          await updateGlimmerStatus(glimmerId, "incomplete");
          console.log(`Incomplete glimmer: ${glimmer.id}`);
        }

        send({ type: "done" });
      } catch (error: unknown) {
        try {
          await updateGlimmerStatus(glimmerId, "failed");
        } catch {
          // Ignore status update failure if request itself failed
        }
        console.error(
          `Failed to process glimmer: ${glimmerId}, error: ${error}`,
        );
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
