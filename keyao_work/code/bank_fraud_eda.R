suppressPackageStartupMessages({
  library(tidyverse)
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(scales)
})

set.seed(123)

data_path <- "data/bank_fraud.csv"
figure_dir <- "figures"
dir.create(figure_dir, showWarnings = FALSE, recursive = TRUE)

bank_fraud <- read_csv(data_path, show_col_types = FALSE)

required_columns <- c(
  "is_fraud", "fraud_type", "transaction_amount", "is_weekend",
  "is_night_transaction", "is_international", "pin_changed_recently",
  "failed_attempts", "payment_method", "merchant_category", "hour_of_day"
)
missing_columns <- setdiff(required_columns, names(bank_fraud))
if (length(missing_columns) > 0) {
  stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
}

fraud_levels <- sort(unique(bank_fraud$is_fraud))
if (!all(c(0, 1) %in% fraud_levels)) {
  stop("The is_fraud column must contain both 0 and 1.")
}

group_sizes <- bank_fraud %>% count(is_fraud)
if (any(group_sizes$n[group_sizes$is_fraud %in% c(0, 1)] < 1000)) {
  stop("At least 1,000 records are required in each fraud class.")
}

sample_bank_fraud <- bank_fraud %>%
  filter(is_fraud %in% c(0, 1)) %>%
  group_by(is_fraud) %>%
  slice_sample(n = 1000) %>%
  ungroup() %>%
  arrange(desc(is_fraud))

write_csv(sample_bank_fraud, "data/sample_bank_fraud.csv")

plot_theme <- theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank(),
    axis.title = element_text(face = "bold")
  )

fraud_colours <- c("Non-fraud" = "#4C78A8", "Fraud" = "#E45756")

fraud_distribution <- bank_fraud %>%
  mutate(fraud_status = if_else(is_fraud == 1, "Fraud", "Non-fraud")) %>%
  count(fraud_status) %>%
  ggplot(aes(x = fraud_status, y = n, fill = fraud_status)) +
  geom_col(width = 0.65, show.legend = FALSE) +
  geom_text(aes(label = comma(n)), vjust = -0.4, size = 4) +
  scale_fill_manual(values = fraud_colours) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.08))) +
  labs(title = "Distribution of Fraudulent and Non-fraudulent Transactions",
       x = "Transaction status", y = "Number of transactions") +
  plot_theme
ggsave(file.path(figure_dir, "fraud_distribution.png"), fraud_distribution,
       width = 7, height = 5, dpi = 300)

fraud_type_distribution <- bank_fraud %>%
  filter(is_fraud == 1, !is.na(fraud_type), fraud_type != "None") %>%
  count(fraud_type, sort = TRUE) %>%
  mutate(fraud_type = forcats::fct_reorder(fraud_type, n)) %>%
  ggplot(aes(x = fraud_type, y = n)) +
  geom_col(fill = "#E45756", width = 0.7) +
  geom_text(aes(label = comma(n)), hjust = -0.1, size = 3.5) +
  coord_flip() +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.12))) +
  labs(title = "Distribution of Fraud Types", x = "Fraud type",
       y = "Number of fraudulent transactions") +
  plot_theme
ggsave(file.path(figure_dir, "fraud_type_distribution.png"), fraud_type_distribution,
       width = 8, height = 5.5, dpi = 300)

amount_skew_ratio <- quantile(bank_fraud$transaction_amount, 0.99, na.rm = TRUE) /
  median(bank_fraud$transaction_amount, na.rm = TRUE)

transaction_amount_by_fraud <- bank_fraud %>%
  mutate(fraud_status = if_else(is_fraud == 1, "Fraud", "Non-fraud")) %>%
  ggplot(aes(x = fraud_status, y = transaction_amount, fill = fraud_status)) +
  geom_boxplot(width = 0.6, outlier.alpha = 0.08, show.legend = FALSE) +
  scale_fill_manual(values = fraud_colours) +
  labs(title = "Transaction Amount by Fraud Status", x = "Transaction status",
       y = "Transaction amount (log scale)") +
  plot_theme
if (is.finite(amount_skew_ratio) && amount_skew_ratio > 10) {
  transaction_amount_by_fraud <- transaction_amount_by_fraud +
    scale_y_log10(labels = label_dollar())
} else {
  transaction_amount_by_fraud <- transaction_amount_by_fraud +
    scale_y_continuous(labels = label_dollar()) +
    labs(y = "Transaction amount")
}
ggsave(file.path(figure_dir, "transaction_amount_by_fraud.png"),
       transaction_amount_by_fraud, width = 7, height = 5, dpi = 300)

binary_feature_rates <- bank_fraud %>%
  select(is_fraud, is_weekend, is_night_transaction, is_international,
         pin_changed_recently) %>%
  pivot_longer(-is_fraud, names_to = "feature", values_to = "value") %>%
  group_by(feature, value) %>%
  summarise(fraud_rate = mean(is_fraud, na.rm = TRUE), n = n(), .groups = "drop") %>%
  mutate(
    feature = recode(feature,
      is_weekend = "Weekend",
      is_night_transaction = "Night transaction",
      is_international = "International",
      pin_changed_recently = "PIN changed recently"
    ),
    value = if_else(value == 1, "Yes", "No")
  )

