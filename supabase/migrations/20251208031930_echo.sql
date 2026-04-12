-- Create a table called echo
CREATE TABLE echoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    glimmer_id UUID NOT NULL REFERENCES glimmers(id) ON DELETE CASCADE,
    souler_id UUID NOT NULL REFERENCES soulers(id),
    session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_echoes_glimmer_id ON echoes (glimmer_id);
CREATE INDEX IF NOT EXISTS idx_echoes_souler_id ON echoes (souler_id);

-- Enable row level security
ALTER TABLE echoes ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Allow users to view their own echoes" ON echoes FOR SELECT USING (auth.uid() = (SELECT user_id FROM glimmers WHERE id = echoes.glimmer_id));
CREATE POLICY "Allow users to delete their own echoes" ON echoes FOR DELETE USING (auth.uid() = (SELECT user_id FROM glimmers WHERE id = echoes.glimmer_id));
CREATE POLICY "Deny anyone from updating echoes" ON echoes FOR UPDATE TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting echoes" ON echoes FOR INSERT TO PUBLIC WITH CHECK (false);

-- Add table to realtime publication
ALTER PUBLICATION supabase_realtime
ADD TABLE echoes;

-- Create a view that joins echoes with souler names
CREATE VIEW public.echoes_with_souler
WITH (security_invoker = true)
AS
SELECT 
    e.id,
    e.glimmer_id,
    e.souler_id,
    e.session_id,
    s.name AS souler_name,
    e.content,
    e.created_at
FROM echoes e
INNER JOIN soulers s ON e.souler_id = s.id;
