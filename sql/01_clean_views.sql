-- Clean layer on top of the raw GEM tables. Raw tables are never edited.

-- 1. Capacities: text '>0' (exists, size unknown) becomes NULL, never 0.
--    Current capacity = operating + operating pre-retirement.
CREATE OR REPLACE VIEW capacities AS
SELECT
    gem_plant_id,
    plant_name_english AS plant_name,
    country_area AS country,
    status,
    status IN ('operating', 'operating pre-retirement') AS is_current,
    TRY_CAST(COLUMNS('capacity_ttpa$') AS DOUBLE),
    (nominal_crude_steel_capacity_ttpa = '>0'
     OR nominal_eaf_steel_capacity_ttpa = '>0'
     OR nominal_bof_steel_capacity_ttpa = '>0') AS steel_capacity_unknown
FROM raw_capacities;

-- 2. Plant parents: one row per plant per parent, equity share as a fraction.
--    Missing shares: remaining share split equally ('estimated').
--    Totals above 100% (two ownership chains listed): scaled to 100% ('normalised').
CREATE OR REPLACE VIEW plant_parents AS
WITH split AS (
    SELECT gem_plant_id,
           unnest(string_split(parent_english, '; ')) AS parent_txt,
           unnest(string_split(parent_gem_entity_id, '; ')) AS id_txt
    FROM raw_plants
),
parsed AS (
    SELECT gem_plant_id,
           trim(regexp_replace(parent_txt, '\s*\[[0-9.]+%\]$', '')) AS parent_name,
           regexp_extract(id_txt, '^(\S+)', 1) AS parent_id,
           TRY_CAST(regexp_extract(parent_txt, '\[([0-9.]+)%\]', 1) AS DOUBLE) / 100 AS share_reported
    FROM split
),
filled AS (
    SELECT *,
           CASE WHEN share_reported IS NOT NULL THEN share_reported
                ELSE GREATEST(1 - COALESCE(SUM(share_reported) OVER w, 0), 0)
                     / COUNT(*) FILTER (WHERE share_reported IS NULL) OVER w
           END AS share_filled
    FROM parsed
    WINDOW w AS (PARTITION BY gem_plant_id)
)
SELECT gem_plant_id, parent_name, parent_id, share_reported,
       CASE WHEN SUM(share_filled) OVER w > 1.01
            THEN share_filled / SUM(share_filled) OVER w
            ELSE share_filled END AS share,
       CASE WHEN SUM(share_filled) OVER w > 1.01 THEN 'normalised'
            WHEN share_reported IS NULL THEN 'estimated'
            ELSE 'reported' END AS share_method
FROM filled
WINDOW w AS (PARTITION BY gem_plant_id);

-- 3. Benchmark companies: GEM parent IDs mapped to group names.
--    Subsidiaries count toward their group, matching consolidated annual reports.
CREATE OR REPLACE TABLE company_map AS
SELECT * FROM (VALUES
    ('E100000000687', 'ArcelorMittal'),
    ('E100001000487', 'ArcelorMittal'),
    ('E100001000504', 'ArcelorMittal'),
    ('E100001000507', 'ArcelorMittal'),
    ('E100001010181', 'Nucor'),
    ('E100000000953', 'POSCO'),
    ('E100000001651', 'SSAB'),
    ('E100001010315', 'Salzgitter'),
    ('E100001010018', 'Tata Steel'),
    ('E100001010159', 'Tata Steel'),
    ('E100000121408', 'Tata Steel'),
    ('E100000000031', 'voestalpine'),
    ('E100000004212', 'thyssenkrupp')
) AS t(parent_id, company);

-- 4. Company benchmark: current capacity (equity-weighted) and EAF share.
CREATE OR REPLACE VIEW company_benchmark AS
SELECT m.company,
       COUNT(DISTINCT c.gem_plant_id) AS plants,
       SUM(c.nominal_crude_steel_capacity_ttpa * pp.share) / 1000 AS crude_mtpa,
       SUM(COALESCE(c.nominal_eaf_steel_capacity_ttpa, 0) * pp.share)
         / SUM(c.nominal_crude_steel_capacity_ttpa * pp.share) AS eaf_share
FROM capacities c
JOIN plant_parents pp USING (gem_plant_id)
JOIN company_map m USING (parent_id)
WHERE c.is_current
GROUP BY m.company;