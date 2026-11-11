# ===== Appendix C: every value for Tables C1 to C4 =====
# Author: Will Page | Data: SoccerMon (Midoglu et al., CC BY 4.0)
# Rebuilds the models exactly as in analysis.R, then prints every number
# Appendix C needs, already formatted to paste into Word.
# Run it with the RStudio project open: Ctrl + Shift + Enter (Source). About a minute.

library(readxl)
library(dplyr)
library(tidyr)
library(lme4)
library(lmerTest)
library(broom.mixed)
library(performance)

# ---- 1. Load the data (run with the working directory set to this 5_Code folder) ----
excel_path <- "../6_Data/1_SoccerMon_Clean.xlsx"   # run with the working directory set to this 5_Code folder
out_dir    <- "results/"

num_cols <- c("DailyLoad", "WeeklyLoad", "ACWR", "Monotony",
              "Fatigue", "Soreness", "SleepQuality", "Stress",
              "Fatigue_z", "Soreness_z", "SleepQuality_z", "Stress_z")

daily    <- read_excel(excel_path, sheet = "Daily") %>%
  mutate(Date = as.Date(Date), across(any_of(num_cols), ~ suppressWarnings(as.numeric(.x))))
leadup   <- read_excel(excel_path, sheet = "LeadUp") %>%
  mutate(across(any_of(num_cols), ~ suppressWarnings(as.numeric(.x))))
episodes <- read_excel(excel_path, sheet = "Episodes") %>% mutate(Start = as.Date(Start))

# ---- 2. Rebuild the datasets and models from analysis.R ----
nextday <- daily %>%
  arrange(Player, Date) %>%
  group_by(Player) %>%
  mutate(FatigueNext  = lead(Fatigue),
         SorenessNext = lead(Soreness),
         NextDate     = lead(Date)) %>%
  ungroup() %>%
  filter(DailyLoad > 0, as.numeric(NextDate - Date) == 1) %>%
  mutate(Load100 = DailyLoad / 100)

leadup <- leadup %>%
  mutate(Window = factor(ifelse(DaysBefore <= 7, "Last 7 days", "Days 8-28"),
                         levels = c("Days 8-28", "Last 7 days")))

m_fatigue  <- lmer(FatigueNext  ~ Load100 + Fatigue  + (1 | Player), data = nextday)
m_soreness <- lmer(SorenessNext ~ Load100 + Soreness + (1 | Player), data = nextday)
m_leadup   <- lmer(Fatigue_z ~ Window + (1 | EpisodeID), data = leadup)

cut99      <- quantile(nextday$DailyLoad, 0.99, na.rm = TRUE)
m_fat_trim <- update(m_fatigue, data = filter(nextday, DailyLoad <= cut99))
m_fat_A    <- update(m_fatigue, data = filter(nextday, Team == "Team A"))
m_fat_B    <- update(m_fatigue, data = filter(nextday, Team == "Team B"))

# ---- 3. Formatting helpers (proper minus signs and commas, ready for Word) ----
num  <- function(x, d = 3) gsub("-", "−", formatC(x, format = "f", digits = d, big.mark = ","))
int  <- function(x) formatC(x, format = "d", big.mark = ",")
pval <- function(p) ifelse(p < 0.001, "<0.001", formatC(p, format = "f", digits = 3))

term_names <- c("Load100"           = "Load (per 100 AU)",
                "Fatigue"           = "Same-day fatigue",
                "Soreness"          = "Same-day soreness",
                "WindowLast 7 days" = "Final 7 days (vs days 8–28)")

mods <- list("Q1: next-day fatigue"        = m_fatigue,
             "Q1: next-day soreness"       = m_soreness,
             "Q2: fatigue z before injury" = m_leadup)

# ---- 4. Table C1: fixed effects ----
c1 <- bind_rows(lapply(names(mods), function(nm)
  tidy(mods[[nm]], effects = "fixed", conf.int = TRUE) %>% mutate(Model = nm))) %>%
  filter(term != "(Intercept)") %>%
  transmute(Model,
            Term     = term_names[term],
            Estimate = num(estimate),
            `95% CI` = paste(num(conf.low), "to", num(conf.high)),
            p        = pval(p.value))

# ---- 5. Table C2: model size and fit ----
c2 <- bind_rows(lapply(names(mods), function(nm) {
  m  <- mods[[nm]]
  r2 <- suppressWarnings(performance::r2(m))
  tibble(Model                = nm,
         Observations         = int(nobs(m)),
         `Players / episodes` = int(as.integer(ngrps(m)[1])),
         `Marginal R2`        = num(r2$R2_marginal),
         `Conditional R2`     = num(r2$R2_conditional),
         `Singular fit?`      = ifelse(isSingular(m), "YES - tell Claude", "No"))
}))

