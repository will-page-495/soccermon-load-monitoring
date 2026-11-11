# ===== Render the three sample weekly reports (Phase 8 Step 7) =====
# Run with the RStudio project open: Ctrl + Shift + Enter. Takes 1-2 minutes.

if (!requireNamespace("quarto", quietly = TRUE)) install.packages("quarto")

qdir <- "."   # run with the working directory set to this 5_Code folder
dest <- file.path(qdir, "..", "3_Weekly_Reports")
dir.create(dest, recursive = TRUE, showWarnings = FALSE)

runs <- data.frame(week_end = c("2021-09-15", "2021-03-31", "2020-10-14"),
                   team     = c("All",        "Team A",     "Team B"),
                   tag      = c("All_players", "Team_A",    "Team_B"))

for (i in seq_len(nrow(runs))) {
  out <- paste0(i, "_Week_ending_", runs$week_end[i], "_", runs$tag[i], ".html")
  quarto::quarto_render(file.path(qdir, "5_weekly_report.qmd"),
                        output_file    = out,
                        execute_params = list(week_end = runs$week_end[i], team = runs$team[i]),
                        quiet          = TRUE)
  file.copy(file.path(qdir, out), file.path(dest, out), overwrite = TRUE)
  file.remove(file.path(qdir, out))
  cat("Saved", out, "\n")
}
cat("\nAll three are in:", normalizePath(dest), "\n")
