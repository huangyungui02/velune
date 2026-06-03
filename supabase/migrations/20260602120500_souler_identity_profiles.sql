CREATE EXTENSION IF NOT EXISTS moddatetime schema extensions;

ALTER TABLE public.soulers
    ADD COLUMN IF NOT EXISTS avatar TEXT;

CREATE TEMP TABLE souler_identity_migration_map ON COMMIT DROP AS
WITH ranked AS (
    SELECT
        id AS old_id,
        CASE
            WHEN wiki_id IS NULL THEN id
            ELSE FIRST_VALUE(id) OVER (
                PARTITION BY wiki_id
                ORDER BY checked DESC, created_at ASC, id ASC
            )
        END AS new_id
    FROM public.soulers
)
SELECT old_id, new_id
FROM ranked;

CREATE TABLE IF NOT EXISTS public.souler_profile (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    souler_id UUID NOT NULL REFERENCES public.soulers(id) ON DELETE CASCADE,
    lang VARCHAR(16) NOT NULL,
    name VARCHAR(64) NOT NULL,
    introduction TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT souler_profile_souler_lang_unique UNIQUE (souler_id, lang)
);

CREATE INDEX IF NOT EXISTS idx_souler_profile_lang_name
    ON public.souler_profile (lang, name);
CREATE INDEX IF NOT EXISTS idx_souler_profile_souler_id
    ON public.souler_profile (souler_id);

DROP TRIGGER IF EXISTS handle_souler_profile_updated_at ON public.souler_profile;
CREATE TRIGGER handle_souler_profile_updated_at
    BEFORE UPDATE ON public.souler_profile
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

ALTER TABLE public.chapters
    ADD COLUMN IF NOT EXISTS lang VARCHAR(16);

UPDATE public.chapters c
SET lang = s.lang
FROM public.soulers s
WHERE c.souler_id = s.id
    AND c.lang IS NULL;

UPDATE public.chapters
SET lang = 'zh'
WHERE lang IS NULL;

ALTER TABLE public.chapters
    ALTER COLUMN lang SET NOT NULL;

INSERT INTO public.souler_profile (souler_id, lang, name, introduction)
SELECT m.new_id, s.lang, s.name, s.introduction
FROM public.soulers s
JOIN souler_identity_migration_map m
    ON m.old_id = s.id
ON CONFLICT (souler_id, lang) DO UPDATE SET
    name = EXCLUDED.name,
    introduction = EXCLUDED.introduction;

UPDATE public.soulers s
SET avatar = a.image_path
FROM public.souler_avatars a
WHERE s.wiki_id = a.wiki_id
    AND s.avatar IS NULL;

DROP INDEX IF EXISTS public.idx_resonances_user_id_souler_id;

UPDATE public.sessions s
SET souler_id = m.new_id
FROM souler_identity_migration_map m
WHERE s.souler_id = m.old_id
    AND m.old_id <> m.new_id;

UPDATE public.messages msg
SET souler_id = m.new_id
FROM souler_identity_migration_map m
WHERE msg.souler_id = m.old_id
    AND m.old_id <> m.new_id;

WITH ranked_resonances AS (
    SELECT
        r.id,
        m.new_id,
        ROW_NUMBER() OVER (
            PARTITION BY r.user_id, m.new_id
            ORDER BY r.updated_at DESC, r.created_at DESC, r.id ASC
        ) AS rn
    FROM public.resonances r
    JOIN souler_identity_migration_map m
        ON m.old_id = r.souler_id
)
DELETE FROM public.resonances r
USING ranked_resonances rr
WHERE r.id = rr.id
    AND rr.rn > 1;

UPDATE public.resonances r
SET souler_id = m.new_id
FROM souler_identity_migration_map m
WHERE r.souler_id = m.old_id
    AND m.old_id <> m.new_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_resonances_user_id_souler_id
    ON public.resonances (user_id, souler_id);

ALTER TABLE public.chapters
    DROP CONSTRAINT IF EXISTS chapters_souler_seq_unique;

