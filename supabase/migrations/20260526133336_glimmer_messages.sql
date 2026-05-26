CREATE TABLE public.glimmer_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    glimmer_id UUID NOT NULL REFERENCES public.glimmers(id) ON DELETE CASCADE,
    sequence INT NOT NULL,
    type TEXT NOT NULL,
    role TEXT CHECK (role IN ('user', 'assistant')),
    content TEXT,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT glimmer_messages_content_or_payload_check
    CHECK (
        NULLIF(trim(COALESCE(content, '')), '') IS NOT NULL
        OR payload <> '{}'::jsonb
    )
);

CREATE UNIQUE INDEX glimmer_messages_glimmer_sequence_idx
    ON public.glimmer_messages (glimmer_id, sequence);

CREATE INDEX glimmer_messages_user_glimmer_sequence_idx
    ON public.glimmer_messages (user_id, glimmer_id, sequence);

ALTER TABLE public.glimmer_messages ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.glimmer_messages TO authenticated;

CREATE POLICY "Allow users to view their own glimmer messages"
    ON public.glimmer_messages FOR SELECT
    TO authenticated
    USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Deny users from inserting glimmer messages"
    ON public.glimmer_messages FOR INSERT
    TO authenticated
    WITH CHECK (false);

CREATE POLICY "Deny users from updating glimmer messages"
    ON public.glimmer_messages FOR UPDATE
    TO authenticated
    USING (false)
    WITH CHECK (false);

CREATE POLICY "Deny users from deleting glimmer messages"
    ON public.glimmer_messages FOR DELETE
    TO authenticated
    USING (false);
