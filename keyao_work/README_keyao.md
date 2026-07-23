# Keyao's Bank Fraud Analysis Work

This folder contains Keyao's contribution to the bank transaction fraud data
visualization project:

- R scripts for data preparation, data inspection, and exploratory analysis
- a small stratified sample dataset for code submission
- selected overview, bivariate, and multivariate figures
- the integrated R Markdown analysis report and rendered PDF
- CSV summary tables used for reproducibility

## Data

`data/sample_bank_fraud.csv` is a small stratified sample containing 1,000
fraudulent and 1,000 non-fraudulent transactions. It is included so the
repository contains a manageable example dataset.

The full raw Kaggle dataset, `bank_fraud.csv`, and the generated full prepared
dataset, `bank_fraud_prepared.csv`, are not included because they are too large
for this repository. To reproduce the full analysis, obtain the original
Kaggle dataset separately and place it locally at `data/bank_fraud.csv`.

## Required R packages

The analysis uses:

- `tidyverse`
- `readr`
- `dplyr`
- `ggplot2`
- `scales`
- `knitr`
- `rmarkdown`
- `kableExtra`
- `patchwork`

Install missing packages in R with:

```r
install.packages(c(
  "tidyverse", "readr", "dplyr", "ggplot2", "scales",
  "knitr", "rmarkdown", "kableExtra", "patchwork"
))
```

PDF rendering also requires Pandoc and a LaTeX engine such as XeLaTeX. RStudio
normally supplies Pandoc. TinyTeX can provide the LaTeX toolchain:

```r
install.packages("tinytex")
tinytex::install_tinytex()
```

## Running the analysis

Run commands from the `keyao_work/` directory after placing the full raw
dataset at `data/bank_fraud.csv`.

Prepare the data:

```bash
Rscript code/01_data_preparation.R
```

Run the exploratory scripts:

```bash
Rscript code/check_data.R
Rscript code/bank_fraud_eda.R
```

Render the integrated report from R:

```r
rmarkdown::render("paper/Project_Report.Rmd")
```

The scripts save prepared/sample data under `data/`, reusable PNG figures under
`figures/`, and report summaries under `paper/summaries/`.
