#!/usr/bin/env Rscript
# Initialize DuckDB database from CSV files
# This script builds the initial database from committed CSV files
# instead of downloading from the API (much faster for CI/CD)

library(DBI)
library(duckdb)

# Get the script directory
script_dir <- if (interactive()) {
  getwd()
} else {
  dirname(sys.frame(1)$ofile)
}

# Set working directory to script location
setwd(script_dir)

cat("Initializing database from CSV files...\n")

# Check if incomes.csv exists (it's too large to commit to git)
if (!file.exists("csvs/incomes.csv")) {
  cat("Warning: csvs/incomes.csv not found (not committed due to size)\n")
  cat("Database will be created without incomes data.\n")
  cat("Run update-db.R after initialization to fetch incomes from API.\n")
}

# Connect to DuckDB (will create if doesn't exist)
con <- dbConnect(duckdb::duckdb(), "budget.duckdb")

# Ensure cleanup on exit
on.exit({
  if (exists("con") && !is.null(con)) {
    dbDisconnect(con, shutdown = TRUE)
  }
}, add = TRUE)

# Read and execute the setup SQL script
cat("Reading setup-db.sql...\n")
sql_script <- readLines("setup-db.sql", warn = FALSE)
sql_commands <- paste(sql_script, collapse = "\n")

# Split by semicolons and execute each statement
statements <- strsplit(sql_commands, ";")[[1]]
statements <- trimws(statements)
statements <- statements[nchar(statements) > 0]

cat("Executing SQL statements...\n")
for (stmt in statements) {
  if (nchar(trimws(stmt)) > 0 && !grepl("^--", trimws(stmt))) {
    tryCatch({
      dbExecute(con, stmt)
    }, error = function(e) {
      # Skip errors for incomes table if CSV doesn't exist
      if (!grepl("incomes", stmt, ignore.case = TRUE)) {
        cat("Warning:", conditionMessage(e), "\n")
      }
    })
  }
}

# Verify tables were created
tables <- dbListTables(con)
cat("\nCreated tables:", paste(tables, collapse = ", "), "\n")

# Show row counts
for (table in tables) {
  if (!grepl("^sqlite_", table) && table != "budget_summary") {
    count <- dbGetQuery(con, sprintf("SELECT COUNT(*) as n FROM %s", table))$n
    cat(sprintf("  %s: %s rows\n", table, format(count, big.mark = ",")))
  }
}

cat("\n✓ Database initialized successfully from CSV files\n")
if (!file.exists("csvs/incomes.csv")) {
  cat("⚠ Note: Incomes table is empty. Run update-db.R to populate from API.\n")
}
