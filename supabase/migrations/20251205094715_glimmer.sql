CREATE TABLE IF NOT EXISTS glimmers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index on user_id
CREATE INDEX IF NOT EXISTS idx_glimmers_user_id ON glimmers (user_id);

-- Enable row level security
ALTER TABLE glimmers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to view their own glimmers" ON glimmers FOR SELECT USING (user_id = (select auth.uid()));
CREATE POLICY "Allow users to update their own glimmers" ON glimmers FOR UPDATE USING (user_id = (select auth.uid()));
CREATE POLICY "Allow users to delete their own glimmers" ON glimmers FOR DELETE USING (user_id = (select auth.uid()));
CREATE POLICY "Allow users to insert their own glimmers" ON glimmers FOR INSERT WITH CHECK (user_id = (select auth.uid()));