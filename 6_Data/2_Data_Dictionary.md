# Data dictionary

Every table in `6_Data/1_SoccerMon_Clean.xlsx`, which is also the data model in the Power BI dashboard and the input to the R scripts.

**Conventions**

- **Player** is the anonymised SoccerMon ID: the team, then a unique code (for example `TeamA-0362cdd5-…`). **Label** is a short version for charts: team letter + first 4 characters of the code (for example `A-0362`).
- **Load** is session RPE (sRPE) in arbitrary units (AU): the player's effort rating (0–10) × session minutes.
- **Wellness** items are self-reported, with **higher scores meaning better wellness**. Blank means the player didn't report that day; it is never treated as zero.
- **z-scores** compare a value with that player's own average and spread: 0 = her normal, −1 = one standard deviation worse than normal.

## Daily

One row per player per day, 1 January 2020 to 31 December 2021. **36,550 rows** (50 players × 731 days).

| Column | Meaning |
|---|---|
| Player | Anonymised player ID |
| Date | Calendar date |
| Team | Team A or Team B |
| DailyLoad | Total sRPE load for the day (AU). 0 = no training recorded |
| WeeklyLoad | Total load over the last 7 days (AU) |
| ATL | Acute training load: average daily load over the last 7 days |
| CTL28 | Chronic training load: average daily load over the last 28 days |
| CTL42 | Chronic training load: average daily load over the last 42 days |
| ACWR | Acute:chronic workload ratio, ATL ÷ CTL28 ("coupled": the 7 days sit inside the 28). Matches SoccerMon's published values to within about 0.005 |
| Monotony | Average daily load ÷ the standard deviation of daily load over the last 7 days. Above 2 = little variation between hard and easy days |
| Strain | Weekly load × monotony |
| Fatigue | Self-rated fatigue, 1–5 (higher = fresher) |
| Mood | Self-rated mood, 1–5 (higher = better) |
| Readiness | Self-rated readiness to train (higher = more ready) |
| SleepDuration | Hours slept the night before |
| SleepQuality | Self-rated sleep quality, 1–5 (higher = better) |
| Soreness | Self-rated muscle soreness, 1–5 (higher = less sore) |
| Stress | Self-rated stress, 1–5 (higher = less stressed) |
| Fatigue_z, Soreness_z, SleepQuality_z, Stress_z | The item as a z-score within that player. The 7-day wellness index used in the dashboard and reports is the average of these four over the last 7 days |

## Players

One row per player. **50 rows** (Team A 27, Team B 23).

| Column | Meaning |
|---|---|
| Player | Anonymised player ID |
| Label | Short label for charts (for example `A-0362`) |
| Team | Team A or Team B |
| FirstActive | First day with any training or wellness report |
| LastActive | Last day with any training or wellness report |
| ActiveDays | Days from FirstActive to LastActive (inclusive) |
| WellnessDays | Active days with a wellness report |
| Compliance | WellnessDays ÷ ActiveDays (0 to 1) |

## Sessions

One row per training session. **16,265 rows.**

| Column | Meaning |
|---|---|
| Player | Anonymised player ID |
| Date | Session date (dd.mm.yyyy, as in the source) |
| SessionID | Number of the session within that player's day (1, 2, …) |
| RPE | Rating of perceived exertion, 0 (rest) to 10 (maximal) |
| DurationMin | Session length in minutes |
| SessionLoad | sRPE load for the session: RPE × DurationMin (AU) |
| LoadCheck | "OK" if SessionLoad equals RPE × DurationMin (true for every session) |
| PossibleDuplicate | "Yes" if another session has the same player, date, RPE and duration. Kept: two identical sessions can be genuine |
| SessionsThatDay | Number of sessions that player logged that day |

## InjuryReports

One row per body area per injury report: reports listing several areas are split into one row each. **306 rows** (from 162 raw reports).

