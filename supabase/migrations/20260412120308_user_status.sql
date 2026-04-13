CREATE TABLE public.user_status (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    timezone TEXT NOT NULL,
    region TEXT NOT NULL,
    language TEXT NOT NULL,
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.user_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to view their own user status"
    ON public.user_status FOR SELECT
    TO authenticated
    USING (user_id = (SELECT auth.uid()));

CREATE OR REPLACE FUNCTION public.upsert_user_status_for_current_user(
    p_timezone TEXT DEFAULT NULL,
    p_region TEXT DEFAULT NULL,
    p_language TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_timezone TEXT := coalesce(nullif(trim(coalesce(p_timezone, '')), ''), 'UTC');
    v_region TEXT := coalesce(nullif(trim(coalesce(p_region, '')), ''), 'unknown');
    v_language TEXT := coalesce(nullif(trim(coalesce(p_language, '')), ''), 'unknown');
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User is not authenticated';
    END IF;

    IF v_timezone <> 'UTC'
        AND NOT EXISTS (
            SELECT 1
            FROM pg_catalog.pg_timezone_names
            WHERE name = v_timezone
        )
    THEN
        v_timezone := 'UTC';
    END IF;

    INSERT INTO public.user_status AS us (
        user_id,
        timezone,
        region,
        language,
        last_active_at
    )
    VALUES (
        v_user_id,
        v_timezone,
        v_region,
        v_language,
        NOW()
    )
    ON CONFLICT (user_id)
    DO UPDATE SET
        timezone = CASE
            WHEN us.timezone = 'UTC' AND EXCLUDED.timezone <> 'UTC' THEN EXCLUDED.timezone
            ELSE us.timezone
        END,
        region = CASE
            WHEN us.region = 'unknown' AND EXCLUDED.region <> 'unknown' THEN EXCLUDED.region
            ELSE us.region
        END,
        language = CASE
            WHEN us.language = 'unknown' AND EXCLUDED.language <> 'unknown' THEN EXCLUDED.language
            ELSE us.language
        END;
END;
$$;

CREATE OR REPLACE FUNCTION public.touch_user_status_for_current_user()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User is not authenticated';
    END IF;

    UPDATE public.user_status
    SET last_active_at = NOW()
    WHERE user_id = v_user_id;

    IF NOT FOUND THEN
        INSERT INTO public.user_status (
            user_id,
            timezone,
            region,
            language,
            last_active_at
        )
        VALUES (
            v_user_id,
            'UTC',
            'unknown',
            'unknown',
            NOW()
        )
        ON CONFLICT (user_id)
        DO UPDATE SET
            last_active_at = NOW();
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_user_status_for_current_user(TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.touch_user_status_for_current_user() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.upsert_user_status_for_current_user(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_user_status_for_current_user(TEXT, TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.touch_user_status_for_current_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.touch_user_status_for_current_user() TO service_role;
