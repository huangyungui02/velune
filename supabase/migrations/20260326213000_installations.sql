-- Installation -> user binding used by anonymous and formal sign-in flows.
CREATE TABLE public.installations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    installation_id TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_anonymous BOOLEAN NOT NULL DEFAULT true,
    refresh_token TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT installations_installation_id_not_blank
        CHECK (char_length(trim(installation_id)) > 0)
);

-- One installation id maps to one current user identity.
CREATE UNIQUE INDEX idx_installations_installation_id_unique
    ON public.installations (installation_id);

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

CREATE FUNCTION public.get_installation_anonymous_session(p_installation_id TEXT)
RETURNS TABLE (
    user_id UUID,
    refresh_token TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_installation_id TEXT := trim(coalesce(p_installation_id, ''));
BEGIN
    IF char_length(v_installation_id) = 0 THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT i.user_id, i.refresh_token
    FROM public.installations AS i
    WHERE i.installation_id = v_installation_id
      AND i.is_anonymous = true
      AND i.refresh_token IS NOT NULL
      AND char_length(trim(i.refresh_token)) > 0
    LIMIT 1;
END;
$$;

CREATE FUNCTION public.upsert_installation_for_current_user(
    p_installation_id TEXT,
    p_is_anonymous BOOLEAN,
    p_refresh_token TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_installation_id TEXT := trim(coalesce(p_installation_id, ''));
    v_refresh_token TEXT := trim(coalesce(p_refresh_token, ''));
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User is not authenticated';
    END IF;

    IF char_length(v_installation_id) = 0 THEN
        RAISE EXCEPTION 'installation_id is required';
    END IF;

    INSERT INTO public.installations (
        installation_id,
        user_id,
        is_anonymous,
        refresh_token
    )
    VALUES (
        v_installation_id,
        v_user_id,
        p_is_anonymous,
        CASE
            WHEN p_is_anonymous AND char_length(v_refresh_token) > 0 THEN v_refresh_token
            ELSE NULL
        END
    )
    ON CONFLICT (installation_id)
    DO UPDATE SET
        user_id = EXCLUDED.user_id,
        is_anonymous = EXCLUDED.is_anonymous,
        refresh_token = EXCLUDED.refresh_token;
END;
$$;

REVOKE ALL ON FUNCTION public.get_installation_anonymous_session(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_installation_anonymous_session(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.get_installation_anonymous_session(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_installation_anonymous_session(TEXT) TO service_role;

REVOKE ALL ON FUNCTION public.upsert_installation_for_current_user(TEXT, BOOLEAN, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.upsert_installation_for_current_user(TEXT, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_installation_for_current_user(TEXT, BOOLEAN, TEXT) TO service_role;
