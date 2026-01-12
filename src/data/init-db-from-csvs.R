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
      cat("Warning:", conditionMessage(e), "\n")
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
    size_mb <- dbGetQuery(con, sprintf("SELECT pg_size_pretty(pg_total_relation_size('%s'))", table))
    cat(sprintf("  %s: %s rows\n", table, format(count, big.mark = ",")))
  }
}

cat("\n✓ Database initialized successfully from CSV files\n")
