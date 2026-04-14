import { supabase } from "../_shared/supabase.ts";
import {
  isRecord,
  jsonResponse,
  truncateError,
} from "../_shared/webhook.ts";

type RevenueCatEventType =
  | "INITIAL_PURCHASE"
  | "RENEWAL"
  | "EXPIRATION";

const HANDLED_EVENT_TYPES = new Set<RevenueCatEventType>([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "EXPIRATION",
]);

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const REVENUECAT_WEBHOOK_AUTH_HEADER = Deno.env.get("REVENUECAT_WEBHOOK_AUTH_HEADER")
  ?.trim();

const normalizeUuid = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toLowerCase();
  if (!UUID_REGEX.test(normalized)) return null;
  return normalized;
};

const parseExpirationAt = (event: Record<string, unknown>): string | null => {
  const expirationAtMs = event.expiration_at_ms;
  if (typeof expirationAtMs === "number" && Number.isFinite(expirationAtMs)) {
    return new Date(expirationAtMs).toISOString();
  }

  if (typeof expirationAtMs === "string") {
    const parsed = Number(expirationAtMs);
    if (Number.isFinite(parsed)) {
      return new Date(parsed).toISOString();
    }
  }

  const expirationAt = event.expiration_at;
  if (typeof expirationAt === "string" && expirationAt.trim()) {
    const parsedDate = new Date(expirationAt);
    if (!Number.isNaN(parsedDate.getTime())) {
      return parsedDate.toISOString();
    }
  }

  return null;
};

const assertWebhookAuthorization = (req: Request): Response | null => {
  if (!REVENUECAT_WEBHOOK_AUTH_HEADER) {
    return null;
  }

  const received = req.headers.get("authorization")?.trim() ?? "";
  if (received === REVENUECAT_WEBHOOK_AUTH_HEADER) {
    return null;
  }

  return jsonResponse({ error: "Unauthorized" }, 401);
};

const syncSubscription = async (
  appUserId: string,
  event: Record<string, unknown>,
) => {
  const productId = typeof event.product_id === "string" ? event.product_id.trim() : "";
  if (!productId) {
    throw new Error("Missing product_id");
  }

  const environment = typeof event.environment === "string"
    ? event.environment.trim()
    : "";
  const expirationAt = parseExpirationAt(event);

  const { error } = await supabase.rpc("sync_subscription", {
    p_user_id: appUserId,
    p_product_id: productId,
    p_expiration_at: expirationAt,
    p_environment: environment,
  });

  if (error) {
    throw new Error(`sync_subscription failed: ${error.message}`);
  }
};

const syncExpiration = async (appUserId: string) => {
  const { error } = await supabase.rpc("sync_expiration", {
    p_user_id: appUserId,
  });

  if (error) {
    throw new Error(`sync_expiration failed: ${error.message}`);
  }
};

Deno.serve(async (req) => {
  if (req.method === "GET") {
    return jsonResponse({ ok: true, service: "revenuecat-webhook" });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const authError = assertWebhookAuthorization(req);
  if (authError) return authError;

  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  try {
    if (!isRecord(payload) || !isRecord(payload.event)) {
      return jsonResponse({ error: "Missing event object" }, 400);
    }

    const event = payload.event;
    const rawType = typeof event.type === "string" ? event.type.trim() : "";

    if (!HANDLED_EVENT_TYPES.has(rawType as RevenueCatEventType)) {
      console.log(
        JSON.stringify({
          source: "revenuecat-webhook",
          level: "info",
          action: "ignore_event",
          type: rawType || "unknown",
          payload,
        }),
      );

      return jsonResponse({ ok: true, ignored: true, type: rawType || "unknown" });
    }

    const appUserId = normalizeUuid(event.app_user_id);
    if (!appUserId) {
      throw new Error("Missing app_user_id");
    }

    if (rawType === "INITIAL_PURCHASE" || rawType === "RENEWAL") {
      await syncSubscription(appUserId, event);
      return jsonResponse({ ok: true, type: rawType, user_id: appUserId });
    }

    if (rawType === "EXPIRATION") {
      await syncExpiration(appUserId);
      return jsonResponse({ ok: true, type: rawType, user_id: appUserId });
    }

    return jsonResponse({ ok: true, ignored: true, type: rawType });
  } catch (error) {
    const detail = truncateError(error);
    console.error(
      JSON.stringify({
        source: "revenuecat-webhook",
        level: "error",
        message: detail,
        payload,
      }),
    );

    return jsonResponse({ error: "Unhandled webhook error", detail }, 500);
  }
});
