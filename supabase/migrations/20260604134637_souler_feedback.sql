CREATE TABLE IF NOT EXISTS public.souler_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    souler_id UUID NOT NULL REFERENCES public.soulers(id) ON DELETE CASCADE,
    lang VARCHAR(16) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT souler_feedback_content_not_empty CHECK (length(trim(content)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_souler_feedback_souler_created
    ON public.souler_feedback (souler_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_souler_feedback_user_created
    ON public.souler_feedback (user_id, created_at DESC);

CREATE TRIGGER handle_souler_feedback_updated_at
    BEFORE UPDATE ON public.souler_feedback
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

ALTER TABLE public.souler_feedback ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Deny public select souler feedback"
    ON public.souler_feedback FOR SELECT TO PUBLIC
    USING (false);

CREATE POLICY "Allow users to insert their own souler feedback"
    ON public.souler_feedback FOR INSERT TO authenticated
    WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Deny users to update souler feedback"
    ON public.souler_feedback FOR UPDATE TO PUBLIC
    USING (false)
    WITH CHECK (false);

CREATE POLICY "Deny users to delete souler feedback"
    ON public.souler_feedback FOR DELETE TO PUBLIC
    USING (false);
