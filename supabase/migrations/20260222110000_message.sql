-- Create table for resonance chat messages
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    souler_id UUID NOT NULL REFERENCES soulers(id) ON DELETE CASCADE,
    session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for chat history queries
CREATE INDEX IF NOT EXISTS idx_messages_user_souler_created
    ON messages (user_id, souler_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_souler_id
    ON messages (souler_id);

CREATE INDEX IF NOT EXISTS idx_messages_user_session_created
    ON messages (user_id, session_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_session_id
    ON messages (session_id, created_at DESC);

-- Enable RLS
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Users can read their own chat messages
CREATE POLICY "Allow users to view their own messages"
    ON messages FOR SELECT
    USING (user_id = (SELECT auth.uid()));

-- Users can insert their own user-role messages only
CREATE POLICY "Allow users to insert their own user messages"
    ON messages FOR INSERT
    WITH CHECK (
        user_id = (SELECT auth.uid())
        AND role = 'user'
    );

-- Deny updates/deletes from client
CREATE POLICY "Deny users to update messages"
    ON messages FOR UPDATE TO PUBLIC
    USING (false) WITH CHECK (false);

CREATE POLICY "Deny users to delete messages"
    ON messages FOR DELETE TO PUBLIC
    USING (false);
