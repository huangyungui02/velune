CREATE EXTENSION IF NOT EXISTS moddatetime SCHEMA extensions;

CREATE TYPE billing_plan AS ENUM ('free', 'premium');

CREATE TABLE IF NOT EXISTS user_billing_state (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    plan billing_plan NOT NULL DEFAULT 'free',
    entitlement_id TEXT,
    product_id TEXT,
    is_entitlement_active BOOLEAN NOT NULL DEFAULT false,
    entitlement_expires_at TIMESTAMPTZ,
    rc_environment TEXT,
    rc_last_synced_at TIMESTAMPTZ,
    cycle_month_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    monthly_limit INT NOT NULL DEFAULT 50,
    credits_remaining INT NOT NULL DEFAULT 50,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT user_billing_state_monthly_limit_check CHECK (monthly_limit >= 0),
    CONSTRAINT user_billing_state_credits_remaining_check CHECK (credits_remaining >= 0)
);

CREATE INDEX IF NOT EXISTS idx_user_billing_state_plan ON user_billing_state (plan);
CREATE INDEX IF NOT EXISTS idx_user_billing_state_updated_at ON user_billing_state (updated_at DESC);

ALTER TABLE user_billing_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to view their own billing state"
    ON user_billing_state FOR SELECT
    USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Deny users to insert billing state"
    ON user_billing_state FOR INSERT TO PUBLIC
    WITH CHECK (false);

CREATE POLICY "Deny users to update billing state"
    ON user_billing_state FOR UPDATE TO PUBLIC
    USING (false)
    WITH CHECK (false);

CREATE POLICY "Deny users to delete billing state"
    ON user_billing_state FOR DELETE TO PUBLIC
    USING (false);

DROP TRIGGER IF EXISTS handle_user_billing_state_updated_at ON user_billing_state;
CREATE TRIGGER handle_user_billing_state_updated_at
    BEFORE UPDATE ON user_billing_state
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

