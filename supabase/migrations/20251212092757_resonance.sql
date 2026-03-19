-- CREATE EXTENSION IF NOT EXISTS moddatetime schema extensions;
CREATE EXTENSION IF NOT EXISTS moddatetime schema extensions;

-- Create a table called resonances
CREATE TABLE IF NOT EXISTS resonances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    souler_id UUID NOT NULL REFERENCES soulers(id),
    last_session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
    last_session_title TEXT NOT NULL DEFAULT '',
    count INT NOT NULL DEFAULT 1 CHECK (count >= 1),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create unique index on user_id and souler_id
CREATE UNIQUE INDEX IF NOT EXISTS idx_resonances_user_id_souler_id ON resonances (user_id, souler_id);

-- Enable row level security
ALTER TABLE resonances ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Allow users to view their own resonances" ON resonances FOR SELECT USING (user_id = (select auth.uid()));
CREATE POLICY "Allow users to delete their own resonances" ON resonances FOR DELETE USING (user_id = (select auth.uid()));
CREATE POLICY "Deny users to insert resonances" ON resonances FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny users to update their own resonances" ON resonances FOR UPDATE TO PUBLIC WITH CHECK (false);

-- Handle updated_at column
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON resonances FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime (updated_at);
