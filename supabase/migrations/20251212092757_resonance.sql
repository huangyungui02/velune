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

-- Create a function to touch a resonance
CREATE OR REPLACE FUNCTION public.touch_resonance(
    p_user_id UUID,
    p_souler_id UUID,
    p_last_session_id UUID,
    p_last_session_title TEXT
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    INSERT INTO public.resonances (
        user_id,
        souler_id,
        last_session_id,
        last_session_title,
        count
    )
    VALUES (
        p_user_id,
        p_souler_id,
        p_last_session_id,
        COALESCE(p_last_session_title, ''),
        1
    )
    ON CONFLICT (user_id, souler_id)
    DO UPDATE SET
        last_session_id = EXCLUDED.last_session_id,
        last_session_title = EXCLUDED.last_session_title,
        count = public.resonances.count + 1;
$$;

REVOKE ALL ON FUNCTION public.touch_resonance(UUID, UUID, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.touch_resonance(UUID, UUID, UUID, TEXT) TO service_role;
