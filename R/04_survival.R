# Time-to-end-of-life analysis: Kaplan-Meier and Cox proportional hazards.
# End-of-life = first month the 12-month rolling mean PR falls below EOL_THRESHOLD.
source("R/00_setup.R")
d <- read_csv("data/pv_monthly_curated.csv", show_col_types = FALSE) |>
  arrange(module_id, date) |> group_by(module_id) |>
  mutate(month = row_number() - 1,
         pr_filled = approx(month[!is.na(pr_clean)], pr_clean[!is.na(pr_clean)], month, rule = 2)$y,
         roll12 = stats::filter(pr_filled, rep(1/12, 12), sides = 1) |> as.numeric()) |> ungroup()

surv <- d |> group_by(module_id, zone, tech) |>
  summarise(event_month = suppressWarnings(min(month[!is.na(roll12) & roll12 < EOL_THRESHOLD])),
            .groups = "drop") |>
  mutate(event = is.finite(event_month), time = ifelse(event, event_month, N_MONTHS - 1) / 12,
         zone = factor(zone, levels = c("Cold", "Temperate", "Hot-Arid", "Hot-Humid")))
write_csv(surv, "results/module_survival_data.csv")

cox <- coxph(Surv(time, event) ~ zone + tech, data = surv)
ph <- cox.zph(cox)
hr <- tidy(cox, exponentiate = TRUE, conf.int = TRUE) |> mutate(across(where(is.numeric), ~round(.x, 3)))
write_csv(hr, "results/cox_hazard_ratios.csv"); print(hr)
cat("Concordance:", round(summary(cox)$concordance[1], 3), " | PH global test p =", round(ph$table["GLOBAL", "p"], 3), "\n")
cat("Events:", sum(surv$event), "of", nrow(surv), "modules\n")
write_csv(tibble(concordance = round(summary(cox)$concordance[1], 3), ph_global_p = round(ph$table["GLOBAL", "p"], 3),
                 events = sum(surv$event), modules = nrow(surv)), "results/cox_summary.csv")

km <- survfit(Surv(time, event) ~ zone, data = surv)
png("results/fig5_kaplan_meier.png", 900, 600, res = 120)
plot(km, col = c("steelblue", "forestgreen", "orange", "firebrick"), lwd = 2, mark.time = TRUE,
     xlab = "Years in field", ylab = "Proportion of modules above end-of-life threshold",
     main = "Kaplan-Meier: time to end-of-life by climate zone")
legend("bottomleft", legend = levels(surv$zone), col = c("steelblue", "forestgreen", "orange", "firebrick"), lwd = 2, bty = "n")
dev.off()
