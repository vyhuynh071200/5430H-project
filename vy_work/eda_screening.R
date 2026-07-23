options(stringsAsFactors = FALSE)

input_file <- "vy_work/data/sample_bank_fraud.csv"
numeric_output <- "vy_work/tables/eda_screening_numeric.csv"
categorical_output <- "vy_work/tables/eda_screening_categorical.csv"
figure_dir <- "vy_work/figures/screening"

numeric_vars <- c(
  "customer_age", "credit_score", "account_age_years", "account_balance",
  "num_prev_transactions", "transaction_freq_monthly",
  "time_since_last_txn_hrs"
)
categorical_vars <- c("country", "city")
required_vars <- c(numeric_vars, categorical_vars, "is_fraud")
sparse_threshold <- 20L

dat <- read.csv(input_file, check.names = FALSE, na.strings = c("", "NA"))
missing_columns <- setdiff(required_vars, names(dat))
if (length(missing_columns) > 0L) {
  stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
}
if (!all(dat$is_fraud %in% c(0, 1, NA))) {
  stop("is_fraud must be coded 0/1 (apart from missing values).")
}
fraud_counts <- table(dat$is_fraud, useNA = "ifany")
if (!identical(as.integer(fraud_counts[c("0", "1")]), c(1000L, 1000L))) {
  warning("Observed fraud-group counts differ from the stated 1,000/1,000 balance.")
}

