CREATE EXTENSION IF NOT EXISTS moddatetime schema extensions;

-- Create a table called soulers
CREATE TABLE soulers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(64) NOT NULL,
    canonical_name VARCHAR(128),
    lang VARCHAR(16) NOT NULL,
    wiki_id VARCHAR(32),
    image_path TEXT DEFAULT NULL,
    checked BOOLEAN NOT NULL DEFAULT FALSE,
    bio TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_soulers_name ON soulers (name);
CREATE INDEX IF NOT EXISTS idx_soulers_canonical_name ON soulers (canonical_name);
CREATE INDEX IF NOT EXISTS idx_soulers_canonical_name_lang
    ON soulers (canonical_name, lang);
CREATE INDEX IF NOT EXISTS idx_soulers_lang ON soulers (lang);
CREATE INDEX IF NOT EXISTS idx_soulers_wiki_id ON soulers (wiki_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_soulers_wiki_id_lang_unique
    ON soulers (wiki_id, lang)
    WHERE wiki_id IS NOT NULL;

CREATE TABLE souler_aliases (
    souler_id UUID NOT NULL REFERENCES soulers(id) ON DELETE CASCADE,
    alias VARCHAR(128) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (souler_id, alias)
);

CREATE INDEX IF NOT EXISTS idx_souler_aliases_souler_id ON souler_aliases (souler_id);
CREATE INDEX IF NOT EXISTS idx_souler_aliases_alias ON souler_aliases (alias);

CREATE TABLE souler_status (
    souler_id UUID PRIMARY KEY REFERENCES soulers(id) ON DELETE CASCADE,
    bio_status TEXT NOT NULL DEFAULT 'pending',
    chapters_status TEXT NOT NULL DEFAULT 'pending',
    bio_error TEXT,
    chapters_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT souler_status_bio_status_check
        CHECK (bio_status IN ('pending', 'processing', 'complete', 'failed')),
    CONSTRAINT souler_status_chapters_status_check
        CHECK (chapters_status IN ('pending', 'processing', 'complete', 'failed'))
);

CREATE TRIGGER handle_souler_status_updated_at
    BEFORE UPDATE ON souler_status
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

CREATE OR REPLACE FUNCTION create_souler_status()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO souler_status (souler_id)
    VALUES (NEW.id)
    ON CONFLICT (souler_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER handle_souler_insert_create_status
    AFTER INSERT ON soulers
    FOR EACH ROW
    EXECUTE FUNCTION create_souler_status();

CREATE TRIGGER handle_soulers_updated_at
    BEFORE UPDATE ON soulers
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

-- Enable row level security
ALTER TABLE soulers ENABLE ROW LEVEL SECURITY;
ALTER TABLE souler_aliases ENABLE ROW LEVEL SECURITY;
ALTER TABLE souler_status ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Allow anyone to view soulers" ON soulers FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "Deny anyone from updating soulers" ON soulers FOR UPDATE TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting soulers" ON soulers FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting soulers" ON soulers FOR DELETE TO PUBLIC USING (false);
CREATE POLICY "Allow anyone to view souler aliases" ON souler_aliases FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "Deny anyone from updating souler aliases" ON souler_aliases FOR UPDATE TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting souler aliases" ON souler_aliases FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting souler aliases" ON souler_aliases FOR DELETE TO PUBLIC USING (false);
CREATE POLICY "Allow anyone to view souler status" ON souler_status FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "Deny anyone from inserting souler status" ON souler_status FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from updating souler status" ON souler_status FOR UPDATE TO PUBLIC USING (false) WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting souler status" ON souler_status FOR DELETE TO PUBLIC USING (false);