INSERT INTO public.chapters (souler_id, lang, seq, title, subtitle, task, created_at, updated_at)
SELECT m.new_id, c.lang, c.seq, c.title, c.subtitle, c.task, c.created_at, c.updated_at
FROM public.chapters c
JOIN souler_identity_migration_map m
    ON m.old_id = c.souler_id
WHERE m.old_id <> m.new_id
ON CONFLICT DO NOTHING;

DELETE FROM public.chapters c
USING souler_identity_migration_map m
WHERE c.souler_id = m.old_id
    AND m.old_id <> m.new_id;

INSERT INTO public.souler_aliases (souler_id, alias, created_at)
SELECT m.new_id, a.alias, MIN(a.created_at)
FROM public.souler_aliases a
JOIN souler_identity_migration_map m
    ON m.old_id = a.souler_id
WHERE m.old_id <> m.new_id
GROUP BY m.new_id, a.alias
ON CONFLICT DO NOTHING;

DELETE FROM public.souler_aliases a
USING souler_identity_migration_map m
WHERE a.souler_id = m.old_id
    AND m.old_id <> m.new_id;

INSERT INTO public.discover_section_items (section_id, souler_id, sort_order, created_at, updated_at)
SELECT i.section_id, m.new_id, MIN(i.sort_order), MIN(i.created_at), MAX(i.updated_at)
FROM public.discover_section_items i
JOIN souler_identity_migration_map m
    ON m.old_id = i.souler_id
WHERE m.old_id <> m.new_id
GROUP BY i.section_id, m.new_id
ON CONFLICT (section_id, souler_id) DO UPDATE SET
    sort_order = LEAST(public.discover_section_items.sort_order, EXCLUDED.sort_order),
    updated_at = GREATEST(public.discover_section_items.updated_at, EXCLUDED.updated_at);

DELETE FROM public.discover_section_items i
USING souler_identity_migration_map m
WHERE i.souler_id = m.old_id
    AND m.old_id <> m.new_id;

INSERT INTO public.souler_keyword (souler_id, keyword_id, weight, created_at, updated_at)
SELECT m.new_id, sk.keyword_id, MAX(sk.weight), MIN(sk.created_at), MAX(sk.updated_at)
FROM public.souler_keyword sk
JOIN souler_identity_migration_map m
    ON m.old_id = sk.souler_id
WHERE m.old_id <> m.new_id
GROUP BY m.new_id, sk.keyword_id
ON CONFLICT (souler_id, keyword_id) DO UPDATE SET
    weight = GREATEST(public.souler_keyword.weight, EXCLUDED.weight),
    updated_at = GREATEST(public.souler_keyword.updated_at, EXCLUDED.updated_at);

DELETE FROM public.souler_keyword sk
USING souler_identity_migration_map m
WHERE sk.souler_id = m.old_id
    AND m.old_id <> m.new_id;

UPDATE public.souler_resolution_requests r
SET souler_id = m.new_id
FROM souler_identity_migration_map m
WHERE r.souler_id = m.old_id
    AND m.old_id <> m.new_id;

DELETE FROM public.soulers s
USING souler_identity_migration_map m
WHERE s.id = m.old_id
    AND m.old_id <> m.new_id;

ALTER TABLE public.souler_profile ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anyone to view souler profile"
    ON public.souler_profile FOR SELECT TO PUBLIC
    USING (true);
CREATE POLICY "Deny anyone from updating souler profile"
    ON public.souler_profile FOR UPDATE TO PUBLIC
    USING (false)
    WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting souler profile"
    ON public.souler_profile FOR INSERT TO PUBLIC
    WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting souler profile"
    ON public.souler_profile FOR DELETE TO PUBLIC
    USING (false);
CREATE POLICY "Allow admins to insert souler profile"
    ON public.souler_profile FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to update souler profile"
    ON public.souler_profile FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to delete souler profile"
    ON public.souler_profile FOR DELETE TO authenticated
    USING (public.is_admin());