CREATE OR REPLACE FUNCTION public.ensure_user_billing_state(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_created_at TIMESTAMPTZ;
BEGIN
    SELECT created_at
    INTO v_created_at
    FROM auth.users
    WHERE id = p_user_id;

    INSERT INTO public.user_billing_state (
        user_id,
        plan,
        cycle_month_start,
        monthly_limit,
        credits_remaining
    )
    VALUES (
        p_user_id,
        'free',
        COALESCE(v_created_at, NOW()),
        50,
        50
    )
    ON CONFLICT (user_id) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.compute_billing_cycle_start(
    p_anchor TIMESTAMPTZ,
    p_reference TIMESTAMPTZ DEFAULT NOW()
)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_anchor_utc TIMESTAMP;
    v_reference_utc TIMESTAMP;
    v_months_between INT;
    v_candidate TIMESTAMP;
BEGIN
    v_anchor_utc := timezone('utc', p_anchor);
    v_reference_utc := timezone('utc', p_reference);

    IF v_reference_utc <= v_anchor_utc THEN
        RETURN v_anchor_utc AT TIME ZONE 'utc';
    END IF;

    v_months_between := (
        (extract(year FROM v_reference_utc) - extract(year FROM v_anchor_utc)) * 12
        + (extract(month FROM v_reference_utc) - extract(month FROM v_anchor_utc))
    )::INT;

    v_candidate := v_anchor_utc + make_interval(months => v_months_between);
    IF v_candidate > v_reference_utc THEN
        v_candidate := v_candidate - INTERVAL '1 month';
    END IF;

    RETURN v_candidate AT TIME ZONE 'utc';
END;
$$;

CREATE OR REPLACE FUNCTION public.compute_billing_next_reset_at(
    p_plan billing_plan,
    p_cycle_month_start TIMESTAMPTZ,
    p_entitlement_expires_at TIMESTAMPTZ
)
RETURNS TIMESTAMPTZ
LANGUAGE sql
STABLE
SET search_path = public
AS $$
    SELECT CASE
        WHEN p_plan = 'premium'::billing_plan
            AND p_entitlement_expires_at IS NOT NULL
        THEN p_entitlement_expires_at
        ELSE (p_cycle_month_start + INTERVAL '1 month')
    END;
$$;

CREATE OR REPLACE FUNCTION public.handle_new_auth_user_billing_state()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    PERFORM public.ensure_user_billing_state(NEW.id);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_billing_state ON auth.users;
CREATE TRIGGER on_auth_user_created_billing_state
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_auth_user_billing_state();

INSERT INTO public.user_billing_state (user_id)
SELECT id FROM auth.users
ON CONFLICT (user_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.refresh_user_billing_state(p_user_id UUID)
RETURNS user_billing_state
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_created_at TIMESTAMPTZ;
    v_current_cycle_start TIMESTAMPTZ;
    v_state user_billing_state;
    v_is_premium BOOLEAN;
    v_plan billing_plan;
    v_monthly_limit INT;
    v_new_remaining INT;
BEGIN
    PERFORM public.ensure_user_billing_state(p_user_id);

    SELECT *
    INTO v_state
    FROM public.user_billing_state
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Billing state not found for user %', p_user_id;
    END IF;

    SELECT created_at
    INTO v_created_at
    FROM auth.users
    WHERE id = p_user_id;

    v_is_premium := v_state.is_entitlement_active
        AND (
            v_state.entitlement_expires_at IS NULL
            OR v_state.entitlement_expires_at > NOW()
        );

    v_plan := CASE WHEN v_is_premium THEN 'premium'::billing_plan ELSE 'free'::billing_plan END;
    v_monthly_limit := CASE WHEN v_is_premium THEN 1000 ELSE 50 END;
    v_new_remaining := v_state.credits_remaining;

    v_current_cycle_start := public.compute_billing_cycle_start(
        COALESCE(v_created_at, v_state.created_at),
        NOW()
    );

    IF v_state.cycle_month_start IS DISTINCT FROM v_current_cycle_start THEN
        v_new_remaining := v_monthly_limit;
    ELSIF v_monthly_limit > v_state.monthly_limit THEN
        v_new_remaining := LEAST(
            v_state.credits_remaining + (v_monthly_limit - v_state.monthly_limit),
            v_monthly_limit
        );
    ELSIF v_monthly_limit < v_state.monthly_limit THEN
        v_new_remaining := LEAST(v_state.credits_remaining, v_monthly_limit);
    END IF;

    IF v_state.plan IS DISTINCT FROM v_plan
        OR v_state.monthly_limit IS DISTINCT FROM v_monthly_limit
        OR v_state.credits_remaining IS DISTINCT FROM v_new_remaining
        OR v_state.cycle_month_start IS DISTINCT FROM v_current_cycle_start
    THEN
        UPDATE public.user_billing_state
        SET
            plan = v_plan,
            monthly_limit = v_monthly_limit,
            credits_remaining = v_new_remaining,
            cycle_month_start = v_current_cycle_start
        WHERE user_id = p_user_id
        RETURNING * INTO v_state;
    END IF;

    RETURN v_state;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_credit_state(p_user_id UUID)
RETURNS TABLE (
    plan TEXT,
    monthly_limit INT,
    credits_remaining INT,
    cycle_month_start TIMESTAMPTZ,
    is_entitlement_active BOOLEAN,
    entitlement_expires_at TIMESTAMPTZ,
    rc_last_synced_at TIMESTAMPTZ,
    next_reset_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_state user_billing_state;
BEGIN
    v_state := public.refresh_user_billing_state(p_user_id);

    RETURN QUERY
    SELECT
        v_state.plan::TEXT,
        v_state.monthly_limit,
        v_state.credits_remaining,
        v_state.cycle_month_start,
        v_state.is_entitlement_active,
        v_state.entitlement_expires_at,
        v_state.rc_last_synced_at,
        public.compute_billing_next_reset_at(
            v_state.plan,
            v_state.cycle_month_start,
            v_state.entitlement_expires_at
        );
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_billing_subscription(
    p_user_id UUID,
    p_entitlement_id TEXT,
    p_product_id TEXT,
    p_is_entitlement_active BOOLEAN,
    p_entitlement_expires_at TIMESTAMPTZ,
    p_rc_environment TEXT
)
RETURNS TABLE (
    plan TEXT,
    monthly_limit INT,
    credits_remaining INT,
    cycle_month_start TIMESTAMPTZ,
    is_entitlement_active BOOLEAN,
    entitlement_expires_at TIMESTAMPTZ,
    rc_last_synced_at TIMESTAMPTZ,
    next_reset_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_previous_state user_billing_state;
    v_state user_billing_state;
    v_previous_active BOOLEAN;
    v_incoming_active BOOLEAN;
    v_should_reset_credits BOOLEAN := false;
BEGIN
    PERFORM public.ensure_user_billing_state(p_user_id);

    SELECT *
    INTO v_previous_state
    FROM public.user_billing_state
    WHERE user_id = p_user_id
    FOR UPDATE;

    v_previous_active := v_previous_state.is_entitlement_active
        AND (
            v_previous_state.entitlement_expires_at IS NULL
            OR v_previous_state.entitlement_expires_at > NOW()
        );

    v_incoming_active := COALESCE(p_is_entitlement_active, false)
        AND (
            p_entitlement_expires_at IS NULL
            OR p_entitlement_expires_at > NOW()
        );

    IF v_incoming_active THEN
        v_should_reset_credits := (NOT v_previous_active)
            OR (
                p_entitlement_expires_at IS NOT NULL
                AND (
                    v_previous_state.entitlement_expires_at IS NULL
                    OR p_entitlement_expires_at > v_previous_state.entitlement_expires_at
                )
            );
    END IF;

    UPDATE public.user_billing_state
    SET
        entitlement_id = NULLIF(trim(COALESCE(p_entitlement_id, '')), ''),
        product_id = NULLIF(trim(COALESCE(p_product_id, '')), ''),
        is_entitlement_active = COALESCE(p_is_entitlement_active, false),
        entitlement_expires_at = p_entitlement_expires_at,
        rc_environment = NULLIF(trim(COALESCE(p_rc_environment, '')), ''),
        rc_last_synced_at = NOW()
    WHERE user_id = p_user_id;

    v_state := public.refresh_user_billing_state(p_user_id);

    IF v_should_reset_credits
        AND v_state.credits_remaining IS DISTINCT FROM v_state.monthly_limit
    THEN
        UPDATE public.user_billing_state
        SET credits_remaining = v_state.monthly_limit
        WHERE user_id = p_user_id
        RETURNING * INTO v_state;
    END IF;

    RETURN QUERY
    SELECT
        v_state.plan::TEXT,
        v_state.monthly_limit,
        v_state.credits_remaining,
        v_state.cycle_month_start,
        v_state.is_entitlement_active,
        v_state.entitlement_expires_at,
        v_state.rc_last_synced_at,
        public.compute_billing_next_reset_at(
            v_state.plan,
            v_state.cycle_month_start,
            v_state.entitlement_expires_at
        );
END;
$$;

CREATE OR REPLACE FUNCTION public.consume_user_credit(
    p_user_id UUID
)
RETURNS TABLE (
    ok BOOLEAN,
    code TEXT,
    message TEXT,
    plan TEXT,
    monthly_limit INT,
    credits_remaining INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_state user_billing_state;
BEGIN
    v_state := public.refresh_user_billing_state(p_user_id);

    IF v_state.credits_remaining < 1 THEN
        RETURN QUERY
        SELECT
            false,
            'INSUFFICIENT_CREDITS',
            'Not enough credits for this request',
            v_state.plan::TEXT,
            v_state.monthly_limit,
            v_state.credits_remaining;
        RETURN;
    END IF;

    UPDATE public.user_billing_state AS ubs
    SET credits_remaining = ubs.credits_remaining - 1
    WHERE ubs.user_id = p_user_id
    RETURNING ubs.* INTO v_state;

    RETURN QUERY
    SELECT
        true,
        NULL::TEXT,
        NULL::TEXT,
        v_state.plan::TEXT,
        v_state.monthly_limit,
        v_state.credits_remaining;
END;
$$;

CREATE OR REPLACE FUNCTION public.touch_resonance(
    p_user_id UUID,
    p_souler_id UUID,
    p_last_session_id UUID,
    p_last_session_title TEXT
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    INSERT INTO public.resonances (
        user_id,
        souler_id,
        last_session_id,
        last_session_title,
        count
    )
    VALUES (
        p_user_id,
        p_souler_id,
        p_last_session_id,
        COALESCE(p_last_session_title, ''),
        1
    )
    ON CONFLICT (user_id, souler_id)
    DO UPDATE SET
        last_session_id = EXCLUDED.last_session_id,
        last_session_title = EXCLUDED.last_session_title,
        count = public.resonances.count + 1;
$$;

REVOKE ALL ON FUNCTION public.ensure_user_billing_state(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_new_auth_user_billing_state() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.compute_billing_cycle_start(TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.compute_billing_next_reset_at(billing_plan, TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refresh_user_billing_state(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_user_credit_state(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sync_billing_subscription(UUID, TEXT, TEXT, BOOLEAN, TIMESTAMPTZ, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_user_credit(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.touch_resonance(UUID, UUID, UUID, TEXT) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_user_credit_state(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.sync_billing_subscription(UUID, TEXT, TEXT, BOOLEAN, TIMESTAMPTZ, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.consume_user_credit(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.compute_billing_next_reset_at(billing_plan, TIMESTAMPTZ, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION public.touch_resonance(UUID, UUID, UUID, TEXT) TO service_role;
