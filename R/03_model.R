# Longitudinal modeling: linear mixed-effects degradation model, model comparison,
# slope recovery vs known truth, and out-of-time forecast validation.
source("R/00_setup.R")
d <- read_csv("data/pv_monthly_curated.csv", show_col_types = FALSE) |>
  filter(!is.na(pr_clean)) |>
  mutate(zone = factor(zone, levels = c("Temperate", "Cold", "Hot-Arid", "Hot-Humid")),
         tech = factor(tech), pr_pct = pr_clean * 100)

# Model comparison (ML for likelihood-ratio tests)
m0 <- lmer(pr_pct ~ time_yr + s + c + (1 | module_id), data = d, REML = FALSE)
m1 <- lmer(pr_pct ~ time_yr + s + c + (1 + time_yr | module_id), data = d, REML = FALSE)
m2 <- lmer(pr_pct ~ time_yr * zone + time_yr * tech + s + c + (1 + time_yr | module_id), data = d, REML = FALSE)
cmp <- anova(m0, m1, m2)
write_csv(as_tibble(cmp, rownames = "model") |> mutate(across(where(is.numeric), ~round(.x, 3))),
          "results/model_comparison.csv")
print(cmp)

final <- update(m2, REML = TRUE)
fe <- as.data.frame(coef(summary(final))) |> tibble::rownames_to_column("term") |>
  transmute(term, estimate = Estimate, std_error = `Std. Error`, df = df, t = `t value`, p_value = `Pr(>|t|)`,
            conf_low = estimate - qt(.975, df) * std_error, conf_high = estimate + qt(.975, df) * std_error) |>
  mutate(across(where(is.numeric), ~round(.x, 4)))
write_csv(fe, "results/fixed_effects.csv")
write_csv(as_tibble(VarCorr(final)) |> mutate(across(where(is.numeric), ~round(.x, 4))),
          "results/variance_components.csv")

# Degradation rate (pp/yr) per zone x tech vs known truth
em <- emtrends(final, ~ zone * tech, var = "time_yr", lmer.df = "asymptotic") |> as_tibble() |>
  mutate(zone = as.character(zone), tech = as.character(tech))
truth <- read_csv("data/truth_slopes.csv", show_col_types = FALSE)
rec <- left_join(em, truth, by = c("zone", "tech")) |>
  transmute(zone, tech, est_pp_yr = round(time_yr.trend, 3),
            lower = round(asymp.LCL, 3), upper = round(asymp.UCL, 3),
            true_pp_yr = true_slope_pp_yr,
            ci_covers_truth = true_pp_yr >= lower & true_pp_yr <= upper,
            abs_error = round(abs(est_pp_yr - true_pp_yr), 3))
write_csv(rec, "results/degradation_rates_vs_truth.csv"); print(rec)

# Out-of-time validation: fit on months 0-47, forecast months 48-59
train <- filter(d, time_yr < 4); test <- filter(d, time_yr >= 4)
fit_tr <- lmer(formula(final), data = train, REML = TRUE)
test$pred <- predict(fit_tr, newdata = test, allow.new.levels = FALSE)
base <- lmer(pr_pct ~ s + c + (1 | module_id), data = train)   # no-degradation baseline
test$pred_base <- predict(base, newdata = test)
rmse <- function(a, b) sqrt(mean((a - b)^2))
fc <- tibble(model = c("Mixed-effects degradation model", "Seasonal baseline (no trend)"),
             rmse_pp = round(c(rmse(test$pred, test$pr_pct), rmse(test$pred_base, test$pr_pct)), 3))
write_csv(fc, "results/forecast_validation.csv"); print(fc)

# Figures
set.seed(1)
p1 <- ggplot(d, aes(time_yr, pr_pct, group = module_id)) +
  geom_line(alpha = 0.15, colour = "grey40") +
  geom_smooth(aes(group = zone, colour = zone), method = "lm", se = FALSE, linewidth = 1.3) +
  facet_wrap(~ zone) + labs(x = "Years in field", y = "Performance ratio (%)",
  title = "PV performance ratio by climate zone", subtitle = "Grey: individual modules; coloured: zone trend") +
  theme(legend.position = "none")
ggsave("results/fig1_pr_trajectories.png", p1, width = 9, height = 6, dpi = 150)

p2 <- ggplot(rec, aes(est_pp_yr, interaction(zone, tech, sep = " / "))) +
  geom_pointrange(aes(xmin = lower, xmax = upper)) +
  geom_point(aes(true_pp_yr), colour = "red", shape = 4, size = 3, stroke = 1.2) +
  labs(x = "Degradation rate (percentage points / year)", y = NULL,
       title = "Estimated degradation rates (95% CI) vs known truth (red x)")
ggsave("results/fig2_rates_vs_truth.png", p2, width = 8, height = 5, dpi = 150)

dg <- tibble(fitted = fitted(final), resid = resid(final))
p3 <- ggplot(dg, aes(fitted, resid)) + geom_point(alpha = .25) + geom_hline(yintercept = 0, colour = "red") +
  labs(title = "Residuals vs fitted", x = "Fitted PR (%)", y = "Residual")
ggsave("results/fig3_residuals.png", p3, width = 6, height = 4, dpi = 150)
png("results/fig4_qq.png", 700, 500, res = 110); qqnorm(resid(final), main = "Normal Q-Q of residuals"); qqline(resid(final), col = "red"); dev.off()
