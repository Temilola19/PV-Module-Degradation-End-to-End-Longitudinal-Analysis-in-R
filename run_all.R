
# Run the full pipeline from scratch
for (f in c("R/01_simulate_data.R", "R/02_clean_validate.R", "R/03_model.R", "R/04_survival.R")) {
  message("==> ", f); source(f, echo = FALSE)
}
writeLines(capture.output(sessionInfo()), "results/session_info.txt")
