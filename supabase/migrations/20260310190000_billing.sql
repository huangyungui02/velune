CREATE EXTENSION IF NOT EXISTS moddatetime SCHEMA extensions;

CREATE TABLE user_billing_state (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    is_entitlement_active BOOLEAN NOT NULL DEFAULT false,
    entitlement_expires_at TIMESTAMPTZ,
    entitlement_id TEXT,
    product_id TEXT,
    rc_environment TEXT,
    rc_last_synced_at TIMESTAMPTZ,
    credits INT NOT NULL DEFAULT 0,
    credits_refreshed_on DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT user_billing_state_credits_check CHECK (credits >= 0)
);

ALTER TABLE user_billing_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to view their own billing state"
    ON user_billing_state FOR SELECT
    USING (user_id = (SELECT auth.uid()));

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
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM auth.users
        WHERE id = p_user_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN;
    END IF;

    INSERT INTO public.user_billing_state (user_id)
    VALUES (p_user_id)
    ON CONFLICT (user_id) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.billing_effective_is_active(
    p_is_entitlement_active BOOLEAN,
    p_entitlement_expires_at TIMESTAMPTZ,
    p_reference TIMESTAMPTZ DEFAULT NOW()
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SET search_path = public
AS $$
    SELECT COALESCE(p_is_entitlement_active, false)
        AND (
            p_entitlement_expires_at IS NULL
            OR p_entitlement_expires_at > p_reference
        );
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
    v_state user_billing_state;
    v_reference TIMESTAMPTZ := NOW();
    v_today DATE := timezone('utc', v_reference)::DATE;
    v_is_active BOOLEAN;
    v_daily_credits INT;
    v_should_refresh BOOLEAN;
    v_credits_before_refresh INT;
    v_credits INT;
    v_refreshed_on DATE;
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

    v_is_active := public.billing_effective_is_active(
        v_state.is_entitlement_active,
        v_state.entitlement_expires_at,
        v_reference
    );

    v_daily_credits := CASE
        WHEN v_is_active THEN 100
        ELSE 10
    END;
    v_should_refresh := v_state.credits_refreshed_on IS DISTINCT FROM v_today;
    v_credits_before_refresh := GREATEST(COALESCE(v_state.credits, 0), 0);

    IF v_should_refresh AND v_credits_before_refresh < v_daily_credits THEN
        v_credits := v_daily_credits;
        v_refreshed_on := v_today;
    ELSE
        v_credits := v_credits_before_refresh;
        v_refreshed_on := v_state.credits_refreshed_on;
    END IF;

    IF v_state.is_entitlement_active IS DISTINCT FROM v_is_active
        OR v_state.credits_refreshed_on IS DISTINCT FROM v_refreshed_on
        OR v_state.credits IS DISTINCT FROM v_credits
    THEN
        UPDATE public.user_billing_state
        SET
            is_entitlement_active = v_is_active,
            credits_refreshed_on = v_refreshed_on,
            credits = v_credits
        WHERE user_id = p_user_id
        RETURNING * INTO v_state;
    END IF;

    RETURN v_state;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_credit_state()
RETURNS TABLE (
    credits INT,
    is_entitlement_active BOOLEAN,
    entitlement_expires_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_state user_billing_state;
BEGIN
    v_user_id := (SELECT auth.uid());

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated'
            USING ERRCODE = '28000';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM auth.users
        WHERE id = v_user_id
    ) THEN
        RAISE EXCEPTION 'Not authenticated'
            USING ERRCODE = '28000';
    END IF;

    v_state := public.refresh_user_billing_state(v_user_id);

    RETURN QUERY
    SELECT
        v_state.credits,
        v_state.is_entitlement_active,
        v_state.entitlement_expires_at;
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
    credits INT,
    is_entitlement_active BOOLEAN,
    entitlement_expires_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_reference TIMESTAMPTZ := NOW();
    v_incoming_active BOOLEAN;
    v_state user_billing_state;
BEGIN
    PERFORM public.ensure_user_billing_state(p_user_id);

    v_incoming_active := public.billing_effective_is_active(
        COALESCE(p_is_entitlement_active, false),
        p_entitlement_expires_at,
        v_reference
    );

    UPDATE public.user_billing_state AS ubs
    SET
        entitlement_id = NULLIF(trim(COALESCE(p_entitlement_id, '')), ''),
        product_id = NULLIF(trim(COALESCE(p_product_id, '')), ''),
        is_entitlement_active = v_incoming_active,
        entitlement_expires_at = p_entitlement_expires_at,
        credits_refreshed_on = CASE
            WHEN ubs.is_entitlement_active IS DISTINCT FROM v_incoming_active THEN NULL
            ELSE ubs.credits_refreshed_on
        END,
        rc_environment = NULLIF(trim(COALESCE(p_rc_environment, '')), ''),
        rc_last_synced_at = NOW()
    WHERE ubs.user_id = p_user_id;

    v_state := public.refresh_user_billing_state(p_user_id);

    RETURN QUERY
    SELECT
        v_state.credits,
        v_state.is_entitlement_active,
        v_state.entitlement_expires_at;
END;
$$;

CREATE OR REPLACE FUNCTION public.consume_stardust(
    p_user_id UUID,
    p_cost INT
)
RETURNS TABLE (
    ok BOOLEAN,
    code TEXT,
    message TEXT,
    credits INT,
    is_entitlement_active BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_state user_billing_state;
    v_cost INT;
BEGIN
    v_cost := GREATEST(COALESCE(p_cost, 0), 0);
    v_state := public.refresh_user_billing_state(p_user_id);

    IF v_cost = 0 THEN
        RETURN QUERY
        SELECT
            true,
            NULL::TEXT,
            NULL::TEXT,
            v_state.credits,
            v_state.is_entitlement_active;
        RETURN;
    END IF;

    IF v_state.credits < v_cost THEN
        RETURN QUERY
        SELECT
            false,
            'INSUFFICIENT_CREDITS',
            'Not enough credits for this request',
            v_state.credits,
            v_state.is_entitlement_active;
        RETURN;
    END IF;

    UPDATE public.user_billing_state AS ubs
    SET credits = ubs.credits - v_cost
    WHERE ubs.user_id = p_user_id
    RETURNING ubs.* INTO v_state;

    RETURN QUERY
    SELECT
        true,
        NULL::TEXT,
        NULL::TEXT,
        v_state.credits,
        v_state.is_entitlement_active;
END;
$$;

CREATE OR REPLACE FUNCTION public.consume_echo_credit(
    p_user_id UUID
)
RETURNS TABLE (
    ok BOOLEAN,
    code TEXT,
    message TEXT,
    credits INT,
    is_entitlement_active BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.consume_stardust(
        p_user_id,
        1
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.consume_chat_credit(
    p_user_id UUID
)
RETURNS TABLE (
    ok BOOLEAN,
    code TEXT,
    message TEXT,
    credits INT,
    is_entitlement_active BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.consume_stardust(
        p_user_id,
        1
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.refund_stardust(
    p_user_id UUID,
    p_amount INT
)
RETURNS TABLE (
    ok BOOLEAN,
    code TEXT,
    message TEXT,
    credits INT,
    is_entitlement_active BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_state user_billing_state;
    v_amount INT;
    v_daily_credits INT;
BEGIN
    v_amount := GREATEST(COALESCE(p_amount, 0), 0);
    v_state := public.refresh_user_billing_state(p_user_id);

    IF v_amount = 0 THEN
        RETURN QUERY
        SELECT
            true,
            NULL::TEXT,
            NULL::TEXT,
            v_state.credits,
            v_state.is_entitlement_active;
        RETURN;
    END IF;

    v_daily_credits := CASE
        WHEN v_state.is_entitlement_active THEN 100
        ELSE 10
    END;

    UPDATE public.user_billing_state AS ubs
    SET credits = LEAST(ubs.credits + v_amount, v_daily_credits)
    WHERE ubs.user_id = p_user_id
    RETURNING ubs.* INTO v_state;

    RETURN QUERY
    SELECT
        true,
        NULL::TEXT,
        NULL::TEXT,
        v_state.credits,
        v_state.is_entitlement_active;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_user_billing_state(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.billing_effective_is_active(BOOLEAN, TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_new_auth_user_billing_state() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refresh_user_billing_state(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_user_credit_state() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sync_billing_subscription(UUID, TEXT, TEXT, BOOLEAN, TIMESTAMPTZ, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_stardust(UUID, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_echo_credit(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_chat_credit(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refund_stardust(UUID, INT) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_user_credit_state() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_credit_state() TO service_role;
GRANT EXECUTE ON FUNCTION public.sync_billing_subscription(UUID, TEXT, TEXT, BOOLEAN, TIMESTAMPTZ, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.consume_echo_credit(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.consume_chat_credit(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.refund_stardust(UUID, INT) TO service_role;