dir.create(dirname(numeric_output), recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

safe_stat <- function(x, fn) if (sum(!is.na(x)) == 0L) NA_real_ else fn(x, na.rm = TRUE)

numeric_effects <- function(x, g) {
  x0 <- x[g == 0 & !is.na(g) & !is.na(x)]
  x1 <- x[g == 1 & !is.na(g) & !is.na(x)]
  pooled_sd <- sqrt(((length(x1) - 1) * var(x1) + (length(x0) - 1) * var(x0)) /
    (length(x1) + length(x0) - 2))
  smd <- if (is.finite(pooled_sd) && pooled_sd > 0) (mean(x1) - mean(x0)) / pooled_sd else NA_real_
  ranks <- rank(c(x1, x0), ties.method = "average")
  u1 <- sum(ranks[seq_along(x1)]) - length(x1) * (length(x1) + 1) / 2
  rank_biserial <- 2 * u1 / (length(x1) * length(x0)) - 1
  c(smd = smd, rank_biserial = rank_biserial)
}

numeric_rows <- list()
effect_rows <- list()
for (v in numeric_vars) {
  x <- dat[[v]]
  effects <- numeric_effects(x, dat$is_fraud)
  effect_rows[[v]] <- data.frame(
    variable = v, standardized_mean_difference = effects[["smd"]],
    rank_biserial_correlation = effects[["rank_biserial"]],
    separation_score = pmax(abs(effects[["smd"]]), abs(effects[["rank_biserial"]]), na.rm = TRUE)
  )
  for (group in c(0, 1)) {
    values <- x[dat$is_fraud == group & !is.na(dat$is_fraud)]
    numeric_rows[[paste(v, group)]] <- data.frame(
      variable = v, fraud_group = group, sample_size = length(values),
      missing_count = sum(is.na(values)), nonmissing_count = sum(!is.na(values)),
      mean = safe_stat(values, mean), median = safe_stat(values, median),
      standard_deviation = safe_stat(values, sd),
      first_quartile = safe_stat(values, function(z, ...) quantile(z, 0.25, ...)),
      third_quartile = safe_stat(values, function(z, ...) quantile(z, 0.75, ...))
    )
  }

  group_labels <- factor(dat$is_fraud, levels = c(0, 1), labels = c("Non-fraud", "Fraud"))
  png(file.path(figure_dir, paste0(v, "_distribution.png")), width = 1400, height = 700, res = 140)
  par(mfrow = c(1, 2), mar = c(5, 4, 3, 1))
  common_breaks <- pretty(range(x, na.rm = TRUE), n = 25)
  hist(x[dat$is_fraud == 0], breaks = common_breaks, probability = TRUE,
       col = rgb(0.2, 0.45, 0.75, 0.6), border = "white", main = "Non-fraud", xlab = v)
  hist(x[dat$is_fraud == 1], breaks = common_breaks, probability = TRUE,
       col = rgb(0.85, 0.3, 0.25, 0.6), border = "white", main = "Fraud", xlab = v)
  mtext(paste("Distribution screening:", v), outer = TRUE, line = -2, cex = 1.1)
  dev.off()

  png(file.path(figure_dir, paste0(v, "_boxplot.png")), width = 900, height = 700, res = 140)
  boxplot(x ~ group_labels, col = c("#4E79A7", "#E15759"), ylab = v,
          main = paste("Fraud-group boxplot:", v), outline = TRUE)
  dev.off()
}

effect_table <- do.call(rbind, effect_rows)
effect_table$rank <- rank(-effect_table$separation_score, ties.method = "min")
numeric_table <- merge(do.call(rbind, numeric_rows), effect_table, by = "variable", sort = FALSE)
numeric_table <- numeric_table[order(numeric_table$rank, numeric_table$fraud_group), ]
write.csv(numeric_table, numeric_output, row.names = FALSE, na = "")

cramers_v <- function(x, g) {
  tab <- table(x, g)
  n <- sum(tab)
  if (n == 0L || min(dim(tab)) < 2L) return(NA_real_)
  chi_sq <- suppressWarnings(chisq.test(tab, correct = FALSE)$statistic)
  as.numeric(sqrt(chi_sq / (n * min(nrow(tab) - 1, ncol(tab) - 1))))
}

categorical_rows <- list()
categorical_effects <- list()
for (v in categorical_vars) {
  category <- dat[[v]]
  category[is.na(category)] <- "(Missing)"
  v_value <- cramers_v(category, dat$is_fraud)
  tab <- as.data.frame.matrix(table(category, dat$is_fraud))
  tab$category <- rownames(tab)
  rownames(tab) <- NULL
  names(tab)[names(tab) == "0"] <- "nonfraud_count"
  names(tab)[names(tab) == "1"] <- "fraud_count"
  tab$total_count <- tab$nonfraud_count + tab$fraud_count
  tab$sample_fraud_rate <- tab$fraud_count / tab$total_count
  tab$sparse_flag <- tab$total_count < sparse_threshold
  tab$variable <- v
  tab$cramers_v <- v_value
  tab$sparse_threshold <- sparse_threshold
  categorical_rows[[v]] <- tab[, c(
    "variable", "category", "total_count", "nonfraud_count", "fraud_count",
    "sample_fraud_rate", "sparse_flag", "sparse_threshold", "cramers_v"
  )]
  categorical_effects[[v]] <- data.frame(variable = v, cramers_v = v_value)

  plot_tab <- tab[!tab$sparse_flag, ]
  plot_tab <- plot_tab[order(plot_tab$sample_fraud_rate), ]
  png(file.path(figure_dir, paste0(v, "_fraud_rate.png")), width = 1200,
      height = max(700, 38 * nrow(plot_tab) + 180), res = 140)
  par(mar = c(5, max(8, max(nchar(plot_tab$category)) * 0.55), 4, 2))
  bp <- barplot(plot_tab$sample_fraud_rate, names.arg = plot_tab$category,
                horiz = TRUE, las = 1, col = "#E15759", xlim = c(0, 1),
                xlab = "Sample fraud rate (not population prevalence)",
                main = paste("Category-level sample fraud rates:", v))
  text(plot_tab$sample_fraud_rate, bp, labels = paste0(" n=", plot_tab$total_count),
       pos = 4, cex = 0.75, xpd = TRUE)
  dev.off()
}

categorical_effect_table <- do.call(rbind, categorical_effects)
categorical_effect_table$rank <- rank(-categorical_effect_table$cramers_v, ties.method = "min")
categorical_table <- do.call(rbind, categorical_rows)
categorical_table <- merge(categorical_table, categorical_effect_table[, c("variable", "rank")],
                           by = "variable", sort = FALSE)
categorical_table <- categorical_table[order(categorical_table$rank,
  -categorical_table$total_count, categorical_table$category), ]
write.csv(categorical_table, categorical_output, row.names = FALSE, na = "")

cat("Verified columns:", paste(required_vars, collapse = ", "), "\n")
cat("Fraud counts:", paste(names(fraud_counts), fraud_counts, collapse = "; "), "\n")
cat("Numeric ranking:\n")
print(effect_table[order(effect_table$rank), ], row.names = FALSE)
cat("Categorical ranking:\n")
print(categorical_effect_table[order(categorical_effect_table$rank), ], row.names = FALSE)
