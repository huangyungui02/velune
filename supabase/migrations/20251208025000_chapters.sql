CREATE EXTENSION IF NOT EXISTS moddatetime schema extensions;
CREATE TABLE IF NOT EXISTS public.chapters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    souler_id UUID NOT NULL REFERENCES public.soulers(id) ON DELETE CASCADE,
    seq INT NOT NULL CHECK (seq > 0),
    title TEXT NOT NULL,
    subtitle TEXT NOT NULL,
    task TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    lang VARCHAR(16) NOT NULL,
    CONSTRAINT chapters_souler_lang_seq_unique UNIQUE (souler_id, lang, seq)
);

CREATE INDEX IF NOT EXISTS idx_chapters_souler_lang_seq
    ON public.chapters (souler_id, lang, seq);

ALTER TABLE public.chapters ENABLE ROW LEVEL SECURITY;

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

CREATE TRIGGER handle_chapters_updated_at
    BEFORE UPDATE ON public.chapters
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);
