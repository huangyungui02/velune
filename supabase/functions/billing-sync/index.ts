import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

type BillingStateRow = {
  plan: string;
  monthly_limit: number;
  credits_remaining: number;
  cycle_month_start: string;
  is_entitlement_active: boolean;
  entitlement_expires_at: string | null;
  rc_last_synced_at: string | null;
  next_reset_at: string | null;
};

const jsonResponse = (
  payload: Record<string, unknown>,
  status = 200,
) =>
  new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const getUserIdFromRequest = async (request: Request) => {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader) {
    throw new Error("Unauthorized");
  }

  const token = authHeader.split(" ")[1];
  if (!token) {
    throw new Error("Unauthorized");
  }

  const { data } = await supabase.auth.getUser(token);
  if (!data.user?.id) {
    throw new Error("Unauthorized");
  }

  return data.user.id;
};

const normalizeBillingState = (row: unknown) => {
  const item = Array.isArray(row) ? row[0] : row;
  if (!item || typeof item !== "object") {
    throw new Error("Invalid billing state");
  }

  const data = item as BillingStateRow;
  return {
    plan: data.plan,
    monthlyLimit: Number(data.monthly_limit ?? 50),
    creditsRemaining: Number(data.credits_remaining ?? 0),
    cycleMonthStart: data.cycle_month_start,
    isEntitlementActive: Boolean(data.is_entitlement_active),
    entitlementExpiresAt: data.entitlement_expires_at,
    rcLastSyncedAt: data.rc_last_synced_at,
    nextResetAt: data.next_reset_at,
  };
};

const getBillingState = async (userId: string) => {
  const { data, error } = await supabase.rpc("get_user_credit_state", {
    p_user_id: userId,
  });

  if (error) {
    throw error;
  }

  return normalizeBillingState(data);
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const userId = await getUserIdFromRequest(req);
    const billingState = await getBillingState(userId);
    return jsonResponse({ ...billingState, source: "database" });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error ? error.message : String(error),
      },
      400,
    );
  }
});
