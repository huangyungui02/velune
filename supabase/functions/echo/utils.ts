import { getUserId } from "./supabase.ts";

const getJwtFromRequest = (request: Request) => {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader) {
    throw new Error("Unauthorized");
  }
  return authHeader.split(" ")[1];
};

export const getUserIdFromRequest = async (request: Request) => {
  const jwt = getJwtFromRequest(request);
  const userId = await getUserId(jwt);
  if (!userId) {
    throw new Error("Unauthorized");
  }
  return userId;
};
