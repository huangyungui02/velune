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

CREATE OR REPLACE FUNCTION public.touch_user_status_for_current_user(
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
    v_timezone TEXT := coalesce(nullif(trim(coalesce(p_timezone, '')), ''), 'unknown');
    v_region TEXT := coalesce(nullif(trim(coalesce(p_region, '')), ''), 'unknown');
    v_language TEXT := coalesce(nullif(trim(coalesce(p_language, '')), ''), 'unknown');
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User is not authenticated';
    END IF;

    INSERT INTO public.user_status (
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
        last_active_at = NOW();
END;
$$;

REVOKE ALL ON FUNCTION public.touch_user_status_for_current_user(TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.touch_user_status_for_current_user(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.touch_user_status_for_current_user(TEXT, TEXT, TEXT) TO service_role;
