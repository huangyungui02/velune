CREATE EXTENSION IF NOT EXISTS moddatetime SCHEMA extensions;

CREATE TABLE public.billings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    product_id TEXT,
    expiration_at TIMESTAMPTZ,
    environment TEXT,
    credits INT NOT NULL DEFAULT 0,
    credits_refreshed_on DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT billings_credits_check CHECK (credits >= 0)
);

ALTER TABLE public.billings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to view their own billing state"
    ON public.billings FOR SELECT
    USING (user_id = (SELECT auth.uid()));

CREATE TRIGGER handle_billing_updated_at
    BEFORE UPDATE ON public.billings
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

CREATE OR REPLACE FUNCTION public.daily_credits(p_product_id TEXT)
RETURNS INT
LANGUAGE sql
STABLE
SET search_path = public
AS $$
    SELECT CASE
        WHEN NULLIF(trim(COALESCE(p_product_id, '')), '') IS NULL THEN 10
        WHEN lower(COALESCE(p_product_id, '')) LIKE '%depth%' THEN 100
        WHEN lower(COALESCE(p_product_id, '')) LIKE '%awaken%' THEN 50
        ELSE 10
    END;
$$;

CREATE OR REPLACE FUNCTION public.billing_refresh_day(
    p_user_id UUID,
    p_reference TIMESTAMPTZ DEFAULT NOW()
)
RETURNS DATE
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_user_timezone TEXT := 'UTC';
    v_refresh_day DATE;
BEGIN
    SELECT us.timezone
    INTO v_user_timezone
    FROM public.user_status AS us
    WHERE us.user_id = p_user_id;

    v_user_timezone := COALESCE(NULLIF(trim(COALESCE(v_user_timezone, '')), ''), 'UTC');

    BEGIN
        v_refresh_day := timezone(v_user_timezone, p_reference)::DATE;
    EXCEPTION
        WHEN invalid_parameter_value THEN
            v_refresh_day := timezone('UTC', p_reference)::DATE;
    END;

    RETURN v_refresh_day;
END;
$$;

