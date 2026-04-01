import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

type RevenueCatEntitlement = {
  id: string | null;
  lookupKey: string | null;
  displayName: string | null;
};

type RevenueCatSubscription = {
  productId: string | null;
  expiresAt: Date | null;
  givesAccess: boolean;
  environment: "sandbox" | "production" | null;
  entitlements: RevenueCatEntitlement[];
};

type RevenueCatApiError = {
  type?: string;
};

type RevenueCatWebhookEvent = {
  id?: unknown;
  type?: unknown;
  app_user_id?: unknown;
  original_app_user_id?: unknown;
  aliases?: unknown;
  transferred_from?: unknown;
  transferred_to?: unknown;
  entitlement_ids?: unknown;
  product_id?: unknown;
  expiration_at_ms?: unknown;
  expiration_at?: unknown;
  environment?: unknown;
};

type ParsedState = {
  active: boolean;
  matchedEntitlementId: string;
  configuredEntitlementId: string;
  availableEntitlementIds: string[];
  availableSubscriptionProductIds: string[];
  activeSubscriptionProductIds: string[];
  usedSubscriptionFallback: boolean;
  usedWebhookFallback: boolean;
  productId: string | null;
  expiresDate: string | null;
  environment: string | null;
};

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const WEBHOOK_INACTIVE_EVENT_TYPES = new Set(["EXPIRATION", "REFUND"]);

const jsonResponse = (payload: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;

const serializeErrorDetail = (error: unknown): Record<string, unknown> => {
  if (error instanceof Error) {
    const detail: Record<string, unknown> = {
      name: error.name,
      message: error.message,
    };

    if (error.stack) {
      detail.stack = error.stack;
    }

    return detail;
  }

  if (isRecord(error)) {
    const detail = Object.fromEntries(
      Object.entries(error).map(([key, value]) => [
        key,
        value instanceof Error ? serializeErrorDetail(value) : value,
      ]),
    );

    if (!("message" in detail)) {
      detail.message = JSON.stringify(error);
    }

    return detail;
  }

  return {
    message: typeof error === "string" ? error : String(error),
  };
};

const parseISODate = (value?: string | null): Date | null => {
  if (!value) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const normalizeISODate = (date: Date | null) => (date ? date.toISOString() : null);

const parseTimestamp = (value: unknown): Date | null => {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return null;
  }

  // Accept both seconds and milliseconds timestamps.
  const milliseconds = value > 10_000_000_000 ? value : value * 1000;
  const parsed = new Date(milliseconds);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const parseDate = (value: unknown): Date | null => {
  const fromTimestamp = parseTimestamp(value);
  if (fromTimestamp) return fromTimestamp;

  if (typeof value === "string") {
    return parseISODate(value);
  }

  return null;
};

const normalizeToken = (value: string | null | undefined) =>
  (value ?? "").trim().toLowerCase();

const collectUniqueStrings = (values: Array<string | null | undefined>) =>
  Array.from(
    new Set(
      values.filter((value): value is string => {
        return typeof value === "string" && value.trim().length > 0;
      }),
    ),
  );

const asStringArray = (value: unknown) => {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === "string");
};

const toUUID = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  if (!UUID_REGEX.test(normalized)) return null;
  return normalized.toLowerCase();
};

const parseRevenueCatApiError = (payload: string): RevenueCatApiError => {
  try {
    const parsed = JSON.parse(payload) as Record<string, unknown>;
    return {
      type: typeof parsed.type === "string" ? parsed.type : undefined,
    };
  } catch {
    return {};
  }
};

const parseRevenueCatEntitlements = (
  payload: unknown,
): RevenueCatEntitlement[] => {
  if (!payload || typeof payload !== "object") {
    return [];
  }

  const root = payload as Record<string, unknown>;
  const rawItems = Array.isArray(root.items)
    ? root.items
    : Array.isArray(payload)
    ? payload
    : [];

  return rawItems
    .map((item) => {
      if (!item || typeof item !== "object") return null;
      const value = item as Record<string, unknown>;
      const id = typeof value.id === "string"
        ? value.id
        : typeof value.entitlement_id === "string"
        ? value.entitlement_id
        : null;
      const lookupKey = typeof value.lookup_key === "string"
        ? value.lookup_key
        : null;
      const displayName = typeof value.display_name === "string"
        ? value.display_name
        : null;

      if (!id && !lookupKey && !displayName) {
        return null;
      }

      return { id, lookupKey, displayName };
    })
    .filter((item): item is RevenueCatEntitlement => item !== null);
};

