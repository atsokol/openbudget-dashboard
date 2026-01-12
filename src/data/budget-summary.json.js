#!/usr/bin/env node
import duckdb from "duckdb";

const db = new duckdb.Database("src/data/budget.duckdb");

const result = await new Promise((resolve, reject) => {
  db.all(`
  WITH income_agg AS (
    SELECT 
      CITY,
      REP_PERIOD,
      SUM(CASE WHEN FUND_TYP = 'T' THEN FAKT_AMT ELSE 0 END) / 1000000 as income,
      SUM(CASE 
        WHEN FUND_TYP = 'T' 
        AND COD_INCO NOT IN (30000000, 42000000, 21050000, 24110000, 21010500, 21010700, 21010800, 21010900)
        AND (COD_INCO < 30000000 OR COD_INCO >= 40000000)
        AND (COD_INCO < 42000000 OR COD_INCO >= 43000000)
        AND (COD_INCO < 21050000 OR COD_INCO >= 21060000)
        AND (COD_INCO < 24110000 OR COD_INCO >= 24120000)
        AND COD_INCO NOT BETWEEN 21010500 AND 21010599
        AND COD_INCO NOT BETWEEN 21010700 AND 21010799
        AND COD_INCO NOT BETWEEN 21010800 AND 21010899
        AND COD_INCO NOT BETWEEN 21010900 AND 21010999
        THEN FAKT_AMT ELSE 0 END) / 1000000 as income_curr,
      YEAR(REP_PERIOD) as year,
      MONTH(REP_PERIOD) as month
    FROM incomes
    WHERE FUND_TYP = 'T'
    GROUP BY CITY, REP_PERIOD
  ),
  expense_agg AS (
    SELECT 
      CITY,
      REP_PERIOD,
      SUM(CASE WHEN FUND_TYP = 'T' THEN FAKT_AMT ELSE 0 END) / 1000000 as expense,
      SUM(CASE 
        WHEN FUND_TYP = 'T' 
        AND COD_CONS_EK NOT IN (2281, 3000)
        AND (COD_CONS_EK < 2281 OR COD_CONS_EK >= 2282)
        AND (COD_CONS_EK < 3000 OR COD_CONS_EK >= 4000)
        THEN FAKT_AMT ELSE 0 END) / 1000000 as expense_curr
    FROM expenses
    WHERE FUND_TYP = 'T'
    GROUP BY CITY, REP_PERIOD
  )
  SELECT 
    i.CITY,
    i.REP_PERIOD,
    i.income,
    COALESCE(e.expense, 0) as expense,
    i.income_curr,
    COALESCE(e.expense_curr, 0) as expense_curr,
    i.year,
    i.month
  FROM income_agg i
  LEFT JOIN expense_agg e ON i.CITY = e.CITY AND i.REP_PERIOD = e.REP_PERIOD
  ORDER BY i.CITY, i.REP_PERIOD
`, (err, rows) => {
    db.close();
    if (err) reject(err);
    else resolve(rows);
  });
});

// Convert BigInt to number for JSON serialization
const jsonResult = result.map(row => {
  const newRow = {};
  for (const [key, value] of Object.entries(row)) {
    newRow[key] = typeof value === 'bigint' ? Number(value) : value;
  }
  return newRow;
});

process.stdout.write(JSON.stringify(jsonResult));
