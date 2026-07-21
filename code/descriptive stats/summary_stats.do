* ============================================================
* summary_stats.do
* Summary statistics for the merged datasets used in regressions
* ============================================================

clear all
set more off

local base "C:/Users/`c(username)'/Documents/GitHub/tb_football"


* ============================================================
* Goals merged dataset — WC vs EU
* ============================================================

import excel using "`base'/data/out/goals_merged.xlsx", firstrow clear

* Drop initial-state rows (minute = 0, no match yet; elo_favorite missing)
* This matches the Python dropna() on all variables, giving N=381 (WC) / 226 (EU)
drop if missing(elo_favorite)

* Goal-level summary: World Cup (fifa_rule == 1)
tabstat goal_minute half_time qual_changed qual_count elo_favorite elo_underdog elo1st elo2nd elo3rd elo4th suspense ///
    if fifa_rule == 1, stat(n mean sd min max) col(stat)

* Goal-level summary: European Championship (fifa_rule == 0)
tabstat goal_minute half_time qual_changed qual_count elo_favorite elo_underdog elo1st elo2nd elo3rd elo4th suspense ///
    if fifa_rule == 0, stat(n mean sd min max) col(stat)


* ============================================================
* Group-level summary (for Poisson model)
* One row per group, keeping max(qual_count)
* ============================================================

import excel using "`base'/data/out/goals_merged.xlsx", firstrow clear

preserve

collapse (max) qual_count (first) elo1st elo2nd elo3rd elo4th, by(year stage fifa_rule)

* World Cup groups
tabstat qual_count elo1st elo2nd elo3rd elo4th ///
    if fifa_rule == 1, stat(n mean sd min max) col(stat)

* European Championship groups
tabstat qual_count elo1st elo2nd elo3rd elo4th ///
    if fifa_rule == 0, stat(n mean sd min max) col(stat)

restore


* ============================================================
* MBM merged dataset — WC vs EU
* ============================================================

import excel using "`base'/data/out/mbm_merged.xlsx", firstrow clear

* MBM summary: World Cup
tabstat qual_changed qual_count elo1st elo2nd elo3rd elo4th suspense ///
    if fifa_rule == 1, stat(n mean sd min max) col(stat)

* MBM summary: European Championship
tabstat qual_changed qual_count elo1st elo2nd elo3rd elo4th suspense ///
    if fifa_rule == 0, stat(n mean sd min max) col(stat)
