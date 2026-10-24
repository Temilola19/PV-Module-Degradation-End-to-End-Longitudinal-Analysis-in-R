# Simulate monthly performance-ratio (PR) data for a PV module field study.
# SIMULATED so true degradation rates are known and the pipeline can be validated against them.
source("R/00_setup.R"); set.seed(SEED)

zones <- c("Hot-Humid", "Hot-Arid", "Temperate", "Cold")
true_zone_slope <- c("Hot-Humid" = -0.85, "Hot-Arid" = -0.70, "Temperate" = -0.45, "Cold" = -0.35) # pp / year
true_tech_extra <- c("mono-PERC" = 0, "multi-Si" = -0.15)                                         # pp / year

modules <- expand.grid(zone = zones, tech = names(true_tech_extra), rep = 1:8, stringsAsFactors = FALSE) |>
  mutate(module_id = sprintf("M%03d", row_number()),
         int_re   = rnorm(n(), 0, 0.010),
         slope_re = rnorm(n(), 0, 0.15))

dates <- seq(as.Date("2019-01-01"), by = "month", length.out = N_MONTHS)
raw <- modules |>
  tidyr::crossing(m = 0:(N_MONTHS - 1)) |>
  mutate(date = dates[m + 1], time_yr = m / 12,
         slope = true_zone_slope[zone] + true_tech_extra[tech] + slope_re,
         season = 0.015 * sin(2 * pi * m / 12 + 0.8) * ifelse(zone == "Cold", 1.4, 1),
         pr = 0.84 + int_re + slope / 100 * time_yr + season + rnorm(n(), 0, 0.006))

n <- nrow(raw)
raw$fault <- FALSE
f_idx <- sample(n, round(0.012 * n))
raw$pr[f_idx] <- sample(c(0.25, 0.4, 1.25, 1.4), length(f_idx), TRUE) + rnorm(length(f_idx), 0, 0.02)
raw$fault[f_idx] <- TRUE
raw$pr[sample(n, round(0.04 * n))] <- NA
dups <- raw[sample(n, 25), ]
out <- bind_rows(raw, dups) |> arrange(module_id, date)

write_csv(select(out, module_id, zone, tech, date, pr), "data/pv_monthly_raw.csv")
write_csv(select(out, module_id, date, fault) |> distinct(), "data/truth_faults.csv")
write_csv(tibble(zone = rep(zones, 2), tech = rep(names(true_tech_extra), each = 4)) |>
            mutate(true_slope_pp_yr = true_zone_slope[zone] + true_tech_extra[tech]),
          "data/truth_slopes.csv")
message("Raw data written: ", nrow(out), " rows, ", n_distinct(out$module_id), " modules")
