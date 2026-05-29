/* =============================================================================
   regression.do

   Sections:
     1. Load datasets
     2. Descriptive statistics — goals data
     3. Descriptive statistics — MBM data
     4. Statistical tests (paired t-test and Wilcoxon signed-rank)
     5. Build stacked goal-event datasets
     6. Spec 1 & 2 — Goal-level LPM

   Unit of observation for regressions: a goal scored during matchday 3.
   Elo ratings are already embedded in the goals files (elo_home, elo_away).
   Initial-state rows (goal_minute = 0, missing Elo) are excluded from
   regressions automatically by regress.

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
* 1.  Load datasets
* ===========================================================================

* --- Goals ---
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

* --- MBM ---
tempfile m_eu_fifa m_eu_uefa m_wc_fifa m_wc_uefa

import excel "$DATA/fifa/eu/mbm_eu_fifa.xlsx", firstrow clear
count
di "mbm_eu_fifa: `r(N)' rows"
save `m_eu_fifa'

import excel "$DATA/uefa/eu/mbm_eu_uefa.xlsx", firstrow clear
count
di "mbm_eu_uefa: `r(N)' rows"
save `m_eu_uefa'

import excel "$DATA/fifa/wc/mbm_wc_fifa.xlsx", firstrow clear
count
di "mbm_wc_fifa: `r(N)' rows"
save `m_wc_fifa'

import excel "$DATA/uefa/wc/mbm_wc_uefa.xlsx", firstrow clear
count
di "mbm_wc_uefa: `r(N)' rows"
save `m_wc_uefa'


* ===========================================================================
* 2.  Descriptive Statistics — Goals data
*     Rows with missing elo_home are initial-state rows (minute 0 before the
*     first goal); they carry no Elo information and are excluded here.
* ===========================================================================

di _newline "================================================================"
di "DESCRIPTIVE STATISTICS — GOALS DATA"
di "================================================================"

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

    use "`gfifa'", clear
    gen FIFA_rule = 1
    tempfile fifa_side
    save `fifa_side'

    use "`guefa'", clear
    gen FIFA_rule = 0
    append using `fifa_side'

    rename goal_minute minute

    di _newline "=== `label' — by rule (1=FIFA, 0=UEFA), goal events only ==="
    tabstat minute half_time qual_changed qual_count suspense elo_home elo_away ///
        if !missing(elo_home),                                                  ///
        by(FIFA_rule) stats(mean sd min max) columns(statistics) longstub
}


* ===========================================================================
* 3.  Descriptive Statistics — MBM data
* ===========================================================================

di _newline "================================================================"
di "DESCRIPTIVE STATISTICS — MBM DATA"
di "================================================================"

foreach tournament in eu wc {

    if "`tournament'" == "eu" {
        local mfifa `m_eu_fifa'
        local muefa `m_eu_uefa'
        local label "EURO"
    }
    else {
        local mfifa `m_wc_fifa'
        local muefa `m_wc_uefa'
        local label "World Cup"
    }

    use "`mfifa'", clear
    gen FIFA_rule = 1
    tempfile fifa_mbm
    save `fifa_mbm'

    use "`muefa'", clear
    gen FIFA_rule = 0
    append using `fifa_mbm'

    di _newline "=== `label' — by rule (1=FIFA, 0=UEFA) ==="
    tabstat qual_changed qual_count suspense elo_home elo_away, ///
        by(FIFA_rule) stats(mean sd min max) columns(statistics) longstub
}


* ===========================================================================
* 4.  Statistical Tests
*     Paired t-test and Wilcoxon signed-rank test on group-level means.
*     For each group (year x stage) we compute mean suspense and mean
*     qual_count under FIFA and under UEFA separately, then test whether the
*     within-group difference (UEFA minus FIFA) is zero.
*     All rows (including initial-state rows) are included in the group means.
* ===========================================================================

di _newline "================================================================"
di "STATISTICAL TESTS — PAIRED T-TEST AND WILCOXON SIGNED-RANK"
di "================================================================"

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

    * Stack and collapse to one row per (group, rule)
    use "`gfifa'", clear
    gen FIFA_rule = 1
    tempfile fifa_side
    save `fifa_side'

    use "`guefa'", clear
    gen FIFA_rule = 0
    append using `fifa_side'

    collapse (mean) qual_count suspense, by(year stage FIFA_rule)

    * Reshape wide so each group occupies one row
    reshape wide qual_count suspense, i(year stage) j(FIFA_rule)
    * qual_count0 = UEFA mean, qual_count1 = FIFA mean (same for suspense)

    gen diff_qual = qual_count0 - qual_count1   // UEFA - FIFA
    gen diff_susp = suspense0   - suspense1      // UEFA - FIFA

    di _newline "=== `label' — Qualification Count (UEFA - FIFA) ==="
    ttest diff_qual == 0
    signrank diff_qual = 0

    di _newline "=== `label' — Suspense (UEFA - FIFA) ==="
    ttest diff_susp == 0
    signrank diff_susp = 0
}


* ===========================================================================
* 5.  Build stacked goal-event datasets
* ===========================================================================

di _newline "================================================================"
di "BUILDING STACKED DATASETS FOR REGRESSION"
di "================================================================"

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

    * Elo already in goals data
    gen elo_diff = abs(elo_home - elo_away)
    gen elo_avg  = (elo_home + elo_away) / 2

    rename goal_minute minute
    gen minute_sq = minute^2

    gen group_id = string(year) + "_" + stage
    encode group_id, gen(group_num)

    * Show effective sample (initial-state rows excluded by missing Elo)
    count if !missing(suspense, FIFA_rule, minute, elo_diff, group_num, year)
    di "`label': `r(N)' goal events with complete data"

    tempfile stacked_`tournament'
    save `stacked_`tournament''
}


* ===========================================================================
* 6.  Specs 1 & 2 — Goal-level LPM
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
    di "suspense ~ FIFA_rule + minute + minute^2 + elo_diff + elo_std + FIFA x elo_std + year FE"
    regress suspense FIFA_rule minute minute_sq elo_diff ///
        elo_std FIFA_x_elo_std i.year, vce(cluster group_num)
}

di _newline "All done."
