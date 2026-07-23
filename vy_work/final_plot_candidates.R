options(stringsAsFactors = FALSE)

input_file <- "vy_work/data/sample_bank_fraud.csv"
output_dir <- "vy_work/figures/final_plot_candidates"
index_file <- "vy_work/tables/final_plot_candidates_index.csv"

continuous_vars <- c(
  "customer_age", "credit_score", "account_age_years", "account_balance",
  "transaction_amount", "num_prev_transactions", "transaction_freq_monthly",
  "distance_from_home_km", "time_since_last_txn_hrs"
)
required_vars <- c(
  continuous_vars, "is_fraud", "transaction_type", "merchant_category",
  "city", "failed_attempts"
)
sparse_threshold <- 20L

d <- read.csv(input_file, check.names = FALSE, na.strings = c("", "NA"))
missing_vars <- setdiff(required_vars, names(d))
if (length(missing_vars)) stop("Missing columns: ", paste(missing_vars, collapse = ", "))
if (!all(d$is_fraud %in% c(0, 1)) || !identical(as.integer(table(d$is_fraud)), c(1000L, 1000L))) {
  stop("Expected is_fraud coded 0/1 with exactly 1,000 observations per group.")
}
if (!all(vapply(d[continuous_vars], is.numeric, logical(1)))) {
  stop("One or more verified continuous variables are not numeric.")
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(index_file), recursive = TRUE, showWarnings = FALSE)

fraud_cols <- c("Non-fraud" = "#4E79A7", "Fraud" = "#E15759")
neutral_col <- "#6B7280"
caption_text <- paste(
  "Balanced sample: 1,000 sampled fraud and 1,000 sampled non-fraud observations;",
  "sample shares do not estimate population prevalence."
)

open_png <- function(filename, width = 10, height = 7) {
  png(file.path(output_dir, filename), width = width, height = height,
      units = "in", res = 300, bg = "white", family = "sans", type = "windows")
}

cramers_v <- function(x, y) {
  tab <- table(x, y)
  chi <- suppressWarnings(chisq.test(tab, correct = FALSE)$statistic)
  sqrt(as.numeric(chi) / (sum(tab) * min(nrow(tab) - 1, ncol(tab) - 1)))
}

wilson <- function(successes, totals, z = qnorm(0.975)) {
  p <- successes / totals
  denom <- 1 + z^2 / totals
  center <- (p + z^2 / (2 * totals)) / denom
  half <- z * sqrt(p * (1 - p) / totals + z^2 / (4 * totals^2)) / denom
  cbind(lower = pmax(0, center - half), upper = pmin(1, center + half))
}

rank_biserial <- function(x, g) {
  x1 <- x[g == 1 & !is.na(x)]
  x0 <- x[g == 0 & !is.na(x)]
  r <- rank(c(x1, x0), ties.method = "average")
  u <- sum(r[seq_along(x1)]) - length(x1) * (length(x1) + 1) / 2
  2 * u / (length(x1) * length(x0)) - 1
}

smd <- function(x, g) {
  x1 <- x[g == 1 & !is.na(x)]
  x0 <- x[g == 0 & !is.na(x)]
  ps <- sqrt(((length(x1) - 1) * var(x1) + (length(x0) - 1) * var(x0)) /
    (length(x1) + length(x0) - 2))
  (mean(x1) - mean(x0)) / ps
}

