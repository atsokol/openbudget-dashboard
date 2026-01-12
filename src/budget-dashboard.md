---
title: Ukraine Municipal Budget Analysis
toc: false
---

# Ukraine Municipal Budget Analysis

Analysis is based on data from [Open Budget](https://openbudget.gov.ua), an open resource maintained by the Ministry of Finance of Ukraine.

<div class="note">
  💡 Configure which budget categories are treated as capital vs. current in the <a href="./adjustments">Adjustments</a> page.
</div>


```js
import * as d3 from "npm:d3";
import * as aq from "npm:arquero";
import {Icicle, get_treetab} from "./components/icicle.js";
import {HorizontalComparisonChart} from "./components/horizontal-comparison.js";
import {TrendsChart} from "./components/trends-chart.js";
import {YoYComparisonChart} from "./components/yoy-comparison-chart.js";
import {WaterfallChart, WaterfallComparisonChart} from "./components/waterfall.js";
import {prepareWaterfallData, prepareWaterfallComparisonData, get_codes} from "./components/waterfall-data.js";

// Load data files
const budgetData = await FileAttachment("data/budget-summary.json").json();
const config = await FileAttachment("data/config.json").json();

// Load Parquet files and convert Arrow tables to plain JavaScript objects
// Note: Arrow tables return Proxy objects with BigInt values, so we explicitly map to plain objects
const incomes = await FileAttachment("data/incomes.parquet").parquet()
  .then(table => [...table].map(row => ({
    CITY: row.CITY,
    REP_PERIOD: new Date(row.REP_PERIOD),
    FUND_TYP: row.FUND_TYP,
    COD_INCO: Number(row.COD_INCO),
    NAME_INC: row.NAME_INC,
    FAKT_AMT: row.FAKT_AMT
  })));

const expenses_econ = await FileAttachment("data/expenses.parquet").parquet()
  .then(table => [...table].map(row => ({
    CITY: row.CITY,
    REP_PERIOD: new Date(row.REP_PERIOD),
    FUND_TYP: row.FUND_TYP,
    COD_CONS_EK: Number(row.COD_CONS_EK),
    COD_CONS_EK_NAME: row.COD_CONS_EK_NAME,
    FAKT_AMT: row.FAKT_AMT
  })));

const expenses_func = await FileAttachment("data/expenses-functional.parquet").parquet()
  .then(table => [...table].map(row => ({
    CITY: row.CITY,
    REP_PERIOD: new Date(row.REP_PERIOD),
    FUND_TYP: row.FUND_TYP,
    COD_CONS_MB_FK: Number(row.COD_CONS_MB_FK),
    COD_CONS_MB_FK_NAME: row.COD_CONS_MB_FK_NAME,
    FAKT_AMT: row.FAKT_AMT
  })));

// Load classificators
const inck_table = await FileAttachment("data/classificators/KDB.json").json();
const kfk_table = await FileAttachment("data/classificators/FKV.json").json();
const kek_table = await FileAttachment("data/classificators/KEKV.json").json();

// Load FX rates
const fx_rates_raw = await FileAttachment("data/fx_rates.json").json();
const fx_rates = fx_rates_raw.map(d => ({
  date: new Date(d.date),
  rate: d.rate
}));

// Pre-compute average FX rates by year-month for performance
const fxRatesByPeriod = new Map();

// Get all unique year-month combinations from the data
const allPeriods = new Set(budgetData.map(d => {
  const date = new Date(d.REP_PERIOD);
  return `${date.getFullYear()}-${date.getMonth()}`;
}));

// Pre-calculate average rate for each period
for (const periodKey of allPeriods) {
  const [year, month] = periodKey.split('-').map(Number);
  const endDate = new Date(year, month, 1);
  endDate.setMonth(endDate.getMonth() + 1);
  endDate.setDate(0); // Last day of the month
  
  const startDate = new Date(year, 0, 1);
  const relevantRates = fx_rates.filter(d => d.date >= startDate && d.date <= endDate);
  
  if (relevantRates.length > 0) {
    fxRatesByPeriod.set(periodKey, d3.mean(relevantRates, d => d.rate));
  } else {
    fxRatesByPeriod.set(periodKey, 1);
  }
}

// Helper function to get average FX rate for a period
function getAverageFxRate(date) {
  const periodKey = `${date.getFullYear()}-${date.getMonth()}`;
  return fxRatesByPeriod.get(periodKey) || 1;
}

// Parse budget summary data and calculate current surplus
const data = budgetData.map(d => ({
  ...d,
  REP_PERIOD: new Date(d.REP_PERIOD),
  curr_surplus: d.income_curr - d.expense_curr
}));

const cityNames = [...new Set(data.map(d => d.CITY))].sort();
```

```js
// Helper functions
const fmt = n => d3.format(",d")(n);

// Prepare classificator tables with deduplication
const inck_prep = [
  {code: 0, parentCode: null, name: "Загальні доходи", level: 0},
  ...Array.from(new Map(
    inck_table
      .filter(d => d.endDate == null)
      .map(d => ({code: +d.code, parentCode: +d.parentCode ?? 0, name: d.name, level: d.level}))
      .map(d => [d.code, d])
  ).values())
  .sort((a,b) => a.code - b.code)
];

const kek_prep = [
  {code: 0, parentCode: null, name: "Загальні видатки", level: 0},
  ...Array.from(new Map(
    kek_table
      .filter(d => d.endDate == null)
      .map(d => ({code: +d.code, parentCode: +d.parentCode ?? 0, name: d.name, level: d.level}))
      .map(d => [d.code, d])
  ).values())
  .sort((a,b) => a.code - b.code)
];

const kfk_prep = [
  {code: 0, parentCode: null, name: "Загальні видатки", level: 0},
  ...Array.from(new Map(
    kfk_table
      .filter(d => d.endDate == null)
      .map(d => ({code: +d.code, parentCode: +d.parentCode ?? 0, name: d.name, level: d.level}))
      .map(d => [d.code, d])
  ).values())
  .sort((a,b) => a.code - b.code)
];

// Load capital income and expense categories from localStorage or use defaults
const defaultCapitalIncomeParentCodes = [30000000, 42000000, 21050000, 24110000, 21010500, 21010700, 21010800, 21010900];
const defaultCapitalExpenseParentCodes = [2281, 3000];

// Helper to expand parent codes to all descendant codes
function expandToDescendants(parentCodes, flatData) {
  const allCodes = new Set();
  for (const parentCode of parentCodes) {
    const node = flatData.find(d => d.code === parentCode);
    if (node) {
      const descendants = getDescendantCodesFlat(parentCode, flatData);
      descendants.forEach(c => allCodes.add(c));
    }
  }
  return [...allCodes];
}

// Get descendant codes from flat data
function getDescendantCodesFlat(code, flatData) {
  const codes = [code];
  const children = flatData.filter(d => d.parentCode === code);
  children.forEach(child => {
    codes.push(...getDescendantCodesFlat(child.code, flatData));
  });
  return codes;
}

const getCapitalIncomeCodes = () => {
  const saved = localStorage.getItem('capitalIncomeCodes');
  if (saved) {
    return JSON.parse(saved);
  }
  // Expand defaults to all descendants and save to localStorage
  const expanded = expandToDescendants(defaultCapitalIncomeParentCodes, inck_prep);
  localStorage.setItem('capitalIncomeCodes', JSON.stringify(expanded));
  return expanded;
};

const getCapitalExpenseCodes = () => {
  const saved = localStorage.getItem('capitalExpenseCodes');
  if (saved) {
    return JSON.parse(saved);
  }
  // Expand defaults to all descendants and save to localStorage
  const expanded = expandToDescendants(defaultCapitalExpenseParentCodes, kek_prep);
  localStorage.setItem('capitalExpenseCodes', JSON.stringify(expanded));
  return expanded;
};

const capitalIncomeCodes = getCapitalIncomeCodes();
const capitalExpenseCodes = getCapitalExpenseCodes();

// Get expanded code lists for filtering
const inc_cap_codes = get_codes(inck_prep, capitalIncomeCodes);
const exp_cap_codes = get_codes(kek_prep, capitalExpenseCodes);

// Special code for capital adjustments category
const CAPITAL_ADJ_CODE = 999999999;

// Combine current and capital items into overall surplus structure
const overall_surplus = [
  // Current income (exclude capital)
  ...incomes
    .filter(d => !inc_cap_codes.includes(d.COD_INCO))
    .map(d => ({...d, COD: d.COD_INCO, FAKT_AMT: +d.FAKT_AMT})),
  // Current expenses (exclude capital)
  ...expenses_econ
    .filter(d => !exp_cap_codes.includes(d.COD_CONS_EK))
    .map(d => ({...d, COD: d.COD_CONS_EK, FAKT_AMT: -d.FAKT_AMT})),
  // Capital income as adjustment
  ...incomes
    .filter(d => inc_cap_codes.includes(d.COD_INCO))
    .map(d => ({...d, COD: CAPITAL_ADJ_CODE, FAKT_AMT: +d.FAKT_AMT})),
  // Capital expenses as adjustment
  ...expenses_econ
    .filter(d => exp_cap_codes.includes(d.COD_CONS_EK))
    .map(d => ({...d, COD: CAPITAL_ADJ_CODE, FAKT_AMT: -d.FAKT_AMT}))
];

// Create combined classificator table for current surplus (simplified)
const new_combi_table = [
  {code: 0, parentCode: null, name: "Current surplus", level: 0},
  ...inck_prep.slice(1).filter(d => !inc_cap_codes.includes(d.code)),
  ...kek_prep.slice(1)
    .filter(d => d.code != 2000)
    .filter(d => !exp_cap_codes.includes(d.code))
    .map(d => ({...d, parentCode: d.parentCode == 2000 ? 0 : d.parentCode}))
];

// Create classificator table for overall surplus (including capital adjustments)
const overall_combi_table = [
  {code: 0, parentCode: null, name: "Overall surplus", level: 0},
  ...inck_prep.slice(1).filter(d => !inc_cap_codes.includes(d.code)),
  ...kek_prep.slice(1)
    .filter(d => d.code != 2000)
    .filter(d => !exp_cap_codes.includes(d.code))
    .map(d => ({...d, parentCode: d.parentCode == 2000 ? 0 : d.parentCode})),
  {code: CAPITAL_ADJ_CODE, parentCode: 0, name: "Capital Adjustments", level: 1}
];
```

```js
const selectCity = view(Inputs.select(cityNames, {
  label: "Select city",
  value: "Cherkasy"
}));
```

```js
const selectCurrency = view(Inputs.radio(["UAH", "EUR"], {
  label: "Currency",
  value: "UAH"
}));
```

```js
// Currency conversion function
function convertAmount(amount, date, currency) {
  if (currency === "UAH") return amount;
  const avgRate = getAverageFxRate(date);
  return amount / avgRate;
}

// Currency formatting
const currencyFormat = (value, currency) => {
  return d3.format(",.0f")(value);
};

const currencyLabel = (currency) => {
  return currency === "EUR" ? "EUR million" : "UAH million";
};

// Currency conversion helper - applies exchange rates to all monetary fields
function withConversion(data, currency) {
  if (currency === "UAH") return data;
  
  return data.map(d => {
    const rate = getAverageFxRate(d.REP_PERIOD);
    const converted = {...d};
    
    // Convert all amount fields
    if ('income' in d) converted.income = d.income / rate;
    if ('income_curr' in d) converted.income_curr = d.income_curr / rate;
    if ('expense' in d) converted.expense = d.expense / rate;
    if ('expense_curr' in d) converted.expense_curr = d.expense_curr / rate;
    if ('curr_surplus' in d) converted.curr_surplus = d.curr_surplus / rate;
    if ('FAKT_AMT' in d) converted.FAKT_AMT = d.FAKT_AMT / rate;
    
    return converted;
  });
}

// Apply currency conversion to all datasets
const dataConverted = withConversion(data, selectCurrency);
const incomesConverted = withConversion(incomes, selectCurrency);
const expenses_econConverted = withConversion(expenses_econ, selectCurrency);
const expenses_funcConverted = withConversion(expenses_func, selectCurrency);

// Apply same conversion logic to overall surplus
const overall_surplus_converted = withConversion(overall_surplus, selectCurrency);
```

```js
const indicators = [
  {name: "Revenues", indicator: "income"},
  {name: "Expenses", indicator: "expense"},
  {name: "Current surplus", indicator: "curr_surplus"}
];

const selectIndicator = view(Inputs.select(indicators, {
  label: "Select indicator",
  format: d => d.name,
  value: indicators[0]
}));
```

```js
TrendsChart(dataConverted, selectCity, selectIndicator.name, selectIndicator.indicator, (value) => currencyFormat(value, selectCurrency), currencyLabel(selectCurrency))
```

## Year Comparison

```js
const availableYears = [...new Set(data.map(d => d.year))].sort();
```

```js
const selectYear = view(Inputs.select(availableYears.slice(-4), {
  label: "Select year",
  value: Math.max(...availableYears),
  format: d => d.toString()
}));
```

```js
const baseYear = view(Inputs.select(availableYears.slice(-5, -1), {
  label: "Base year",
  value: Math.max(...availableYears) - 1,
  format: d => d.toString()
}));
```

```js
const data_transform = dataConverted.map(d => ({...d, 
  YEAR: d.REP_PERIOD.getUTCFullYear(), 
  MONTH: d.REP_PERIOD.getMonth()
}));

const data_pivot = aq.from(data_transform.filter(d => d.YEAR == baseYear || d.YEAR == selectYear))
  .groupby(["CITY", "MONTH"])
  .pivot(['YEAR'], [selectIndicator.indicator])
  .rename(aq.names(["city", "month", 'base', 'current']))
  .objects();

const month_max = Math.max(...incomes
  .filter(d => d.REP_PERIOD.getUTCFullYear() == selectYear)
  .map(d => d.REP_PERIOD.getUTCMonth()));
```

```js
YoYComparisonChart(data_pivot, selectCity, selectIndicator.name, selectYear, baseYear, (value) => currencyFormat(value, selectCurrency), currencyLabel(selectCurrency))
```

## Budget Breakdown

### Revenue breakdown in ${selectCity} ${selectYear}

```js
// Prepare tree table data for icicle charts - use converted data
const inc_trtab = get_treetab(incomesConverted, inck_prep, "COD_INCO", selectCity, selectYear, month_max);
const exp_e_trtab = get_treetab(expenses_econConverted, kek_prep, "COD_CONS_EK", selectCity, selectYear, month_max);
const exp_f_trtab = get_treetab(expenses_funcConverted, kfk_prep, "COD_CONS_MB_FK", selectCity, selectYear, month_max, true);
```

```js
Icicle(inc_trtab, {
  label: d => d.name,
  width: 1152,
  height: 450
})
```

### Overall surplus waterfall: ${selectCity} ${selectYear}

```js
const overall_surplus_wf = prepareWaterfallData(overall_surplus_converted, overall_combi_table, "COD", {code: 0, name: "Overall"}, selectCity, selectYear, month_max);
```

```js
WaterfallChart(overall_surplus_wf, `Overall surplus waterfall: ${selectCity} ${selectYear}`, (value) => currencyFormat(value, selectCurrency), currencyLabel(selectCurrency))
```

### Overall surplus change: ${selectCity} ${selectYear} vs ${baseYear}

```js
// Calculate FX adjustment and prepare data for waterfall comparison
let fxAdjustment = null;
let dataForWaterfall = overall_surplus_converted;
let baseYearAdjustment = null; // To adjust displayed base year value

if (selectCurrency === "EUR") {
  // Get base year rate and current year rate
  const baseYearPeriod = new Date(baseYear, month_max, 1);
  const currentYearPeriod = new Date(selectYear, month_max, 1);
  const baseYearRate = getAverageFxRate(baseYearPeriod);
  const currentYearRate = getAverageFxRate(currentYearPeriod);
  
  // For operational changes, convert BOTH years at current year rate to isolate real changes
  dataForWaterfall = overall_surplus.map(d => {
    const converted = {...d};
    converted.FAKT_AMT = d.FAKT_AMT / currentYearRate; // Use SAME rate for both years
    return converted;
  });
  
  // Calculate base year at both rates for adjustment
  const baseYearDataConstantRate = dataForWaterfall
    .filter(d => d.FUND_TYP == "T")
    .filter(d => d.CITY == selectCity)
    .filter(d => new Date(d.REP_PERIOD).getUTCFullYear() == baseYear)
    .filter(d => new Date(d.REP_PERIOD).getUTCMonth() == month_max)
    .reduce((sum, d) => sum + d.FAKT_AMT, 0) / 1000000;
    
  const baseYearDataOwnRate = overall_surplus_converted
    .filter(d => d.FUND_TYP == "T")
    .filter(d => d.CITY == selectCity)
    .filter(d => new Date(d.REP_PERIOD).getUTCFullYear() == baseYear)
    .filter(d => new Date(d.REP_PERIOD).getUTCMonth() == month_max)
    .reduce((sum, d) => sum + d.FAKT_AMT, 0) / 1000000;
  
  // FX adjustment is the difference
  fxAdjustment = baseYearDataConstantRate - baseYearDataOwnRate;
  
  // Adjustment to make base year display at its own rate instead of constant rate
  baseYearAdjustment = baseYearDataOwnRate - baseYearDataConstantRate;
} else {
  dataForWaterfall = overall_surplus; // UAH mode, no conversion needed
}

const overall_surplus_wfd = prepareWaterfallComparisonData(
  dataForWaterfall, 
  overall_combi_table, 
  "COD", 
  {code: 0, name: "Overall surplus"}, 
  selectCity, 
  selectYear, 
  baseYear, 
  month_max,
  fxAdjustment,
  baseYearAdjustment
);
```

```js
WaterfallComparisonChart(overall_surplus_wfd, `Overall surplus change: ${selectCity} ${selectYear} vs ${baseYear}`, (value) => currencyFormat(value, selectCurrency), currencyLabel(selectCurrency))
```

### Expense functional breakdown in ${selectCity} ${selectYear}

```js
Icicle(exp_f_trtab, {
  label: d => d.name,
  width: 1152,
  height: 450
})
```

### Expense economic breakdown in ${selectCity} ${selectYear}

```js
Icicle(exp_e_trtab, {
  label: d => d.name,
  width: 1152,
  height: 450
})
```

## Horizontal Comparison

```js
const data_change = aq.from(data_pivot)
  .groupby("city")
  .filter(d => d.current != undefined)
  .filter(d => d.month == aq.op.max(d.month))
  .derive({pct_change: d => (d.current - d.base) / d.base})
  .objects();
```

```js
HorizontalComparisonChart(data_change, selectCity, selectIndicator.name, month_max, selectYear, baseYear, (value) => currencyFormat(value, selectCurrency))
```

---

## Data Notes

- **Revenues**: Total budget revenues (million UAH)
- **Expenses**: Total budget expenses (million UAH)  
- Data is updated monthly from Open Budget Ukraine
- Charts show actual (FAKT_AMT) amounts, not planned amounts

Data source: [Open Budget Ukraine](https://openbudget.gov.ua)

<style>
.note {
  background-color: var(--theme-foreground-faintest);
  border-left: 4px solid var(--theme-foreground-focus);
  padding: 1rem;
  margin: 1rem 0;
  border-radius: 4px;
}

.note a {
  color: var(--theme-foreground-focus);
  font-weight: 600;
}
</style>
