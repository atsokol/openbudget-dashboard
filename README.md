# Ukraine Municipal Budget Analysis

Dashboard for analyzing Ukrainian municipal budget data. 

## Architecture

All cities, budget categories, and colors defined in `config.yaml`. Add cities or change categorization without touching code.

### Data Flow
```
config.yaml → config.R (R scripts) + config.json.js (Dashboard)
OpenBudget API → helper-functions.R → update-db.R → budget.duckdb
budget.duckdb → generate-parquet.js → 3× Parquet files → Dashboard
```

### Components

**Configuration** - `config.yaml` (24 cities, 4 revenue categories, 3 expense categories, color schemes)

**R Scripts** (3 files)
- `src/data/config.R` - Config helpers: read_config(), get_all_city_codes(), create_city_lookup()
- `src/data/helper-functions.R` - API: download_data(), api_construct(), call_api()
- `src/data/update-db.R` - Updater: downloads from API, updates DuckDB

**Data Loaders** (3 files)
- `src/data/config.json.js` - Config as JSON for dashboard
- `src/data/budget-summary.json.js` - Aggregated budget data
- `src/data/generate-parquet.js` - Consolidated Parquet generator (creates incomes, expenses, expenses-functional)

**Database** - `src/data/budget.duckdb` (5 tables: incomes, expenses, expenses_functional, debts, credits)

**Dashboards** (3 files)
- `src/index.md` - Home page
- `src/test.md` - Minimal test
- `src/budget-dashboard.md` - Full dashboard

## Quick Start

```bash
npm install              # Install dependencies
npm run init-db          # Create database from CSV files
npm run dev              # Start dev server → http://localhost:3000
```

## Common Tasks

### Update Data
```bash
npm run update-data      # Downloads latest from API, updates DB
npm run generate-parquet # Regenerate Parquet files from DuckDB
```

**How it works:**
1. Checks if all cities from `config.yaml` are in database
2. If cities missing → downloads all years (2021-present) for missing cities only
3. If all cities present → downloads new months for all cities
4. Run `generate-parquet` to update the Parquet files used by the dashboard

**Note:** Observable Framework automatically runs data loaders during build, but you can manually regenerate Parquet files if needed.

### Add a City
Edit `config.yaml`:
```yaml
cities:
  - name: "NewCity"
    codes: ["1234567890"]
```
Run: `npm run update-data`

### Change Category Colors
Edit `config.yaml`:
```yaml
revenue_categories:
  - name: "Tax revenues"
    codes: [0, 19999999]
    color: "#3498db"
    type: "range"
```
Refresh browser (no rebuild needed)

### Validate Config
```bash
cd src/data
Rscript -e "source('config.R'); validate_config()"
```

## Project Structure

```
openbudget-dashboard/
├── config.yaml                    # Central configuration
├── src/
│   ├── data/
│   │   ├── config.R               # R config helpers
│   │   ├── helper-functions.R     # API download
│   │   ├── update-db.R            # Update script
│   │   ├── setup-db.sql           # DB schema
│   │   ├── config.json.js         # Config loader
│   │   ├── budget-summary.json.js # Summary data loader
│   │   ├── generate-parquet.js    # Consolidated Parquet generator
│   │   ├── budget.duckdb          # Database (50MB)
│   │   └── csvs/                  # CSV source data
│   ├── components/                # Visualization components
│   ├── index.md                   # Home
│   ├── adjustments.md             # Capital adjustments
│   └── budget-dashboard.md        # Main dashboard
├── observablehq.config.js         # Framework config
└── package.json                   # Dependencies
```

## Configuration Examples

### Single Range
```yaml
revenue_categories:
  - name: "Tax revenues"
    codes: [0, 19999999]
    color: "#4682b4"
    type: "range"
```

### Multiple Ranges
```yaml
revenue_categories:
  - name: "Non-tax revenues"
    codes:
      - [20000000, 21010499]
      - [21010600, 21010699]
    color: "#2e8b57"
    type: "ranges"
```

### City with Multiple Codes
```yaml
cities:
  - name: "Kyiv"
    codes: ["2600000000", "26000000000"]
```

## Debugging

### Check Database
```bash
duckdb src/data/budget.duckdb
SELECT COUNT(*) FROM incomes;
SELECT DISTINCT CITY FROM incomes;
```

### Test Loaders
```bash
node src/data/config.json.js | head -100
node src/data/budget-summary.json.js | head -100
# Parquet files are binary, check build output instead
npm run build | grep parquet
```

## Technology

- **Observable Framework** - Reactive JavaScript notebooks
- **DuckDB** - Columnar analytical database
- **Apache Parquet** - Compressed columnar file format (~50x smaller than JSON)
- **R** - Data processing, API access
- **Observable Plot + D3** - Visualization
- **OpenBudget API** - api.openbudget.gov.ua

## Build Optimization

Data is stored in compressed Parquet format (12MB build) instead of JSON (130MB). Parquet files are:
- ~50x smaller than JSON
- Fast to decompress in browser
- Column-oriented for efficient queries
- Generated at build time from DuckDB

## Data Source

[Open Budget Ukraine](https://openbudget.gov.ua) - Ministry of Finance portal

## How Database Updates Work

### Automated Updates (GitHub Actions)
- **Weekly Schedule**: Every Sunday at 2 AM UTC
- **Manual Trigger**: Run "Update Budget Data" workflow from Actions tab
- **Workflow**: 
  1. Updates DuckDB database from OpenBudget API
  2. Generates Parquet files (`npm run generate-parquet`)
  3. Builds and deploys site

### Local Updates
```bash
npm run update-data       # Downloads latest from API
npm run generate-parquet  # Regenerates Parquet files
npm run build            # Builds site
```

### Update Logic
1. **Coverage Check**: Compares cities in `config.yaml` vs database
2. **Missing Cities**: If any city absent → downloads 2021-present for that city
3. **Incremental**: If all cities present → downloads new months for all cities
4. **Idempotent**: Deletes existing periods before inserting (no duplicates)

### Data Range
- **Start Year**: 2021 (configurable in code)
- **End**: Current month
- Use case: Add city to config.yaml, run update, city data auto-downloads

### Schema
```
COD_BUDGET: BIGINT  (city budget code)
PLANS_AMT: DOUBLE   (planned amount)
REP_PERIOD: DATE    (reporting period)
FAKT_AMT: DOUBLE    (actual amount)
```

### Column Types
- Types hardcoded in `helper-functions.R` based on OpenBudget API
- Match database schema in `setup-db.sql`
- Consistent with API response structure

## License

MIT