# 1. Transaction type x fraud mosaic -----------------------------------------
filename <- "01_transaction_type_mosaic.png"
tab <- table(
  factor(d$transaction_type, levels = c("Domestic", "International")),
  factor(d$is_fraud, levels = c(0, 1), labels = c("Non-fraud", "Fraud"))
)
v_transaction <- cramers_v(d$transaction_type, d$is_fraud)
open_png(filename, 10, 7)
par(mar = c(5, 5, 5, 2), xpd = NA)
type_totals <- rowSums(tab)
x_edges <- c(0, cumsum(type_totals / sum(tab)))
plot.new(); plot.window(c(0, 1), c(0, 1))
for (i in seq_len(nrow(tab))) {
  heights <- tab[i, ] / type_totals[i]
  y_edges <- c(0, cumsum(heights))
  for (j in seq_len(ncol(tab))) {
    rect(x_edges[i], y_edges[j], x_edges[i + 1], y_edges[j + 1],
         col = fraud_cols[j], border = "white", lwd = 3)
    text(mean(x_edges[i:(i + 1)]), mean(y_edges[j:(j + 1)]),
         sprintf("%s\nn = %d\n%.1f%% within type", colnames(tab)[j], tab[i, j],
                 100 * tab[i, j] / type_totals[i]),
         col = "white", font = 2, cex = if (i == 1) 0.9 else 0.75)
  }
  text(mean(x_edges[i:(i + 1)]), -0.055,
       sprintf("%s (n = %d)", rownames(tab)[i], type_totals[i]), font = 2)
}
axis(2, at = seq(0, 1, 0.2), labels = paste0(seq(0, 100, 20), "%"), las = 1)
mtext("Within-transaction-type sample composition", side = 2, line = 3.2)
title("Transaction type and sampled fraud-group membership",
      sub = sprintf("Mosaic widths reflect sample counts; Cramér's V = %.3f", v_transaction),
      line = 2.8)
mtext(caption_text, side = 1, line = 3.8, cex = 0.72, col = neutral_col)
dev.off()

# 2. Merchant category by transaction type ----------------------------------
filename <- "02_merchant_category_by_transaction_type.png"
merchant_all <- aggregate(is_fraud ~ merchant_category, d,
                          function(x) c(n = length(x), fraud = sum(x), share = mean(x)))
merchant_order <- merchant_all$merchant_category[order(merchant_all$is_fraud[, "share"])]
type_levels <- c("Domestic", "International")
open_png(filename, 13, 8.5)
par(mfrow = c(1, 2), mar = c(6, 12, 5, 2), oma = c(2.8, 0, 3.2, 0))
for (tt in type_levels) {
  z <- d[d$transaction_type == tt, ]
  a <- aggregate(is_fraud ~ merchant_category, z,
                 function(x) c(n = length(x), fraud = sum(x), share = mean(x)))
  a <- a[match(merchant_order, a$merchant_category), ]
  n <- a$is_fraud[, "n"]; fraud <- a$is_fraud[, "fraud"]; share <- a$is_fraud[, "share"]
  ci <- wilson(fraud, n); sparse <- n < sparse_threshold
  y <- seq_along(merchant_order)
  plot(share, y, xlim = c(0, 1), ylim = c(0.5, length(y) + 0.5), yaxt = "n",
       pch = ifelse(sparse, 17, 19), col = ifelse(sparse, "#F28E2B", fraud_cols["Fraud"]),
       xlab = "Sample fraud share", ylab = "", main = sprintf("%s transactions", tt),
       xaxt = "n")
  axis(1, at = seq(0, 1, 0.2), labels = paste0(seq(0, 100, 20), "%"))
  axis(2, at = y, labels = merchant_order, las = 1, cex.axis = 0.78)
  abline(v = 0.5, lty = 3, col = "#A0A0A0")
  segments(ci[, "lower"], y, ci[, "upper"], y, col = "#555555", lwd = 1.5)
  points(share, y, pch = ifelse(sparse, 17, 19),
         col = ifelse(sparse, "#F28E2B", fraud_cols["Fraud"]), cex = 1.05)
  text(pmin(ci[, "upper"] + 0.025, 0.94), y, labels = paste0("n=", n),
       pos = 4, cex = 0.68, col = neutral_col)
  mtext(sprintf("Cramér's V within %s = %.3f", tolower(tt),
                cramers_v(z$merchant_category, z$is_fraud)), side = 3, line = 0.5, cex = 0.82)
}
mtext("Merchant-category sample fraud shares by transaction type", outer = TRUE,
      side = 3, line = 1.3, font = 2, cex = 1.25)
mtext(paste(caption_text, "Points marked ▲ have n < 20; no categories were aggregated."),
      outer = TRUE, side = 1, line = 1.2, cex = 0.7, col = neutral_col)
dev.off()