const parseRevenueCatSubscriptions = (
  payload: unknown,
): RevenueCatSubscription[] => {
  if (!payload || typeof payload !== "object") {
    return [];
  }

  const root = payload as Record<string, unknown>;
  const rawItems = Array.isArray(root.items)
    ? root.items
    : Array.isArray(root.subscriptions)
    ? root.subscriptions
    : [];

  return rawItems
    .map((item) => {
      if (!item || typeof item !== "object") return null;
      const value = item as Record<string, unknown>;
      const status = typeof value.status === "string"
        ? value.status.toLowerCase()
        : null;
      const givesAccess = value.gives_access === true ||
        status === "active" ||
        status === "trialing" ||
        status === "grace_period" ||
        status === "in_grace_period";
      const environment = typeof value.environment === "string"
        ? value.environment === "sandbox"
          ? "sandbox"
          : value.environment === "production"
          ? "production"
          : null
        : value.is_sandbox === true
        ? "sandbox"
        : value.is_sandbox === false
        ? "production"
        : null;
      const entitlements = parseRevenueCatEntitlements(value.entitlements);

      const productId = typeof value.product_id === "string"
        ? value.product_id
        : typeof value.store_id === "string"
        ? value.store_id
        : null;
      const expiresAt = parseDate(value.ends_at) ??
        parseDate(value.current_period_ends_at) ??
        parseDate(value.expires_at) ??
        parseDate(value.expires_date) ??
        parseDate(value.expiration_date);

      return {
        productId,
        expiresAt,
        givesAccess,
        environment,
        entitlements,
      };
    })
    .filter((item): item is RevenueCatSubscription => item !== null);
};

const entitlementMatches = (
  entitlement: RevenueCatEntitlement,
  candidate: string,
) => {
  const normalizedCandidate = normalizeToken(candidate);
  if (!normalizedCandidate) {
    return false;
  }

  return [
    entitlement.lookupKey,
    entitlement.id,
    entitlement.displayName,
  ].some((value) => normalizeToken(value) === normalizedCandidate);
};

const sameEntitlement = (
  a: RevenueCatEntitlement,
  b: RevenueCatEntitlement,
) => {
  const aTokens = [
    normalizeToken(a.lookupKey),
    normalizeToken(a.id),
    normalizeToken(a.displayName),
  ].filter((token) => token.length > 0);
  const bTokens = new Set(
    [
      normalizeToken(b.lookupKey),
      normalizeToken(b.id),
      normalizeToken(b.displayName),
    ].filter((token) => token.length > 0),
  );

  return aTokens.some((token) => bTokens.has(token));
};

const parseRevenueCatState = (
  subscriptions: RevenueCatSubscription[],
  entitlementId: string,
): ParsedState => {
  const activeSubscriptions = subscriptions.filter((subscription) => {
    if (subscription.givesAccess) {
      return true;
    }
    if (!subscription.expiresAt) {
      return false;
    }
    return subscription.expiresAt.getTime() > Date.now();
  });

  const fallbackSubscription = activeSubscriptions[0] ?? null;
  const allEntitlements = subscriptions.flatMap((subscription) =>
    subscription.entitlements
  );
  const activeEntitlements = activeSubscriptions.flatMap((subscription) =>
    subscription.entitlements
  );

  let matchedEntitlement = activeEntitlements.find((item) =>
    entitlementMatches(item, entitlementId)
  ) ?? null;

  if (!matchedEntitlement && activeEntitlements.length > 0) {
    matchedEntitlement = activeEntitlements[0];
  }

  const matchedSubscription = matchedEntitlement
    ? activeSubscriptions.find((subscription) =>
      subscription.entitlements.some((item) =>
        sameEntitlement(item, matchedEntitlement as RevenueCatEntitlement)
      )
    ) ?? fallbackSubscription
    : fallbackSubscription;

  const matchedEntitlementId = matchedEntitlement?.lookupKey ??
    matchedEntitlement?.id ??
    entitlementId;

  return {
    active: matchedSubscription !== null,
    matchedEntitlementId,
    configuredEntitlementId: entitlementId,
    availableEntitlementIds: collectUniqueStrings(
      allEntitlements.map((item) => item.lookupKey ?? item.id ?? item.displayName),
    ),
    availableSubscriptionProductIds: collectUniqueStrings(
      subscriptions.map((subscription) => subscription.productId),
    ),
    activeSubscriptionProductIds: collectUniqueStrings(
      activeSubscriptions.map((subscription) => subscription.productId),
    ),
    usedSubscriptionFallback: !matchedEntitlement && fallbackSubscription !== null,
    usedWebhookFallback: false,
    productId: matchedSubscription?.productId ?? null,
    expiresDate: normalizeISODate(matchedSubscription?.expiresAt ?? null),
    environment: matchedSubscription?.environment ?? null,
  };
};

