# Standalone Fraud Risk EDA (R)

**Purpose:** Reproducible descriptive summaries and charts for a synthetic transaction dataset.

## Running the analysis

From the repository root, install R packages `readr`, `dplyr`, `ggplot2`, and `scales`, then run:

```bash
Rscript analysis/fraud_risk_eda.R
```

To use a different CSV and output folder:

```bash
Rscript analysis/fraud_risk_eda.R path/to/data.csv output_dir
```

Default input: `submit/data/sample_transactions.csv` (2,000 rows balanced by design).

## Outputs

- `outputs/overall_summary.csv`: source and label counts
- `outputs/risk_by_dimension.csv`: descriptive within-group fraud rates
- `outputs/failed_attempts_fraud_share.png`: one visualization
- `outputs/DATA_PROVENANCE.txt`: data and sampling warnings

## Important limitations

The default sample is deliberately balanced and its fraud share cannot be used as an estimate of actual prevalence. No classifier is fitted and no causal claims are made. The original full synthetic-data academic paper and its reported findings are separate from this sample demonstration.

## Validation status

The script has been reviewed for structure but has not been executed in the connected environment, so chart outputs are not yet verified.
