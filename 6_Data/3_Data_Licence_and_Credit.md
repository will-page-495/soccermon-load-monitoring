# Data licence and credit

## The data

This project uses the **SoccerMon** dataset:

> Midoglu, C. et al. (2024) 'A large-scale multivariate soccer athlete health, performance, and position monitoring dataset', *Scientific Data*, 11, 553. Data available at https://zenodo.org/records/10033832

SoccerMon is published under the **Creative Commons Attribution 4.0 International licence (CC BY 4.0)**: https://creativecommons.org/licenses/by/4.0/

- The **raw data is not included** in this repository. Download it from Zenodo.
- `6_Data/1_SoccerMon_Clean.xlsx`, `2_Dashboards/2_Power_BI_Dashboard.pbix` and the files in `5_Code/results/` contain data **derived from SoccerMon**. The changes made are reshaping the files to one row per player per day, splitting injury reports by body area and grouping them into episodes, calculating z-scores, compliance and other measures, and correcting one spelling error. Every change is listed in Appendix A of the report. These derived files are shared under the same CC BY 4.0 licence.
- Players are anonymised in the source data. No attempt has been made to identify anyone.

## My own work

The code, dashboards, reports and written analysis in this repository are © 2026 Will Page. You're welcome to read them and learn from them; please get in touch before reusing them.
