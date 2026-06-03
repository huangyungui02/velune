DROP TRIGGER IF EXISTS handle_souler_insert_sync_name_alias ON public.soulers;
DROP FUNCTION IF EXISTS public.sync_souler_name_alias();

DROP INDEX IF EXISTS public.idx_soulers_name;
DROP INDEX IF EXISTS public.idx_soulers_canonical_name;
DROP INDEX IF EXISTS public.idx_soulers_canonical_name_lang;
DROP INDEX IF EXISTS public.idx_soulers_checked_canonical_name_trgm;
DROP INDEX IF EXISTS public.idx_soulers_lang;
DROP INDEX IF EXISTS public.idx_soulers_wiki_id_lang_unique;
DROP INDEX IF EXISTS public.idx_chapters_souler_seq;

DROP VIEW IF EXISTS public.resonances_with_souler;
DROP VIEW IF EXISTS public.echoes_with_souler;

CREATE VIEW public.resonances_with_souler
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
    COALESCE(p.name, '') AS souler_name
FROM public.resonances AS r
JOIN public.soulers AS s
    ON s.id = r.souler_id
LEFT JOIN public.souler_profile AS p
    ON p.souler_id = s.id
    AND p.lang = 'zh'
LEFT JOIN public.sessions AS sess
    ON sess.id = r.last_session_id;

REVOKE ALL ON TABLE public.resonances_with_souler FROM PUBLIC;
GRANT SELECT ON TABLE public.resonances_with_souler TO authenticated;
GRANT SELECT ON TABLE public.resonances_with_souler TO service_role;

ALTER TABLE public.souler_aliases
    DROP CONSTRAINT IF EXISTS souler_aliases_pkey;

CREATE UNIQUE INDEX IF NOT EXISTS souler_aliases_alias_unique
    ON public.souler_aliases (alias);
CREATE INDEX IF NOT EXISTS idx_souler_aliases_souler_id
    ON public.souler_aliases (souler_id);

DROP POLICY IF EXISTS "Allow admins to insert souler aliases" ON public.souler_aliases;
DROP POLICY IF EXISTS "Allow admins to update souler aliases" ON public.souler_aliases;
DROP POLICY IF EXISTS "Allow admins to delete souler aliases" ON public.souler_aliases;

CREATE POLICY "Allow admins to insert souler aliases"
    ON public.souler_aliases FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to update souler aliases"
    ON public.souler_aliases FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to delete souler aliases"
    ON public.souler_aliases FOR DELETE TO authenticated
    USING (public.is_admin());

ALTER TABLE public.soulers
    DROP COLUMN IF EXISTS name,
    DROP COLUMN IF EXISTS canonical_name,
    DROP COLUMN IF EXISTS lang,
    DROP COLUMN IF EXISTS introduction;

CREATE UNIQUE INDEX IF NOT EXISTS idx_soulers_wiki_id_unique
    ON public.soulers (wiki_id)
    WHERE wiki_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_soulers_checked_updated_at_desc
    ON public.soulers (updated_at DESC)
    WHERE checked = true;

ALTER TABLE public.chapters
    DROP CONSTRAINT IF EXISTS chapters_souler_seq_unique;

ALTER TABLE public.chapters
    ADD CONSTRAINT chapters_souler_lang_seq_unique UNIQUE (souler_id, lang, seq);

CREATE INDEX IF NOT EXISTS idx_chapters_souler_lang_seq
    ON public.chapters (souler_id, lang, seq);

DROP TABLE IF EXISTS public.souler_avatars;

ALTER TABLE public.discover_sections
    DROP COLUMN IF EXISTS lang,
    DROP COLUMN IF EXISTS title,
    DROP COLUMN IF EXISTS subtitle;

CREATE INDEX IF NOT EXISTS idx_discover_sections_active_sort
    ON public.discover_sections (sort_order)
    WHERE is_active = true;
