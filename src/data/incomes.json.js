#!/usr/bin/env node
import duckdb from "duckdb";
import fs from "fs";
import {fileURLToPath} from "url";
import {dirname, join} from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const outputPath = join(__dirname, "incomes.parquet");

const db = new duckdb.Database("src/data/budget.duckdb", duckdb.OPEN_READONLY);

await new Promise((resolve, reject) => {
  db.run(`
    COPY (
      SELECT 
        CITY,
        REP_PERIOD,
        FUND_TYP,
        COD_INCO,
        NAME_INC,
        FAKT_AMT
      FROM incomes
      ORDER BY CITY, REP_PERIOD, COD_INCO
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

