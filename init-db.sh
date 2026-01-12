#!/bin/bash
# Initialize DuckDB database from CSV files
# Run this script once to set up the database

echo "Setting up DuckDB database..."

# Create the database and run setup SQL
duckdb src/data/budget.duckdb < src/data/setup-db.sql

echo "Database setup complete!"
echo ""
echo "The database has been created at: src/data/budget.duckdb"
echo ""
echo "Next steps:"
echo "1. Copy your classificator JSON files (INC.json, KEK.json, KFK.json) to src/data/"
echo "2. Run 'npm run dev' to start the development server"
echo "3. To update data, run: Rscript src/data/update-db.R"
