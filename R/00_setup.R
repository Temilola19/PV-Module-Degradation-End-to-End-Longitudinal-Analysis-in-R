# Shared setup: packages, paths, constants
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(ggplot2)
  library(lme4); library(lmerTest); library(emmeans); library(survival); library(broom)
})
dir.create("data", showWarnings = FALSE); dir.create("results", showWarnings = FALSE)
SEED <- 2026
EOL_THRESHOLD <- 0.82   # end-of-life: 12-month rolling mean performance ratio below this
N_MONTHS <- 60
theme_set(theme_minimal(base_size = 12))
