#!/usr/bin/env Rscript
# R Data Loader for Observable Framework
# Downloads new budget data from OpenBudget API and updates DuckDB database

library(readr)
library(tidyr)
library(dplyr)
library(purrr)
library(httr)
library(jsonlite)
library(lubridate)
library(DBI)
library(duckdb)

# Source helper functions
source("config.R")
source("helper-functions.R")

# Suppress column specification messages
options(readr.show_col_types = FALSE)

# Set working directory to data folder
setwd(dirname(parent.frame(2)$ofile))

# Load configuration and get city codes
config <- read_config()
validate_config(config)

city_lookup <- create_city_lookup(config)
all_codes <- get_all_city_codes(config)
all_cities <- get_city_names(config)

# Connect to DuckDB database
con <- dbConnect(duckdb::duckdb(), dbdir = "budget.duckdb")

# Check if tables exist
tables <- dbListTables(con)
if (!"incomes" %in% tables) {
  message("Database not initialized. Run setup first.")
  dbDisconnect(con, shutdown = TRUE)
  q(status = 1)
}

# Check which cities are in the database
db_cities <- dbGetQuery(con, "SELECT DISTINCT CITY FROM incomes WHERE CITY IS NOT NULL")$CITY
missing_cities <- setdiff(all_cities, db_cities)

if (length(missing_cities) > 0) {
  # Some cities are missing - download all years (2021-present) for missing cities
  message(sprintf("Missing cities found: %s", paste(missing_cities, collapse = ", ")))
  
  # Get codes for missing cities
  missing_city_codes <- city_lookup %>%
    filter(city %in% missing_cities) %>%
    pull(value)
  
  codes <- missing_city_codes
  current_year <- year(Sys.Date())
  years_to_update <- 2021:current_year
  
  message(sprintf("Downloading all years (2021-%d) for %d missing cities", 
                  current_year, length(missing_cities)))
} else {
  # All cities present - check for new months
  message("All cities present in database, checking for new months...")
  
  latest_period <- dbGetQuery(con, "SELECT MAX(REP_PERIOD) as max_date FROM incomes")$max_date
  latest_period <- as.Date(latest_period)
  
  if (is.na(latest_period)) {
    stop("Could not determine latest period from database")
  }
  
  # Use last day of previous month
  current_date <- floor_date(Sys.Date(), "month") - days(1)
  current_year <- year(current_date)
  current_month <- month(current_date)
  latest_year <- year(latest_period)
  latest_month <- month(latest_period)
  
  message(sprintf("Latest data: %s", format(latest_period, "%Y-%m-%d")))
  message(sprintf("Current date: %s", format(current_date, "%Y-%m-%d")))
  
  # Check if update is needed
  if (current_year == latest_year && current_month == latest_month) {
    message("Data is up to date.")
    dbDisconnect(con, shutdown = TRUE)
    q(status = 0)
  }
  
  # Determine years to update for all cities
  codes <- all_codes
  years_to_update <- integer(0)
  if (current_year > latest_year) {
    years_to_update <- c(years_to_update, current_year)
  }
  if (current_year == latest_year && current_month > latest_month) {
    years_to_update <- c(years_to_update, current_year)
  }
  if (latest_year == current_year - 1 && latest_month < 12) {
    years_to_update <- c(years_to_update, latest_year)
  }
  
  message(sprintf("Updating all cities for years: %s", paste(years_to_update, collapse = ", ")))
}