const parseWebhookFallbackState = (
  event: RevenueCatWebhookEvent,
  entitlementId: string,
): ParsedState | null => {
  const entitlementIds = collectUniqueStrings(asStringArray(event.entitlement_ids));
  if (entitlementIds.length === 0) {
    return null;
  }

  const matchedEntitlementId = entitlementIds.find((item) =>
    normalizeToken(item) === normalizeToken(entitlementId)
  ) ?? entitlementIds[0] ?? entitlementId;

  const expiration = parseDate(event.expiration_at_ms) ?? parseDate(event.expiration_at);
  const normalizedType = typeof event.type === "string"
    ? event.type.trim().toUpperCase()
    : "";
  const hasMatchingEntitlement = entitlementIds.some((item) =>
    normalizeToken(item) === normalizeToken(entitlementId)
  );
  const active = hasMatchingEntitlement &&
    !WEBHOOK_INACTIVE_EVENT_TYPES.has(normalizedType) &&
    (expiration === null || expiration.getTime() > Date.now());

  const environment = typeof event.environment === "string"
    ? normalizeToken(event.environment)
    : "";

  return {
    active,
    matchedEntitlementId,
    configuredEntitlementId: entitlementId,
    availableEntitlementIds: entitlementIds,
    availableSubscriptionProductIds: collectUniqueStrings([
      typeof event.product_id === "string" ? event.product_id : null,
    ]),
    activeSubscriptionProductIds: active
      ? collectUniqueStrings([
        typeof event.product_id === "string" ? event.product_id : null,
      ])
      : [],
    usedSubscriptionFallback: false,
    usedWebhookFallback: true,
    productId: typeof event.product_id === "string" ? event.product_id : null,
    expiresDate: normalizeISODate(expiration),
    environment: environment === "sandbox" || environment === "production"
      ? environment
      : null,
  };
};

