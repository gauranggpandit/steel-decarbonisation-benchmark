# Steel Decarbonisation Benchmark (work in progress)

Benchmarks steelmakers' technology mix against their emissions, combining plant-level asset data with figures an LLM extracts from annual reports, and measures how accurate that extraction is.

## What is done
- **Plant database:** Global Energy Monitor's Global Iron and Steel Tracker (1,293 plants) loaded into DuckDB, with documented data-quality checks and ownership-weighted capacity and EAF share for 8 steelmakers.
- **LLM extraction:** PyMuPDF page text, keyword retrieval, then Gemini with structured output (value, unit, year, page, quote). Covers SSAB, thyssenkrupp and Nucor.
- **Validation:** every field checked by hand against the source page.

| | v1 | v2 |
|---|---|---|
| Accuracy (15 fields) | 73% | 93% |
| Recall | 56% | 89% |

## Main findings
- Most errors came from retrieval (wrong pages), not the LLM.
- Reports show base-year and reporting-year values side by side; the prompt must name the column.
- A stricter prompt (unit always required) removed wrong answers but also dropped one correct value.
- Unit traps: US short tons, and a published table whose header says "million t" while the figure is in tonnes.
- GIST covers plants of at least 0.5 Mtpa only; its parent field is the direct parent, not the ultimate owner.

## Next
Remaining 5 companies, CO2 intensity vs EAF share chart, capacity cross-check for all companies.

## Run
`python src/load_gist.py` rebuilds the database. Company reports are not included (copyright); see notebooks for sources.

Data: Global Energy Monitor, Global Iron and Steel Tracker (CC BY 4.0).
