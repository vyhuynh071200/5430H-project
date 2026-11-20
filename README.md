# Exploratory Fraud Risk Patterns — R Data Analysis

**Focus:** Exploratory data analysis of synthetic bank-transaction data to investigate which transaction characteristics show associations with fraud.

## Why this project matters
Fraud is a minority outcome. Comparing raw fraud counts can be misleading when transaction volumes differ across groups. This project uses rate-based comparisons and data visualizations to identify potential indicators for further investigation — **not** to claim a deployed fraud-detection model.

## Analysis workflow
1. Load and validate transaction fields.
2. Prepare variables and check missingness and class composition.
3. Compare fraud rates by transaction context, timing, account behavior, and authentication signals.
4. Generate plots and discuss limitations, class imbalance, and practical interpretation.

**Tools:** R, R Markdown, dplyr/tidyverse, ggplot2, knitr, patchwork and related packages.

## Findings from the full synthetic-data analysis
The project's R Markdown report states that **5.53%** of transactions in the full synthetic dataset were labelled fraudulent. The strongest visible exploratory associations included:
- repeated failed authentication attempts;
- night / early-morning timing;
- international transaction status;
- recent PIN changes;
- merchant category.

Weekend status and account balance showed weaker visual separation. These are **observational, dataset-specific associations**, not independently validated predictive factors or evidence of causation.

## Reproducibility: an important distinction
- **[Source R Markdown](./submit/Exploratory_Fraud_Risk_Patterns.Rmd)**
- **[Sample data and run instructions](./submit/README.md)**
- **[Rendered analysis report](./submit/Exploratory_Fraud_Risk_Patterns.pdf)**

The shared `submit/data/sample_transactions.csv` contains a deliberately **balanced 2,000-row sample** for testing the workflow. Its class proportions are **not** representative of the full dataset, so sample-derived plots must not be used to estimate real fraud prevalence or reproduce the full report's results.

For a local demonstration:
1. Install R, R Markdown, required packages, Pandoc and a LaTeX distribution.
2. Open the [`submit` directory](./submit/) as the working directory.
3. Render `Exploratory_Fraud_Risk_Patterns.Rmd` (for example, using the instructions in `submit/README.md`).
4. The analysis selects the sample demonstration mode if the full dataset is absent.

The full dataset is not bundled as the default sample; the code can take a full dataset path from the `BANK_FRAUD_FULL_DATA` environment variable.

## Limitations
- The underlying data are **synthetic**, so findings should not be generalized directly to real bank customers.
- This is EDA and descriptive interpretation, not a trained or independently evaluated fraud classifier.
- The sample is intentionally balanced and is unsuitable for prevalence estimates.
- Additional independent validation would be needed before operational recommendations.

---
*Research and reproducible exploratory-analysis project by Vy Huynh.*
