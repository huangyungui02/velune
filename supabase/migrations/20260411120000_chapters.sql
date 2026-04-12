CREATE EXTENSION IF NOT EXISTS moddatetime schema extensions;

ALTER TABLE public.soulers
    ADD COLUMN IF NOT EXISTS chapters_status TEXT NOT NULL DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS chapters_generated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS chapters_error TEXT;

ALTER TABLE public.soulers
    DROP CONSTRAINT IF EXISTS soulers_chapters_status_check;

ALTER TABLE public.soulers
    ADD CONSTRAINT soulers_chapters_status_check
    CHECK (chapters_status IN ('pending', 'processing', 'complete', 'failed'));

CREATE TABLE IF NOT EXISTS public.chapters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    souler_id UUID NOT NULL REFERENCES public.soulers(id) ON DELETE CASCADE,
    seq INT NOT NULL CHECK (seq > 0),
    title TEXT NOT NULL,
    subtitle TEXT NOT NULL,
    role TEXT NOT NULL,
    task TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chapters_souler_seq_unique'
    ) THEN
        ALTER TABLE public.chapters
            ADD CONSTRAINT chapters_souler_seq_unique UNIQUE (souler_id, seq);
    END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_chapters_souler_seq
    ON public.chapters (souler_id, seq);

ALTER TABLE public.chapters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow anyone to view chapters" ON public.chapters;
DROP POLICY IF EXISTS "Deny anyone from inserting chapters" ON public.chapters;
DROP POLICY IF EXISTS "Deny anyone from updating chapters" ON public.chapters;
DROP POLICY IF EXISTS "Deny anyone from deleting chapters" ON public.chapters;

CREATE POLICY "Allow anyone to view chapters"
    ON public.chapters FOR SELECT TO PUBLIC
    USING (true);

CREATE POLICY "Deny anyone from inserting chapters"
    ON public.chapters FOR INSERT TO PUBLIC
    WITH CHECK (false);

CREATE POLICY "Deny anyone from updating chapters"
    ON public.chapters FOR UPDATE TO PUBLIC
    USING (false)
    WITH CHECK (false);

CREATE POLICY "Deny anyone from deleting chapters"
    ON public.chapters FOR DELETE TO PUBLIC
    USING (false);

DROP TRIGGER IF EXISTS handle_chapters_updated_at ON public.chapters;
CREATE TRIGGER handle_chapters_updated_at
    BEFORE UPDATE ON public.chapters
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

ALTER TABLE public.sessions
    ADD COLUMN IF NOT EXISTS chapter_id UUID REFERENCES public.chapters(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_sessions_user_chapter_updated_at
    ON public.sessions (user_id, chapter_id, updated_at DESC);

CREATE OR REPLACE FUNCTION public.start_souler_chapters_generation(
    p_souler_id UUID
)
RETURNS TABLE(can_start BOOLEAN, status TEXT, message TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_status TEXT;
BEGIN
    SELECT chapters_status
    INTO v_status
    FROM public.soulers
    WHERE id = p_souler_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Souler not found';
    END IF;

    IF v_status = 'complete' THEN
        RETURN QUERY SELECT false, v_status, 'chapters already complete';
        RETURN;
    END IF;

    IF v_status = 'processing' THEN
        RETURN QUERY SELECT false, v_status, 'chapters are already processing';
        RETURN;
    END IF;

    UPDATE public.soulers
    SET
        chapters_status = 'processing',
        chapters_error = NULL
    WHERE id = p_souler_id;

    RETURN QUERY SELECT true, 'processing'::TEXT, 'chapter generation started';
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_souler_chapters_generation(
    p_souler_id UUID,
    p_chapters JSONB
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_status TEXT;
    v_seq INT := 0;
    v_item JSONB;
    v_title TEXT;
    v_subtitle TEXT;
    v_role TEXT;
    v_task TEXT;
BEGIN
    SELECT chapters_status
    INTO v_status
    FROM public.soulers
    WHERE id = p_souler_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Souler not found';
    END IF;

    IF v_status <> 'processing' THEN
        RAISE EXCEPTION 'Souler chapter generation is not in processing state';
    END IF;

    IF jsonb_typeof(p_chapters) <> 'array' OR jsonb_array_length(p_chapters) <> 10 THEN
        RAISE EXCEPTION 'Expected exactly 10 chapters';
    END IF;

    DELETE FROM public.chapters
    WHERE souler_id = p_souler_id;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_chapters)
    LOOP
        v_seq := v_seq + 1;
        v_title := NULLIF(BTRIM(v_item ->> 'title'), '');
        v_subtitle := NULLIF(BTRIM(v_item ->> 'subtitle'), '');
        v_role := NULLIF(BTRIM(v_item ->> 'role'), '');
        v_task := NULLIF(BTRIM(v_item ->> 'task'), '');

        IF v_title IS NULL OR v_subtitle IS NULL OR v_role IS NULL OR v_task IS NULL THEN
            RAISE EXCEPTION 'Invalid chapter payload at seq=%', v_seq;
        END IF;

        INSERT INTO public.chapters (
            souler_id,
            seq,
            title,
            subtitle,
            role,
            task
        )
        VALUES (
            p_souler_id,
            v_seq,
            v_title,
            v_subtitle,
            v_role,
            v_task
        );
    END LOOP;

    UPDATE public.soulers
    SET
        chapters_status = 'complete',
        chapters_generated_at = NOW(),
        chapters_error = NULL
    WHERE id = p_souler_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.fail_souler_chapters_generation(
    p_souler_id UUID,
    p_error TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.soulers
    SET
        chapters_status = 'failed',
        chapters_generated_at = NULL,
        chapters_error = LEFT(
            COALESCE(NULLIF(BTRIM(p_error), ''), 'chapter generation failed'),
            2000
        )
    WHERE id = p_souler_id;
END;
$$;

REVOKE ALL ON FUNCTION public.start_souler_chapters_generation(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.start_souler_chapters_generation(UUID) TO service_role;

REVOKE ALL ON FUNCTION public.complete_souler_chapters_generation(UUID, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_souler_chapters_generation(UUID, JSONB) TO service_role;

REVOKE ALL ON FUNCTION public.fail_souler_chapters_generation(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fail_souler_chapters_generation(UUID, TEXT) TO service_role;
