CREATE TABLE IF NOT EXISTS public.folios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    souler_id UUID NOT NULL REFERENCES public.soulers(id) ON DELETE CASCADE,
    cover_image TEXT,
    featured BOOLEAN NOT NULL DEFAULT FALSE,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_folios_souler_id
    ON public.folios (souler_id);
CREATE INDEX IF NOT EXISTS idx_folios_public_featured_created_at
    ON public.folios (featured DESC, created_at DESC)
    WHERE is_public = TRUE;

DROP TRIGGER IF EXISTS handle_folios_updated_at ON public.folios;
CREATE TRIGGER handle_folios_updated_at
    BEFORE UPDATE ON public.folios
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

CREATE TABLE IF NOT EXISTS public.folio_translations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    folio_id UUID NOT NULL REFERENCES public.folios(id) ON DELETE CASCADE,
    lang VARCHAR(16) NOT NULL,
    title VARCHAR(128) NOT NULL,
    subtitle TEXT,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT folio_translations_folio_lang_unique UNIQUE (folio_id, lang)
);

CREATE INDEX IF NOT EXISTS idx_folio_translations_lang_title
    ON public.folio_translations (lang, title);
CREATE INDEX IF NOT EXISTS idx_folio_translations_folio_id
    ON public.folio_translations (folio_id);

DROP TRIGGER IF EXISTS handle_folio_translations_updated_at ON public.folio_translations;
CREATE TRIGGER handle_folio_translations_updated_at
    BEFORE UPDATE ON public.folio_translations
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

CREATE TABLE IF NOT EXISTS public.themes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT themes_key_unique UNIQUE (key)
);

DROP TRIGGER IF EXISTS handle_themes_updated_at ON public.themes;
CREATE TRIGGER handle_themes_updated_at
    BEFORE UPDATE ON public.themes
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

CREATE TABLE IF NOT EXISTS public.themes_translations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    theme_id UUID NOT NULL REFERENCES public.themes(id) ON DELETE CASCADE,
    lang VARCHAR(16) NOT NULL,
    name VARCHAR(128) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT themes_translations_theme_lang_unique UNIQUE (theme_id, lang)
);

CREATE INDEX IF NOT EXISTS idx_themes_translations_lang_name
    ON public.themes_translations (lang, name);
CREATE INDEX IF NOT EXISTS idx_themes_translations_theme_id
    ON public.themes_translations (theme_id);

DROP TRIGGER IF EXISTS handle_themes_translations_updated_at ON public.themes_translations;
CREATE TRIGGER handle_themes_translations_updated_at
    BEFORE UPDATE ON public.themes_translations
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

CREATE TABLE IF NOT EXISTS public.folio_themes (
    folio_id UUID NOT NULL REFERENCES public.folios(id) ON DELETE CASCADE,
    theme_id UUID NOT NULL REFERENCES public.themes(id) ON DELETE CASCADE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (folio_id, theme_id)
);

