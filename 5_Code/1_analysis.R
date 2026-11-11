# ===== SoccerMon: load, wellness and injury analysis =====
# Author: Will Page | Data: SoccerMon (Midoglu et al., CC BY 4.0)

# ---- 1. Packages
# Run once to install:
# install.packages(c("readxl", "dplyr", "tidyr", "ggplot2", "lme4", "lmerTest",
#                    "broom.mixed", "performance", "see", "ggeffects"))

library(readxl)
library(dplyr)
library(tidyr)
library(ggplot2)
library(lme4)
library(lmerTest)
library(broom.mixed)
library(performance)
library(ggeffects)



# ---- 2. Load, clean and check ----
excel_path <- "../6_Data/1_SoccerMon_Clean.xlsx"   # run with the working directory set to this 5_Code folder
out_dir    <- "results/"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

daily    <- read_excel(excel_path, sheet = "Daily")    %>% mutate(Date  = as.Date(Date))
leadup   <- read_excel(excel_path, sheet = "LeadUp")
episodes <- read_excel(excel_path, sheet = "Episodes") %>% mutate(Start = as.Date(Start))

num_cols <- c("DailyLoad", "WeeklyLoad", "ACWR", "Monotony",
              "Fatigue", "Soreness", "SleepQuality", "Stress",
              "Fatigue_z", "Soreness_z", "SleepQuality_z", "Stress_z")
daily  <- daily  %>% mutate(across(any_of(num_cols), ~ suppressWarnings(as.numeric(.x))))
leadup <- leadup %>% mutate(across(any_of(num_cols), ~ suppressWarnings(as.numeric(.x))))

# Dashboard colours and one shared chart style
navy <- "#1F4E79"; light <- "#5FB3E6"; red <- "#C0392B"; grey <- "#5A6270"
theme_set(
  theme_minimal(base_size = 12) +
    theme(plot.title    = element_text(face = "bold", colour = "#1F2A36"),
          plot.subtitle = element_text(colour = grey),
          plot.caption  = element_text(colour = grey, hjust = 0),
          panel.grid.minor = element_blank())
)

nrow(daily)                  # checkpoint: 36550
nrow(leadup)                 # checkpoint: 812
nrow(episodes)               # checkpoint: 29
sum(!is.na(daily$Fatigue))   # checkpoint: 16992







# ---- 3. Sample description ----
ep_by_team <- episodes %>%
  mutate(Team = ifelse(startsWith(Player, "TeamA"), "Team A", "Team B")) %>%
  count(Team, name = "Injury episodes")

table1 <- daily %>%
  group_by(Team) %>%
  summarise(Players                 = n_distinct(Player),
            `Training days`         = sum(DailyLoad > 0, na.rm = TRUE),
            `Mean session-day load (AU)` = round(mean(DailyLoad[DailyLoad > 0], na.rm = TRUE)),
            `Wellness reports`      = sum(!is.na(Fatigue)),
            .groups = "drop") %>%
  left_join(ep_by_team, by = "Team")

print(table1)
write.csv(table1, paste0(out_dir, "1_table1_sample_by_team.csv"), row.names = FALSE)







# ---- 4. Next-day dataset ----
nextday <- daily %>%
  arrange(Player, Date) %>%
  group_by(Player) %>%
  mutate(FatigueNext  = lead(Fatigue),
         SorenessNext = lead(Soreness),
         NextDate     = lead(Date)) %>%
  ungroup() %>%
  filter(DailyLoad > 0, as.numeric(NextDate - Date) == 1) %>%
  mutate(Load100 = DailyLoad / 100)

sum(!is.na(nextday$FatigueNext))   # checkpoint: 11980







# ---- 5. Q1: does today's load change tomorrow's wellness? ----
m_fatigue  <- lmer(FatigueNext  ~ Load100 + Fatigue  + (1 | Player), data = nextday)
m_soreness <- lmer(SorenessNext ~ Load100 + Soreness + (1 | Player), data = nextday)

summary(m_fatigue)
summary(m_soreness)

# Tidy results table: the Load100 effect with 95% CIs
q1_results <- bind_rows(
  tidy(m_fatigue,  effects = "fixed", conf.int = TRUE) %>% mutate(Outcome = "Next-day fatigue"),
  tidy(m_soreness, effects = "fixed", conf.int = TRUE) %>% mutate(Outcome = "Next-day soreness")
) %>%
  filter(term == "Load100") %>%
  mutate(`Effect: 600 vs 300 AU` = estimate * 3) %>%
  select(Outcome, estimate, conf.low, conf.high, p.value, `Effect: 600 vs 300 AU`)
print(q1_results)

# How much does the model explain?
r2(m_fatigue)
r2(m_soreness)

# Is the model sound? Opens a panel of diagnostic plots
check_model(m_fatigue)

# Robustness 1: drop the most extreme 1% of loads
cut99 <- quantile(nextday$DailyLoad, 0.99, na.rm = TRUE)
m_fat_trim <- update(m_fatigue, data = filter(nextday, DailyLoad <= cut99))

