#!/usr/bin/env node
import duckdb from "duckdb";

const db = new duckdb.Database("src/data/budget.duckdb");

const result = await new Promise((resolve, reject) => {
  db.all(`
  SELECT 
    CITY,
    REP_PERIOD,
    FUND_TYP,
    COD_CONS_MB_FK,
    COD_CONS_MB_FK_NAME,
    FAKT_AMT
  FROM expenses_functional
  ORDER BY CITY, REP_PERIOD, COD_CONS_MB_FK
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

