#!/usr/bin/env node
import duckdb from "duckdb";
import fs from "fs";
import {fileURLToPath} from "url";
import {dirname, join} from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const outputPath = join(__dirname, "expenses.parquet");

const db = new duckdb.Database("src/data/budget.duckdb", duckdb.OPEN_READONLY);

await new Promise((resolve, reject) => {
  db.run(`
    COPY (
      SELECT 
        CITY,
        REP_PERIOD,
        FUND_TYP,
        COD_CONS_EK,
        COD_CONS_EK_NAME,
        FAKT_AMT
      FROM expenses
      ORDER BY CITY, REP_PERIOD, COD_CONS_EK
    ) TO '${outputPath}' (FORMAT PARQUET)
  `, (err) => {
    db.close();
    if (err) reject(err);
    else resolve();
  });
});

// Output the parquet file to stdout
const data = fs.readFileSync(outputPath);
process.stdout.write(data);

