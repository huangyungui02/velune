CREATE EXTENSION IF NOT EXISTS moddatetime SCHEMA extensions;

CREATE TABLE public.billings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    product_id TEXT,
    expiration_at TIMESTAMPTZ,
    environment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.billings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to view their own billing state"
    ON public.billings FOR SELECT
    USING (user_id = (SELECT auth.uid()));

CREATE TRIGGER handle_billing_updated_at
    BEFORE UPDATE ON public.billings
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

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
        environment = NULLIF(trim(COALESCE(p_environment, '')), '')
    WHERE ubs.user_id = p_user_id
    RETURNING * INTO v_state;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Billing state not found for user %', p_user_id;
    END IF;

    RETURN v_state;
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
        environment = NULL
    WHERE ubs.user_id = p_user_id
    RETURNING * INTO v_state;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Billing state not found for user %', p_user_id;
    END IF;

    RETURN v_state;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_subscription_state()
RETURNS TABLE (
    product_id TEXT,
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

    SELECT *
    INTO v_state
    FROM public.billings
    WHERE user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Billing state not found for user %', v_user_id;
    END IF;

    RETURN QUERY
    SELECT
        v_state.product_id,
        v_state.expiration_at;
END;
$$;

REVOKE ALL ON FUNCTION public.init_billing() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sync_subscription(UUID, TEXT, TIMESTAMPTZ, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sync_expiration(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_user_subscription_state() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_user_subscription_state() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_subscription_state() TO service_role;
GRANT EXECUTE ON FUNCTION public.sync_subscription(UUID, TEXT, TIMESTAMPTZ, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.sync_expiration(UUID) TO service_role;
