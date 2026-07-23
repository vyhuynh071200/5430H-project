# Vy's EDA Workspace

`vy_work` is a separate workspace for Vy's exploratory data analysis contribution.
It is designed to complement Kayla's existing EDA rather than duplicate its
transaction-timing and merchant-focused analyses.

## Input dataset

The report is configured to use the existing stratified sample dataset:

`keyao_work/data/sample_bank_fraud.csv`

This dataset is read as an input only; no files inside `keyao_work` are changed.

## Render the report

From the repository root, render the report in R with:

```r
rmarkdown::render("vy_work/EDA_Report.Rmd")
```

## Outputs

Future figures will be saved in `vy_work/figures/`, and future tables will be
saved in `vy_work/tables/`. No figures, tables, or EDA results are created in
this initial workspace setup.
