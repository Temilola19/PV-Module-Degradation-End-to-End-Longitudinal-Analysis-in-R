# Data curation: range checks, duplicate removal, robust outlier flagging, coverage checks.
source("R/00_setup.R")
raw <- read_csv("data/pv_monthly_raw.csv", show_col_types = FALSE)
log <- list()
log$rows_raw <- nrow(raw)
log$duplicates_removed <- sum(duplicated(raw[c("module_id", "date")]))
d <- distinct(raw, module_id, date, .keep_all = TRUE)
log$missing_pr <- sum(is.na(d$pr))

d <- d |>
  mutate(time_yr = as.numeric(date - as.Date("2019-01-01")) / 365.25,
         s = sin(2 * pi * time_yr), c = cos(2 * pi * time_yr),
         range_flag = !is.na(pr) & (pr <= 0.5 | pr >= 1.15))
log$out_of_physical_range <- sum(d$range_flag)

# Robust per-module outlier detection: residuals from robust trend+season fit, flag > 4 MAD
d <- d |> group_by(module_id) |> group_modify(~{
  ok <- !is.na(.x$pr) & !.x$range_flag
  fit <- MASS::rlm(pr ~ time_yr + s + c, data = .x[ok, ], maxit = 50)
  r <- rep(NA_real_, nrow(.x)); r[ok] <- resid(fit)
  .x$mad_flag <- !is.na(r) & abs(r) > 4 * mad(r, na.rm = TRUE)
  .x
}) |> ungroup()
d <- mutate(d, outlier = range_flag | mad_flag)
log$outliers_flagged <- sum(d$outlier)

# Validate QC against injected truth
truth <- read_csv("data/truth_faults.csv", show_col_types = FALSE) |> distinct(module_id, date, .keep_all = TRUE)
chk <- left_join(d, truth, by = c("module_id", "date")) |> filter(!is.na(pr))
tp <- sum(chk$outlier & chk$fault); fp <- sum(chk$outlier & !chk$fault); fn <- sum(!chk$outlier & chk$fault)
log$qc_precision <- round(tp / (tp + fp), 3); log$qc_recall <- round(tp / (tp + fn), 3)

curated <- d |> mutate(pr_clean = ifelse(outlier, NA_real_, pr)) |>
  select(module_id, zone, tech, date, time_yr, s, c, pr_raw = pr, pr_clean, outlier)
log$rows_curated <- nrow(curated)
log$analysis_rows <- sum(!is.na(curated$pr_clean))
log$pct_usable <- round(100 * log$analysis_rows / log$rows_curated, 1)
cov <- curated |> group_by(module_id) |> summarise(cov = mean(!is.na(pr_clean)))
log$modules_below_80pct_coverage <- sum(cov$cov < 0.8)
stopifnot(log$modules_below_80pct_coverage == 0)

write_csv(curated, "data/pv_monthly_curated.csv")
rep <- tibble(check = names(log), value = unlist(log))
write_csv(rep, "results/data_validation_report.csv")
print(rep, n = Inf)
