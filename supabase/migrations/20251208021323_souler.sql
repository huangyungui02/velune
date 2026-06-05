CREATE EXTENSION IF NOT EXISTS moddatetime schema extensions;
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;

CREATE TABLE soulers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wiki_id VARCHAR(32),
    checked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    avatar TEXT
);

CREATE INDEX IF NOT EXISTS idx_soulers_wiki_id ON soulers (wiki_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_soulers_wiki_id_unique
    ON soulers (wiki_id)
    WHERE wiki_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_soulers_checked_true_updated_at_desc
    ON public.soulers (updated_at DESC)
    WHERE checked = true;

CREATE TABLE public.souler_profile (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    souler_id UUID NOT NULL REFERENCES public.soulers(id) ON DELETE CASCADE,
    lang VARCHAR(16) NOT NULL,
    name VARCHAR(64) NOT NULL,
    introduction TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT souler_profile_souler_lang_unique UNIQUE (souler_id, lang)
);

CREATE INDEX IF NOT EXISTS idx_souler_profile_lang_name
    ON public.souler_profile (lang, name);
CREATE INDEX IF NOT EXISTS idx_souler_profile_souler_id
    ON public.souler_profile (souler_id);

CREATE TABLE souler_aliases (
    souler_id UUID NOT NULL REFERENCES soulers(id) ON DELETE CASCADE,
    alias VARCHAR(128) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_souler_aliases_souler_id ON souler_aliases (souler_id);
CREATE INDEX IF NOT EXISTS idx_souler_aliases_alias ON souler_aliases (alias);
CREATE INDEX IF NOT EXISTS idx_souler_aliases_alias_lower
    ON public.souler_aliases (lower(trim(alias)));
CREATE UNIQUE INDEX IF NOT EXISTS souler_aliases_alias_unique
    ON public.souler_aliases (alias);
CREATE INDEX IF NOT EXISTS idx_souler_aliases_alias_trgm
    ON public.souler_aliases
    USING gin (alias extensions.gin_trgm_ops);

CREATE TRIGGER handle_soulers_updated_at
    BEFORE UPDATE ON soulers
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

CREATE TRIGGER handle_souler_profile_updated_at
    BEFORE UPDATE ON public.souler_profile
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

ALTER TABLE soulers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.souler_profile ENABLE ROW LEVEL SECURITY;
ALTER TABLE souler_aliases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anyone to view soulers" ON soulers FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "Deny anyone from updating soulers" ON soulers FOR UPDATE TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting soulers" ON soulers FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting soulers" ON soulers FOR DELETE TO PUBLIC USING (false);
CREATE POLICY "Allow anyone to view souler profile" ON public.souler_profile FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "Deny anyone from updating souler profile" ON public.souler_profile FOR UPDATE TO PUBLIC USING (false) WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting souler profile" ON public.souler_profile FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting souler profile" ON public.souler_profile FOR DELETE TO PUBLIC USING (false);
CREATE POLICY "Allow anyone to view souler aliases" ON souler_aliases FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "Deny anyone from updating souler aliases" ON souler_aliases FOR UPDATE TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting souler aliases" ON souler_aliases FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting souler aliases" ON souler_aliases FOR DELETE TO PUBLIC USING (false);
