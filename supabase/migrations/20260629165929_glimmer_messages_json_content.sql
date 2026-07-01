ALTER TABLE public.glimmer_messages
    DROP CONSTRAINT IF EXISTS glimmer_messages_content_or_payload_check;

ALTER TABLE public.glimmer_messages
    ADD COLUMN content_json JSONB;

UPDATE public.glimmer_messages
SET
    content_json = CASE
        WHEN type = 'tool_result'
            AND payload->>'tool' = 'resonance_match'
            THEN COALESCE(payload->'items', '[]'::jsonb)
        WHEN payload <> '{}'::jsonb
            THEN payload
        ELSE to_jsonb(content)
    END,
    type = CASE
        WHEN type = 'tool_result'
            AND NULLIF(payload->>'tool', '') IS NOT NULL
            THEN payload->>'tool'
        ELSE type
    END,
    role = CASE
        WHEN type = 'tool_result' THEN 'assistant'
        WHEN type = 'divination' THEN 'user'
        ELSE role
    END;

ALTER TABLE public.glimmer_messages
    DROP COLUMN content,
    DROP COLUMN payload;

ALTER TABLE public.glimmer_messages
    RENAME COLUMN content_json TO content;

ALTER TABLE public.glimmer_messages
    ALTER COLUMN content SET NOT NULL;

ALTER TABLE public.glimmer_messages
    ADD CONSTRAINT glimmer_messages_content_check
    CHECK (content <> 'null'::jsonb);
