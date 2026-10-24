# PV Module Degradation: End-to-End Longitudinal Analysis in R

Reproducible R pipeline that curates, models, and validates photovoltaic (PV) performance-ratio data, built to mirror
degradation-science research workflows (longitudinal data, mixed-effects models, time-to-failure analysis).

**Data note:** the data are *simulated* (64 modules, 4 climate zones, 2 technologies, 60 months) so the true
degradation rates are known and the pipeline can be checked against ground truth. Swap in real field data (e.g., public
NREL/DuraMAT datasets) by replacing `data/pv_monthly_raw.csv` with the same columns.

## Run it
```r
# R >= 4.3; packages: dplyr tidyr readr ggplot2 lme4 lmerTest emmeans survival broom MASS
source("run_all.R")   # simulate -> clean/validate -> model -> survival; outputs in results/
```

## Pipeline
| Step | Script | What it does |
|---|---|---|
| 1 | `R/01_simulate_data.R` | Simulates monthly performance ratio with module-level random intercepts/slopes, seasonality, noise, sensor faults, dropouts, duplicate rows |
| 2 | `R/02_clean_validate.R` | Duplicate removal, physical-range checks, robust per-module outlier detection (rlm + 4 MAD), coverage checks, QC scored against injected truth |
| 3 | `R/03_model.R` | Linear mixed-effects models (random intercept vs random slope vs climate/technology interactions), LRT model comparison, degradation rates per group vs truth, out-of-time forecast validation, diagnostics |
| 4 | `R/04_survival.R` | Time-to-end-of-life (12-month rolling mean PR < 82%): Kaplan-Meier curves, Cox model, proportional-hazards test |

## Key results (seed 2026)
- **Data QC:** 3,865 raw rows -> 3,637 analysis rows (94.7% usable); 25 duplicates removed; outlier detection recall 100%, precision 83.7%.
- **Model selection:** random slopes improved fit massively over random intercepts only (LRT chi2 = 913, p < 0.001); climate zone and technology interactions improved it further (chi2 = 59.4, 8 df, p < 1e-9).
- **Degradation rates:** estimated for all 8 zone x technology groups; every estimate within 0.11 percentage points/year of the true rate, 6 of 8 95% CIs cover the truth. Hot-humid multi-Si degrades fastest (about -1.0 pp/yr).
- **Forecasting:** trained on years 0-4, predicted year 5: RMSE 0.66 pp vs 1.93 pp for a seasonal no-trend baseline.
- **Survival:** 51 of 64 modules reached end-of-life; Hot-Humid vs Cold hazard ratio 6.8 (95% CI 2.8-16.6); multi-Si vs mono-PERC HR 1.98 (1.12-3.48); concordance 0.69; PH assumption not rejected (global p = 0.33).

## Limitations
Simulated data; asymptotic CIs from a small number of modules per group (8) are somewhat optimistic; the Cox model treats the rolling-mean EOL threshold as the event definition.
