# Experimental EDA plots. This script writes only to the authorized experiment paths.

options(stringsAsFactors = FALSE, scipen = 999)

full_candidates <- c(
  "final_submission/code/Exploratory_Fraud_Risk_Patterns_Code/data/transactions.csv",
  "bank_fraud.csv"
)
sample_candidates <- c(
  "final_submission/code/Exploratory_Fraud_Risk_Patterns_Code/data/sample_transactions.csv",
  "keyao_work/data/sample_bank_fraud.csv"
)

inspect_candidate <- function(path) {
  if (!file.exists(path)) return(NULL)
  d <- read.csv(path, check.names = FALSE)
  required <- c("is_fraud", "failed_attempts", "hour_of_day", "merchant_category",
                "is_international", "account_balance")
  list(path = path, data = d, valid = all(required %in% names(d)),
       n = nrow(d), p = ncol(d), classes = table(d$is_fraud))
}

full_info <- lapply(full_candidates, inspect_candidate)
full_info <- Filter(function(x) !is.null(x) && x$valid && x$n > 100000 &&
                      all(c("0", "1") %in% names(x$classes)), full_info)
sample_info <- lapply(sample_candidates, inspect_candidate)
sample_info <- Filter(function(x) !is.null(x) && x$valid && x$n == 2000 &&
                        identical(as.integer(x$classes[c("0", "1")]), c(1000L, 1000L)),
                      sample_info)
if (!length(full_info)) stop("No verified full transaction dataset found.")
if (!length(sample_info)) stop("No verified balanced 1,000/1,000 sample found.")

full_pick <- full_info[[which.max(vapply(full_info, `[[`, numeric(1), "n"))]]
sample_pick <- sample_info[[1]]
full <- full_pick$data
sample_data <- sample_pick$data

cat("Selected full dataset:", normalizePath(full_pick$path, winslash = "/"), "\n")
cat("Full dimensions:", nrow(full), "x", ncol(full),
    "| class distribution:", paste(names(table(full$is_fraud)), table(full$is_fraud), collapse = ", "), "\n")
cat("Selected balanced sample:", normalizePath(sample_pick$path, winslash = "/"), "\n")
cat("Sample dimensions:", nrow(sample_data), "x", ncol(sample_data),
    "| class distribution:", paste(names(table(sample_data$is_fraud)), table(sample_data$is_fraud), collapse = ", "), "\n")
cat("Packages used: base R stats, graphics, grDevices, utils\n")

out_dir <- "vy_work/figures/plot_experiments"
index_path <- "vy_work/tables/plot_experiments_index.csv"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

blue <- "#4C78A8"
red <- "#E45756"
navy <- "#17324D"
grey <- "#6B7280"
light_grey <- "#E5E7EB"
dark <- "#25313C"
sparse_threshold <- 100L

png_open <- function(filename, width, height) {
  png(file.path(out_dir, filename), width = width, height = height,
      units = "in", res = 300, bg = "white", type = "cairo")
  par(family = "sans", fg = dark, col.axis = dark, col.lab = dark,
      col.main = dark, las = 1)
}

wald_rate <- function(y, n) {
  p <- y / n
  se <- sqrt(p * (1 - p) / n)
  cbind(rate = p, lower = pmax(0, p - 1.96 * se), upper = pmin(1, p + 1.96 * se))
}

binary_specs <- list(
  c("Night vs Day", "is_night_transaction", "1", "0", "Night", "Day"),
  c("PIN Changed vs No PIN Change", "pin_changed_recently", "1", "0", "PIN Changed", "No PIN Change"),
  c("Weekend vs Weekday", "is_weekend", "1", "0", "Weekend", "Weekday"),
  c("International vs Domestic", "is_international", "1", "0", "International", "Domestic")
)

binary_effects <- do.call(rbind, lapply(binary_specs, function(s) {
  x <- full[[s[2]]]
  keep <- !is.na(x) & !is.na(full$is_fraud) & as.character(x) %in% c(s[3], s[4])
  y1 <- sum(full$is_fraud[keep & as.character(x) == s[3]] == 1)
  n1 <- sum(keep & as.character(x) == s[3])
  y0 <- sum(full$is_fraud[keep & as.character(x) == s[4]] == 1)
  n0 <- sum(keep & as.character(x) == s[4])
  p1 <- y1 / n1; p0 <- y0 / n0
  diff <- p1 - p0
  se_diff <- sqrt(p1 * (1 - p1) / n1 + p0 * (1 - p0) / n0)
  rr <- p1 / p0
  se_log_rr <- sqrt(1 / y1 - 1 / n1 + 1 / y0 - 1 / n0)
  data.frame(comparison = s[1], comparison_label = s[5], reference_label = s[6],
             n_comparison = n1, n_reference = n0, rate_comparison = p1,
             rate_reference = p0, difference = diff,
             diff_lower = diff - 1.96 * se_diff, diff_upper = diff + 1.96 * se_diff,
             risk_ratio = rr, rr_lower = exp(log(rr) - 1.96 * se_log_rr),
             rr_upper = exp(log(rr) + 1.96 * se_log_rr))
}))
binary_effects <- binary_effects[order(binary_effects$difference), ]

