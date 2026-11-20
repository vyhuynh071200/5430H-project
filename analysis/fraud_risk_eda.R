#!/usr/bin/env Rscript
# Exploratory Fraud Risk Patterns — portfolio edition.
# Run from repository root: Rscript analysis/fraud_risk_eda.R
# Optional: Rscript analysis/fraud_risk_eda.R input.csv output_directory
# This is descriptive EDA, not predictive fraud scoring.

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = TRUE)
input_file <- if (length(args) >= 1L) args[[1]] else "submit/data/sample_transactions.csv"
output_dir <- if (length(args) >= 2L) args[[2]] else "outputs"

if (!file.exists(input_file)) stop("Missing input file: ", input_file, call. = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

data <- readr::read_csv(input_file, show_col_types = FALSE)
required <- c("is_fraud", "failed_attempts", "hour_of_day",
              "is_international", "pin_changed_recently", "merchant_category")
missing <- setdiff(required, names(data))
if (length(missing) > 0L) {
  stop("Missing required columns: ", paste(missing, collapse = ", "), call. = FALSE)
}

data <- data |>
  mutate(
    is_fraud = suppressWarnings(as.integer(is_fraud)),
    failed_attempts = suppressWarnings(as.numeric(failed_attempts)),
    hour_of_day = suppressWarnings(as.integer(hour_of_day)),
    is_international = suppressWarnings(as.integer(is_international)),
    pin_changed_recently = suppressWarnings(as.integer(pin_changed_recently)),
    merchant_category = as.character(merchant_category)
  )

if (any(!is.na(data$is_fraud) & !(data$is_fraud %in% c(0L, 1L)))) {
  stop("Fraud labels must be 0 or 1.", call. = FALSE)
}
if (any(!is.na(data$hour_of_day) & !(data$hour_of_day %in% 0:23))) {
  stop("Hour of day must be 0–23.", call. = FALSE)
}

data <- data |>
  mutate(
    failed_attempt_group = case_when(
      is.na(failed_attempts) | failed_attempts < 0 ~ NA_character_,
      failed_attempts == 0 ~ "0",
      failed_attempts == 1 ~ "1",
      TRUE ~ "2+"
    ),
    time_period = case_when(
      is.na(hour_of_day) ~ NA_character_,
      hour_of_day >= 22 | hour_of_day <= 6 ~ "Night / early morning",
      TRUE ~ "Other hours"
    ),
    international_status = case_when(
      is_international == 1 ~ "International",
      is_international == 0 ~ "Domestic",
      TRUE ~ NA_character_
    ),
    pin_change_status = case_when(
      pin_changed_recently == 1 ~ "Recently changed",
      pin_changed_recently == 0 ~ "Not recently changed",
      TRUE ~ NA_character_
    )
  )

valid <- data |> filter(!is.na(is_fraud))
if (nrow(valid) == 0L) stop("No valid labels.", call. = FALSE)

summarize_rate <- function(df, field) {
  df |>
    filter(!is.na(.data[[field]])) |>
    group_by(group = .data[[field]]) |>
    summarise(
      transactions = n(),
      fraud_transactions = sum(is_fraud == 1L),
      fraud_share = mean(is_fraud == 1L),
      .groups = "drop"
    ) |>
    mutate(dimension = field, .before = 1)
}

dimensions <- c("failed_attempt_group", "time_period",
                "international_status", "pin_change_status", "merchant_category")
rates <- bind_rows(lapply(dimensions, function(field) summarize_rate(valid, field)))
overall <- tibble::tibble(
  input = basename(input_file),
  input_rows = nrow(data),
  valid_label_rows = nrow(valid),
  fraud_rows = sum(valid$is_fraud == 1L),
  input_fraud_share = mean(valid$is_fraud == 1L)
)

readr::write_csv(overall, file.path(output_dir, "overall_summary.csv"))
readr::write_csv(rates, file.path(output_dir, "risk_by_dimension.csv"))

chart_data <- rates |>
  filter(dimension == "failed_attempt_group") |>
  mutate(group = factor(group, levels = c("0", "1", "2+")))

if (nrow(chart_data) > 0L) {
  chart <- ggplot(chart_data, aes(x = group, y = fraud_share)) +
    geom_col(fill = "#436987", width = 0.65) +
    scale_y_continuous(labels = scales::label_percent()) +
    labs(
      title = "Observed fraud share by failed attempts",
      subtitle = "Descriptive rates for supplied dataset (may be balanced by design)",
      x = "Failed attempts", y = "Within-group fraud share",
      caption = paste("Source:", basename(input_file))
    ) +
    theme_minimal(base_size = 11)
  ggsave(file.path(output_dir, "failed_attempts_fraud_share.png"),
         plot = chart, width = 8, height = 5, dpi = 180)
}

writeLines(c(
  paste("Input:", normalizePath(input_file)),
  "The supplied default CSV is intentionally balanced (1,000 fraud / 1,000 non-fraud).",
  "Rates here describe the supplied data, NOT population fraud prevalence.",
  "No causal or predictive claims can be made from these summaries."
), file.path(output_dir, "DATA_PROVENANCE.txt"))

message("Analysis complete; outputs saved under ", normalizePath(output_dir))
