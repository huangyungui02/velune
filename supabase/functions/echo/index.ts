import graph from "./graph.ts";
import {
  checkStatusBeforeProcessing,
  getInspiration,
  updateInspirationStatus,
} from "./supabase.ts";

import { getUserIdFromRequest } from "./utils.ts";

Deno.serve(async (req) => {
  const { inspirationId }: { inspirationId: string } = await req.json();
  console.log(`Received inspiration: ${inspirationId}`);
  try {
    // Get the user ID from the request
    const userId = await getUserIdFromRequest(req);

    // Check if the inspiration exists and is owned by the user
    const inspiration = await getInspiration(inspirationId, userId);

    // Check if the inspiration is pending
    await checkStatusBeforeProcessing(inspirationId);

    const num = 5;
    // Invoke the graph
    const completed = await graph.invoke({
      userId: userId,
      inspirationId: inspirationId,
      inspirationContent: inspiration.content,
      num: num,
    });
    if (completed) {
      // Update the inspiration status to complete
      await updateInspirationStatus(inspirationId, "complete");
      console.log(`Successfully processed inspiration: ${inspiration.id}`);
    } else {
      // Update the inspiration status to incomplete
      await updateInspirationStatus(inspirationId, "incomplete");
      console.log(`Incomplete inspiration: ${inspiration.id}`);
    }
  } catch (error: unknown) {
    // Update the inspiration status to failed
    await updateInspirationStatus(inspirationId, "failed");

    // const err = error instanceof Error ? error : new Error(String(error));
    console.error(
      `Failed to process inspiration: ${inspirationId}, error: ${error}`,
    );
    return new Response(JSON.stringify({ error }), {
      status: 500,
    });
  }
  // Return success
  return new Response(
    "success",
    { headers: { "Content-Type": "application/json" } },
  );
});