png_open("01_binary_characteristic_effect_plot.png", 7.2, 4.3)
par(mar = c(5.4, 10.8, 2.8, 1.0))
ylim <- seq_len(nrow(binary_effects))
xr <- range(c(binary_effects$diff_lower, binary_effects$diff_upper)) * 100
plot(binary_effects$difference * 100, ylim, xlim = xr + c(-0.4, 0.4),
     ylim = c(0.5, 4.5), yaxt = "n", pch = 19, col = red, cex = 1.05,
     xlab = "Fraud-rate difference (percentage points)", ylab = "", main = "Binary-characteristic fraud-rate differences")
abline(v = 0, lty = 2, col = grey)
segments(binary_effects$diff_lower * 100, ylim, binary_effects$diff_upper * 100, ylim,
         col = red, lwd = 2)
labels <- sprintf("%s\n%.2f%% n=%s  |  %.2f%% n=%s", binary_effects$comparison,
                  binary_effects$rate_comparison * 100, format(binary_effects$n_comparison, big.mark = ","),
                  binary_effects$rate_reference * 100, format(binary_effects$n_reference, big.mark = ","))
axis(2, at = ylim, labels = labels, las = 1, tick = FALSE, cex.axis = 0.66, line = -0.4)
mtext("Full-data descriptive differences; bars are approximate 95% confidence intervals.", side = 1, line = 4.0, cex = 0.64, col = grey)
dev.off()

png_open("01b_binary_characteristic_risk_ratio.png", 7.2, 4.3)
par(mar = c(5.4, 10.8, 2.8, 1.0))
xr <- range(c(binary_effects$rr_lower, binary_effects$rr_upper))
plot(binary_effects$risk_ratio, ylim, log = "x", xlim = xr * c(0.96, 1.04),
     ylim = c(0.5, 4.5), yaxt = "n", pch = 19, col = blue, cex = 1.05,
     xlab = "Risk ratio (log scale)", ylab = "", main = "Binary-characteristic fraud risk ratios")
abline(v = 1, lty = 2, col = grey)
segments(binary_effects$rr_lower, ylim, binary_effects$rr_upper, ylim, col = blue, lwd = 2)
axis(2, at = ylim, labels = labels, las = 1, tick = FALSE, cex.axis = 0.66, line = -0.4)
mtext("Full-data descriptive ratios; bars are approximate 95% confidence intervals.", side = 1, line = 4.0, cex = 0.64, col = grey)
dev.off()

failed_tab <- aggregate(is_fraud ~ failed_attempts, full, function(z) c(n = length(z), fraud = sum(z == 1)))
failed <- data.frame(failed_attempts = failed_tab$failed_attempts,
                     n = failed_tab$is_fraud[, "n"], fraud = failed_tab$is_fraud[, "fraud"])
failed <- cbind(failed, wald_rate(failed$fraud, failed$n))

png_open("02_failed_attempts_fraud_rate.png", 7.0, 4.4)
par(mar = c(6.0, 5.4, 2.8, 1.2))
plot(failed$failed_attempts, failed$rate, type = "o", pch = 19, lwd = 1.5,
     col = red, ylim = c(0, max(failed$upper) * 1.22), xlim = c(-0.15, 5.15),
     xaxt = "n", yaxt = "n",
     xlab = "Failed attempts (discrete)", ylab = "Full-data fraud rate",
     main = "Fraud rate by failed attempts")
axis(1, at = failed$failed_attempts)
axis(2, at = pretty(c(0, max(failed$upper))), labels = paste0(round(pretty(c(0, max(failed$upper))) * 100), "%"))
segments(failed$failed_attempts, failed$lower, failed$failed_attempts, failed$upper, col = red, lwd = 1.5)
arrows(failed$failed_attempts, failed$lower, failed$failed_attempts, failed$upper,
       angle = 90, code = 3, length = 0.035, col = red)