| Column | Meaning |
|---|---|
| Player | Anonymised player ID |
| Date | Date of the report |
| BodyArea | Body area reported (for example "Right Thigh") |
| Severity | Minor or Major, as the player reported it |
| IsMajor | 1 if Major, 0 if Minor |
| NewEpisode | 1 if this report starts a new injury episode (the player's first report, or the first after a gap of more than 14 days), otherwise 0 |
| EpisodeID | The injury episode this report belongs to |

## Episodes

One row per injury episode. **29 rows** (Team A 25, Team B 4).

| Column | Meaning |
|---|---|
| EpisodeID | Episode number |
| Player | Anonymised player ID |
| Start | Date of the first report in the episode |
| End | Date of the last report in the episode |
| DurationDays | Days from first to last report (inclusive). This measures reporting, not time lost from training |
| BodyAreaReports | Number of body-area rows in the episode |
| MajorReports | Number of those rows marked Major |
| Areas | Body areas reported during the episode |
| Severity | Major if any report in the episode was Major, otherwise Minor |

## LeadUp

The 28 days before each injury episode, used for the pre-injury analysis. **812 rows** (29 episodes × 28 days).

| Column | Meaning |
|---|---|
| EpisodeID | Episode number |
| Player | Anonymised player ID |
| Start | Start date of the episode |
| DaysBefore | Days before the episode start (1 = the day before, up to 28) |
| Date | Calendar date |
| ACWR, DailyLoad | As in Daily, for that date |
| Fatigue_z, Soreness_z, SleepQuality_z, Stress_z | As in Daily, for that date |

## Games

One row per player per game rating. **248 rows.** Described only; not used in the statistical analysis.

| Column | Meaning |
|---|---|
| Player | Anonymised player ID |
| Date | Game date (dd.mm.yyyy, as in the source) |
| TeamRating | Player's rating of the team's performance |
| AttackingRating | Player's rating of attacking performance |
| DefensiveRating | Player's rating of defensive performance |

## Illness

One row per illness report. **15 rows**, from 4 players. Described only; too few to test.

| Column | Meaning |
|---|---|
| Player | Anonymised player ID |
| Date | Report date (dd.mm.yyyy, as in the source) |
| Symptoms | Symptoms reported (one spelling error in the source, "soar throat", was corrected) |

## Working sheets

These sheets record checks and early exploration. They are not part of the data model.

| Sheet | What it is |
|---|---|
| Validation | Rebuilds SoccerMon's load metrics (ACWR and others) from the raw daily loads to confirm they match |
| DataQuality | The data quality audit: each check, what it tests, the result and the decision taken |
| Explore | Pivot tables used for first exploration |
| Weekly Squad Report | The first Excel version of the weekly report, later rebuilt in R |

## Power BI additions

The Power BI model adds a **Date** table (one row per day, linked to every table with a date) and a **_measure** table holding the 46 DAX measures, grouped into display folders. The fact tables link to Players and Date in a star schema (13 relationships).

## R results (`5_Code/results/`)

| File | What it contains |
|---|---|
| `1_table1_sample_by_team.csv` | Players, training days, mean load, wellness reports and injury episodes by team |
| `2_q1_results.csv` | Q1: effect of load on next-day fatigue and soreness |
| `2_q1_robustness.csv` | Q1 robustness checks (top 1% of loads removed, each team separately) |
| `3_q2_results.csv`, `3_q2_paired_ttest.txt` | Q2: wellness in the final week before injury vs the three weeks before |
| `4_q3_rates.csv`, `4_q3_rate_ratio.txt` | Q3: injury rates by ACWR band and the rate ratio |
| `5_full_model_output.txt` | Full model output used in Appendix C of the report |
| `6_case_study_A-74af.csv` | Weekly load, ACWR and wellness around one player's knee injury |
| `2_q1_model_prediction.png`, `2_q1_load_bands.png`, `3_q2_leadup_fatigue.png`, `4_q3_injury_rate_by_acwr.png`, `6_case_study_A-74af.png` | The report's charts |
| `7_session_info.txt` | R and package versions used |
