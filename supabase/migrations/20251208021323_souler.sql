-- Create a table called soulers
CREATE TABLE soulers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(64) NOT NULL,
    lang VARCHAR(16) NOT NULL,
    bio TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_soulers_name ON soulers (name);
CREATE INDEX IF NOT EXISTS idx_soulers_lang ON soulers (lang);

CREATE TABLE souler_aliases (
    souler_id UUID NOT NULL REFERENCES soulers(id) ON DELETE CASCADE,
    alias VARCHAR(128) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (souler_id, alias)
);

CREATE INDEX IF NOT EXISTS idx_souler_aliases_souler_id ON souler_aliases (souler_id);
CREATE INDEX IF NOT EXISTS idx_souler_aliases_alias ON souler_aliases (alias);

-- Enable row level security
ALTER TABLE soulers ENABLE ROW LEVEL SECURITY;
ALTER TABLE souler_aliases ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Allow anyone to view soulers" ON soulers FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "Deny anyone from updating soulers" ON soulers FOR UPDATE TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting soulers" ON soulers FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting soulers" ON soulers FOR DELETE TO PUBLIC USING (false);
CREATE POLICY "Allow anyone to view souler aliases" ON souler_aliases FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "Deny anyone from updating souler aliases" ON souler_aliases FOR UPDATE TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting souler aliases" ON souler_aliases FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting souler aliases" ON souler_aliases FOR DELETE TO PUBLIC USING (false);
