CREATE TABLE IF NOT EXISTS public.bookself (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    souler_id UUID NOT NULL REFERENCES public.soulers(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT bookself_pkey PRIMARY KEY (user_id, souler_id)
);

CREATE INDEX IF NOT EXISTS idx_bookself_user_created_at
    ON public.bookself (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_bookself_souler_id
    ON public.bookself (souler_id);

ALTER TABLE public.bookself ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, DELETE ON TABLE public.bookself TO authenticated;

CREATE POLICY "Allow users to view their own bookself"
    ON public.bookself FOR SELECT TO authenticated
    USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Allow users to insert their own bookself"
    ON public.bookself FOR INSERT TO authenticated
    WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Deny users from updating bookself"
    ON public.bookself FOR UPDATE TO PUBLIC
    USING (false)
    WITH CHECK (false);

CREATE POLICY "Allow users to delete their own bookself"
    ON public.bookself FOR DELETE TO authenticated
    USING (user_id = (SELECT auth.uid()));
