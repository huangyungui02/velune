CREATE EXTENSION IF NOT EXISTS moddatetime schema extensions;
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS public.chapters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    souler_id UUID NOT NULL REFERENCES public.soulers(id) ON DELETE CASCADE,
    seq INT NOT NULL CHECK (seq > 0),
    title TEXT NOT NULL,
    subtitle TEXT NOT NULL,
    task TEXT NOT NULL,
    "for" TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chapters_souler_seq_unique UNIQUE (souler_id, seq)
);

CREATE INDEX IF NOT EXISTS idx_chapters_souler_seq
    ON public.chapters (souler_id, seq);

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

CREATE TABLE IF NOT EXISTS public.chapter_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chapter_id UUID NOT NULL REFERENCES public.chapters(id) ON DELETE CASCADE,
    source_text TEXT NOT NULL,
    embedding extensions.vector(1024) NOT NULL,
    model TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chapter_embeddings_chapter_id_unique UNIQUE (chapter_id)
);

CREATE INDEX IF NOT EXISTS idx_chapter_embeddings_embedding_hnsw
    ON public.chapter_embeddings
    USING hnsw (embedding vector_cosine_ops);

ALTER TABLE public.chapter_embeddings ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER handle_chapter_embeddings_updated_at
    BEFORE UPDATE ON public.chapter_embeddings
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);