# 3. Account balance violin and boxplot --------------------------------------
filename <- "03_account_balance_violin_boxplot.png"
balance_log <- log1p(d$account_balance)
groups <- factor(d$is_fraud, levels = c(0, 1), labels = c("Non-fraud", "Fraud"))
open_png(filename, 9, 7)
par(mar = c(7, 5, 5, 2))
yr <- range(balance_log)
plot(NA, xlim = c(0.4, 2.6), ylim = yr, xaxt = "n",
     xlab = "Sample group", ylab = "log1p(account balance)",
     main = "Account-balance distributions by sampled fraud group")
mtext("Violin width shows density; boxes show median and interquartile range",
      side = 3, line = 0.6, cex = 0.85)
axis(1, at = 1:2, labels = levels(groups))
for (i in 1:2) {
  vals <- balance_log[groups == levels(groups)[i]]
  den <- density(vals, n = 512, from = yr[1], to = yr[2])
  w <- den$y / max(den$y) * 0.36
  polygon(c(i - w, rev(i + w)), c(den$x, rev(den$x)),
          col = adjustcolor(fraud_cols[i], alpha.f = 0.55), border = fraud_cols[i], lwd = 1.4)
  boxplot(vals, at = i, add = TRUE, boxwex = 0.13, outline = FALSE,
          col = "white", border = "#333333", axes = FALSE)
  raw_median <- median(d$account_balance[groups == levels(groups)[i]])
  text(i, yr[1] + 0.04 * diff(yr), sprintf("n = %d\nmedian = $%s",
       length(vals), format(round(raw_median), big.mark = ",")), cex = 0.78, font = 2)
}
mtext("Log transformation used because account balance is strongly right-skewed; medians are shown on the original scale.",
      side = 1, line = 5.2, cex = 0.72, col = neutral_col)
dev.off()

# 4. Pearson and Spearman heatmaps -------------------------------------------
filename <- "04_numeric_correlation_heatmap.png"
verified_continuous <- continuous_vars
labels <- c("Customer\nage", "Credit\nscore", "Account\nage", "Account\nbalance",
            "Transaction\namount", "Previous\ntransactions", "Monthly\nfrequency",
            "Distance\nfrom home", "Time since\nlast txn")
pearson <- cor(d[verified_continuous], use = "pairwise.complete.obs", method = "pearson")
spearman <- cor(d[verified_continuous], use = "pairwise.complete.obs", method = "spearman")
pal <- colorRampPalette(c("#2166AC", "white", "#B2182B"))(201)
draw_heatmap <- function(mat, title_text) {
  n <- nrow(mat)
  image(1:n, 1:n, t(mat[n:1, ]), zlim = c(-1, 1), col = pal, axes = FALSE,
        xlab = "", ylab = "", main = title_text, asp = 1)
  axis(1, at = 1:n, labels = labels, las = 2, cex.axis = 0.63)
  axis(2, at = 1:n, labels = rev(labels), las = 1, cex.axis = 0.63)
  for (i in 1:n) for (j in 1:n) {
    value <- mat[n - j + 1, i]
    text(i, j, sprintf("%.2f", value), cex = 0.58,
         col = if (abs(value) > 0.6) "white" else "#222222")
  }
  box()
}
open_png(filename, 14, 8)
par(oma = c(2.2, 0, 2.2, 0))
layout(matrix(c(1, 2, 3), nrow = 1), widths = c(1, 1, 0.15))
par(mar = c(10, 8, 5, 2)); draw_heatmap(pearson, "Pearson correlations")
par(mar = c(10, 8, 5, 2)); draw_heatmap(spearman, "Spearman correlations")
par(mar = c(10, 0, 5, 2))
image(1, seq(-1, 1, length.out = 201), matrix(seq(-1, 1, length.out = 201), nrow = 1),
      col = pal, zlim = c(-1, 1), axes = FALSE, xlab = "", ylab = "")
axis(4, at = seq(-1, 1, 0.5), las = 1)
mtext("Correlation", side = 4, line = 1.4)
mtext("Continuous-variable correlation structure", outer = TRUE, side = 3,
      line = 0.4, font = 2, cex = 1.25)
