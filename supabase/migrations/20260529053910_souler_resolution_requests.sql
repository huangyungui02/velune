CREATE TABLE souler_resolution_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requested_name VARCHAR(128) NOT NULL,
    lang VARCHAR(16) NOT NULL,
    status TEXT NOT NULL DEFAULT 'queued',
    task_id TEXT,
    souler_id UUID REFERENCES soulers(id) ON DELETE SET NULL,
    canonical_name VARCHAR(128),
    wiki_id VARCHAR(32),
    error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    CONSTRAINT souler_resolution_requests_status_check
        CHECK (status IN ('queued', 'processing', 'complete', 'failed'))
);

CREATE UNIQUE INDEX idx_souler_resolution_requests_name_lang_unique
    ON souler_resolution_requests (requested_name, lang);

CREATE INDEX idx_souler_resolution_requests_status_updated_at
    ON souler_resolution_requests (status, updated_at DESC);

CREATE INDEX idx_souler_resolution_requests_souler_id
    ON souler_resolution_requests (souler_id)
    WHERE souler_id IS NOT NULL;

CREATE TRIGGER handle_souler_resolution_requests_updated_at
    BEFORE UPDATE ON souler_resolution_requests
    FOR EACH ROW
    EXECUTE FUNCTION extensions.moddatetime(updated_at);

ALTER TABLE souler_resolution_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Deny public select souler resolution requests"
    ON souler_resolution_requests FOR SELECT TO PUBLIC USING (false);
CREATE POLICY "Deny public insert souler resolution requests"
    ON souler_resolution_requests FOR INSERT TO PUBLIC WITH CHECK (false);
CREATE POLICY "Deny public update souler resolution requests"
    ON souler_resolution_requests FOR UPDATE TO PUBLIC USING (false) WITH CHECK (false);
CREATE POLICY "Deny public delete souler resolution requests"
    ON souler_resolution_requests FOR DELETE TO PUBLIC USING (false);
