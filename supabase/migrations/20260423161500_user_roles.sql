CREATE TABLE public.user_roles (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT user_roles_pk PRIMARY KEY (user_id, role),
    CONSTRAINT user_roles_role_not_blank_check CHECK (NULLIF(trim(role), '') IS NOT NULL),
    CONSTRAINT user_roles_role_lowercase_check CHECK (role = lower(role))
);

CREATE INDEX user_roles_role_idx
    ON public.user_roles (role);

CREATE TRIGGER handle_user_roles_updated_at
    BEFORE UPDATE ON public.user_roles
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to view their own roles"
    ON public.user_roles FOR SELECT
    TO authenticated
    USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Deny anyone from inserting user roles"
    ON public.user_roles FOR INSERT
    TO PUBLIC
    WITH CHECK (false);

CREATE POLICY "Deny anyone from updating user roles"
    ON public.user_roles FOR UPDATE
    TO PUBLIC
    USING (false)
    WITH CHECK (false);

CREATE POLICY "Deny anyone from deleting user roles"
    ON public.user_roles FOR DELETE
    TO PUBLIC
    USING (false);
