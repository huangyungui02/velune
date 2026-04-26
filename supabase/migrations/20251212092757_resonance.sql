-- CREATE EXTENSION IF NOT EXISTS moddatetime schema extensions;
CREATE EXTENSION IF NOT EXISTS moddatetime schema extensions;

-- Create a table called resonances
CREATE TABLE IF NOT EXISTS resonances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    souler_id UUID NOT NULL REFERENCES soulers(id) ON DELETE CASCADE,
    last_session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
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

CREATE OR REPLACE VIEW public.resonances_with_souler
WITH (security_invoker = true)
AS
SELECT
    r.id,
    r.user_id,
    r.souler_id,
    r.last_session_id,
    COALESCE(sess.title, '') AS last_session_title,
    r.created_at,
    r.updated_at,
    s.name AS souler_name
FROM public.resonances AS r
JOIN public.soulers AS s
    ON s.id = r.souler_id
LEFT JOIN public.sessions AS sess
    ON sess.id = r.last_session_id;

REVOKE ALL ON TABLE public.resonances_with_souler FROM PUBLIC;
GRANT SELECT ON TABLE public.resonances_with_souler TO authenticated;
GRANT SELECT ON TABLE public.resonances_with_souler TO service_role;
