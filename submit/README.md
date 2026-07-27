# Exploratory Fraud Risk Patterns — Code

## Contents

- `Exploratory_Fraud_Risk_Patterns.Rmd` — self-contained source code
- `references.bib` — references used by the IEEE paper
- `data/sample_transactions.csv` — balanced 2,000-row sample

All data preparation, validation, summary, and plotting functions are included
directly in the R Markdown source.

## Required software

- R 4.2 or newer
- Pandoc
- A LaTeX distribution such as TinyTeX

Install the required R packages:

```r
install.packages(c(
  "rmarkdown", "knitr", "rticles", "tidyverse", "ggplot2",
  "scales", "patchwork", "janitor", "kableExtra"
))
```

## Run with the supplied sample

The submitted R Markdown file uses:

`data/sample_transactions.csv`

Open `Exploratory_Fraud_Risk_Patterns.Rmd` in RStudio and click **Knit**.

Alternatively, open a terminal in this folder and run:

### For Windows: 
```powershell
Rscript -e "rmarkdown::render('Exploratory_Fraud_Risk_Patterns.Rmd')"
```

### For macOS and Linux:
```bash
Rscript -e 'rmarkdown::render("Exploratory_Fraud_Risk_Patterns.Rmd")'
```

When the full dataset is not present, the Rmd automatically selects
`data/sample_transactions.csv` and generates a clearly labelled sample
demonstration PDF. The balanced sample verifies that the submitted source code
can read, prepare, summarize, and visualize the data. Its percentages do not
estimate population prevalence or reproduce the final paper's full-data
results.