if (length(years_to_update) > 0) {
  years_to_update <- sort(unique(years_to_update))
  message(sprintf("Updating data for years: %s", paste(years_to_update, collapse = ", ")))
  
  # Download data
  data <- safe_download_data(codes, years_to_update)
  
  if (is.null(data) || length(data) == 0) {
    stop("Downloaded data is empty or NULL")
  }
  
  # Map data by name
  data_map <- list(
    credits = if ("CREDITS, CREDIT" %in% names(data)) data[["CREDITS, CREDIT"]] else NULL,
    expenses = if ("EXPENSES, ECONOMIC" %in% names(data)) data[["EXPENSES, ECONOMIC"]] else NULL,
    expenses_functional = if ("EXPENSES, PROGRAM" %in% names(data)) data[["EXPENSES, PROGRAM"]] else NULL,
    debts = if ("FINANCING_DEBTS" %in% names(data)) data[["FINANCING_DEBTS"]] else NULL,
    incomes = if ("INCOMES" %in% names(data)) data[["INCOMES"]] else NULL
  )
  
  # Function to update database table
  update_table <- function(table_name, new_data, description) {
    if (is.null(new_data) || nrow(new_data) == 0) {
      message(sprintf("Skipping %s: no new data", description))
      return(invisible(NULL))
    }
    
    message(sprintf("Updating %s...", description))
    
    # Add city information using config-based lookup
    new_data_with_city <- new_data |>
      mutate(COD_BUDGET = as.character(COD_BUDGET)) |>
      left_join(city_lookup, join_by(COD_BUDGET == value)) |>
      rename(CITY = city) |>
      mutate(COD_BUDGET = as.numeric(COD_BUDGET))  # Convert back to numeric for database
    
    if (sum(is.na(new_data_with_city$CITY)) > 0) {
      warning(sprintf("%s: %d rows with unmatched city codes", 
                     description, sum(is.na(new_data_with_city$CITY))))
    }
    
    # Get new periods
    new_periods <- unique(new_data_with_city$REP_PERIOD)
    
    # Check each period for differences
    periods_to_update <- character(0)
    total_deleted <- 0
    
    for (period in new_periods) {
      period_str <- format(as.Date(period), "%Y-%m-%d")
      
      # Count existing rows for this period
      existing_count <- dbGetQuery(con, sprintf(
        "SELECT COUNT(*) as cnt FROM %s WHERE REP_PERIOD = '%s'",
        table_name, period_str
      ))$cnt
      
      # Get new data row count for this period
      period_new_count <- sum(new_data_with_city$REP_PERIOD == period)
      
      # If row counts differ, data has changed
      data_differs <- existing_count != period_new_count || existing_count == 0
      
      if (data_differs) {
        periods_to_update <- c(periods_to_update, period_str)
        rows_deleted <- dbExecute(con, sprintf("DELETE FROM %s WHERE REP_PERIOD = '%s'", 
                                              table_name, period_str))
        total_deleted <- total_deleted + rows_deleted
      }
    }
    
    # Insert only data for periods that changed
    if (length(periods_to_update) > 0) {
      data_to_insert <- new_data_with_city |>
        filter(format(as.Date(REP_PERIOD), "%Y-%m-%d") %in% periods_to_update)
      
      if (nrow(data_to_insert) > 0) {
        dbWriteTable(con, table_name, data_to_insert, append = TRUE)
        message(sprintf("%s: %d rows updated across %d periods\", 
                       description, nrow(data_to_insert), length(periods_to_update)))
      }
    } else {
      message(sprintf("%s: all periods unchanged, no updates needed\", description))
    }
  }
  
  # Update each table
  update_table("credits", data_map$credits |> distinct(), "credits")
  update_table("expenses", data_map$expenses |> distinct(), "expenses")
  
  # Expenses functional needs aggregation and NA handling
  if (!is.null(data_map$expenses_functional)) {
    exp_f_agg <- data_map$expenses_functional |>
      distinct() |>
      mutate(COD_CONS_MB_FK = if_else(is.na(COD_CONS_MB_FK), 0L, COD_CONS_MB_FK)) |>
      group_by(REP_PERIOD, FUND_TYP, COD_BUDGET, COD_CONS_MB_FK, COD_CONS_MB_FK_NAME) |>
      summarise(across(c(COD_CONS_MB_PK, ZAT_AMT, FAKT_AMT, FAKT_V2MB_AMT, FAKTSIK_AMT, FAKTSIK_V2MB_AMT, 
                         FAKTSPP_AMT, FAKTSPP_V2MB_AMT, FAKTSID_AMT, FAKTSID_V2MB_AMT), 
                       ~sum(., na.rm = TRUE)), .groups = "drop")
    
    update_table("expenses_functional", exp_f_agg, "expenses_functional")
  }
  
  update_table("debts", data_map$debts |> distinct(), "debts")
  update_table("incomes", data_map$incomes |> distinct(), "incomes")
  
  message("Database update completed successfully")
} else {
  message("Data is up to date.")
}

# Disconnect
dbDisconnect(con, shutdown = TRUE)