text(failed$failed_attempts, failed$upper + max(failed$upper) * 0.055,
     labels = paste0("n=", format(failed$n, big.mark = ",")), cex = 0.65, col = grey)
mtext("Points are full-data rates; intervals are approximate 95% binomial intervals.", side = 1, line = 4.5, cex = 0.64, col = grey)
dev.off()

full$transaction_type <- ifelse(full$is_international == 1, "International", "Domestic")
mh <- aggregate(is_fraud ~ merchant_category + hour_of_day + transaction_type, full,
                function(z) c(n = length(z), fraud = sum(z == 1), rate = mean(z == 1)))
mh <- data.frame(mh[1:3], n = mh$is_fraud[, "n"], fraud = mh$is_fraud[, "fraud"], rate = mh$is_fraud[, "rate"])
merchants <- sort(unique(mh$merchant_category))
hours <- sort(unique(mh$hour_of_day))
make_matrix <- function(type, value) {
  z <- mh[mh$transaction_type == type, ]
  out <- matrix(NA_real_, nrow = length(merchants), ncol = length(hours), dimnames = list(merchants, hours))
  out[cbind(match(z$merchant_category, merchants), match(z$hour_of_day, hours))] <- z[[value]]
  out
}
dom_rate <- make_matrix("Domestic", "rate"); int_rate <- make_matrix("International", "rate")
dom_n <- make_matrix("Domestic", "n"); int_n <- make_matrix("International", "n")
diff_rate <- int_rate - dom_rate
rate_limits <- range(c(dom_rate, int_rate), na.rm = TRUE)
diff_limit <- max(abs(diff_rate), na.rm = TRUE)
rate_cols <- colorRampPalette(c(navy, "#DCEAF4", red))(100)
diff_cols <- colorRampPalette(c(blue, "white", red))(101)

draw_heat <- function(z, counts, title, cols, limits, show_y = TRUE, difference = FALSE) {
  nr <- nrow(z); nc <- ncol(z)
  image(x = seq_len(nc), y = seq_len(nr), z = t(z), col = cols, zlim = limits,
        axes = FALSE, xlab = "Hour of day", ylab = "", main = title, useRaster = TRUE)
  axis(1, at = seq(1, nc, 3), labels = hours[seq(1, nc, 3)], cex.axis = 0.72)
  if (show_y) axis(2, at = seq_len(nr), labels = merchants, las = 1, cex.axis = 0.62, tick = FALSE)
  sparse <- which(counts < sparse_threshold, arr.ind = TRUE)
  if (nrow(sparse)) points(sparse[, 2], sparse[, 1], pch = 4, cex = 0.45, col = "#555555")
  box(col = light_grey)
}

png_open("03_merchant_hour_interaction_heatmaps.png", 7.2, 8.5)
layout(matrix(1:3, ncol = 1), heights = c(1, 1, 1))
par(mar = c(5.2, 8.8, 2.4, 1.0))
draw_heat(dom_rate, dom_n, "A. Domestic full-data fraud rate", rate_cols, rate_limits)
draw_heat(int_rate, int_n, "B. International full-data fraud rate", rate_cols, rate_limits)
draw_heat(diff_rate, pmin(dom_n, int_n), "C. International minus domestic difference", diff_cols,
          c(-diff_limit, diff_limit), difference = TRUE)
mtext(sprintf("Common scale for A/B: %.1f%% to %.1f%%. C uses a zero-centred diverging scale. × marks cells with n < %d in either group.",
              rate_limits[1] * 100, rate_limits[2] * 100, sparse_threshold),
      side = 1, line = 4.0, cex = 0.56, col = grey)
dev.off()

png_open("03b_merchant_hour_difference_heatmap.png", 7.2, 4.8)
par(mar = c(6.0, 9.0, 2.8, 1.0))
draw_heat(diff_rate, pmin(dom_n, int_n), "International minus domestic fraud-rate difference",
          diff_cols, c(-diff_limit, diff_limit), difference = TRUE)
mtext(sprintf("Descriptive percentage-point interaction pattern; × marks cells with n < %d in either group.", sparse_threshold),
      side = 1, line = 4.4, cex = 0.62, col = grey)
dev.off()

sample_data$fraud_group <- factor(ifelse(sample_data$is_fraud == 1, "Fraud", "Non-fraud"),
                                  levels = c("Non-fraud", "Fraud"))
set.seed(5430)
jitter_rows <- unlist(lapply(split(seq_len(nrow(sample_data)), sample_data$fraud_group),
                             function(i) sample(i, min(200, length(i)))))
jitter_data <- sample_data[jitter_rows, ]

