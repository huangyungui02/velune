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
  const { data, error } = await supabase
    .from("glimmers")
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
  const { error } = await supabase
    .from("glimmers")
    .update({ status })
    .eq("id", glimmerId);
  if (error) {
    throw error;
  }
};

export const getGlimmer = async (glimmerId: string, userId: string) => {
  const { data, error } = await supabase
    .from("glimmers")
    .select("*")
    .eq("id", glimmerId)
    .eq("user_id", userId)
    .single();
  if (error) {
    throw error;
  }
  return data;
};

export const getSoulerByAlias = async (candidateName: string) => {
  const query = candidateName.trim();
  if (!query) {
    return null;
  }
  const { data, error } = await supabase
    .from("soulers")
    .select()
    .contains("aliases", [query])
    .limit(1);
  if (error) {
    console.error(`Error querying souler by alias: ${error.message}`);
    throw error;
  }
  return data?.[0] ?? null;
};

export const createSouler = async (
  name: string,
  aliases: string[] = [],
) => {
  const { data, error } = await supabase
    .from("soulers")
    .insert({
      name,
      aliases,
    })
    .select()
    .single();
  if (error) {
    console.error(`Error creating souler: ${error.message}`);
    throw error;
  }
  return data;
};

export const appendSoulerAlias = async (soulerId: string, alias: string) => {
  const cleanedAlias = alias.trim();
  if (!cleanedAlias) {
    throw new Error("Alias cannot be empty");
  }
  const { data, error } = await supabase.rpc("append_souler_alias", {
    souler_id: soulerId,
    alias_to_add: cleanedAlias,
  });
  if (error) {
    throw error;
  }
  if (!data || data.length === 0) {
    throw new Error("Souler not found when appending alias");
  }
  return data[0];
};

export const updateSouler = async (
  id: string,
  data: Record<string, unknown>,
) => {
  const { data: updatedData, error } = await supabase
    .from("soulers")
    .update(data)
    .eq("id", id)
    .select()
    .single();
  if (error) {
    throw error;
  }
  return updatedData;
};

export const createEcho = async (
  glimmerId: string,
  soulerId: string,
  content: string,
  sessionId?: string,
) => {
  const payload: {
    glimmer_id: string;
    souler_id: string;
    content: string;
    session_id?: string;
  } = {
    glimmer_id: glimmerId,
    souler_id: soulerId,
    content,
  };
  if (sessionId) {
    payload.session_id = sessionId;
  }

  const { data, error } = await supabase
    .from("echoes")
    .insert(payload)
    .select()
    .single();
  if (error) {
    throw error;
  }
  return data;
};

export const createSession = async (
  userId: string,
  soulerId: string,
  title: string,
) => {
  const { data, error } = await supabase
    .from("sessions")
    .insert({
      user_id: userId,
      souler_id: soulerId,
      title,
    })
    .select("id")
    .single();
  if (error) {
    throw error;
  }
  return data as { id: string };
};

export const insertSessionMessage = async (
  userId: string,
  soulerId: string,
  sessionId: string,
  role: "user" | "assistant",
  content: string,
) => {
  const { error } = await supabase.from("messages").insert({
    user_id: userId,
    souler_id: soulerId,
    session_id: sessionId,
    role,
    content,
  });
  if (error) {
    throw error;
  }
};

export const createOrUpdateResonance = async (
  userId: string,
  soulerId: string,
) => {
  // check if resonance exists
  const { data, error } = await supabase
    .from("resonances")
    .select()
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
  const { data, error } = await supabase
    .from("resonances")
    .insert({
      user_id: userId,
      souler_id: soulerId,
    })
    .select()
    .single();
  if (error) {
    throw error;
  }
  return data;
};

const updateResonance = async (id: string, data: Record<string, unknown>) => {
  const { data: updatedData, error } = await supabase
    .from("resonances")
    .update(data)
    .eq("id", id)
    .select()
    .single();
  if (error) {
    throw error;
  }
  return updatedData;
};