mtext("Raw continuous values are shown; rank-based Spearman correlations provide a skew-robust comparison. is_fraud is excluded.",
      outer = TRUE, side = 1, line = 0.5, cex = 0.72, col = neutral_col)
dev.off()

# 5. City sample fraud share -------------------------------------------------
filename <- "05_city_sample_fraud_share.png"
city_tab <- as.data.frame.matrix(table(d$city, d$is_fraud))
city_tab$city <- rownames(city_tab); rownames(city_tab) <- NULL
names(city_tab)[1:2] <- c("nonfraud", "fraud")
city_tab$n <- city_tab$nonfraud + city_tab$fraud
city_tab$share <- city_tab$fraud / city_tab$n
city_tab <- city_tab[order(city_tab$share), ]
city_ci <- wilson(city_tab$fraud, city_tab$n)
city_sparse <- city_tab$n < sparse_threshold
v_city <- cramers_v(d$city, d$is_fraud)
open_png(filename, 10, 8)
par(mar = c(7, 10, 5, 2))
y <- seq_len(nrow(city_tab))
plot(city_tab$share, y, xlim = c(0.25, 0.75), ylim = c(0.5, length(y) + 0.5),
     yaxt = "n", xaxt = "n", pch = ifelse(city_sparse, 17, 19),
     col = ifelse(city_sparse, "#F28E2B", fraud_cols["Fraud"]),
     xlab = "Sample fraud share", ylab = "",
     main = "Sample fraud share by city")
mtext(sprintf("Sorted descriptive comparison; Cramér's V = %.3f", v_city),
      side = 3, line = 0.6, cex = 0.85)
axis(1, at = seq(0.3, 0.7, 0.1), labels = paste0(seq(30, 70, 10), "%"))
axis(2, at = y, labels = city_tab$city, las = 1, cex.axis = 0.82)
abline(v = 0.5, lty = 3, col = "#999999")
segments(city_ci[, "lower"], y, city_ci[, "upper"], y, col = "#555555", lwd = 1.5)
points(city_tab$share, y, pch = ifelse(city_sparse, 17, 19),
       col = ifelse(city_sparse, "#F28E2B", fraud_cols["Fraud"]), cex = 1.1)
text(pmin(city_ci[, "upper"] + 0.012, 0.71), y, paste0("n=", city_tab$n),
     pos = 4, cex = 0.72, col = neutral_col)
mtext(paste(caption_text, sprintf("Sparse threshold: n < %d; no cities were flagged.", sparse_threshold)),
      side = 1, line = 5.3, cex = 0.7, col = neutral_col)
dev.off()

# 6. Failed attempts by fraud ------------------------------------------------
filename <- "06_failed_attempts_by_fraud.png"
attempt_levels <- sort(unique(d$failed_attempts))
attempt_tab <- table(
  factor(d$failed_attempts, levels = attempt_levels),
  factor(d$is_fraud, levels = c(0, 1), labels = c("Non-fraud", "Fraud"))
)
attempt_prop <- prop.table(attempt_tab, margin = 2)
effect_smd <- smd(d$failed_attempts, d$is_fraud)
effect_rb <- rank_biserial(d$failed_attempts, d$is_fraud)
open_png(filename, 10, 7)
par(mar = c(7, 5, 5, 2))
bp <- barplot(t(attempt_prop), beside = TRUE, col = fraud_cols, border = "white",
              ylim = c(0, max(attempt_prop) * 1.18), names.arg = attempt_levels,
              xlab = "Number of failed attempts", ylab = "Within-group sample proportion",
              main = "Discrete failed-attempt distributions by sampled fraud group",
              axes = FALSE)
axis(1, at = colMeans(bp), labels = attempt_levels)
axis(2, at = seq(0, 1, 0.2), labels = paste0(seq(0, 100, 20), "%"), las = 1)
mtext(sprintf("SMD = %.3f; rank-biserial correlation = %.3f", effect_smd, effect_rb),
      side = 3, line = 0.6, cex = 0.85)