# ---- 6. Table C3: robustness (load effect on next-day fatigue) ----
rob <- list("Main model" = m_fatigue, "Top 1% of loads removed" = m_fat_trim,
            "Team A only" = m_fat_A, "Team B only" = m_fat_B)
c3 <- tibble(`Q1 fatigue model`         = names(rob),
             `Load effect (per 100 AU)` = sapply(rob, function(m) num(fixef(m)["Load100"])),
             Observations               = sapply(rob, function(m) int(nobs(m))))

# ---- 7. Table C4: paired t-test and rate ratio ----
ep_windows <- leadup %>%
  group_by(EpisodeID, Window) %>%
  summarise(Fatigue_z = mean(Fatigue_z, na.rm = TRUE), .groups = "drop") %>%
  mutate(Fatigue_z = ifelse(is.nan(Fatigue_z), NA, Fatigue_z)) %>%
  pivot_wider(names_from = Window, values_from = Fatigue_z) %>%
  filter(!is.na(`Last 7 days`), !is.na(`Days 8-28`))
tt <- t.test(ep_windows$`Last 7 days`, ep_windows$`Days 8-28`, paired = TRUE)

injury_starts <- episodes %>% distinct(Player, Date = Start) %>% mutate(InjuryStart = 1)
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
bands <- acwr_days %>% group_by(Band) %>%
  summarise(PD = n(), Inj = sum(InjuryStart), .groups = "drop")
hi  <- filter(bands, Band == "Above 1.5")
ref <- filter(bands, Band == "0.8-1.3")
rr  <- poisson.test(c(hi$Inj, ref$Inj), c(hi$PD, ref$PD))

c4 <- tibble(
  Test   = c(paste0("Q2: paired t-test (", nrow(ep_windows), " episodes)"),
             "Q3: exact Poisson rate ratio, ACWR 1.5 and above vs 0.8–1.3"),
  Result = c(paste0("Mean difference ", num(tt$estimate), " (95% CI ", num(tt$conf.int[1]), " to ",
                    num(tt$conf.int[2]), "), t(", tt$parameter, ") = ", num(tt$statistic, 2),
                    ", p = ", pval(tt$p.value)),
             paste0(num(rr$estimate, 2), " (95% CI ", num(rr$conf.int[1], 2), " to ", num(rr$conf.int[2], 2),
                    "), p = ", pval(rr$p.value), "; ", hi$Inj, " injuries in ", int(hi$PD),
                    " player-days vs ", ref$Inj, " in ", int(ref$PD))))

# ---- 8. The sentence for Results 4.2 ----
r2f <- suppressWarnings(performance::r2(m_fatigue))
sentence <- paste0("Load and same-day fatigue together explained ", round(100 * r2f$R2_marginal),
                   "% of the variation in next-day fatigue, rising to ", round(100 * r2f$R2_conditional),
                   "% once differences between players were included.")

# ---- 9. Check the models match your report (all should say TRUE) ----
near <- function(x, target, tol) abs(as.numeric(x) - target) < tol
checks <- c(
  "Q1 fatigue load effect is -0.034"   = near(fixef(m_fatigue)["Load100"],  -0.034, 0.0005),
  "Q1 soreness load effect is -0.039"  = near(fixef(m_soreness)["Load100"], -0.039, 0.0005),
  "Q1 fatigue model has 10,966 rows"   = nobs(m_fatigue) == 10966,
  "Q2 window effect is 0.229"          = near(fixef(m_leadup)[2], 0.229, 0.0005),
  "Paired t-test has 17 episodes"      = nrow(ep_windows) == 17,
  "Rate ratio is 2.35"                 = near(rr$estimate, 2.35, 0.005))

# ---- 10. Print everything and save it to one text file ----
show <- function(title, df) { cat("\n====", title, "====\n"); print(as.data.frame(df), row.names = FALSE, right = FALSE) }
report <- capture.output({
  cat("APPENDIX C VALUES\n")
  cat("\n==== Checks (all should be TRUE) ====\n"); print(checks)
  show("Table C1. Fixed effects from the mixed-effects models", c1)
  show("Table C2. Model size and fit", c2)
  show("Table C3. Q1 robustness checks (next-day fatigue)", c3)
  show("Table C4. Other tests", c4)
  cat("\n==== Sentence for Results 4.2 ====\n", sentence, "\n")
})
cat(report, sep = "\n")
writeLines(report, paste0(out_dir, "5_full_model_output.txt"), useBytes = TRUE)
cat("\nSaved to", paste0(out_dir, "5_full_model_output.txt"), "\n")
