-- Create a table called soulers
CREATE TABLE soulers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(64) NOT NULL,
    aliases TEXT[] NOT NULL DEFAULT '{}',
    bio TEXT,
    prompt TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index on name
CREATE INDEX IF NOT EXISTS idx_soulers_name ON soulers (name);
CREATE INDEX IF NOT EXISTS idx_soulers_aliases_gin ON soulers USING GIN (aliases);

-- Enable row level security
ALTER TABLE soulers ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Allow anyone to view soulers" ON soulers FOR SELECT TO PUBLIC USING (true);
CREATE POLICY "Deny anyone from updating soulers" ON soulers FOR UPDATE TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting soulers" ON soulers FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting soulers" ON soulers FOR DELETE TO PUBLIC USING (false);

-- Atomically append one alias into aliases if it does not exist
CREATE OR REPLACE FUNCTION append_souler_alias(souler_id UUID, alias_to_add TEXT)
RETURNS SETOF soulers
LANGUAGE sql
AS $$
  UPDATE soulers
  SET aliases = CASE
    WHEN aliases @> ARRAY[alias_to_add]::TEXT[] THEN aliases
    ELSE array_append(aliases, alias_to_add)
  END,
  updated_at = NOW()
  WHERE id = souler_id
  RETURNING *;
$$;