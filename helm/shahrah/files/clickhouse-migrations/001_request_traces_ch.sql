CREATE TABLE IF NOT EXISTS request_traces_ch
(
  trace_id String,
  tenant_id String,
  request_id String,
  model String,
  route String,
  status_code Int32,
  started_at DateTime64(3, 'UTC'),
  duration_ms Int32,
  error_code String,
  sampled UInt8
)
ENGINE = MergeTree
PARTITION BY toDate(started_at)
ORDER BY (tenant_id, started_at, trace_id)
TTL toDate(started_at) + INTERVAL 7 DAY;
