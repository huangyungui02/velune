export type Json = Record<string, unknown>;

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const jsonResponse = (payload: Json, status = 200) =>
  new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });

export const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;

const toSoulerId = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toLowerCase();
  if (!UUID_REGEX.test(normalized)) return null;
  return normalized;
};

export const extractSoulerId = (payload: unknown): string | null => {
  if (!isRecord(payload)) return null;

  const direct =
    toSoulerId(payload.souler_id) || toSoulerId(payload.soulerId) ||
    toSoulerId(payload.id);
  if (direct) return direct;

  if (isRecord(payload.record)) {
    return toSoulerId(payload.record.id) || toSoulerId(payload.record.souler_id);
  }

  if (isRecord(payload.new)) {
    return toSoulerId(payload.new.id) || toSoulerId(payload.new.souler_id);
  }

  return null;
};

export const truncateError = (error: unknown, maxLength = 4000): string => {
  const message = error instanceof Error
    ? error.message
    : typeof error === "string"
    ? error
    : JSON.stringify(error);
  return message.slice(0, maxLength);
};
