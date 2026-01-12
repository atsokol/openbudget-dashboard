#!/usr/bin/env node
import duckdb from "duckdb";
import { readFileSync } from "fs";

const db = new duckdb.Database("src/data/budget.duckdb", duckdb.OPEN_READONLY);

// Generate all three Parquet files using DuckDB's COPY command
await new Promise((resolve, reject) => {
  db.serialize(() => {
    // Install and load Parquet extension
    db.run("INSTALL parquet; LOAD parquet;", (err) => {
      if (err) {
        console.error("Error loading parquet extension:", err);
        reject(err);
        return;
      }

      // Export incomes to Parquet
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
        ) TO 'src/data/incomes.parquet' (FORMAT PARQUET, COMPRESSION 'ZSTD')
      `, (err) => {
        if (err) {
          console.error("Error exporting incomes:", err);
          reject(err);
          return;
        }
        console.error("✓ Generated incomes.parquet");

        // Export expenses (economic classification)
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
          ) TO 'src/data/expenses.parquet' (FORMAT PARQUET, COMPRESSION 'ZSTD')
        `, (err) => {
          if (err) {
            console.error("Error exporting expenses:", err);
            reject(err);
            return;
          }
          console.error("✓ Generated expenses.parquet");

          // Export expenses (functional classification)
          db.run(`
            COPY (
              SELECT 
                CITY,
                REP_PERIOD,
                FUND_TYP,
                COD_CONS_MB_FK,
                COD_CONS_MB_FK_NAME,
                FAKT_AMT
              FROM expenses_functional
              ORDER BY CITY, REP_PERIOD, COD_CONS_MB_FK
            ) TO 'src/data/expenses-functional.parquet' (FORMAT PARQUET, COMPRESSION 'ZSTD')
          `, (err) => {
            if (err) {
              console.error("Error exporting expenses-functional:", err);
              reject(err);
              return;
            }
            console.error("✓ Generated expenses-functional.parquet");

            db.close((closeErr) => {
              if (closeErr) {
                console.error("Error closing database:", closeErr);
                reject(closeErr);
              } else {
                resolve();
              }
            });
          });
        });
      });
    });
  });
});

// For Observable Framework, we need to output something to stdout
// Since the actual files are already written to disk, we can just output a success message
process.stdout.write(JSON.stringify({ 
  success: true,
  files: [
    "incomes.parquet",
    "expenses.parquet", 
    "expenses-functional.parquet"
  ]
}));
