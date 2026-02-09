-- Create a table called soulers
CREATE TABLE soulers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(64) NOT NULL,
    alias VARCHAR(64),
    bio TEXT,
    prompt TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index on name
CREATE INDEX IF NOT EXISTS idx_soulers_name ON soulers (name);

-- Enable row level security
ALTER TABLE soulers ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Allow anyone to view soulers" ON soulers FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "Deny anyone from updating soulers" ON soulers FOR UPDATE TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting soulers" ON soulers FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting soulers" ON soulers FOR DELETE TO PUBLIC USING (false);