import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

export const getUserId = async (jwt: string) => {
  const { data } = await supabase.auth.getUser(jwt);
  return data.user?.id;
};

export const checkStatusBeforeProcessing = async (glimmerId: string) => {
  const { data, error } = await supabase.from("glimmers")
    .select("status")
    .eq("id", glimmerId)
    .single();
  const status = data?.status;
  if (error) {
    throw error;
  }
  if (status !== "pending") {
    throw new Error("Glimmer is not pending");
  }
};

export const updateGlimmerStatus = async (
  glimmerId: string,
  status: "processing" | "complete" | "incomplete" | "failed",
) => {
  const { error } = await supabase.from("glimmers").update({ status })
    .eq("id", glimmerId);
  if (error) {
    throw error;
  }
};

export const getGlimmer = async (glimmerId: string, userId: string) => {
  const { data, error } = await supabase.from("glimmers").select("*")
    .eq("id", glimmerId)
    .eq("user_id", userId)
    .single();
  if (error) {
    throw error;
  }
  return data;
};

export const getOrCreateSoulerByName = async (
  name: string,
) => {
  // Check if souler exists by canonical name.
  const { data, error } = await supabase.from("soulers").select().eq("name", name)
    .maybeSingle();
  if (error) {
    console.error(`Error getting or creating souler: ${error.message}`);
    throw error;
  }

  // if souler does not exist, create it
  if (!data) {
    return await createSouler(name);
  }
  return data;
};

const createSouler = async (name: string) => {
  const { data, error } = await supabase.from("soulers").insert({ name }).select()
    .single();
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
  glimmerId: string,
  soulerId: string,
  content: string,
) => {
  const { data, error } = await supabase.from("echoes").insert({
    glimmer_id: glimmerId,
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