# Robustness 2: each team on its own
m_fat_A <- update(m_fatigue, data = filter(nextday, Team == "Team A"))
m_fat_B <- update(m_fatigue, data = filter(nextday, Team == "Team B"))

robust <- tibble(
  Model   = c("Main", "Top 1% loads removed", "Team A only", "Team B only"),
  Load100 = c(fixef(m_fatigue)["Load100"], fixef(m_fat_trim)["Load100"],
              fixef(m_fat_A)["Load100"],   fixef(m_fat_B)["Load100"])
)
print(robust)







# ---- 6. Q1 charts ----
# Effect size for the subtitle, taken straight from the results (so it updates if the data changes)
fat <- filter(q1_results, Outcome == "Next-day fatigue")
q1_sub <- sprintf("Each extra 100 AU = %.2f points more fatigue (95%% CI %.2f to %.2f). Small but consistent.",
                  -fat$estimate, -fat$conf.high, -fat$conf.low)

# Chart A: model prediction with 95% confidence band
pred <- ggpredict(m_fatigue, terms = "Load100 [0:10 by=0.5]")

ggplot(pred, aes(x = x * 100, y = predicted)) +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), fill = light, alpha = 0.3) +
  geom_line(colour = navy, linewidth = 1.2) +
  labs(title    = "Harder training days predict slightly more fatigue the next day",
       subtitle = q1_sub,
       x = "Training load that day (AU)", y = "Predicted fatigue next day (5 = fresh)",
       caption  = "Mixed model adjusted for same-day fatigue. n = 11,980 player-days, 50 players. Data: SoccerMon (CC BY 4.0)")
ggsave(paste0(out_dir, "2_q1_model_prediction.png"), width = 8, height = 4.5, dpi = 300)

# Chart B: raw averages by load band (points, not bars, so the trend is visible)
band_plot <- nextday %>%
  filter(!is.na(FatigueNext)) %>%
  mutate(LoadBand = cut(DailyLoad, breaks = c(0, 200, 400, 600, 800, Inf),
                        labels = c("1-200", "201-400", "401-600", "601-800", "800+"))) %>%
  group_by(LoadBand) %>%
  summarise(mean_next = mean(FatigueNext),
            se = sd(FatigueNext) / sqrt(n()), n = n(), .groups = "drop")
print(band_plot)

ggplot(band_plot, aes(x = LoadBand, y = mean_next)) +
  geom_errorbar(aes(ymin = mean_next - 1.96 * se, ymax = mean_next + 1.96 * se),
                width = 0.12, colour = grey) +
  geom_line(aes(group = 1), colour = navy, linewidth = 0.8) +
  geom_point(size = 3.5, colour = navy) +
  scale_x_discrete(labels = paste0(band_plot$LoadBand, "\n(n = ",
                                   format(band_plot$n, big.mark = ","), ")")) +
  labs(title = "Players feel more fatigued the day after harder training",
       subtitle = "Average fatigue score the day after training (5 = fresh), with 95% confidence intervals",
       x = "Training load that day (AU)", y = "Fatigue next day (5 = fresh)",
       caption = "Raw averages, not adjusted for player or same-day fatigue")
ggsave(paste0(out_dir, "2_q1_load_bands.png"), width = 8, height = 4.5, dpi = 300)








# ---- 7. Q2: wellness in the 28 days before injury ----
leadup <- leadup %>%
  mutate(Window = factor(ifelse(DaysBefore <= 7, "Last 7 days", "Days 8-28"),
                         levels = c("Days 8-28", "Last 7 days")))

# Method A: paired t-test (one average per episode per window, each injury counts once)
ep_windows <- leadup %>%
  group_by(EpisodeID, Window) %>%
  summarise(Fatigue_z = mean(Fatigue_z, na.rm = TRUE), .groups = "drop") %>%
  mutate(Fatigue_z = ifelse(is.nan(Fatigue_z), NA, Fatigue_z)) %>%
  pivot_wider(names_from = Window, values_from = Fatigue_z) %>%
  filter(!is.na(`Last 7 days`), !is.na(`Days 8-28`))
nrow(ep_windows)
tt <- t.test(ep_windows$`Last 7 days`, ep_windows$`Days 8-28`, paired = TRUE)
tt

# Method B: mixed model on every daily report
m_leadup <- lmer(Fatigue_z ~ Window + (1 | EpisodeID), data = leadup)
q2_results <- tidy(m_leadup, effects = "fixed", conf.int = TRUE) %>%
  filter(term == "WindowLast 7 days")
print(q2_results)

# Chart: 28-day lead-up with 95% confidence band
lead_plot <- leadup %>%
  group_by(DaysBefore) %>%
  summarise(mean_z = mean(Fatigue_z, na.rm = TRUE),
            se = sd(Fatigue_z, na.rm = TRUE) / sqrt(sum(!is.na(Fatigue_z))),
            .groups = "drop")

