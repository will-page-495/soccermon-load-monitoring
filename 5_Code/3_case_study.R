# ===== Case study: A-74af return to training after a major knee injury =====
# Author: Will Page | Data: SoccerMon (Midoglu et al., CC BY 4.0)
# Builds the weekly table and the chart for Phase 8 Step 6.
# Run with the RStudio project open: Ctrl + Shift + Enter.

library(readxl)
library(dplyr)
library(ggplot2)

# ---- 1. Load (run with the working directory set to this 5_Code folder) ----
excel_path <- "../6_Data/1_SoccerMon_Clean.xlsx"   # run with the working directory set to this 5_Code folder
out_dir    <- "results/"

num_cols <- c("DailyLoad", "ACWR", "Fatigue", "Fatigue_z", "Soreness_z", "SleepQuality_z", "Stress_z")
players  <- read_excel(excel_path, sheet = "Players")
daily    <- read_excel(excel_path, sheet = "Daily") %>%
  mutate(Date = as.Date(Date)) %>%
  left_join(select(players, Player, Label), by = "Player") %>%
  mutate(across(any_of(num_cols), ~ suppressWarnings(as.numeric(.x))))

injury_date <- as.Date("2021-03-25")
injury_week <- as.Date(cut(injury_date, "week"))   # Monday of the injury week

# ---- 2. Her daily data, 4 weeks before to 6 weeks after (Monday-to-Sunday weeks) ----
p <- daily %>%
  filter(Label == "A-74af") %>%
  arrange(Date) %>%
  mutate(WeekStart = as.Date(cut(Date, "week")),
         Week      = as.integer(WeekStart - injury_week) / 7) %>%
  filter(Week >= -4, Week <= 6)
stopifnot(nrow(p) > 0)

p$Wellness <- rowMeans(p[, c("Fatigue_z", "Soreness_z", "SleepQuality_z", "Stress_z")], na.rm = TRUE)
p$Wellness[is.nan(p$Wellness)] <- NA

last_value <- function(x) { x <- x[!is.na(x)]; if (length(x)) tail(x, 1) else NA }

weekly <- p %>%
  group_by(Week, WeekStart) %>%
  summarise(Load         = sum(DailyLoad, na.rm = TRUE),
            TrainingDays = sum(DailyLoad > 0, na.rm = TRUE),
            ACWR         = last_value(ACWR),
            Wellness     = mean(Wellness, na.rm = TRUE),
            Reports      = sum(!is.na(Fatigue)),
            .groups = "drop") %>%
  mutate(Wellness = ifelse(is.nan(Wellness), NA, Wellness))

pre_avg <- mean(weekly$Load[weekly$Week < 0])
weekly  <- weekly %>% mutate(PctPre = round(100 * Load / pre_avg))

# ---- 3. The table, formatted for Word ----
minus <- function(x) gsub("-", "−", x)
tab <- weekly %>%
  transmute(Week = case_when(Week == 0 ~ "Injury week",
                             Week <  0 ~ minus(paste0("Week ", Week)),
                             TRUE      ~ paste0("Week +", Week)),
            `Week starting`     = format(WeekStart, "%d %b"),
            `Load (AU)`         = formatC(Load, format = "d", big.mark = ","),
            `% of pre-injury`   = paste0(PctPre, "%"),
            `Training days`     = TrainingDays,
            `ACWR (end of week)` = ifelse(is.na(ACWR), "–", formatC(ACWR, format = "f", digits = 2)),
            `Wellness (avg z)`  = ifelse(is.na(Wellness), "–", minus(formatC(Wellness, format = "f", digits = 2))),
            `Wellness reports`  = Reports)

cat("\n==== Case study table: A-74af ====\n")
print(as.data.frame(tab), row.names = FALSE, right = FALSE)
write.csv(tab, paste0(out_dir, "6_case_study_A-74af.csv"), row.names = FALSE, fileEncoding = "UTF-8")

# ---- 4. Key facts for the text ----
after     <- filter(weekly, Week >= 1)
back_week <- after$Week[which(after$Load >= 0.9 * pre_avg)[1]]
cat("\n==== Key facts for the text ====\n")
cat("Average weekly load in the 4 weeks before:", formatC(round(pre_avg), format = "d", big.mark = ","), "AU\n")
cat("Loads in weeks +1 to +6:", paste(formatC(after$Load, format = "d", big.mark = ","), collapse = ", "), "AU\n")
cat("First week back to at least 90% of her pre-injury load: Week +", back_week, "\n", sep = "")
cat("Highest end-of-week ACWR during the return:", formatC(max(after$ACWR, na.rm = TRUE), format = "f", digits = 2), "\n")
cat("Return weeks ending with ACWR above 1.5:", sum(after$ACWR > 1.5, na.rm = TRUE), "\n")
cat("Average wellness z before the injury:", formatC(mean(weekly$Wellness[weekly$Week < 0], na.rm = TRUE), format = "f", digits = 2), "\n")
cat("Average wellness z in weeks 0 to +2:", formatC(mean(weekly$Wellness[weekly$Week %in% 0:2], na.rm = TRUE), format = "f", digits = 2), "\n")

# ---- 5. The chart: weekly load on top, wellness underneath ----
navy <- "#1F4E79"; red <- "#C0392B"; grey <- "#5A6270"
chart <- bind_rows(
  weekly %>% transmute(Week, Value = Load,     Panel = "Weekly load (AU)"),
  weekly %>% transmute(Week, Value = Wellness, Panel = "Average wellness z-score (0 = her normal)")
) %>% mutate(Panel = factor(Panel, levels = c("Weekly load (AU)", "Average wellness z-score (0 = her normal)")))

ggplot(chart, aes(Week, Value)) +
  geom_col(data = filter(chart, Panel == "Weekly load (AU)"), fill = navy, width = 0.7) +
  geom_hline(data = data.frame(Panel = factor("Weekly load (AU)", levels = levels(chart$Panel)), y = pre_avg),
             aes(yintercept = y), linetype = "dashed", colour = grey) +
  geom_hline(data = data.frame(Panel = factor("Average wellness z-score (0 = her normal)", levels = levels(chart$Panel)), y = 0),
             aes(yintercept = y), colour = grey) +
  geom_line(data = filter(chart, Panel != "Weekly load (AU)", !is.na(Value)), colour = navy, linewidth = 1) +
  geom_point(data = filter(chart, Panel != "Weekly load (AU)", !is.na(Value)), colour = navy, size = 2.5) +
  geom_vline(xintercept = 0, colour = red, linetype = "dashed") +
  facet_wrap(~ Panel, ncol = 1, scales = "free_y") +
  scale_x_continuous(breaks = -4:6, labels = c(minus(paste0(-4:-1)), "Injury", paste0("+", 1:6))) +
  labs(title = "A-74af: weekly load and wellness around a major knee injury (25 March 2021)",
       subtitle = "Dashed line on load = her pre-injury weekly average. Red line = injury week.",
       x = "Weeks relative to injury", y = NULL,
       caption = "Data: SoccerMon (CC BY 4.0)") +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), plot.subtitle = element_text(colour = grey),
        plot.caption = element_text(colour = grey, hjust = 0), panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold", hjust = 0))

ggsave(paste0(out_dir, "6_case_study_A-74af.png"), width = 8, height = 4.5, dpi = 300)
cat("\nSaved:", paste0(out_dir, "6_case_study_A-74af.png"), "and", paste0(out_dir, "6_case_study_A-74af.csv"), "\n")
