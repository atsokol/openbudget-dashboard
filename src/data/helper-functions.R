# Helper Functions for OpenBudget API Access
# Functions to construct API calls and download budget data

library(httr)
library(readr)
library(dplyr)
library(tidyr)
library(purrr)
library(lubridate)

# Construct API path for OpenBudget portal
api_construct <- function(budgetCode,
                          budgetItem, # "INCOMES","EXPENSES","FINANCING_DEBTS","FINANCING_CREDITOR","CREDITS"
                          classificationType, # "PROGRAM","FUNCTIONAL","ECONOMIC","CREDIT"
                          year,
                          period = "MONTH") {

  api_base <- "https://api.openbudget.gov.ua/api/public/localBudgetData?"

  if (budgetItem %in% c("EXPENSES", "CREDITS")) {
    api_path <-
      paste(api_base,
            "budgetCode=", budgetCode,
            "&budgetItem=", budgetItem,
            "&classificationType=", classificationType,  # classificationType parameter is mandatory for EXPENSES and CREDITS items
            "&period=", period,
            "&year=", year,
            sep = "")
  } else {
    api_path <-
      paste(api_base,
            "budgetCode=", budgetCode,
            "&budgetItem=", budgetItem,
            "&period=", period,
            "&year=", year,
            sep = "")
  }

  return(api_path)
}

# Function to call API, read in and parse data
call_api <- function(api_path, col_types) {
  response <- GET(api_path)
  
  # Check HTTP status
  if (status_code(response) != 200) {
    stop(sprintf("API request failed with status %d: %s", 
                status_code(response), api_path))
  }
  
  # Check if response has content
  if (length(response$content) == 0) {
    warning(sprintf("Empty response from API: %s", api_path))
    return(tibble())
  }
  
  # Parse response
  data_call <- tryCatch({
    response |>
      pluck("content") |>
      rawToChar() |>
      read_delim(delim = ";", col_types = col_types, show_col_types = FALSE) |>
      mutate(REP_PERIOD = readr::parse_date(REP_PERIOD, "%m.%Y") |>
               ceiling_date(unit = "month") - days(1))  # Use end of month dates
  }, error = function(e) {
    stop(sprintf("Failed to parse API response: %s\nError: %s", api_path, e$message))
  })
  
  # Validate parsed data
  if (nrow(data_call) == 0) {
    warning(sprintf("No data returned from API: %s", api_path))
  }

  return(data_call)
}

# Function to download data from OpenBudget API
download_data <- function(BUDGETCODE, YEAR, con = NULL) {
  # Define API data types based on OpenBudget API structure
  # These are the required field specifications for API calls
  var_types <- tribble(
    ~budgetItem, ~classificationType, ~colType,
    "INCOMES", NA, "ccciccddd",  # REP_PERIOD,FUND_TYP,COD_BUDGET,COD_INCO,NAME_INC,ZAT_AMT,PLANS_AMT,FAKT_AMT,DONE_CORR_YEAR_PCT
    "FINANCING_DEBTS", NA, "cccicdd",  # REP_PERIOD,FUND_TYP,COD_BUDGET,COD_FINA,NAME_FIN,ZAT_AMT,FAKT_AMT,DONE_CORR_YEAR_PCT
    "EXPENSES", "ECONOMIC", "cccicddddddddddd",  # REP_PERIOD,FUND_TYP,COD_BUDGET,COD_CONS_EK,COD_CONS_EK_NAME,ZAT_AMT,PLANS_AMT,FAKT_AMT, etc
    "EXPENSES", "PROGRAM", "ccciciccddddddddddddd",  # REP_PERIOD,FUND_TYP,COD_BUDGET,COD_CONS_MB_PK,COD_CONS_MB_PK_NAME,COD_CONS_MB_FK,etc
    "CREDITS", "CREDIT", "ccciccddddd"  # REP_PERIOD,FUND_TYP,COD_BUDGET,COD_CRED,NAME_CRED,ZAT_AMT,PLANS_AMT,FAKT_AMT,etc
  )

  # Construct API calls
  df_api <- var_types |>
    filter(!is.na(colType)) |>
    expand_grid(budgetCode = BUDGETCODE, year = YEAR) |>
    rowwise() |>
    mutate(api_path = api_construct(budgetCode, budgetItem, classificationType, year))

  message(sprintf("Downloading data for %d budget codes, %d years, %d API calls", 
                 length(unique(BUDGETCODE)), length(unique(YEAR)), nrow(df_api)))

  # Read in data across multiple periods and categories into a nested data frame
  df_n <- df_api |>
    mutate(data = list(call_api(api_path, colType))) |>
    select(budgetItem, classificationType, data) |>
    group_by(budgetItem, classificationType) |>
    summarise(data = list(list_rbind(data) |> arrange(REP_PERIOD)), .groups = "drop")

  # Validate data was retrieved
  if (nrow(df_n) == 0) {
    stop("No data retrieved from API")
  }

  # Extract nested data column into a named list
  data_l <- df_n$data
  names(data_l) <- if_else(!is.na(df_n$classificationType),
                           paste(df_n$budgetItem, df_n$classificationType, sep=", "),
                           df_n$budgetItem)

  return(data_l)
}

# Safe download with retry logic
safe_download_data <- function(codes, periods, max_retries = 5) {
  for (attempt in seq_len(max_retries)) {
    result <- tryCatch(
      {
        message(sprintf("Download attempt %d of %d", attempt, max_retries))
        download_data(codes, periods)
      },
      error = function(e) {
        message(sprintf("Download failed (attempt %d): %s", attempt, e$message))
        if (attempt < max_retries) {
          wait_time <- min(2^attempt, 10)
          message(sprintf("Waiting %d seconds before retry...", wait_time))
          Sys.sleep(wait_time)
        }
        return(NULL)
      }
    )
    if (!is.null(result)) {
      message("Download successful")
      return(result)
    }
  }
  stop(sprintf("Failed to download data after %d attempts", max_retries))
}
