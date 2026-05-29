/* =============================================================================
   regression.do
   Spec 1 — Goal-level LPM (baseline)
   Spec 2 — Adds elo_std and FIFA_rule × elo_std (heterogeneous effects)

   Unit of observation: a goal scored during matchday 3.
   Elo ratings are already embedded in the goals files (elo_home, elo_away),
   so no separate Elo merge is needed. Initial-state rows (goal_minute = 0,
   missing Elo) are dropped automatically by regress.

   Set ROOT below, then run.
   ============================================================================= */

clear all
set more off

* ---------------------------------------------------------------------------
* 0.  Paths  —  set ROOT to the repo root before running
* ---------------------------------------------------------------------------
* Option A: repo root is the current working directory
* global ROOT "`c(pwd)'"

* Option B: set manually
global ROOT "C:/Users/YOUR_USERNAME/Documents/GitHub/tb_football"

global DATA "$ROOT/data/out/wiki/men"


* ===========================================================================
* 1.  Load goals datasets (matchday 3 only, Elo already embedded)
* ===========================================================================

tempfile g_eu_fifa g_eu_uefa g_wc_fifa g_wc_uefa

import excel "$DATA/fifa/eu/goals_eu_fifa.xlsx", firstrow clear
count
di "goals_eu_fifa: `r(N)' rows"
save `g_eu_fifa'

import excel "$DATA/uefa/eu/goals_eu_uefa.xlsx", firstrow clear
count
di "goals_eu_uefa: `r(N)' rows"
save `g_eu_uefa'

import excel "$DATA/fifa/wc/goals_wc_fifa.xlsx", firstrow clear
count
di "goals_wc_fifa: `r(N)' rows"
save `g_wc_fifa'

import excel "$DATA/uefa/wc/goals_wc_uefa.xlsx", firstrow clear
count
di "goals_wc_uefa: `r(N)' rows"
save `g_wc_uefa'


* ===========================================================================
* 2.  Build stacked datasets
* ===========================================================================

foreach tournament in eu wc {

    if "`tournament'" == "eu" {
        local gfifa `g_eu_fifa'
        local guefa `g_eu_uefa'
        local label "EURO"
    }
    else {
        local gfifa `g_wc_fifa'
        local guefa `g_wc_uefa'
        local label "World Cup"
    }

    * Stack FIFA and UEFA, add rule indicator
    use "`gfifa'", clear
    gen FIFA_rule = 1
    tempfile fifa_side
    save `fifa_side'

    use "`guefa'", clear
    gen FIFA_rule = 0
    append using `fifa_side'

    count
    di "`label': `r(N)' rows after stacking"

    * Elo already in goals data — compute elo_diff and elo_avg
    gen elo_diff = abs(elo_home - elo_away)
    gen elo_avg  = (elo_home + elo_away) / 2

    * Rename goal_minute to minute
    rename goal_minute minute
    gen minute_sq = minute^2

    * Group identifier for clustering
    gen group_id = string(year) + "_" + stage
    encode group_id, gen(group_num)

    * Show how many rows survive (initial-state rows dropped by missing Elo)
    count if !missing(suspense, FIFA_rule, minute, elo_diff, group_num, year)
    di "`label': `r(N)' goal events with complete data (initial-state rows excluded)"

    tempfile stacked_`tournament'
    save `stacked_`tournament''
}


* ===========================================================================
* 3.  Specs 1 & 2 — Goal-level LPM
* ===========================================================================

di _newline "================================================================"
di "SPECS 1 & 2: GOAL-LEVEL LPM"
di "================================================================"

foreach tournament in eu wc {

    if "`tournament'" == "eu" local label "EURO"
    else                      local label "World Cup"

    use `stacked_`tournament'', clear

    * Compute group-level elo_std from FIFA rows only (rule-invariant)
    preserve
        keep if FIFA_rule == 1
        collapse (sd) elo_std = elo_avg, by(year stage)
        tempfile elo_std_grp
        save `elo_std_grp'
    restore
    merge m:1 year stage using `elo_std_grp', nogen
    gen FIFA_x_elo_std = FIFA_rule * elo_std

    * --- Spec 1: baseline ---
    di _newline "=== `label' — Spec 1 ==="
    di "suspense ~ FIFA_rule + minute + minute^2 + elo_diff + year FE"
    regress suspense FIFA_rule minute minute_sq elo_diff i.year, ///
        vce(cluster group_num)

    * --- Spec 2: heterogeneous effects ---
    di _newline "=== `label' — Spec 2 ==="
    di "suspense ~ FIFA_rule + minute + minute^2 + elo_diff + elo_std + FIFA×elo_std + year FE"
    regress suspense FIFA_rule minute minute_sq elo_diff ///
        elo_std FIFA_x_elo_std i.year, vce(cluster group_num)
}

di _newline "All done."