png_open("04_account_balance_raincloud.png", 7.0, 4.5)
par(mar = c(6.4, 4.8, 2.8, 1.0))
vals <- split(log1p(sample_data$account_balance), sample_data$fraud_group)
yr <- range(unlist(vals), finite = TRUE)
plot(NA, xlim = c(0.55, 2.65), ylim = yr, xaxt = "n",
     xlab = "Balanced-sample group", ylab = "log1p(account balance)",
     main = "Balanced-sample account-balance distributions")
cols <- c(blue, red)
set.seed(5430)
for (i in 1:2) {
  den <- density(vals[[i]], na.rm = TRUE)
  width <- den$y / max(den$y) * 0.32
  polygon(c(rep(i, length(den$x)), i + width), c(den$x, rev(den$x)),
          col = adjustcolor(cols[i], alpha.f = 0.42), border = cols[i])
  v <- jitter_data$account_balance[jitter_data$fraud_group == levels(sample_data$fraud_group)[i]]
  points(jitter(rep(i - 0.18, length(v)), amount = 0.07), log1p(v), pch = 16,
         cex = 0.42, col = adjustcolor(cols[i], alpha.f = 0.28))
  boxplot(vals[[i]], at = i, add = TRUE, widths = 0.13, outline = FALSE,
          col = "white", border = dark, axes = FALSE)
  raw <- sample_data$account_balance[sample_data$fraud_group == levels(sample_data$fraud_group)[i]]
  text(i, yr[1] + 0.03 * diff(yr),
       sprintf("median=$%s\nn=%s", format(round(median(raw, na.rm = TRUE)), big.mark = ","),
               format(sum(!is.na(raw)), big.mark = ",")), cex = 0.7, pos = 3)
}
axis(1, at = 1:2, labels = levels(sample_data$fraud_group))
mtext("Density and boxplots use all 2,000 records; jitter shows a seeded 200-per-group subsample.", side = 1, line = 4.8, cex = 0.62, col = grey)
dev.off()

ctx <- aggregate(is_fraud ~ failed_attempts + transaction_type, full,
                 function(z) c(n = length(z), fraud = sum(z == 1)))
ctx <- data.frame(ctx[1:2], n = ctx$is_fraud[, "n"], fraud = ctx$is_fraud[, "fraud"])
ctx <- cbind(ctx, wald_rate(ctx$fraud, ctx$n))

png_open("05_failed_attempts_by_transaction_context.png", 7.2, 4.5)
par(mfrow = c(1, 2), mar = c(5.3, 5.2, 2.7, 0.8), oma = c(1.5, 0, 0, 0))
common_ylim <- c(0, max(ctx$upper) * 1.17)
for (type in c("Domestic", "International")) {
  z <- ctx[ctx$transaction_type == type, ]
  col <- if (type == "Domestic") blue else red
  plot(z$failed_attempts, z$rate, type = "o", pch = 19, lwd = 1.4, col = col,
       ylim = common_ylim, xlim = c(-0.2, 5.2), xaxt = "n", yaxt = "n",
       xlab = "Failed attempts", ylab = "Full-data fraud rate",
       main = type)
  axis(1, at = z$failed_attempts)
  axis(2, at = pretty(common_ylim), labels = paste0(round(pretty(common_ylim) * 100), "%"))
  arrows(z$failed_attempts, z$lower, z$failed_attempts, z$upper, angle = 90,
         code = 3, length = 0.03, col = col)
  label_x <- pmin(pmax(z$failed_attempts, 0.28), 4.72)
  label_y <- z$upper + rep(c(0.018, 0.038), length.out = nrow(z)) * diff(common_ylim)
  text(label_x, label_y,
       ifelse(z$n < sparse_threshold, paste0("n=", z$n, "*"), paste0("n=", format(z$n, big.mark = ","))),
       cex = 0.45, col = grey)
}
mtext(sprintf("Approximate 95%% intervals; * denotes n < %d. Day/night omitted to preserve readability.", sparse_threshold),
      side = 1, outer = TRUE, line = 0.1, cex = 0.64, col = grey)
dev.off()

top_effect <- binary_effects$comparison[which.max(binary_effects$difference)]
merchant_average <- aggregate(rate ~ merchant_category + transaction_type, mh,
                              function(x) mean(x, na.rm = TRUE))
