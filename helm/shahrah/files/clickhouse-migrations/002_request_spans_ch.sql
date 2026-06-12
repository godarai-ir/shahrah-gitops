CREATE TABLE IF NOT EXISTS request_spans_ch
(
  span_id String,
  trace_id String,
  tenant_id String,
  parent_span_id String,
  name String,
  kind String,
  started_at DateTime64(3, 'UTC'),
  duration_ms Int32,
  status String,
  attributes_json String
)
ENGINE = MergeTree
PARTITION BY toDate(started_at)
ORDER BY (tenant_id, trace_id, started_at, span_id)
TTL toDate(started_at) + INTERVAL 7 DAY;
