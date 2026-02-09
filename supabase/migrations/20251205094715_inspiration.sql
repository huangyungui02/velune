-- Create diaries table
-- status: pending, processing, completed, failed
CREATE TYPE inspiration_status AS ENUM ('pending', 'processing', 'complete', 'incomplete', 'failed');

CREATE TABLE IF NOT EXISTS inspirations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status inspiration_status NOT NULL DEFAULT 'pending'
);

-- Create index on user_id
CREATE INDEX IF NOT EXISTS idx_inspirations_user_id ON inspirations (user_id);

-- Enable row level security
ALTER TABLE inspirations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to view their own inspirations" ON inspirations FOR SELECT USING (user_id = (select auth.uid()));
CREATE POLICY "Allow users to update their own inspirations" ON inspirations FOR UPDATE USING (user_id = (select auth.uid()));
CREATE POLICY "Allow users to delete their own inspirations" ON inspirations FOR DELETE USING (user_id = (select auth.uid()));
CREATE POLICY "Allow users to insert their own inspirations" ON inspirations FOR INSERT WITH CHECK (user_id = (select auth.uid()));