fraud_rate_binary_features <- ggplot(
  binary_feature_rates, aes(x = feature, y = fraud_rate, fill = value)
) +
  geom_col(position = position_dodge(width = 0.75), width = 0.65) +
  scale_fill_manual(values = c("No" = "#9ECAE1", "Yes" = "#F28E8B"),
                    name = "Feature present") +
  scale_y_continuous(labels = label_percent(accuracy = 0.1)) +
  labs(title = "Fraud Rate by Binary Transaction Features", x = NULL,
       y = "Fraud rate") +
  plot_theme +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))
ggsave(file.path(figure_dir, "fraud_rate_binary_features.png"),
       fraud_rate_binary_features, width = 8, height = 5.5, dpi = 300)

failed_attempt_rates <- bank_fraud %>%
  group_by(failed_attempts) %>%
  summarise(fraud_rate = mean(is_fraud, na.rm = TRUE), n = n(), .groups = "drop")

fraud_rate_by_failed_attempts <- ggplot(
  failed_attempt_rates, aes(x = failed_attempts, y = fraud_rate)
) +
  geom_line(linewidth = 1, colour = "#E45756") +
  geom_point(size = 2.5, colour = "#E45756") +
  scale_x_continuous(breaks = pretty_breaks()) +
  scale_y_continuous(labels = label_percent(accuracy = 0.1)) +
  labs(title = "Fraud Rate by Number of Failed Attempts",
       x = "Number of failed attempts", y = "Fraud rate") +
  plot_theme
ggsave(file.path(figure_dir, "fraud_rate_by_failed_attempts.png"),
       fraud_rate_by_failed_attempts, width = 7, height = 5, dpi = 300)

payment_method_rates <- bank_fraud %>%
  group_by(payment_method) %>%
  summarise(fraud_rate = mean(is_fraud, na.rm = TRUE), n = n(), .groups = "drop") %>%
  arrange(desc(fraud_rate))

fraud_rate_by_payment_method <- payment_method_rates %>%
  mutate(payment_method = forcats::fct_reorder(payment_method, fraud_rate)) %>%
  ggplot(aes(x = payment_method, y = fraud_rate)) +
  geom_col(fill = "#4C78A8", width = 0.7) +
  coord_flip() +
  scale_y_continuous(labels = label_percent(accuracy = 0.1)) +
  labs(title = "Fraud Rate by Payment Method", x = "Payment method",
       y = "Fraud rate") +
  plot_theme
ggsave(file.path(figure_dir, "fraud_rate_by_payment_method.png"),
       fraud_rate_by_payment_method, width = 8, height = 5.5, dpi = 300)

merchant_category_rates <- bank_fraud %>%
  group_by(merchant_category) %>%
  summarise(fraud_rate = mean(is_fraud, na.rm = TRUE), n = n(), .groups = "drop") %>%
  arrange(desc(fraud_rate))

fraud_rate_by_merchant_category <- merchant_category_rates %>%
  mutate(merchant_category = forcats::fct_reorder(merchant_category, fraud_rate)) %>%
  ggplot(aes(x = merchant_category, y = fraud_rate)) +
  geom_col(fill = "#59A14F", width = 0.7) +
  geom_text(aes(label = paste0("n=", comma(n))), hjust = -0.08, size = 3.1) +
  coord_flip() +
  scale_y_continuous(labels = label_percent(accuracy = 0.1),
                     expand = expansion(mult = c(0, 0.18))) +
  labs(title = "Fraud Rate by Merchant Category",
       subtitle = "Categories ranked by fraud rate; labels show transaction counts",
       x = "Merchant category", y = "Fraud rate") +
  plot_theme
ggsave(file.path(figure_dir, "fraud_rate_by_merchant_category.png"),
       fraud_rate_by_merchant_category, width = 8.5, height = 6, dpi = 300)

hourly_rates <- bank_fraud %>%
  group_by(hour_of_day) %>%
  summarise(fraud_rate = mean(is_fraud, na.rm = TRUE), n = n(), .groups = "drop")

fraud_rate_by_hour <- ggplot(hourly_rates, aes(x = hour_of_day, y = fraud_rate)) +
  geom_line(linewidth = 1, colour = "#4C78A8") +
  geom_point(size = 2, colour = "#4C78A8") +
  scale_x_continuous(breaks = seq(0, 23, by = 2)) +
  scale_y_continuous(labels = label_percent(accuracy = 0.1)) +
  labs(title = "Fraud Rate by Hour of Day", x = "Hour of day",
       y = "Fraud rate") +
  plot_theme
ggsave(file.path(figure_dir, "fraud_rate_by_hour.png"), fraud_rate_by_hour,
       width = 8, height = 5, dpi = 300)

cat("\nBANK FRAUD EDA SUMMARY\n")
cat("======================\n")
cat("Rows read:", comma(nrow(bank_fraud)), "\n")
cat("Overall fraud rate:", percent(mean(bank_fraud$is_fraud, na.rm = TRUE), accuracy = 0.01), "\n")
cat("Stratified sample saved: 1,000 fraud + 1,000 non-fraud transactions\n")

cat("\nFraud rate by binary features:\n")
print(binary_feature_rates %>%
  transmute(feature, value, transactions = n,
            fraud_rate = percent(fraud_rate, accuracy = 0.01)))

cat("\nTop merchant categories by fraud rate:\n")
print(merchant_category_rates %>%
  slice_head(n = 10) %>%
  transmute(merchant_category, transactions = n,
            fraud_rate = percent(fraud_rate, accuracy = 0.01)))

cat("\nFraud rate by payment method:\n")
print(payment_method_rates %>%
  transmute(payment_method, transactions = n,
            fraud_rate = percent(fraud_rate, accuracy = 0.01)))
