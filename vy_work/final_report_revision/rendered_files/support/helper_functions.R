# Helper functions for the self-contained IEEE R Markdown paper.

choose_transaction_data <- function(
    full_path = "data/transactions.csv",
    sample_path = "data/sample_transactions.csv") {
  if (file.exists(full_path)) {
    return(list(path = full_path, using_sample = FALSE))
  }

  if (file.exists(sample_path)) {
    warning(
      "Full data/transactions.csv was not found. Using the balanced sample ",
      "for code demonstration only; sample results do not estimate prevalence.",
      call. = FALSE
    )
    return(list(path = sample_path, using_sample = TRUE))
  }

  stop(
    "No input data found. Add data/transactions.csv or ",
    "data/sample_transactions.csv.",
    call. = FALSE
  )
}

require_columns <- function(data, columns) {
  missing_columns <- setdiff(columns, names(data))
  if (length(missing_columns) > 0) {
    stop(
      "The input data are missing required columns: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(data)
}

prepare_transactions <- function(data) {
  data <- janitor::clean_names(data)

  require_columns(
    data,
    c(
      "is_fraud", "hour_of_day", "failed_attempts", "merchant_category",
      "account_balance"
    )
  )

  if (!"is_night_transaction" %in% names(data)) {
    data <- data |>
      dplyr::mutate(
        is_night_transaction = as.integer(hour_of_day <= 6 | hour_of_day >= 22)
      )
  }

  if (!"pin_changed_recently" %in% names(data)) {
    data$pin_changed_recently <- NA_integer_
  }

  if (!"is_weekend" %in% names(data)) {
    data$is_weekend <- NA_integer_
  }

  if (!"is_international" %in% names(data)) {
    data$is_international <- NA_integer_
  }

  data |>
    dplyr::mutate(
      is_fraud = as.integer(is_fraud),
      fraud_label = factor(
        dplyr::if_else(is_fraud == 1L, "Fraud", "Non-fraud"),
        levels = c("Non-fraud", "Fraud")
      ),
      time_of_day = factor(
        dplyr::if_else(is_night_transaction == 1L, "Night", "Day"),
        levels = c("Day", "Night")
      ),
      pin_change_status = factor(
        dplyr::case_when(
          pin_changed_recently == 1L ~ "PIN Changed",
          pin_changed_recently == 0L ~ "No PIN Change",
          TRUE ~ NA_character_
        ),
        levels = c("No PIN Change", "PIN Changed")
      ),
      weekend_status = factor(
        dplyr::case_when(
          is_weekend == 1L ~ "Weekend",
          is_weekend == 0L ~ "Weekday",
          TRUE ~ NA_character_
        ),
        levels = c("Weekday", "Weekend")
      ),
      transaction_type = factor(
        dplyr::case_when(
          is_international == 1L ~ "International",
          is_international == 0L ~ "Domestic",
          TRUE ~ NA_character_
        ),
        levels = c("Domestic", "International")
      )
    )
}

fraud_rate_by <- function(data, variable) {
  data |>
    dplyr::filter(!is.na({{ variable }}), !is.na(is_fraud)) |>
    dplyr::group_by({{ variable }}) |>
    dplyr::summarise(
      total_transactions = dplyr::n(),
      fraud_count = sum(is_fraud == 1L),
      fraud_rate = mean(is_fraud == 1L),
      .groups = "drop"
    )
}

paper_theme <- function(base_size = 9) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 1),
      plot.subtitle = ggplot2::element_text(size = base_size),
      axis.title = ggplot2::element_text(face = "plain"),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "bottom"
    )
}
