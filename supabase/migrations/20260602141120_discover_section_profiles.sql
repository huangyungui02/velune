CREATE EXTENSION IF NOT EXISTS moddatetime schema extensions;

CREATE TEMP TABLE discover_section_migration_map ON COMMIT DROP AS
WITH ranked AS (
    SELECT
        id AS old_id,
        FIRST_VALUE(id) OVER (
            PARTITION BY sort_order
            ORDER BY is_active DESC, created_at ASC, id ASC
        ) AS new_id
    FROM public.discover_sections
)
SELECT old_id, new_id
FROM ranked;

CREATE TABLE IF NOT EXISTS public.discover_section_profile (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    section_id UUID NOT NULL REFERENCES public.discover_sections(id) ON DELETE CASCADE,
    lang VARCHAR(16) NOT NULL,
    title VARCHAR(128) NOT NULL,
    subtitle TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT discover_section_profile_section_lang_unique UNIQUE (section_id, lang)
);

CREATE INDEX IF NOT EXISTS idx_discover_section_profile_lang_title
    ON public.discover_section_profile (lang, title);
CREATE INDEX IF NOT EXISTS idx_discover_section_profile_section_id
    ON public.discover_section_profile (section_id);

INSERT INTO public.discover_section_profile (section_id, lang, title, subtitle)
SELECT m.new_id, s.lang, s.title, s.subtitle
FROM public.discover_sections s
JOIN discover_section_migration_map m
    ON m.old_id = s.id
ON CONFLICT (section_id, lang) DO UPDATE SET
    title = EXCLUDED.title,
    subtitle = EXCLUDED.subtitle;

INSERT INTO public.discover_section_items (section_id, souler_id, sort_order, created_at, updated_at)
SELECT m.new_id, i.souler_id, MIN(i.sort_order), MIN(i.created_at), MAX(i.updated_at)
FROM public.discover_section_items i
JOIN discover_section_migration_map m
    ON m.old_id = i.section_id
WHERE m.old_id <> m.new_id
GROUP BY m.new_id, i.souler_id
ON CONFLICT (section_id, souler_id) DO UPDATE SET
    sort_order = LEAST(public.discover_section_items.sort_order, EXCLUDED.sort_order),
    updated_at = GREATEST(public.discover_section_items.updated_at, EXCLUDED.updated_at);

DELETE FROM public.discover_section_items i
USING discover_section_migration_map m
WHERE i.section_id = m.old_id
    AND m.old_id <> m.new_id;

DELETE FROM public.discover_sections s
USING discover_section_migration_map m
WHERE s.id = m.old_id
    AND m.old_id <> m.new_id;

DROP TRIGGER IF EXISTS handle_discover_section_profile_updated_at ON public.discover_section_profile;
CREATE TRIGGER handle_discover_section_profile_updated_at
    BEFORE UPDATE ON public.discover_section_profile
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

ALTER TABLE public.discover_section_profile ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anyone to view discover section profile"
    ON public.discover_section_profile FOR SELECT TO PUBLIC
    USING (true);
CREATE POLICY "Deny anyone from updating discover section profile"
    ON public.discover_section_profile FOR UPDATE TO PUBLIC
    USING (false)
    WITH CHECK (false);
CREATE POLICY "Deny anyone from inserting discover section profile"
    ON public.discover_section_profile FOR INSERT TO PUBLIC
    WITH CHECK (false);
CREATE POLICY "Deny anyone from deleting discover section profile"
    ON public.discover_section_profile FOR DELETE TO PUBLIC
    USING (false);
CREATE POLICY "Allow admins to insert discover section profile"
    ON public.discover_section_profile FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to update discover section profile"
    ON public.discover_section_profile FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to delete discover section profile"
    ON public.discover_section_profile FOR DELETE TO authenticated
    USING (public.is_admin());