for (i in seq_len(nrow(bp))) for (j in seq_len(ncol(bp))) {
  text(bp[i, j], attempt_prop[j, i] + 0.018,
       sprintf("n=%d\n%.1f%%", attempt_tab[j, i], 100 * attempt_prop[j, i]),
       cex = 0.64, col = "#333333")
}
legend("topright", legend = names(fraud_cols), fill = fraud_cols, border = NA, bty = "n")
mtext("Proportions are calculated separately within each 1,000-observation sample group; failed attempts are treated as discrete.",
      side = 1, line = 5.2, cex = 0.72, col = neutral_col)
dev.off()

# Candidate index ------------------------------------------------------------
index <- data.frame(
  figure_number = 1:6,
  filename = c(
    "01_transaction_type_mosaic.png",
    "02_merchant_category_by_transaction_type.png",
    "03_account_balance_violin_boxplot.png",
    "04_numeric_correlation_heatmap.png",
    "05_city_sample_fraud_share.png",
    "06_failed_attempts_by_fraud.png"
  ),
  plot_type = c(
    "Mosaic plot", "Faceted dot-and-interval plot", "Violin with boxplot",
    "Paired correlation heatmaps", "Sorted dot-and-interval plot",
    "Proportional grouped bar chart"
  ),
  variables = c(
    "transaction_type; is_fraud",
    "merchant_category; transaction_type; is_fraud",
    "account_balance; is_fraud",
    paste(continuous_vars, collapse = "; "),
    "city; is_fraud", "failed_attempts; is_fraud"
  ),
  analytical_question = c(
    "Is transaction type associated with sampled fraud-group membership?",
    "Do merchant-category sample differences persist across transaction types?",
    "How do full account-balance distributions differ between sampled groups?",
    "Do continuous variables show strong pairwise relationships or redundancy?",
    "How does sample fraud share vary across cities?",
    "How does the discrete failed-attempt distribution differ between sampled groups?"
  ),
  transformation_or_sampling = c(
    "None; mosaic widths use observed sample counts",
    "Wilson 95% intervals; n < 20 flagged; no aggregation",
    "log1p(account_balance); no sampling",
    "No transformation; Pearson and rank-based Spearman shown; is_fraud excluded",
    "Wilson 95% intervals; cities sorted; n < 20 flagged",
    "Within-group proportions; failed_attempts treated as discrete"
  ),
  statistic_reported = c(
    sprintf("Cramér's V = %.3f", v_transaction),
    "Cramér's V by transaction-type facet; Wilson 95% intervals",
    "Original-scale medians and group sample sizes",
    "Pearson and Spearman correlations",
    sprintf("Cramér's V = %.3f; Wilson 95%% intervals", v_city),
    sprintf("SMD = %.3f; rank-biserial = %.3f", effect_smd, effect_rb)
  ),
  strengths = c(
    "Direct count-based view of the strongest eligible categorical association",
    "Shows whether category patterns persist within domestic and international strata",
    "Displays distribution shape and robust location under strong skew",
    "Concise assessment of redundancy with linear and rank-based measures",
    "Readable ordered geographic comparison with denominators and uncertainty",
    "Honest discrete display of the clearest numeric group separation"
  ),
  limitations = c(
    "Balanced sample proportions are not population prevalence",
    "Balanced sample shares are not population prevalence; two cells have n < 20",
    "Group separation is small and log units are less intuitive than dollars",
    "Pooled balanced-sample correlations may differ from population correlations",
    "Balanced sample shares are not population prevalence; multiple comparisons across cities",
    "Balanced groups do not reflect prevalence; SMD is sensitive to discrete skew"
  ),
  recommended_for_final_report = c("Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
  check.names = FALSE
)
write.csv(index, index_file, row.names = FALSE, na = "")

expected <- file.path(output_dir, index$filename)
if (!all(file.exists(expected)) || any(file.info(expected)$size <= 0)) {
  stop("One or more expected PNG files are missing or empty.")
}
cat("Created six PNG candidates and index file.\n")
cat(paste(basename(expected), file.info(expected)$size, "bytes"), sep = "\n")
