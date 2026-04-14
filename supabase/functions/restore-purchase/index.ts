import { supabase } from "../_shared/supabase.ts";
import { isRecord, jsonResponse, truncateError } from "../_shared/webhook.ts";

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const REVENUECAT_API_BASE_URL = Deno.env.get("REVENUECAT_API_BASE_URL")
  ?.trim() || "https://api.revenuecat.com/v1";
const REVENUECAT_SECRET_API_KEY = Deno.env.get("REVENUECAT_SECRET_API_KEY")
  ?.trim();

type ActiveSubscription = {
  productId: string;
  expirationAt: string | null;
  environment: "SANDBOX" | "PRODUCTION";
  planPriority: number;
  expirationRank: number;
};

type BillingSnapshot = {
  productId: string | null;
  expirationAt: string | null;
  environment: string | null;
};

class HttpError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = "HttpError";
    this.status = status;
  }
}

const normalizeUuid = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toLowerCase();
  if (!UUID_REGEX.test(normalized)) return null;
  return normalized;
};

const normalizeIsoTimestamp = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  const date = new Date(trimmed);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString();
};

const planPriority = (productId: string): number => {
  const normalized = productId.toLowerCase();
  if (normalized.includes("depth")) return 2;
  if (normalized.includes("awaken")) return 1;
  return 0;
};

const getBearerToken = (req: Request): string | null => {
  const header = req.headers.get("authorization")?.trim();
  if (!header) return null;

  const [scheme, ...rest] = header.split(" ");
  if (!scheme || scheme.toLowerCase() != "bearer" || rest.length === 0) {
    return null;
  }

  const token = rest.join(" ").trim();
  return token || null;
};

const requireAuthenticatedUserId = async (req: Request): Promise<string> => {
  const token = getBearerToken(req);
  if (!token) {
    throw new HttpError(401, "Missing or invalid Authorization header");
  }

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) {
    throw new HttpError(401, "Unauthorized");
  }

  const userId = normalizeUuid(data.user.id);
  if (!userId) {
    throw new HttpError(401, "Invalid user id");
  }

  return userId;
};

const fetchRevenueCatCustomerInfo = async (
  userId: string,
): Promise<unknown> => {
  if (!REVENUECAT_SECRET_API_KEY) {
    throw new HttpError(500, "Missing REVENUECAT_SECRET_API_KEY");
  }

  const url = `${REVENUECAT_API_BASE_URL}/subscribers/${
    encodeURIComponent(userId)
  }`;
  const response = await fetch(url, {
    method: "GET",
    headers: {
      "Authorization": `Bearer ${REVENUECAT_SECRET_API_KEY}`,
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    const body = (await response.text()).slice(0, 1000);
    throw new Error(
      `RevenueCat API failed (${response.status} ${response.statusText}): ${body}`,
    );
  }

  return await response.json();
};

const resolveActiveSubscription = (
  payload: unknown,
): ActiveSubscription | null => {
  if (!isRecord(payload)) return null;
  const root = isRecord(payload.value) ? payload.value : payload;
  if (!isRecord(root)) return null;
  if (!isRecord(root.subscriber)) return null;
  if (!isRecord(root.subscriber.subscriptions)) return null;

  const subscriptions = root.subscriber.subscriptions;
  let resolved: ActiveSubscription | null = null;
  const nowMs = Date.now();

  for (const [productIdRaw, detailsRaw] of Object.entries(subscriptions)) {
    const productId = typeof productIdRaw === "string"
      ? productIdRaw.trim()
      : "";
    if (!productId || !isRecord(detailsRaw)) continue;

    if (
      typeof detailsRaw.refunded_at === "string" &&
      detailsRaw.refunded_at.trim()
    ) {
      continue;
    }

    const expirationAt = normalizeIsoTimestamp(detailsRaw.expires_date);
    const expirationMs = expirationAt
      ? new Date(expirationAt).getTime()
      : Number.POSITIVE_INFINITY;
    if (Number.isFinite(expirationMs) && expirationMs <= nowMs) {
      continue;
    }

    const candidate: ActiveSubscription = {
      productId,
      expirationAt,
      environment: detailsRaw.is_sandbox === true ? "SANDBOX" : "PRODUCTION",
      planPriority: planPriority(productId),
      expirationRank: expirationMs,
    };

    if (!resolved) {
      resolved = candidate;
      continue;
    }

    if (candidate.planPriority > resolved.planPriority) {
      resolved = candidate;
      continue;
    }

    if (
      candidate.planPriority === resolved.planPriority &&
      candidate.expirationRank > resolved.expirationRank
    ) {
      resolved = candidate;
    }
  }

  return resolved;
};

const fetchBillingSnapshot = async (
  userId: string,
): Promise<BillingSnapshot> => {
  const { data, error } = await supabase
    .from("billings")
    .select("product_id, expiration_at, environment")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) {
    throw new Error(`Failed to load billing snapshot: ${error.message}`);
  }

  if (!data) {
    throw new HttpError(404, "Billing state not found");
  }

  return {
    productId: typeof data.product_id === "string"
      ? data.product_id.trim() || null
      : null,
    expirationAt: typeof data.expiration_at === "string"
      ? data.expiration_at
      : null,
    environment: typeof data.environment === "string"
      ? data.environment.trim() || null
      : null,
  };
};

const updateSubscriptionMetadataOnly = async (
  userId: string,
  active: ActiveSubscription,
) => {
  const { error } = await supabase
    .from("billings")
    .update({
      product_id: active.productId,
      expiration_at: active.expirationAt,
      environment: active.environment,
    })
    .eq("user_id", userId);

  if (error) {
    throw new Error(`Failed to update billing metadata: ${error.message}`);
  }
};

Deno.serve(async (req) => {
  if (req.method === "GET") {
    return jsonResponse({ ok: true, service: "restore-purchase" });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let userId = "";

  try {
    userId = await requireAuthenticatedUserId(req);
    const before = await fetchBillingSnapshot(userId);

    const customerInfo = await fetchRevenueCatCustomerInfo(userId);
    const active = resolveActiveSubscription(customerInfo);

    if (active) {
      const restored = before.productId === null;
      // Restore purchase only synchronizes subscription metadata.
      // It must not mutate credits or credits_refreshed_on.
      await updateSubscriptionMetadataOnly(userId, active);

      return jsonResponse({
        ok: true,
        restored,
        credits_changed: false,
        action: "metadata_only",
        user_id: userId,
        product_id: active.productId,
        expiration_at: active.expirationAt,
        environment: active.environment,
      });
    }

    // No active subscription in RevenueCat: don't mutate credits on restore tap.
    return jsonResponse({
      ok: true,
      restored: false,
      credits_changed: false,
      action: "noop",
      user_id: userId,
      product_id: before.productId,
      expiration_at: before.expirationAt,
      environment: before.environment,
    });
  } catch (error) {
    const detail = truncateError(error);
    const status = error instanceof HttpError ? error.status : 500;

    console.error(
      JSON.stringify({
        source: "restore-purchase",
        level: "error",
        user_id: userId || null,
        message: detail,
      }),
    );

    return jsonResponse({ error: "Restore purchase failed", detail }, status);
  }
});
