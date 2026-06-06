-- lidb migration 006: academic research catalog (li-research R0)
-- paper_record, citation_edge, research_job — gateway + MCP + ingest scaffolds.

BEGIN;

CREATE TABLE paper_record (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    doi             TEXT,
    title           TEXT NOT NULL,
    authors         JSONB NOT NULL DEFAULT '[]'::jsonb,
    abstract        TEXT,
    source          TEXT NOT NULL DEFAULT 'manual'
                    CHECK (source IN ('arxiv', 'openalex', 'crossref', 'manual')),
    metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_paper_record_doi
    ON paper_record (doi)
    WHERE doi IS NOT NULL;

CREATE INDEX idx_paper_record_title_trgm
    ON paper_record USING gin (to_tsvector('english', title));

CREATE TABLE citation_edge (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    citing_id       UUID NOT NULL REFERENCES paper_record(id) ON DELETE CASCADE,
    cited_id        UUID NOT NULL REFERENCES paper_record(id) ON DELETE CASCADE,
    context         TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (citing_id <> cited_id),
    UNIQUE (citing_id, cited_id)
);

CREATE INDEX idx_citation_edge_citing ON citation_edge (citing_id);
CREATE INDEX idx_citation_edge_cited ON citation_edge (cited_id);

CREATE TABLE research_job (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind            TEXT NOT NULL
                    CHECK (kind IN ('ingest_batch', 'index_citations', 'reindex_paper')),
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'running', 'succeeded', 'failed')),
    source_uri      TEXT,
    paper_ids       UUID[] NOT NULL DEFAULT '{}',
    error           TEXT,
    metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_research_job_status_created
    ON research_job (status, created_at DESC);

COMMIT;
