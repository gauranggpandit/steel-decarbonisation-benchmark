# Steel Decarbonisation Benchmark (work in progress)

Benchmarks steelmakers' technology mix against their emissions, combining plant-level asset data with figures an LLM extracts from annual reports, and measures how accurate that extraction is.

## First results

![EAF share vs CO2 intensity](charts/eaf_vs_intensity.png)

thyssenkrupp (2% EAF capacity) emits 2.26 t CO2e per tonne of crude steel, SSAB (28%) 1.42, Nucor (100%) 0.20. Nucor's value covers Scope 1 only, because it discloses no Scope 2 in these documents; EAF emissions are mostly Scope 2, so the real gap is smaller. Production divided by GIST capacity gives 78-85% utilisation for all three, a plausible range and a consistency check between the two sources.

![Technology mix of 8 steelmakers](charts/capacity_mix.png)

ArcelorMittal has almost as much EAF capacity as Nucor in absolute terms (25.9 vs 26.8 Mt), although EAF is only 30% of its fleet. voestalpine shows 0% because its electric arc furnaces are still under construction.

## What is done
- **Plant database:** Global Energy Monitor's Global Iron and Steel Tracker (1,293 plants) loaded into DuckDB, with documented data-quality checks and ownership-weighted capacity and EAF share for 8 steelmakers.
- **LLM extraction:** PyMuPDF page text, keyword retrieval, then Gemini with structured output (value, unit, year, page, quote). Covers SSAB, thyssenkrupp and Nucor.
- **Validation:** every field checked by hand against the source page.

| | v1 | v2 |
|---|---|---|
| Accuracy (15 fields) | 73% | 93% |
| Recall | 56% | 89% |

- **Benchmark:** CO2 intensity calculated from hand-validated Scope 1+2 and crude steel, joined with GIST capacity and EAF share.

## Main findings
- Most errors came from retrieval (wrong pages), not the LLM.
- Reports show base-year and reporting-year values side by side; the prompt must name the column.
- A stricter prompt (unit always required) removed wrong answers but also dropped one correct value.
- Group CO2 intensity per tonne of steel is rarely printed; it has to be calculated from Scope 1+2 and crude steel.
- Unit traps: US short tons, and a published table whose header says "million t" while the figure is in tonnes.
- GIST covers plants of at least 0.5 Mtpa only; its parent field is the direct parent, not the ultimate owner.

## Next
Extraction and validation for the remaining 5 companies (ArcelorMittal, POSCO, Tata Steel, voestalpine, Salzgitter), then the CO2 chart for all 8 and a capacity cross-check (reported vs GIST) for all companies.

## Run
`python src/load_gist.py` rebuilds the database. Company reports are not included (copyright); see notebooks for sources.

Data: Global Energy Monitor, Global Iron and Steel Tracker (CC BY 4.0).
