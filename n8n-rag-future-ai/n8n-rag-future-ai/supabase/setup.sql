-- ============================================================
-- Supabase setup for the n8n RAG workflow
-- Run this in Supabase → SQL Editor before the first ingestion.
-- ============================================================

-- 1) Enable pgvector
create extension if not exists vector;

-- 2) Documents table (used by both Supabase Vector Store nodes)
--    IMPORTANT: the vector size must match the embedding model.
--    Check an existing table with:
--      select vector_dims(embedding) from documents limit 1;
--    and change 3072 below (here and in the function) if yours differs.
create table if not exists documents (
  id        bigserial primary key,
  content   text,          -- chunk text
  metadata  jsonb,         -- file_id, file_name, mime_type, source_url, loc, ...
  embedding vector(3072)   -- Gemini embedding vector
);

-- 3) Similarity search function (queryName = match_documents in n8n)
create or replace function match_documents (
  query_embedding vector(3072),
  match_count     int   default null,
  filter          jsonb default '{}'
) returns table (
  id         bigint,
  content    text,
  metadata   jsonb,
  similarity float
)
language plpgsql
as $$
#variable_conflict use_column
begin
  return query
  select
    id,
    content,
    metadata,
    1 - (documents.embedding <=> query_embedding) as similarity
  from documents
  where metadata @> filter
  order by documents.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- ============================================================
-- Maintenance
-- ============================================================

-- Remove duplicate chunks (if the ingestion pipeline ran more than once)
-- Keeps the oldest copy of each chunk.
-- delete from documents a
-- using documents b
-- where a.id > b.id
--   and a.content = b.content
--   and a.metadata->>'file_name' = b.metadata->>'file_name';

-- Count chunks per file
-- select metadata->>'file_name' as file, count(*) from documents group by 1;
