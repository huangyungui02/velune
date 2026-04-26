CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.user_roles AS ur
        WHERE ur.user_id = auth.uid()
          AND ur.role = 'admin'
    );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO service_role;


CREATE POLICY "Allow admins to insert soulers"
    ON public.soulers FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to update soulers"
    ON public.soulers FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to delete soulers"
    ON public.soulers FOR DELETE TO authenticated
    USING (public.is_admin());
CREATE POLICY "Allow admins to insert souler avatars"
    ON public.souler_avatars FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to update souler avatars"
    ON public.souler_avatars FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to delete souler avatars"
    ON public.souler_avatars FOR DELETE TO authenticated
    USING (public.is_admin());

CREATE POLICY "Allow admins to insert chapters"
    ON public.chapters FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to update chapters"
    ON public.chapters FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

CREATE POLICY "Allow admins to insert keywords"
    ON public.keywords FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to update keywords"
    ON public.keywords FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to delete keywords"
    ON public.keywords FOR DELETE TO authenticated
    USING (public.is_admin());

CREATE POLICY "Allow admins to insert souler keywords"
    ON public.souler_keyword FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to update souler keywords"
    ON public.souler_keyword FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
CREATE POLICY "Allow admins to delete souler keywords"
    ON public.souler_keyword FOR DELETE TO authenticated
    USING (public.is_admin());

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE
SET
    name = EXCLUDED.name,
    public = EXCLUDED.public;

CREATE POLICY "Allow admins to insert avatar objects"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'avatars' AND public.is_admin());
CREATE POLICY "Allow admins to select avatar objects"
    ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'avatars' AND public.is_admin());
CREATE POLICY "Allow admins to update avatar objects"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'avatars' AND public.is_admin())
    WITH CHECK (bucket_id = 'avatars' AND public.is_admin());
CREATE POLICY "Allow admins to delete avatar objects"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'avatars' AND public.is_admin());
