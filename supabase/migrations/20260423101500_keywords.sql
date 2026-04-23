CREATE TABLE IF NOT EXISTS public.keywords (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    word VARCHAR(128) NOT NULL,
    language VARCHAR(16) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_keywords_word_language_unique
    ON public.keywords (word, language);
CREATE INDEX IF NOT EXISTS idx_keywords_language ON public.keywords (language);

DROP TRIGGER IF EXISTS handle_keywords_updated_at ON public.keywords;
CREATE TRIGGER handle_keywords_updated_at
    BEFORE UPDATE ON public.keywords
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

CREATE TABLE IF NOT EXISTS public.souler_keyword (
    souler_id UUID NOT NULL REFERENCES public.soulers(id) ON DELETE CASCADE,
    keyword_id UUID NOT NULL REFERENCES public.keywords(id) ON DELETE CASCADE,
    weight DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (souler_id, keyword_id),
    CONSTRAINT souler_keyword_weight_check CHECK (weight >= 0 AND weight <= 1)
);

CREATE INDEX IF NOT EXISTS idx_souler_keyword_keyword_id ON public.souler_keyword (keyword_id);
CREATE INDEX IF NOT EXISTS idx_souler_keyword_weight ON public.souler_keyword (weight);

DROP TRIGGER IF EXISTS handle_souler_keyword_updated_at ON public.souler_keyword;
CREATE TRIGGER handle_souler_keyword_updated_at
    BEFORE UPDATE ON public.souler_keyword
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

ALTER TABLE public.keywords ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.souler_keyword ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anyone to view keywords" ON public.keywords FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "Deny anyone from updating keywords" ON public.keywords FOR UPDATE TO PUBLIC USING (false) WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting keywords" ON public.keywords FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting keywords" ON public.keywords FOR DELETE TO PUBLIC USING (false);

CREATE POLICY "Allow anyone to view souler keywords" ON public.souler_keyword FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "Deny anyone from updating souler keywords" ON public.souler_keyword FOR UPDATE TO PUBLIC USING (false) WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting souler keywords" ON public.souler_keyword FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting souler keywords" ON public.souler_keyword FOR DELETE TO PUBLIC USING (false);
