CREATE TABLE IF NOT EXISTS public.feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    installation_id TEXT,
    lang VARCHAR(16) NOT NULL,
    content TEXT NOT NULL,
    app_version TEXT,
    os_version TEXT,
    device_model TEXT,
    status TEXT NOT NULL DEFAULT 'open',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT feedback_content_not_empty CHECK (length(trim(content)) > 0),
    CONSTRAINT feedback_status_valid CHECK (status IN ('open', 'reviewing', 'closed'))
);

CREATE INDEX IF NOT EXISTS idx_feedback_user_created
    ON public.feedback (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_feedback_status_created
    ON public.feedback (status, created_at DESC);

CREATE TRIGGER handle_feedback_updated_at
    BEFORE UPDATE ON public.feedback
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

GRANT INSERT ON TABLE public.feedback TO authenticated;

ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Deny public select feedback"
    ON public.feedback FOR SELECT TO PUBLIC
    USING (false);

CREATE POLICY "Allow users to insert their own feedback"
    ON public.feedback FOR INSERT TO authenticated
    WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Deny users to update feedback"
    ON public.feedback FOR UPDATE TO PUBLIC
    USING (false)
    WITH CHECK (false);

CREATE POLICY "Deny users to delete feedback"
    ON public.feedback FOR DELETE TO PUBLIC
    USING (false);
