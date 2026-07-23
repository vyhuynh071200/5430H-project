# Bank Fraud Project: Data Preparation
# This script inspects the raw data, creates reproducible summary tables,
# adds readable categorical labels, and saves full and sampled datasets.

suppressPackageStartupMessages({
  library(tidyverse)
  library(readr)
  library(dplyr)
})

# -----------------------------------------------------------------------------
# 1. Read the raw dataset
# -----------------------------------------------------------------------------

input_path <- "data/bank_fraud.csv"
prepared_path <- "data/bank_fraud_prepared.csv"
sample_path <- "data/sample_bank_fraud.csv"

dir.create("paper", showWarnings = FALSE, recursive = TRUE)
dir.create("data", showWarnings = FALSE, recursive = TRUE)

bank_fraud <- read_csv(input_path, show_col_types = FALSE)

# Confirm that the variables required for preparation are present.
required_variables <- c(
  "transaction_id", "is_fraud", "fraud_type", "is_international",
  "is_night_transaction", "is_weekend", "pin_changed_recently",
  "customer_age", "transaction_amount", "account_balance", "credit_score",
  "hour_of_day", "failed_attempts"
)
missing_required_variables <- setdiff(required_variables, names(bank_fraud))

if (length(missing_required_variables) > 0) {
  stop(
    "Missing required variables: ",
    paste(missing_required_variables, collapse = ", ")
  )
}

# -----------------------------------------------------------------------------
# 2. Print basic dataset information
# -----------------------------------------------------------------------------

variable_types <- tibble(
  variable = names(bank_fraud),
  type = map_chr(bank_fraud, ~ paste(class(.x), collapse = ", "))
)

cat("\nBANK FRAUD DATA PREPARATION\n")
cat("===========================\n")
cat("Input file:", input_path, "\n")
cat("Number of rows:", format(nrow(bank_fraud), big.mark = ","), "\n")
cat("Number of columns:", ncol(bank_fraud), "\n")

cat("\nColumn names:\n")
print(names(bank_fraud))

cat("\nVariable types:\n")
print(variable_types, n = Inf)

# -----------------------------------------------------------------------------
# 3. Check missing values, duplicates, and impossible values
# -----------------------------------------------------------------------------

missing_values_summary <- tibble(
  variable = names(bank_fraud),
  missing_count = map_int(bank_fraud, ~ sum(is.na(.x))),
  missing_percentage = map_dbl(
    bank_fraud,
    ~ 100 * sum(is.na(.x)) / length(.x)
  )
)

write_csv(missing_values_summary, "paper/missing_values_summary.csv")

# Count repeated IDs/rows after their first occurrence. For example, if an ID
# occurs three times, two records are counted as duplicate transaction IDs.
duplicate_transaction_id_count <- sum(duplicated(bank_fraud$transaction_id))
duplicate_full_row_count <- sum(duplicated(bank_fraud))

# Each rule below counts non-missing values that fall outside the valid range.
data_quality_summary <- tribble(
  ~quality_check, ~issue_count,
  "Missing values (all variables)", sum(missing_values_summary$missing_count),
  "Duplicate transaction_id values", duplicate_transaction_id_count,
  "Duplicate full rows", duplicate_full_row_count,
  "customer_age < 18", sum(bank_fraud$customer_age < 18, na.rm = TRUE),
  "transaction_amount <= 0", sum(bank_fraud$transaction_amount <= 0, na.rm = TRUE),
  "account_balance < 0", sum(bank_fraud$account_balance < 0, na.rm = TRUE),
  "credit_score outside 300 to 850",
    sum(bank_fraud$credit_score < 300 | bank_fraud$credit_score > 850, na.rm = TRUE),
  "hour_of_day outside 0 to 23",
    sum(bank_fraud$hour_of_day < 0 | bank_fraud$hour_of_day > 23, na.rm = TRUE),
  "failed_attempts < 0", sum(bank_fraud$failed_attempts < 0, na.rm = TRUE)
) %>%
  mutate(issue_percentage = 100 * issue_count / nrow(bank_fraud))

write_csv(data_quality_summary, "paper/data_quality_summary.csv")

cat("\nMissing-value check:\n")
cat("Variables with missing values:",
    sum(missing_values_summary$missing_count > 0), "\n")
cat("Total missing values:",
    format(sum(missing_values_summary$missing_count), big.mark = ","), "\n")

cat("\nData-quality checks:\n")
print(data_quality_summary, n = Inf)

# -----------------------------------------------------------------------------
# 4. Create and save summary tables
# -----------------------------------------------------------------------------

# One-row overview of fraud prevalence in the full dataset.
fraud_summary <- bank_fraud %>%
  summarise(
    total_transactions = n(),
    fraud_count = sum(is_fraud == 1, na.rm = TRUE),
    non_fraud_count = sum(is_fraud == 0, na.rm = TRUE),
    fraud_rate = mean(is_fraud == 1, na.rm = TRUE)
  )

write_csv(fraud_summary, "paper/fraud_summary.csv")

