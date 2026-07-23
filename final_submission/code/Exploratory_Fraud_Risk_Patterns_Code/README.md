# AMOD 5430 Fraud Visualization Project - Code Submission

The primary paper source is `Exploratory_Fraud_Risk_Patterns.Rmd`. It reads transaction CSV
data, prepares variables, calculates summaries and fraud rates, and generates
all paper figures with R code. No pre-made PNG is included in the paper body.

`Exploratory_Fraud_Risk_Patterns.Rmd` is the main source-code file. It contains the paper text,
analysis steps, table code, and figure-generation code. The supporting file
`src/helper_functions.R` contains reusable data-preparation and plotting
functions sourced by the Rmd. Both files are source code and are required.

The paper currently generates seven figures in a narrative sequence: class
imbalance, transaction-type sample composition, selected binary fraud rates,
failed-attempt distributions, account-balance distributions, city-level sample
shares, and an hour-by-merchant heatmap. The former fraud-type overview panel
(Fig. 1-B) and transaction-type panel inside the binary-characteristics figure
(Fig. 2-B) were removed. Transaction type is now presented separately as a
code-generated mosaic plot.

## Project structure

```text
Exploratory_Fraud_Risk_Patterns_Code/
├── Exploratory_Fraud_Risk_Patterns.Rmd
├── references.bib
├── data/
│   └── sample_transactions.csv
├── src/
│   └── helper_functions.R
└── README.md
```

## Data selection

The submitted ZIP intentionally contains only
`data/sample_transactions.csv` (2,000 rows: 1,000 fraud and 1,000 non-fraud).
This satisfies the requirement to provide a small runnable data sample without
submitting the full dataset.

The paper first looks for an optional `data/transactions.csv`.

- If it exists, the full dataset is used for descriptive summaries,
  fraud-rate calculations, and the main figures.
- If it does not exist, the paper falls back to
  `data/sample_transactions.csv` and prints a prominent warning.
- The balanced sample is for code demonstration and within-group visual
  comparison only. It must not be used to estimate population prevalence.

The full CSV is deliberately excluded from the code ZIP. To reproduce the
full-data values exactly, place the original file at
`data/transactions.csv`; otherwise the Rmd remains runnable with the included
sample and produces demonstration results.

## Required R packages

```r
install.packages(c(
  "tidyverse", "ggplot2", "scales", "patchwork", "janitor",
  "knitr", "kableExtra", "rticles", "rmarkdown"
))
```

## PDF toolchain

PDF rendering requires Pandoc and a LaTeX installation containing IEEEtran.
RStudio normally supplies Pandoc. TinyTeX can provide LaTeX:

```r
install.packages("tinytex")
tinytex::install_tinytex()
```

## Render from RStudio

1. Open `Exploratory_Fraud_Risk_Patterns.Rmd` in RStudio.
2. Select **Knit > Knit to PDF**.

## Render from R

From the extracted code folder:

```r
rmarkdown::render("Exploratory_Fraud_Risk_Patterns.Rmd")
```

The expected output is `Exploratory_Fraud_Risk_Patterns.pdf`.

Most figures are ordinary one-column IEEE figures and therefore stay near their
corresponding Results subsection. Only the merchant-by-hour heatmap uses a
two-column `figure*`; LaTeX places that wide figure at the top of the next
available page, which is standard IEEE behavior.

## Final checks

- Add the verified Kaggle dataset citation.
- Confirm author affiliations.
- Confirm that the body remains within eight IEEE pages, excluding references.
- Check figure labels at the final two-column PDF size.
