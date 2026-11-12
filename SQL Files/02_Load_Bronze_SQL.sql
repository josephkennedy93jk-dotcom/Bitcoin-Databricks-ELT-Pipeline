CREATE OR REPLACE TABLE workspace.bitcoin.bronze_btc_4h AS
SELECT
  *,
  current_timestamp()  AS _load_ts,
  _metadata.file_path  AS _source_file
FROM read_files(
  '/Volumes/workspace/bitcoin/raw/alpaca/BTC_USD/4h/*.parquet',
  format => 'parquet'
);