index <- data.frame(
  figure_id = c("01", "01b", "02", "03", "03b", "04", "05"),
  filename = c("01_binary_characteristic_effect_plot.png", "01b_binary_characteristic_risk_ratio.png",
               "02_failed_attempts_fraud_rate.png", "03_merchant_hour_interaction_heatmaps.png",
               "03b_merchant_hour_difference_heatmap.png", "04_account_balance_raincloud.png",
               "05_failed_attempts_by_transaction_context.png"),
  plot_type = c("Forest-style rate-difference plot", "Log-scale risk-ratio forest plot",
                "Discrete point-range plot", "Three aligned heatmaps", "Diverging heatmap",
                "Raincloud-style violin/box/jitter plot", "Faceted discrete point-range plot"),
  dataset_used = c(rep(normalizePath(full_pick$path, winslash = "/"), 5),
                   normalizePath(sample_pick$path, winslash = "/"), normalizePath(full_pick$path, winslash = "/")),
  variables = c("is_fraud; is_night_transaction; pin_changed_recently; is_weekend; is_international",
                "is_fraud; is_night_transaction; pin_changed_recently; is_weekend; is_international",
                "is_fraud; failed_attempts", "is_fraud; merchant_category; hour_of_day; is_international",
                "is_fraud; merchant_category; hour_of_day; is_international", "is_fraud; account_balance",
                "is_fraud; failed_attempts; is_international"),
  transformation = c("Absolute rate difference in percentage points", "Log x-axis",
                     "Failed attempts treated as discrete", "Aligned matrices; shared A/B scale; zero-centred C scale",
                     "International minus domestic rate", "log1p(account_balance); seeded 200/group jitter sample",
                     "Failed attempts discrete; panels by transaction type"),
  statistical_measure = c("Rate difference with approximate 95% CI", "Risk ratio with approximate 95% CI",
                          "Fraud rate with approximate 95% binomial CI", "Cell fraud rates and rate differences; cell n",
                          "Cell fraud-rate difference; cell n", "Median, density, IQR, group n",
                          "Fraud rate with approximate 95% binomial CI; cell n"),
  analytical_question = c("Which binary contexts have the largest descriptive fraud-rate separation?",
                          "How large are relative fraud-rate differences across binary contexts?",
                          "How does full-data fraud rate vary across discrete failed-attempt counts?",
                          "How do merchant-hour patterns differ between domestic and international transactions?",
                          "Where are international-domestic rate differences concentrated?",
                          "How do balanced-sample account-balance distribution shapes differ?",
                          "Does the failed-attempt pattern differ by domestic/international context?"),
  main_observed_pattern = c(paste(top_effect, "has the largest positive absolute separation."),
                            paste(top_effect, "has the largest relative separation."),
                            "Rates are much higher from two failed attempts onward than at zero or one.",
                            "Merchant-hour levels vary by transaction type; sparse cells are explicitly marked.",
                            "The sign and size of international-domestic differences vary across merchant-hour cells.",
                            "Fraud balance is somewhat higher in the sample, with substantial distribution overlap.",
                            "Repeated failed attempts are associated with higher rates in both transaction contexts."),
  strengths = c("Direct effect sizes; uncertainty; full group sizes", "Relative effect sizes; uncertainty",
                "Uses full data; discrete encoding; uncertainty", "Displays a three-way interaction on aligned scales",
                "Focused view of interaction differences", "Shows density, median, IQR, and individual observations",
                "Shows effect consistency and uncertainty by context"),
  limitations = c("Wald intervals; descriptive only", "Wald log intervals; descriptive only",
                  "Unadjusted rates", sprintf("Many comparisons; cells below n=%d marked sparse", sparse_threshold),
                  sprintf("Many comparisons; cells below n=%d marked sparse", sparse_threshold),
                  "Balanced sample cannot estimate prevalence", "Unadjusted rates; annotations add density"),
  readable_in_ieee_two_column = c("Yes", "Yes", "Yes", "Best as two-column width", "Yes at two-column width", "Yes", "Yes"),
  recommended_to_replace_current_figure = c("Yes", "Alternative to 01", "Yes", "Possibly", "Exploratory companion", "Possibly", "Exploratory only"),
  current_figure_it_could_replace = c("Binary Transaction Characteristics", "Binary Transaction Characteristics",
                                      "Authentication-Related Patterns", "Merchant and Time-Based Patterns",
                                      "Merchant and Time-Based Patterns", "Account Balance", "Authentication-Related Patterns")
)
write.csv(index, index_path, row.names = FALSE, na = "")

cat("\nCreated figures:\n", paste(file.path(out_dir, index$filename), collapse = "\n"), "\n", sep = "")
cat("Created index:", normalizePath(index_path, winslash = "/"), "\n")
cat("Sparse-cell threshold:", sparse_threshold, "transactions per plotted cell/group.\n")
