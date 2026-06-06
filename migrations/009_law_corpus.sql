-- lidb migration 009: DE law corpus for li-books RAG
-- Requires 007_finance_org.sql applied first.
-- WP-030: law_source, law_document, law_chunk, law_embedding, law_refresh_run

BEGIN;

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE law_source (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                TEXT NOT NULL UNIQUE,
    name                TEXT NOT NULL,
    base_url            TEXT NOT NULL,
    source_kind         TEXT NOT NULL
                        CHECK (source_kind IN ('bundestag_xml', 'gesetze_html', 'bmf_metadata')),
    active              BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE law_document (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id           UUID NOT NULL REFERENCES law_source(id) ON DELETE CASCADE,
    external_id         TEXT NOT NULL,
    title               TEXT NOT NULL,
    law_code            TEXT NOT NULL,
    content_hash        TEXT NOT NULL,
    fetched_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    superseded_at       TIMESTAMPTZ,
    UNIQUE (source_id, external_id)
);

CREATE INDEX idx_law_document_code ON law_document (law_code) WHERE superseded_at IS NULL;

CREATE TABLE law_chunk (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id         UUID NOT NULL REFERENCES law_document(id) ON DELETE CASCADE,
    section_ref           TEXT NOT NULL,
    heading             TEXT,
    body                TEXT NOT NULL,
    tax_domains         TEXT[] NOT NULL DEFAULT '{}',
    token_count         INTEGER,
    chunk_index         INTEGER NOT NULL,
    content_hash        TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (document_id, chunk_index)
);

CREATE INDEX idx_law_chunk_domains ON law_chunk USING gin (tax_domains);
CREATE INDEX idx_law_chunk_section ON law_chunk (section_ref);

CREATE TABLE law_embedding (
    chunk_id            UUID PRIMARY KEY REFERENCES law_chunk(id) ON DELETE CASCADE,
    model               TEXT NOT NULL,
    embedding           vector(768) NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_law_embedding_vector ON law_embedding
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

CREATE TABLE law_refresh_run (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    started_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at         TIMESTAMPTZ,
    status              TEXT NOT NULL DEFAULT 'running'
                        CHECK (status IN ('running', 'success', 'partial', 'failed')),
    sources_processed   INTEGER NOT NULL DEFAULT 0,
    documents_upserted  INTEGER NOT NULL DEFAULT 0,
    chunks_written      INTEGER NOT NULL DEFAULT 0,
    embeddings_written  INTEGER NOT NULL DEFAULT 0,
    error_summary       TEXT
);

INSERT INTO schema_migrations (version, checksum)
VALUES ('009_law_corpus', 'pending:computed-at-apply-time')
ON CONFLICT (version) DO NOTHING;

COMMIT;