CREATE INDEX IF NOT EXISTS idx_folio_themes_folio_sort
    ON public.folio_themes (folio_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_folio_themes_theme_id
    ON public.folio_themes (theme_id);

CREATE TABLE IF NOT EXISTS public.folio_prompts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    folio_id UUID NOT NULL REFERENCES public.folios(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT folio_prompts_version_check CHECK (version > 0),
    CONSTRAINT folio_prompts_folio_version_unique UNIQUE (folio_id, version)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_folio_prompts_one_active_per_folio
    ON public.folio_prompts (folio_id)
    WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_folio_prompts_folio_id
    ON public.folio_prompts (folio_id);

DROP TRIGGER IF EXISTS handle_folio_prompts_updated_at ON public.folio_prompts;
CREATE TRIGGER handle_folio_prompts_updated_at
    BEFORE UPDATE ON public.folio_prompts
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

ALTER TABLE public.folios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.folio_translations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.themes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.themes_translations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.folio_themes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.folio_prompts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anyone to view public folios"
    ON public.folios FOR SELECT TO PUBLIC
    USING (is_public = TRUE);
CREATE POLICY "Deny anyone from updating folios"
    ON public.folios FOR UPDATE TO PUBLIC
    USING (FALSE)
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from inserting folios"
    ON public.folios FOR INSERT TO PUBLIC
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from deleting folios"
    ON public.folios FOR DELETE TO PUBLIC
    USING (FALSE);

CREATE POLICY "Allow anyone to view public folio translations"
    ON public.folio_translations FOR SELECT TO PUBLIC
    USING (
        EXISTS (
            SELECT 1
            FROM public.folios
            WHERE folios.id = folio_translations.folio_id
              AND folios.is_public = TRUE
        )
    );
CREATE POLICY "Deny anyone from updating folio translations"
    ON public.folio_translations FOR UPDATE TO PUBLIC
    USING (FALSE)
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from inserting folio translations"
    ON public.folio_translations FOR INSERT TO PUBLIC
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from deleting folio translations"
    ON public.folio_translations FOR DELETE TO PUBLIC
    USING (FALSE);

CREATE POLICY "Allow anyone to view themes"
    ON public.themes FOR SELECT TO PUBLIC
    USING (TRUE);
CREATE POLICY "Deny anyone from updating themes"
    ON public.themes FOR UPDATE TO PUBLIC
    USING (FALSE)
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from inserting themes"
    ON public.themes FOR INSERT TO PUBLIC
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from deleting themes"
    ON public.themes FOR DELETE TO PUBLIC
    USING (FALSE);

CREATE POLICY "Allow anyone to view theme translations"
    ON public.themes_translations FOR SELECT TO PUBLIC
    USING (TRUE);
CREATE POLICY "Deny anyone from updating theme translations"
    ON public.themes_translations FOR UPDATE TO PUBLIC
    USING (FALSE)
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from inserting theme translations"
    ON public.themes_translations FOR INSERT TO PUBLIC
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from deleting theme translations"
    ON public.themes_translations FOR DELETE TO PUBLIC
    USING (FALSE);

CREATE POLICY "Allow anyone to view public folio themes"
    ON public.folio_themes FOR SELECT TO PUBLIC
    USING (
        EXISTS (
            SELECT 1
            FROM public.folios
            WHERE folios.id = folio_themes.folio_id
              AND folios.is_public = TRUE
        )
    );
CREATE POLICY "Deny anyone from updating folio themes"
    ON public.folio_themes FOR UPDATE TO PUBLIC
    USING (FALSE)
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from inserting folio themes"
    ON public.folio_themes FOR INSERT TO PUBLIC
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from deleting folio themes"
    ON public.folio_themes FOR DELETE TO PUBLIC
    USING (FALSE);

CREATE POLICY "Deny anyone from updating folio prompts"
    ON public.folio_prompts FOR UPDATE TO PUBLIC
    USING (FALSE)
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from inserting folio prompts"
    ON public.folio_prompts FOR INSERT TO PUBLIC
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from deleting folio prompts"
    ON public.folio_prompts FOR DELETE TO PUBLIC
    USING (FALSE);

CREATE POLICY "Allow admins to view all folios"
    ON public.folios FOR SELECT TO authenticated
    USING (public.is_admin());
CREATE POLICY "Allow admins to insert folios"
    ON public.folios FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to update folios"
    ON public.folios FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to delete folios"
    ON public.folios FOR DELETE TO authenticated
    USING (public.is_admin());

CREATE POLICY "Allow admins to view all folio translations"
    ON public.folio_translations FOR SELECT TO authenticated
    USING (public.is_admin());
CREATE POLICY "Allow admins to insert folio translations"
    ON public.folio_translations FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to update folio translations"
    ON public.folio_translations FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to delete folio translations"
    ON public.folio_translations FOR DELETE TO authenticated
    USING (public.is_admin());

CREATE POLICY "Allow admins to insert themes"
    ON public.themes FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to update themes"
    ON public.themes FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to delete themes"
    ON public.themes FOR DELETE TO authenticated
    USING (public.is_admin());

CREATE POLICY "Allow admins to insert theme translations"
    ON public.themes_translations FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to update theme translations"
    ON public.themes_translations FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to delete theme translations"
    ON public.themes_translations FOR DELETE TO authenticated
    USING (public.is_admin());

CREATE POLICY "Allow admins to view all folio themes"
    ON public.folio_themes FOR SELECT TO authenticated
    USING (public.is_admin());
CREATE POLICY "Allow admins to insert folio themes"
    ON public.folio_themes FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to update folio themes"
    ON public.folio_themes FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to delete folio themes"
    ON public.folio_themes FOR DELETE TO authenticated
    USING (public.is_admin());

CREATE POLICY "Allow admins to view all folio prompts"
    ON public.folio_prompts FOR SELECT TO authenticated
    USING (public.is_admin());
CREATE POLICY "Allow admins to insert folio prompts"
    ON public.folio_prompts FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to update folio prompts"
    ON public.folio_prompts FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to delete folio prompts"
    ON public.folio_prompts FOR DELETE TO authenticated
    USING (public.is_admin());