CREATE OR REPLACE FUNCTION public.init_billing()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.billings (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created_billing
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.init_billing();

INSERT INTO public.billings (user_id)
SELECT id
FROM auth.users
ON CONFLICT (user_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.refresh_daily_credits(p_user_id UUID)
RETURNS public.billings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_state public.billings;
    v_refresh_day DATE;
    v_daily_credits INT;
    v_credits INT;
BEGIN
    SELECT *
    INTO v_state
    FROM public.billings
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Billing state not found for user %', p_user_id;
    END IF;

    v_refresh_day := public.billing_refresh_day(p_user_id, NOW());

    IF v_state.credits_refreshed_on IS NOT DISTINCT FROM v_refresh_day THEN
        RETURN v_state;
    END IF;

    v_daily_credits := public.daily_credits(v_state.product_id);
    v_credits := GREATEST(COALESCE(v_state.credits, 0), 0);

    IF v_credits < v_daily_credits THEN
        v_credits := v_daily_credits;
    END IF;

    UPDATE public.billings AS ubs
    SET
        credits = v_credits,
        credits_refreshed_on = v_refresh_day
    WHERE ubs.user_id = p_user_id
    RETURNING * INTO v_state;

    RETURN v_state;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_subscription(
    p_user_id UUID,
    p_product_id TEXT,
    p_expiration_at TIMESTAMPTZ,
    p_environment TEXT
)
RETURNS public.billings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_state public.billings;
BEGIN
    UPDATE public.billings AS ubs
    SET
        product_id = NULLIF(trim(COALESCE(p_product_id, '')), ''),
        expiration_at = p_expiration_at,
        environment = NULLIF(trim(COALESCE(p_environment, '')), ''),
        credits_refreshed_on = NULL
    WHERE ubs.user_id = p_user_id
    RETURNING * INTO v_state;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Billing state not found for user %', p_user_id;
    END IF;

    RETURN public.refresh_daily_credits(p_user_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_expiration(p_user_id UUID)
RETURNS public.billings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_state public.billings;
BEGIN
    UPDATE public.billings AS ubs
    SET
        product_id = NULL,
        expiration_at = NULL,
        environment = NULL,
        credits = public.daily_credits(NULL),
        credits_refreshed_on = NULL
    WHERE ubs.user_id = p_user_id
    RETURNING * INTO v_state;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Billing state not found for user %', p_user_id;
    END IF;

    RETURN v_state;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_credit_state()
RETURNS TABLE (
    credits INT,
    product_id TEXT,
    daily_credits INT,
    expiration_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_state public.billings;
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

    v_state := public.refresh_daily_credits(v_user_id);

    RETURN QUERY
    SELECT
        v_state.credits,
        v_state.product_id,
        public.daily_credits(v_state.product_id),
        v_state.expiration_at;
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
    product_id TEXT,
    daily_credits INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_state public.billings;
    v_cost INT;
BEGIN
    v_cost := GREATEST(COALESCE(p_cost, 0), 0);
    v_state := public.refresh_daily_credits(p_user_id);

    IF v_cost = 0 THEN
        RETURN QUERY
        SELECT
            true,
            NULL::TEXT,
            NULL::TEXT,
            v_state.credits,
            v_state.product_id,
            public.daily_credits(v_state.product_id);
        RETURN;
    END IF;

    UPDATE public.billings AS ubs
    SET credits = ubs.credits - v_cost
    WHERE ubs.user_id = p_user_id
      AND ubs.credits >= v_cost
    RETURNING ubs.* INTO v_state;

    IF FOUND THEN
        RETURN QUERY
        SELECT
            true,
            NULL::TEXT,
            NULL::TEXT,
            v_state.credits,
            v_state.product_id,
            public.daily_credits(v_state.product_id);
        RETURN;
    END IF;

    SELECT *
    INTO v_state
    FROM public.billings
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Billing state not found for user %', p_user_id;
    END IF;

    RETURN QUERY
    SELECT
        false,
        'INSUFFICIENT_CREDITS',
        'Not enough credits for this request',
        v_state.credits,
        v_state.product_id,
        public.daily_credits(v_state.product_id);
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
    product_id TEXT,
    daily_credits INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_state public.billings;
    v_amount INT;
BEGIN
    v_amount := GREATEST(COALESCE(p_amount, 0), 0);
    v_state := public.refresh_daily_credits(p_user_id);

    IF v_amount = 0 THEN
        RETURN QUERY
        SELECT
            true,
            NULL::TEXT,
            NULL::TEXT,
            v_state.credits,
            v_state.product_id,
            public.daily_credits(v_state.product_id);
        RETURN;
    END IF;

    UPDATE public.billings AS ubs
    SET credits = ubs.credits + v_amount
    WHERE ubs.user_id = p_user_id
    RETURNING ubs.* INTO v_state;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Billing state not found for user %', p_user_id;
    END IF;

    RETURN QUERY
    SELECT
        true,
        NULL::TEXT,
        NULL::TEXT,
        v_state.credits,
        v_state.product_id,
        public.daily_credits(v_state.product_id);
END;
$$;

REVOKE ALL ON FUNCTION public.daily_credits(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.billing_refresh_day(UUID, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.init_billing() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refresh_daily_credits(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sync_subscription(UUID, TEXT, TIMESTAMPTZ, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sync_expiration(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_user_credit_state() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_stardust(UUID, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refund_stardust(UUID, INT) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_user_credit_state() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_credit_state() TO service_role;
GRANT EXECUTE ON FUNCTION public.refresh_daily_credits(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.sync_subscription(UUID, TEXT, TIMESTAMPTZ, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.sync_expiration(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.consume_stardust(UUID, INT) TO service_role;
GRANT EXECUTE ON FUNCTION public.refund_stardust(UUID, INT) TO service_role;
