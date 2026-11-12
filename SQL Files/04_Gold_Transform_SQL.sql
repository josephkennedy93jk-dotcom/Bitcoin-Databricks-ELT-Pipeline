-- DAILY: one row per UTC day
CREATE OR REPLACE TABLE workspace.bitcoin.gold_btc_daily AS
WITH bars AS (
  SELECT
    CAST(date_trunc('DAY', timestamp) AS DATE) AS day,
    timestamp, open, high, low, close, volume, is_provisional
  FROM workspace.bitcoin.silver_btc_4h
),
daily AS (
  SELECT
    day,
    min_by(open, timestamp)  AS open,
    max(high)                AS high,
    min(low)                 AS low,
    max_by(close, timestamp) AS close,
    sum(volume)              AS volume,
    count(*)                 AS bars_in_day,
    max(is_provisional)      AS has_open_bar
  FROM bars
  GROUP BY day
)
SELECT
  *,
  (bars_in_day < 6 OR has_open_bar)                         AS is_incomplete,
  (close - lag(close) OVER (ORDER BY day))
    / lag(close) OVER (ORDER BY day) * 100                  AS pct_change_1d
FROM daily;

-- WEEKLY: one row per UTC week, Monday to Sunday
CREATE OR REPLACE TABLE workspace.bitcoin.gold_btc_weekly AS
WITH daily AS (
  SELECT * FROM workspace.bitcoin.gold_btc_daily
),
weekly AS (
  SELECT
    CAST(date_trunc('WEEK', day) AS DATE) AS week_start,
    min_by(open, day)    AS open,
    max(high)            AS high,
    min(low)             AS low,
    max_by(close, day)   AS close,
    sum(volume)          AS volume,
    count(*)             AS days_in_week,
    max(is_incomplete)   AS has_incomplete_day
  FROM daily
  GROUP BY CAST(date_trunc('WEEK', day) AS DATE)
)
SELECT
  *,
  (days_in_week < 7 OR has_incomplete_day)                  AS is_incomplete,
  (close - lag(close) OVER (ORDER BY week_start))
    / lag(close) OVER (ORDER BY week_start) * 100           AS pct_change_1w
FROM weekly;

-- LATEST: one row that feeds the tiles
CREATE OR REPLACE TABLE workspace.bitcoin.gold_btc_latest AS
WITH newest AS (
  SELECT timestamp, close
  FROM workspace.bitcoin.silver_btc_4h
  ORDER BY timestamp DESC
  LIMIT 1
)
SELECT
  n.timestamp                                   AS latest_bar_time,
  n.close                                       AS current_price,
  d.close                                       AS price_1d_ago,
  w.close                                       AS price_1w_ago,
  (n.close - d.close) / d.close * 100           AS pct_change_1d,
  (n.close - w.close) / w.close * 100           AS pct_change_1w
FROM newest n
LEFT JOIN workspace.bitcoin.silver_btc_4h d
  ON d.timestamp = n.timestamp - INTERVAL 1 DAY
LEFT JOIN workspace.bitcoin.silver_btc_4h w
  ON w.timestamp = n.timestamp - INTERVAL 7 DAYS;