ggplot(lead_plot, aes(x = -DaysBefore, y = mean_z)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = grey) +
  annotate("rect", xmin = -7.5, xmax = -0.5, ymin = -Inf, ymax = Inf, fill = red, alpha = 0.06) +
  geom_ribbon(aes(ymin = mean_z - 1.96 * se, ymax = mean_z + 1.96 * se), fill = light, alpha = 0.3) +
  geom_line(colour = navy, linewidth = 1) +
  labs(title = "No sign of rising fatigue before injury",
       subtitle = "Average fatigue z-score (0 = player's normal) with 95% confidence band; final week shaded",
       x = "Days before injury", y = "Fatigue z-score",
       caption = paste0("n = ", nrow(episodes), " injury episodes. Wide bands = few reports that day. Data: SoccerMon (CC BY 4.0)"))
ggsave(paste0(out_dir, "3_q2_leadup_fatigue.png"), width = 8, height = 4.5, dpi = 300)









# ---- 8. Q3: injury rate by ACWR band ----
injury_starts <- episodes %>%
  distinct(Player, Date = Start) %>%
  mutate(InjuryStart = 1)

acwr_days <- daily %>%
  arrange(Player, Date) %>%
  group_by(Player) %>%
  mutate(ACWR_prev = lag(ACWR)) %>%
  ungroup() %>%
  filter(!is.na(ACWR_prev), ACWR_prev > 0) %>%
  left_join(injury_starts, by = c("Player", "Date")) %>%
  mutate(InjuryStart = coalesce(InjuryStart, 0),
         Band = cut(ACWR_prev, breaks = c(0, 0.8, 1.3, 1.5, Inf), right = FALSE,
                    labels = c("Below 0.8", "0.8-1.3", "1.3-1.5", "Above 1.5")))

q3_rates <- acwr_days %>%
  group_by(Band) %>%
  summarise(`Player-days` = n(), Injuries = sum(InjuryStart), .groups = "drop") %>%
  rowwise() %>%
  mutate(Rate = Injuries / `Player-days` * 1000,
         Low  = poisson.test(Injuries, `Player-days`)$conf.int[1] * 1000,
         High = poisson.test(Injuries, `Player-days`)$conf.int[2] * 1000) %>%
  ungroup()
print(q3_rates)
n_injuries_q3 <- sum(q3_rates$Injuries)
n_injuries_q3   # injuries with a valid ACWR the day before

# Rate ratio: above 1.5 vs the 0.8-1.3 reference
hi  <- filter(q3_rates, Band == "Above 1.5")
ref <- filter(q3_rates, Band == "0.8-1.3")
rr  <- poisson.test(c(hi$Injuries, ref$Injuries), c(hi$`Player-days`, ref$`Player-days`))
rr

ggplot(q3_rates, aes(x = Band, y = Rate)) +
  geom_col(fill = c("#A9B4C2", navy, "#A9B4C2", red), width = 0.6) +
  geom_errorbar(aes(ymin = Low, ymax = High), width = 0.15, colour = grey) +
  geom_text(aes(label = paste0(Injuries, ifelse(Injuries == 1, " injury", " injuries"))),
            y = 0, vjust = -0.5, colour = "white", size = 3.5) +
  labs(title = "Injuries were twice as common above ACWR 1.5, but the evidence is weak",
       subtitle = sprintf("Injuries per 1,000 player-days with exact 95%% CIs. Rate ratio vs 0.8-1.3: %.2f (95%% CI %.2f to %.2f)",
                          rr$estimate, rr$conf.int[1], rr$conf.int[2]),
       x = "ACWR the day before", y = "Injuries per 1,000 player-days",
       caption = paste0("Exploratory: ", n_injuries_q3, " of ", nrow(episodes),
                        " injury episodes had a valid ACWR the day before, so intervals are wide"))
ggsave(paste0(out_dir, "4_q3_injury_rate_by_acwr.png"), width = 8, height = 4.5, dpi = 300)









# ---- 9. Save results and session details ----
write.csv(q1_results, paste0(out_dir, "2_q1_results.csv"), row.names = FALSE)
write.csv(robust,     paste0(out_dir, "2_q1_robustness.csv"), row.names = FALSE)
write.csv(q2_results, paste0(out_dir, "3_q2_results.csv"), row.names = FALSE)
write.csv(q3_rates,   paste0(out_dir, "4_q3_rates.csv"), row.names = FALSE)

writeLines(c(paste("Episodes with data in both windows:", nrow(ep_windows)),
             capture.output(tt)),
           paste0(out_dir, "3_q2_paired_ttest.txt"))

writeLines(c(paste("Injuries included:", n_injuries_q3, "of", nrow(episodes)),
             capture.output(rr)),
           paste0(out_dir, "4_q3_rate_ratio.txt"))

writeLines(capture.output(sessionInfo()), paste0(out_dir, "7_session_info.txt"))