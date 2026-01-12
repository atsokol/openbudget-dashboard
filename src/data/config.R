# Configuration Helper Functions for OpenBudget Dashboard
# Provides functions to read and work with config.yaml

library(yaml)
library(dplyr)
library(purrr)
library(tibble)

# Read configuration file
read_config <- function(config_path = "../../config.yaml") {
  if (!file.exists(config_path)) {
    stop(sprintf("Configuration file not found: %s", config_path))
  }
  
  config <- tryCatch(
    yaml::read_yaml(config_path),
    error = function(e) {
      stop(sprintf("Failed to parse configuration file: %s", e$message))
    }
  )
  
  return(config)
}

# Get all city codes as a flat vector
get_all_city_codes <- function(config = NULL) {
  if (is.null(config)) {
    config <- read_config()
  }
  
  codes <- config$cities |>
    map("codes") |>
    unlist() |>
    unique() |>
    as.character()
  
  return(codes)
}

# Create city code lookup table (code -> city name)
create_city_lookup <- function(config = NULL) {
  if (is.null(config)) {
    config <- read_config()
  }
  
  lookup <- map_dfr(config$cities, function(city) {
    tibble(
      value = as.character(city$codes),
      city = city$name
    )
  })
  
  return(lookup)
}

# Categorize revenue based on income code
categorize_revenue <- function(income_code, config = NULL) {
  if (is.null(config)) {
    config <- read_config()
  }
  
  # Convert to numeric
  code_num <- as.numeric(income_code)
  
  # Check each category
  for (cat in config$revenue_categories) {
    if (cat$type == "range") {
      if (code_num >= cat$codes[1] && code_num <= cat$codes[2]) {
        return(cat$name)
      }
    } else if (cat$type == "ranges") {
      for (range in cat$codes) {
        if (code_num >= range[1] && code_num <= range[2]) {
          return(cat$name)
        }
      }
    }
  }
  
  return("Other")
}

# Vectorized version of categorize_revenue
categorize_revenue_vec <- function(income_codes, config = NULL) {
  if (is.null(config)) {
    config <- read_config()
  }
  
  sapply(income_codes, categorize_revenue, config = config)
}

# Categorize expense (economic classification)
categorize_expense_economic <- function(expense_code, config = NULL) {
  if (is.null(config)) {
    config <- read_config()
  }
  
  # Convert to numeric
  code_num <- as.numeric(expense_code)
  
  # Check each category
  for (cat in config$expense_economic_categories) {
    if (cat$type == "range") {
      if (code_num >= cat$codes[1] && code_num <= cat$codes[2]) {
        return(cat$name)
      }
    } else if (cat$type == "ranges") {
      for (range in cat$codes) {
        if (code_num >= range[1] && code_num <= range[2]) {
          return(cat$name)
        }
      }
    }
  }
  
  return("Other")
}

# Vectorized version of categorize_expense_economic
categorize_expense_economic_vec <- function(expense_codes, config = NULL) {
  if (is.null(config)) {
    config <- read_config()
  }
  
  sapply(expense_codes, categorize_expense_economic, config = config)
}

# Get category color
get_category_color <- function(category_name, category_type = "revenue", config = NULL) {
  if (is.null(config)) {
    config <- read_config()
  }
  
  categories <- if (category_type == "revenue") {
    config$revenue_categories
  } else {
    config$expense_economic_categories
  }
  
  for (cat in categories) {
    if (cat$name == category_name) {
      return(cat$color)
    }
  }
  
  return("#cccccc")  # Default gray
}

# Get all city names
get_city_names <- function(config = NULL) {
  if (is.null(config)) {
    config <- read_config()
  }
  
  config$cities |>
    map_chr("name")
}

# Validate configuration
validate_config <- function(config = NULL) {
  if (is.null(config)) {
    config <- read_config()
  }
  
  errors <- character(0)
  warnings <- character(0)
  
  # Check cities
  if (is.null(config$cities) || length(config$cities) == 0) {
    errors <- c(errors, "No cities defined in configuration")
  } else {
    for (i in seq_along(config$cities)) {
      city <- config$cities[[i]]
      if (is.null(city$name)) {
        errors <- c(errors, sprintf("City %d missing name", i))
      }
      if (is.null(city$codes) || length(city$codes) == 0) {
        errors <- c(errors, sprintf("City '%s' has no codes", city$name))
      }
      # Check code format (should be 10 digits with optional leading zeros)
      for (code in city$codes) {
        if (!grepl("^[0-9]{10}$", code)) {
          warnings <- c(warnings, sprintf("City '%s' code '%s' is not 10 digits", 
                                         city$name, code))
        }
      }
    }
  }
  
  # Check revenue categories
  if (is.null(config$revenue_categories) || length(config$revenue_categories) == 0) {
    warnings <- c(warnings, "No revenue categories defined")
  }
  
  # Check expense categories
  if (is.null(config$expense_economic_categories) || 
      length(config$expense_economic_categories) == 0) {
    warnings <- c(warnings, "No expense economic categories defined")
  }
  
  # Report results
  if (length(errors) > 0) {
    stop(sprintf("Configuration validation failed:\n%s", 
                paste("  -", errors, collapse = "\n")))
  }
  
  if (length(warnings) > 0) {
    message("Configuration warnings:")
    for (w in warnings) {
      message(sprintf("  - %s", w))
    }
  } else {
    message("Configuration validation passed")
  }
  
  return(invisible(TRUE))
}
