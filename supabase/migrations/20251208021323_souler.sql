CREATE EXTENSION IF NOT EXISTS moddatetime schema extensions;
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;

-- Create a table called soulers
CREATE TABLE soulers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(64) NOT NULL,
    canonical_name VARCHAR(128),
    lang VARCHAR(16) NOT NULL,
    wiki_id VARCHAR(32),
    checked BOOLEAN NOT NULL DEFAULT FALSE,
    introduction TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_soulers_name ON soulers (name);
CREATE INDEX IF NOT EXISTS idx_soulers_canonical_name ON soulers (canonical_name);
CREATE INDEX IF NOT EXISTS idx_soulers_canonical_name_lang
    ON soulers (canonical_name, lang);
CREATE INDEX IF NOT EXISTS idx_soulers_checked_canonical_name_trgm
    ON public.soulers
    USING gin (canonical_name gin_trgm_ops)
    WHERE checked = true
        AND canonical_name IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_soulers_lang ON soulers (lang);
CREATE INDEX IF NOT EXISTS idx_soulers_wiki_id ON soulers (wiki_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_soulers_wiki_id_lang_unique
    ON soulers (wiki_id, lang)
    WHERE wiki_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_soulers_checked_true_updated_at_desc
    ON public.soulers (updated_at DESC)
    WHERE checked = true;

CREATE TABLE souler_avatars (
    wiki_id VARCHAR(32) PRIMARY KEY,
    image_path TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE souler_aliases (
    souler_id UUID NOT NULL REFERENCES soulers(id) ON DELETE CASCADE,
    alias VARCHAR(128) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (souler_id, alias)
);

CREATE INDEX IF NOT EXISTS idx_souler_aliases_souler_id ON souler_aliases (souler_id);
CREATE INDEX IF NOT EXISTS idx_souler_aliases_alias ON souler_aliases (alias);

CREATE OR REPLACE FUNCTION sync_souler_name_alias()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO souler_aliases (souler_id, alias)
    VALUES (NEW.id, trim(NEW.name))
    ON CONFLICT (souler_id, alias) DO NOTHING;

    IF NEW.canonical_name IS NOT NULL AND trim(NEW.canonical_name) <> '' THEN
        INSERT INTO souler_aliases (souler_id, alias)
        VALUES (NEW.id, trim(NEW.canonical_name))
        ON CONFLICT (souler_id, alias) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER handle_souler_insert_sync_name_alias
    AFTER INSERT ON soulers
    FOR EACH ROW
    EXECUTE FUNCTION sync_souler_name_alias();

CREATE TRIGGER handle_soulers_updated_at
    BEFORE UPDATE ON soulers
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

CREATE TRIGGER handle_souler_avatars_updated_at
    BEFORE UPDATE ON souler_avatars
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

-- Enable row level security
ALTER TABLE soulers ENABLE ROW LEVEL SECURITY;
ALTER TABLE souler_avatars ENABLE ROW LEVEL SECURITY;
ALTER TABLE souler_aliases ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Allow anyone to view soulers" ON soulers FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "Deny anyone from updating soulers" ON soulers FOR UPDATE TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting soulers" ON soulers FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting soulers" ON soulers FOR DELETE TO PUBLIC USING (false);
CREATE POLICY "Allow anyone to view souler avatars" ON souler_avatars FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "Deny anyone from updating souler avatars" ON souler_avatars FOR UPDATE TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting souler avatars" ON souler_avatars FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting souler avatars" ON souler_avatars FOR DELETE TO PUBLIC USING (false);
CREATE POLICY "Allow anyone to view souler aliases" ON souler_aliases FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "Deny anyone from updating souler aliases" ON souler_aliases FOR UPDATE TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting souler aliases" ON souler_aliases FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting souler aliases" ON souler_aliases FOR DELETE TO PUBLIC USING (false);
