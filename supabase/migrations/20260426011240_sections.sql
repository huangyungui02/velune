CREATE TABLE IF NOT EXISTS public.discover_sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_discover_sections_active_sort
    ON public.discover_sections (sort_order)
    WHERE is_active = TRUE;

DROP TRIGGER IF EXISTS handle_discover_sections_updated_at ON public.discover_sections;
CREATE TRIGGER handle_discover_sections_updated_at
    BEFORE UPDATE ON public.discover_sections
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

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

DROP TRIGGER IF EXISTS handle_discover_section_profile_updated_at ON public.discover_section_profile;
CREATE TRIGGER handle_discover_section_profile_updated_at
    BEFORE UPDATE ON public.discover_section_profile
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

CREATE TABLE IF NOT EXISTS public.discover_section_items (
    section_id UUID NOT NULL REFERENCES public.discover_sections(id) ON DELETE CASCADE,
    souler_id UUID NOT NULL REFERENCES public.soulers(id) ON DELETE CASCADE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (section_id, souler_id)
);

CREATE INDEX IF NOT EXISTS idx_discover_section_items_section_sort
    ON public.discover_section_items (section_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_discover_section_items_souler_id
    ON public.discover_section_items (souler_id);

DROP TRIGGER IF EXISTS handle_discover_section_items_updated_at ON public.discover_section_items;
CREATE TRIGGER handle_discover_section_items_updated_at
    BEFORE UPDATE ON public.discover_section_items
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

ALTER TABLE public.discover_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discover_section_profile ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discover_section_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anyone to view discover sections"
    ON public.discover_sections FOR SELECT TO PUBLIC
    USING (TRUE);
CREATE POLICY "Deny anyone from updating discover sections"
    ON public.discover_sections FOR UPDATE TO PUBLIC
    USING (FALSE)
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from inserting discover sections"
    ON public.discover_sections FOR INSERT TO PUBLIC
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from deleting discover sections"
    ON public.discover_sections FOR DELETE TO PUBLIC
    USING (FALSE);

CREATE POLICY "Allow anyone to view discover section profile"
    ON public.discover_section_profile FOR SELECT TO PUBLIC
    USING (TRUE);
CREATE POLICY "Deny anyone from updating discover section profile"
    ON public.discover_section_profile FOR UPDATE TO PUBLIC
    USING (FALSE)
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from inserting discover section profile"
    ON public.discover_section_profile FOR INSERT TO PUBLIC
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from deleting discover section profile"
    ON public.discover_section_profile FOR DELETE TO PUBLIC
    USING (FALSE);

CREATE POLICY "Allow anyone to view discover section items"
    ON public.discover_section_items FOR SELECT TO PUBLIC
    USING (TRUE);
CREATE POLICY "Deny anyone from updating discover section items"
    ON public.discover_section_items FOR UPDATE TO PUBLIC
    USING (FALSE)
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from inserting discover section items"
    ON public.discover_section_items FOR INSERT TO PUBLIC
    WITH CHECK (FALSE);
CREATE POLICY "Deny anyone from deleting discover section items"
    ON public.discover_section_items FOR DELETE TO PUBLIC
    USING (FALSE);

CREATE POLICY "Allow admins to insert discover sections"
    ON public.discover_sections FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to update discover sections"
    ON public.discover_sections FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to delete discover sections"
    ON public.discover_sections FOR DELETE TO authenticated
    USING (public.is_admin());

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

CREATE POLICY "Allow admins to insert discover section items"
    ON public.discover_section_items FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to update discover section items"
    ON public.discover_section_items FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to delete discover section items"
    ON public.discover_section_items FOR DELETE TO authenticated
    USING (public.is_admin());
