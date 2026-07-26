# Exploratory Fraud Risk Patterns — Source Code

## Submitted files

- `Exploratory_Fraud_Risk_Patterns.Rmd` — complete IEEE paper and analysis source
- `Sample_Verification_Report.qmd` — runnable sample-data verification report
- `data/sample_transactions.csv` — balanced 2,000-row sample
- `support/helper_functions.R` — reusable preparation and plotting functions
- `support/references.bib` — bibliography used by the paper

The original one-million-row Kaggle dataset is intentionally excluded from the
submission. The assignment requests a small runnable sample rather than the
entire dataset.

## Required software

- R 4.2 or newer
- Quarto
- A LaTeX distribution such as TinyTeX

Install the required R packages:

```r
install.packages(c(
  "rmarkdown", "knitr", "rticles", "tidyverse", "ggplot2",
  "scales", "patchwork", "janitor", "kableExtra"
))
```

## Run the supplied sample

Open a terminal in this folder and run:

```bash
quarto render Sample_Verification_Report.qmd --to pdf
```

Successful execution creates:

```text
Sample_Verification_Report.pdf
```

This report confirms that the submitted code can read, prepare, summarize, and
visualize the supplied data. Because the sample is deliberately balanced, its
percentages are demonstrations only and do not reproduce the population
estimates in the final paper.

## Reproduce the final IEEE paper

The full Kaggle dataset is required to reproduce the final paper's population
counts, fraud rates, confidence intervals, and indicator-accumulation analysis.
Set the full dataset path and render:

```bash
BANK_FRAUD_FULL_DATA="/absolute/path/to/bank_fraud.csv" \
RSTUDIO_PANDOC="/path/to/pandoc/folder" \
Rscript -e 'rmarkdown::render("Exploratory_Fraud_Risk_Patterns.Rmd")'
```

Without the full dataset, use `Sample_Verification_Report.qmd` to verify the
submitted sample workflow.