const fetchRevenueCatSubscriptions = async (
  projectId: string,
  apiKey: string,
  userId: string,
) => {
  const endpoint = new URL(
    `https://api.revenuecat.com/v2/projects/${encodeURIComponent(projectId)}/customers/${encodeURIComponent(userId)}/subscriptions`,
  );
  endpoint.searchParams.set("limit", "50");

  const response = await fetch(endpoint, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${apiKey}`,
    },
  });

  if (response.ok) {
    return parseRevenueCatSubscriptions(await response.json());
  }

  const body = await response.text();
  const error = parseRevenueCatApiError(body);
  if (response.status === 404 && error.type === "resource_missing") {
    return [];
  }

  throw new Error(
    `RevenueCat API error (${response.status}): ${body || response.statusText}`,
  );
};

const syncBillingSubscription = async (
  userId: string,
  state: ParsedState,
) => {
  const { data, error } = await supabase.rpc("sync_billing_subscription", {
    p_user_id: userId,
    p_entitlement_id: state.matchedEntitlementId,
    p_product_id: state.productId,
    p_is_entitlement_active: state.active,
    p_entitlement_expires_at: state.expiresDate,
    p_rc_environment: state.environment,
  });

  if (error) {
    throw error;
  }

  return data;
};

const extractUserIds = (event: RevenueCatWebhookEvent) => {
  const candidates: unknown[] = [
    event.app_user_id,
    event.original_app_user_id,
    ...asStringArray(event.aliases),
    ...asStringArray(event.transferred_from),
    ...asStringArray(event.transferred_to),
  ];

  return collectUniqueStrings(candidates.map((item) => toUUID(item)));
};

const readEvent = (payload: unknown): RevenueCatWebhookEvent | null => {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const root = payload as Record<string, unknown>;
  if (!root.event || typeof root.event !== "object") {
    return null;
  }

  return root.event as RevenueCatWebhookEvent;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const expectedAuthHeader =
    Deno.env.get("REVENUECAT_WEBHOOK_AUTH_HEADER")?.trim() ?? "";
  if (expectedAuthHeader.length > 0) {
    const actualAuthHeader = req.headers.get("Authorization")?.trim() ?? "";
    if (actualAuthHeader !== expectedAuthHeader) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }
  }

  const projectId = Deno.env.get("REVENUECAT_PROJECT_ID")?.trim();
  const apiKey = Deno.env.get("REVENUECAT_V2_API_KEY")?.trim();
  const entitlementId = Deno.env.get("REVENUECAT_ENTITLEMENT_ID")?.trim();
  if (!projectId || !apiKey || !entitlementId) {
    return jsonResponse(
      { error: "Missing RevenueCat credentials in environment" },
      500,
    );
  }

  try {
    const payload = await req.json();
    const event = readEvent(payload);

    if (!event) {
      return jsonResponse({ error: "Invalid RevenueCat webhook payload" }, 400);
    }

    const eventId = typeof event.id === "string" ? event.id : null;
    const eventType = typeof event.type === "string" ? event.type : "unknown";
    const userIds = extractUserIds(event);

    if (userIds.length === 0) {
      console.log(
        JSON.stringify({
          source: "revenuecat-webhook",
          level: "info",
          message: "Skip webhook event without Supabase UUID user id",
          eventId,
          eventType,
          appUserId: event.app_user_id,
          originalAppUserId: event.original_app_user_id,
          aliases: event.aliases,
        }),
      );
      return jsonResponse({ ok: true, skipped: true, reason: "no_user_id" });
    }

    const processed: Array<Record<string, unknown>> = [];
    let hasSyncFailure = false;

    for (const userId of userIds) {
      try {
        const subscriptions = await fetchRevenueCatSubscriptions(projectId, apiKey, userId);
        const baseState = parseRevenueCatState(subscriptions, entitlementId);
        const fallbackState = subscriptions.length === 0
          ? parseWebhookFallbackState(event, entitlementId)
          : null;
        const state = fallbackState ?? baseState;

        await syncBillingSubscription(userId, state);

        processed.push({
          userId,
          active: state.active,
          productId: state.productId,
          matchedEntitlementId: state.matchedEntitlementId,
          usedSubscriptionFallback: state.usedSubscriptionFallback,
          usedWebhookFallback: state.usedWebhookFallback,
        });
      } catch (error) {
        hasSyncFailure = true;
        const detail = serializeErrorDetail(error);
        console.error(
          JSON.stringify({
            source: "revenuecat-webhook",
            level: "error",
            message: "Failed to sync user billing state",
            userId,
            eventId,
            eventType,
            detail,
          }),
        );
        processed.push({ userId, skipped: true, reason: "sync_failed", detail });
      }
    }

    console.log(
      JSON.stringify({
        source: "revenuecat-webhook",
        level: "info",
        message: "Webhook processed",
        eventId,
        eventType,
        processed,
      }),
    );

    if (hasSyncFailure) {
      return jsonResponse(
        { error: "Failed to sync one or more billing states", eventId, eventType, processed },
        500,
      );
    }

    return jsonResponse({ ok: true, eventId, eventType, processed });
  } catch (error) {
    const detail = serializeErrorDetail(error);
    console.error(
      JSON.stringify({
        source: "revenuecat-webhook",
        level: "error",
        message: "Unhandled webhook error",
        detail,
      }),
    );

    return jsonResponse(
      { error: "Unhandled webhook error", detail },
      500,
    );
  }
});
