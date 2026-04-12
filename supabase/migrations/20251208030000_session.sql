CREATE EXTENSION IF NOT EXISTS moddatetime schema extensions;

CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    souler_id UUID NOT NULL REFERENCES soulers(id) ON DELETE CASCADE,
    chapter_id UUID REFERENCES chapters(id) ON DELETE SET NULL,
    title TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_souler_updated_at
    ON sessions (user_id, souler_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_sessions_user_chapter_updated_at
    ON sessions (user_id, chapter_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_sessions_user_updated_at
    ON sessions (user_id, updated_at DESC);

ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to view their own sessions"
    ON sessions FOR SELECT
    USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Allow users to insert their own sessions"
    ON sessions FOR INSERT
    WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Allow users to update their own sessions"
    ON sessions FOR UPDATE
    USING (user_id = (SELECT auth.uid()))
    WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Allow users to delete their own sessions"
    ON sessions FOR DELETE
    USING (user_id = (SELECT auth.uid()));

DROP TRIGGER IF EXISTS handle_sessions_updated_at ON sessions;
CREATE TRIGGER handle_sessions_updated_at
    BEFORE UPDATE ON sessions
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);
