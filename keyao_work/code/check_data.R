data_path <- "data/bank_fraud.csv"
bank_fraud <- read.csv(data_path, stringsAsFactors = FALSE)

cat("Number of rows:", nrow(bank_fraud), "\n")
cat("Number of columns:", ncol(bank_fraud), "\n\n")

cat("Column names:\n")
print(names(bank_fraud))

cat("\nFirst 5 rows:\n")
print(head(bank_fraud, 5))

cat("\nData summary:\n")
print(summary(bank_fraud))

if ("is_fraud" %in% names(bank_fraud)) {
  cat("\nFraud/non-fraud counts:\n")
  print(table(bank_fraud$is_fraud, useNA = "ifany"))

  fraud_values <- bank_fraud$is_fraud
  if (is.logical(fraud_values) || is.numeric(fraud_values) || is.integer(fraud_values)) {
    fraud_rate <- mean(fraud_values == 1, na.rm = TRUE)
  } else {
    normalized_values <- tolower(trimws(as.character(fraud_values)))
    fraud_rate <- mean(normalized_values %in% c("1", "true", "yes", "fraud"), na.rm = TRUE)
  }

  cat("Overall fraud rate:", sprintf("%.4f (%.2f%%)", fraud_rate, 100 * fraud_rate), "\n")
}

if ("fraud_type" %in% names(bank_fraud)) {
  cat("\nFraud type counts:\n")
  print(table(bank_fraud$fraud_type, useNA = "ifany"))
}
