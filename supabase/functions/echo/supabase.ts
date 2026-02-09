import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

export const getUserId = async (jwt: string) => {
  const { data } = await supabase.auth.getUser(jwt);
  return data.user?.id;
};

export const checkStatusBeforeProcessing = async (inspirationId: string) => {
  const { data, error } = await supabase.from("inspirations")
    .select("status")
    .eq("id", inspirationId)
    .single();
  const status = data?.status;
  if (error) {
    throw error;
  }
  if (status !== "pending") {
    throw new Error("Inspiration is not pending");
  }
};

export const updateInspirationStatus = async (
  inspirationId: string,
  status: "processing" | "complete" | "incomplete" | "failed",
) => {
  const { error } = await supabase.from("inspirations").update({ status })
    .eq("id", inspirationId);
  if (error) {
    throw error;
  }
};

export const getInspiration = async (inspirationId: string, userId: string) => {
  const { data, error } = await supabase.from("inspirations").select("*")
    .eq("id", inspirationId)
    .eq("user_id", userId)
    .single();
  if (error) {
    throw error;
  }
  return data;
};

export const getOrCreateSoulerByName = async (
  name: string,
  alias: string | undefined,
) => {
  // check if souler exists by name or alias
  let query = supabase.from("soulers").select().eq("name", name);
  if (alias) {
    query = query.or(`alias.eq.${alias}`);
  }
  const { data, error } = await query.maybeSingle();
  if (error) {
    console.error(`Error getting or creating souler: ${error.message}`);
    throw error;
  }

  // if souler does not exist, create it
  if (!data) {
    return await createSouler(name, alias);
  }
  return data;
};

const createSouler = async (name: string, alias: string | undefined) => {
  const { data, error } = await supabase.from("soulers").insert({ name, alias })
    .select().single();
  if (error) {
    console.error(`Error creating souler: ${error.message}`);
    throw error;
  }
  return data;
};

export const updateSouler = async (
  id: string,
  data: Record<string, unknown>,
) => {
  const { data: updatedData, error } = await supabase.from("soulers").update(
    data,
  ).eq("id", id).select().single();
  if (error) {
    throw error;
  }
  return updatedData;
};

export const createEcho = async (
  inspirationId: string,
  soulerId: string,
  content: string,
) => {
  const { data, error } = await supabase.from("echoes").insert({
    inspiration_id: inspirationId,
    souler_id: soulerId,
    content,
  })
    .select().single();
  if (error) {
    throw error;
  }
  return data;
};

export const createOrUpdateResonance = async (
  userId: string,
  soulerId: string,
) => {
  // check if resonance exists
  const { data, error } = await supabase.from("resonances").select()
    .eq("user_id", userId)
    .eq("souler_id", soulerId)
    .maybeSingle();
  if (error) {
    throw error;
  }
  // if resonance does not exist, create it
  if (!data) {
    return await createResonance(userId, soulerId);
  }
  // if resonance exists, update count
  return await updateResonance(data.id, { count: data.count + 1 });
};

const createResonance = async (userId: string, soulerId: string) => {
  const { data, error } = await supabase.from("resonances").insert({
    user_id: userId,
    souler_id: soulerId,
  }).select().single();
  if (error) {
    throw error;
  }
  return data;
};

const updateResonance = async (id: string, data: Record<string, unknown>) => {
  const { data: updatedData, error } = await supabase.from("resonances").update(
    data,
  ).eq("id", id).select().single();
  if (error) {
    throw error;
  }
  return updatedData;
};
