-- Purpose: Aggregates sales records into inventory metrics
-- Author: SHAOYIK YEOH
-- Logic: Uses 1.65 Z-Score for 95% service level safety stock

--CREATE OR REPLACE TABLE landing_data_v1.sliver_inventory_report AS
  -- ■■■■■■ Stage 1.Clean Data ■■■■■■
WITH import_sales_report AS (
  SELECT
   SAFE.PARSE_DATE('%d/%m/%Y', date) AS date
  ,doc_no
  ,item_code
  ,item_brand
  ,item_description
  ,CAST(ROUND(SAFE_CAST(qty AS FLOAT64)) AS INT64) AS qty
  ,CAST(unit_price AS FLOAT64) AS unit_price
  ,CAST(gross_total AS FLOAT64) AS gross_total
  ,CAST(discount AS FLOAT64) AS discount
  ,CAST(sub_total AS FLOAT64) AS sub_total
  FROM
  `raw_data_v1.bronze_sales_report`
  WHERE SAFE.PARSE_DATE('%d/%m/%Y', date) IS NOT NULL 
)

-- ■■■■■■ Stage 2. Metadata per SKU ■■■■■■
,cleaned_sales_report AS (
  SELECT
   date
  ,doc_no
  ,item_code
  ,IF(MIN(item_description) OVER(PARTITION BY item_code) != MAX(item_description) OVER(PARTITION  BY item_code), 
   item_code, item_description) AS item_description
  ,CASE
     WHEN item_brand = 'CHINA STOCK' THEN item_brand
     ELSE 'LOCAL STOCK'
     END AS china_or_local  
  ,CASE 
     WHEN item_brand = 'CHINA STOCK' THEN 45 
     ELSE 5 
     END AS lead_time_days
  ,qty
  ,unit_price
  ,gross_total
  ,discount
  ,sub_total
  FROM
  import_sales_report
)

-- ■■■■■■ Stage 3. Daily Sales Flat ■■■■■■
,daily_sales_flat AS(
  SELECT
   date
  ,item_code
  ,item_description
  ,MAX(china_or_local) AS china_or_local
  ,CASE 
     WHEN MAX(china_or_local) = 'CHINA STOCK' THEN 45 ELSE 5 END AS lead_time_days
  ,SUM(qty) as daily_qty
  FROM
  cleaned_sales_report
  GROUP BY
   date
  ,item_code
  ,item_description 
)

-- ■■■■■■ Stage 4. Date Spine (trading days only) ■■■■■■
,date_spine AS (
  SELECT DISTINCT date
  FROM 
  import_sales_report
)

-- ■■■■■■ Stage 5. Fill missing SKU-days with 0 ■■■■■■
,daily_sales_filled AS (
  SELECT
     sku.item_code
    ,sku.item_description
    ,sku.china_or_local
    ,sku.lead_time_days
    ,d.date
    ,COALESCE(f.daily_qty, 0) AS daily_qty
  FROM (
    SELECT 
     DISTINCT item_code
    ,item_description
    ,china_or_local
    ,lead_time_days
        FROM 
        daily_sales_flat) AS sku
  CROSS JOIN 
  date_spine d
  LEFT JOIN 
  daily_sales_flat f
    ON  sku.item_code = f.item_code
    AND d.date        = f.date
)

-- ■■■■■■ Stage 6. Calculations ■■■■■■
,item_stats AS (
  SELECT
    item_code
    ,item_description
    ,china_or_local
    ,lead_time_days
    ,SUM(daily_qty)                                      AS total_sales
    ,SAFE_DIVIDE(SUM(daily_qty), COUNT(DISTINCT date))   AS ads
    ,IFNULL(STDDEV_SAMP(daily_qty), 0)                   AS stddev_qty
  FROM daily_sales_filled
  GROUP BY item_code
  ,item_description
  ,china_or_local
  ,lead_time_days
)

-- ■■■■■■ Stage 7. Summary ■■■■■■
SELECT
   item_code
  ,item_description
  ,china_or_local
  ,lead_time_days
  ,total_sales
  ,ROUND(ads, 4)        AS avg_daily_sales
  ,ROUND(stddev_qty, 2) AS stddev_qty

  -- 1.  Safety Stock  |  Z * σ * √L
  ,CAST(CEIL(
    1.65 * stddev_qty * SQRT(lead_time_days)
  ) AS INT64) AS safety_stock

  -- 2.  Reorder Level  |  (ADS * L) + SS
  ,CAST(CEIL(
    (ads * lead_time_days)
    + (1.65 * stddev_qty * SQRT(lead_time_days))
  ) AS INT64) AS reorder_level

  -- 3.  Maximum Level  |  Reorder Level + (ADS * 14)
  ,CAST(CEIL(
    (ads * lead_time_days)
    + (1.65 * stddev_qty * SQRT(lead_time_days))
    + (ads * 14)
  ) AS INT64) AS maximum_level

FROM item_stats
ORDER BY reorder_level DESC;
