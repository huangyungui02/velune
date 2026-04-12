-- Installation -> user binding used by anonymous and formal sign-in flows.
CREATE TABLE public.installations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    installation_id TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT installations_installation_id_not_blank
        CHECK (char_length(trim(installation_id)) > 0)
);

-- One installation id can bind multiple user identities.
CREATE UNIQUE INDEX idx_installations_installation_id_user_id_unique
    ON public.installations (installation_id, user_id);

CREATE INDEX idx_installations_user_id
    ON public.installations (user_id);

ALTER TABLE public.installations ENABLE ROW LEVEL SECURITY;

CREATE FUNCTION public.set_installations_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_installations_set_updated_at
    BEFORE UPDATE ON public.installations
    FOR EACH ROW
    EXECUTE FUNCTION public.set_installations_updated_at();

CREATE FUNCTION public.upsert_installation_for_current_user(
    p_installation_id TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_installation_id TEXT := trim(coalesce(p_installation_id, ''));
    v_user_id UUID := auth.uid();
    v_is_anonymous BOOLEAN := false;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User is not authenticated';
    END IF;

    IF char_length(v_installation_id) = 0 THEN
        RAISE EXCEPTION 'installation_id is required';
    END IF;

    -- Serialize writes per installation to preserve one-anonymous-per-device behavior.
    PERFORM pg_advisory_xact_lock(hashtextextended(v_installation_id, 0));

    SELECT coalesce(u.is_anonymous, false)
    INTO v_is_anonymous
    FROM auth.users AS u
    WHERE u.id = v_user_id;

    IF v_is_anonymous THEN
        DELETE FROM public.installations AS i
        USING auth.users AS u
        WHERE i.installation_id = v_installation_id
          AND i.user_id <> v_user_id
          AND u.id = i.user_id
          AND u.is_anonymous = true;
    END IF;

    INSERT INTO public.installations (
        installation_id,
        user_id
    )
    VALUES (
        v_installation_id,
        v_user_id
    )
    ON CONFLICT (installation_id, user_id)
    DO UPDATE SET
        updated_at = NOW();
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_installation_for_current_user(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.upsert_installation_for_current_user(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_installation_for_current_user(TEXT) TO service_role;