# Include every fraud_type value, including "None". Missing labels, if present,
# are retained as "Missing" so that the percentages sum to 100%.
fraud_type_summary <- bank_fraud %>%
  mutate(fraud_type = replace_na(fraud_type, "Missing")) %>%
  count(fraud_type, name = "count") %>%
  mutate(
    percentage = 100 * count / sum(count)
  ) %>%
  arrange(desc(count))

write_csv(fraud_type_summary, "paper/fraud_type_summary.csv")

# Summarise the principal continuous/count variables used in the EDA.
key_numeric_variables <- c(
  "customer_age", "credit_score", "account_age_years",
  "account_balance", "transaction_amount", "num_prev_transactions",
  "transaction_freq_monthly", "distance_from_home_km",
  "time_since_last_txn_hrs", "failed_attempts"
)

missing_numeric_variables <- setdiff(key_numeric_variables, names(bank_fraud))
if (length(missing_numeric_variables) > 0) {
  stop(
    "Missing numeric variables required for the summary: ",
    paste(missing_numeric_variables, collapse = ", ")
  )
}

numeric_summary <- bank_fraud %>%
  select(all_of(key_numeric_variables)) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "value") %>%
  group_by(variable) %>%
  summarise(
    missing_count = sum(is.na(value)),
    minimum = min(value, na.rm = TRUE),
    first_quartile = quantile(value, 0.25, na.rm = TRUE),
    median = median(value, na.rm = TRUE),
    mean = mean(value, na.rm = TRUE),
    third_quartile = quantile(value, 0.75, na.rm = TRUE),
    maximum = max(value, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(numeric_summary, "paper/numeric_summary.csv")

# -----------------------------------------------------------------------------
# 5. Add readable label variables and convert useful categories to factors
# -----------------------------------------------------------------------------

bank_fraud_prepared <- bank_fraud %>%
  mutate(
    fraud_status = case_when(
      is_fraud == 1 ~ "Fraud",
      is_fraud == 0 ~ "Non-fraud",
      TRUE ~ NA_character_
    ),
    transaction_type = case_when(
      is_international == 1 ~ "International",
      is_international == 0 ~ "Domestic",
      TRUE ~ NA_character_
    ),
    night_status = case_when(
      is_night_transaction == 1 ~ "Night",
      is_night_transaction == 0 ~ "Day",
      TRUE ~ NA_character_
    ),
    weekend_status = case_when(
      is_weekend == 1 ~ "Weekend",
      is_weekend == 0 ~ "Weekday",
      TRUE ~ NA_character_
    ),
    pin_change_status = case_when(
      pin_changed_recently == 1 ~ "Recent PIN Change",
      pin_changed_recently == 0 ~ "No Recent PIN Change",
      TRUE ~ NA_character_
    ),
    # Explicit levels make reference/order choices reproducible in later plots.
    fraud_status = factor(fraud_status, levels = c("Non-fraud", "Fraud")),
    transaction_type = factor(
      transaction_type,
      levels = c("Domestic", "International")
    ),
    night_status = factor(night_status, levels = c("Day", "Night")),
    weekend_status = factor(weekend_status, levels = c("Weekday", "Weekend")),
    pin_change_status = factor(
      pin_change_status,
      levels = c("No Recent PIN Change", "Recent PIN Change")
    ),
    across(
      c(country, city, merchant_category, payment_method, device_type, fraud_type),
      as.factor
    )
  )

# -----------------------------------------------------------------------------
# 6. Save the complete prepared dataset
# -----------------------------------------------------------------------------

write_csv(bank_fraud_prepared, prepared_path)

# -----------------------------------------------------------------------------
# 7. Create a reproducible stratified sample for final code submission
# -----------------------------------------------------------------------------

class_counts <- bank_fraud_prepared %>%
  filter(is_fraud %in% c(0, 1)) %>%
  count(is_fraud)

if (!all(c(0, 1) %in% class_counts$is_fraud) ||
    any(class_counts$n[class_counts$is_fraud %in% c(0, 1)] < 1000)) {
  stop("At least 1,000 fraud and 1,000 non-fraud records are required.")
}

set.seed(123)

sample_bank_fraud <- bank_fraud_prepared %>%
  filter(is_fraud %in% c(0, 1)) %>%
  group_by(is_fraud) %>%
  slice_sample(n = 1000) %>%
  ungroup() %>%
  arrange(desc(is_fraud))

write_csv(sample_bank_fraud, sample_path)

# -----------------------------------------------------------------------------
# 8. Print a concise completion summary
# -----------------------------------------------------------------------------

cat("\nFraud summary:\n")
print(fraud_summary)

cat("\nStratified sample counts:\n")
print(sample_bank_fraud %>% count(fraud_status))

cat("\nFiles saved:\n")
cat("- paper/missing_values_summary.csv\n")
cat("- paper/data_quality_summary.csv\n")
cat("- paper/fraud_summary.csv\n")
cat("- paper/fraud_type_summary.csv\n")
cat("- paper/numeric_summary.csv\n")
cat("-", prepared_path, "\n")
cat("-", sample_path, "\n")
cat("\nData preparation completed successfully.\n")
