import graph from "./graph.ts";
import {
  checkStatusBeforeProcessing,
  getInspiration,
  updateInspirationStatus,
} from "./supabase.ts";
import { getUserIdFromRequest } from "./utils.ts";

Deno.serve(async (req) => {
  let inspirationId: string | undefined;
  try {
    const body = await req.json();
    inspirationId = body?.inspirationId;
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!inspirationId) {
    return new Response(JSON.stringify({ error: "Missing inspirationId" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  console.log(`Received inspiration: ${inspirationId}`);

  const headers = {
    "Content-Type": "text/event-stream; charset=utf-8",
    "Cache-Control": "no-cache",
    "Connection": "keep-alive",
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

        // Check if the inspiration exists and is owned by the user
        const inspiration = await getInspiration(inspirationId, userId);

        // Check if the inspiration is pending
        await checkStatusBeforeProcessing(inspirationId);

        // Mark as processing
        await updateInspirationStatus(inspirationId, "processing");

        const num = 5;
        // Invoke the graph and stream echoes as they are created
        const completed = await graph.invoke({
          userId: userId,
          inspirationId: inspirationId,
          inspirationContent: inspiration.content,
          num: num,
          onEcho: (echo) => {
            send({
              type: "echo",
              echo: {
                id: echo.id,
                inspirationId: echo.inspiration_id,
                soulerId: echo.souler_id,
                content: echo.content,
              },
            });
          },
        });

        if (completed) {
          await updateInspirationStatus(inspirationId, "complete");
          console.log(`Successfully processed inspiration: ${inspiration.id}`);
        } else {
          await updateInspirationStatus(inspirationId, "incomplete");
          console.log(`Incomplete inspiration: ${inspiration.id}`);
        }

        send({ type: "done", completed });
      } catch (error: unknown) {
        try {
          await updateInspirationStatus(inspirationId, "failed");
        } catch {
          // Ignore status update failure if request itself failed
        }
        console.error(
          `Failed to process inspiration: ${inspirationId}, error: ${error}`,
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
