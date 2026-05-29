/* =============================================================================
   regression.do
   Stata replication of regression.py.

   FIFA vs UEFA tie-breaking rules and group-level suspense.

   Spec 1  — Group-level paired OLS               (Table regression_grp)
   Spec 2  — Minute-by-minute LPM                 (Table regression_mbm)
   Spec 3  — Heterogeneous effects (FIFA×Elo std)  (Table regression_mbm)

   Edit ROOT in Section 0 before running.
   LaTeX tables can be exported with esttab (ssc install estout) — see end of file.
   ============================================================================= */

clear all
set more off

* ---------------------------------------------------------------------------
* 0.  Paths
*     Set ROOT to the repo root before running.
*     If you open Stata from the repo root folder, uncomment Option A.
*     Otherwise set the full path manually in Option B.
* ---------------------------------------------------------------------------

* Option A — repo root is the current working directory:
* global ROOT "`c(pwd)'"

* Option B — set path manually (edit this line):
global ROOT "C:/Users/YOUR_USERNAME/Documents/GitHub/tb_football"

global DATA "$ROOT/data/out/wiki/men"
global IN   "$ROOT/data/in"


* ===========================================================================
* 1.  Load all source files into tempfiles
* ===========================================================================

tempfile g_eu_fifa g_eu_uefa g_wc_fifa g_wc_uefa ///
         m_eu_fifa m_eu_uefa m_wc_fifa m_wc_uefa ///
         elo_eu    elo_wc

import excel "$DATA/fifa/eu/goals_eu_fifa.xlsx", firstrow clear
save `g_eu_fifa'

import excel "$DATA/uefa/eu/goals_eu_uefa.xlsx", firstrow clear
save `g_eu_uefa'

import excel "$DATA/fifa/wc/goals_wc_fifa.xlsx", firstrow clear
save `g_wc_fifa'

import excel "$DATA/uefa/wc/goals_wc_uefa.xlsx", firstrow clear
save `g_wc_uefa'

import excel "$DATA/fifa/eu/mbm_eu_fifa.xlsx", firstrow clear
save `m_eu_fifa'

import excel "$DATA/uefa/eu/mbm_eu_uefa.xlsx", firstrow clear
save `m_eu_uefa'

import excel "$DATA/fifa/wc/mbm_wc_fifa.xlsx", firstrow clear
save `m_wc_fifa'

import excel "$DATA/uefa/wc/mbm_wc_uefa.xlsx", firstrow clear
save `m_wc_uefa'

import excel "$IN/elo_eu.xlsx", firstrow clear
save `elo_eu'

import excel "$IN/elo_wc.xlsx", firstrow clear
save `elo_wc'


* ===========================================================================
* PART I: Spec 1 — Group-level paired OLS
* ===========================================================================

* ---------------------------------------------------------------------------
* 2.  aggregate_group
*     Merges Elo ratings (home and away), computes elo_avg and elo_diff,
*     then collapses to one row per (year, stage).
* ---------------------------------------------------------------------------
capture program drop aggregate_group
program define aggregate_group
    /*
       args: goals_file  elo_file  output_file
    */
    args goals_file elo_file output_file

    * Build home-team Elo lookup
    use "`elo_file'", clear
    rename team       home_team
    rename elo_rating home_elo
    sort year home_team
    tempfile elo_home
    save `elo_home'

    * Build away-team Elo lookup
    use "`elo_file'", clear
    rename team       away_team
    rename elo_rating away_elo
    sort year away_team
    tempfile elo_away
    save `elo_away'

    * Load goals, merge both Elo sides
    use "`goals_file'", clear
    sort year home_team
    merge m:1 year home_team using `elo_home', keep(master match) nogen
    sort year away_team
    merge m:1 year away_team using `elo_away', keep(master match) nogen

    gen elo_avg  = (home_elo + away_elo) / 2
    gen elo_diff = abs(home_elo - away_elo)

    * Collapse to one row per (year, stage)
    collapse                                ///
        (mean)  avg_suspense   = suspense   ///
        (mean)  avg_qual_count = qual_count ///
        (mean)  elo_avg        = elo_avg    ///
        (sd)    elo_std        = elo_avg    ///
        (mean)  elo_diff_avg   = elo_diff   ///
        (count) n_obs          = suspense   ///
        , by(year stage)

    save "`output_file'", replace
end

tempfile agg_eu_fifa agg_eu_uefa agg_wc_fifa agg_wc_uefa

aggregate_group `g_eu_fifa' `elo_eu' `agg_eu_fifa'
aggregate_group `g_eu_uefa' `elo_eu' `agg_eu_uefa'
aggregate_group `g_wc_fifa' `elo_wc' `agg_wc_fifa'
aggregate_group `g_wc_uefa' `elo_wc' `agg_wc_uefa'

* ---------------------------------------------------------------------------
* 3.  make_paired
*     Merges FIFA and UEFA aggregates on (year, stage) and computes the
*     within-group suspense gap: delta_suspense = FIFA - UEFA.
*     Elo variables are taken from the FIFA side (rule-invariant).
* ---------------------------------------------------------------------------
capture program drop make_paired
program define make_paired
    /*
       args: fifa_file  uefa_file  output_file
    */
    args fifa_file uefa_file output_file

    * FIFA side: rename all variables with _fifa suffix
    use "`fifa_file'", clear
    foreach v in avg_suspense avg_qual_count elo_std elo_diff_avg elo_avg n_obs {
        rename `v' `v'_fifa
    }
    sort year stage
    tempfile fifa_side
    save `fifa_side'

    * UEFA side: rename all variables with _uefa suffix
    use "`uefa_file'", clear
    foreach v in avg_suspense avg_qual_count elo_std elo_diff_avg elo_avg n_obs {
        rename `v' `v'_uefa
    }
    sort year stage

    * Merge and compute differences
    merge 1:1 year stage using `fifa_side', nogen

    gen delta_suspense   = avg_suspense_fifa   - avg_suspense_uefa
    gen delta_qual_count = avg_qual_count_fifa - avg_qual_count_uefa
    gen elo_std          = elo_std_fifa        // rule-invariant; use FIFA side
    gen elo_diff_avg     = elo_diff_avg_fifa

    save "`output_file'", replace
end

tempfile paired_eu paired_wc

make_paired `agg_eu_fifa' `agg_eu_uefa' `paired_eu'
make_paired `agg_wc_fifa' `agg_wc_uefa' `paired_wc'

* ---------------------------------------------------------------------------
* 4.  Spec 1 regressions
*     vce(robust) gives HC1 standard errors, matching Python's cov_type="HC1".
* ---------------------------------------------------------------------------

di ""
di "================================================================"
di "SPEC 1: GROUP-LEVEL PAIRED REGRESSIONS"
di "================================================================"

* --- European Championship ---
di _newline "=== EURO — Spec 1a: delta_suspense ~ elo_std ==="
use `paired_eu', clear
regress delta_suspense elo_std, vce(robust)

di _newline "=== EURO — Spec 1b: delta_suspense ~ elo_std + year FE ==="
regress delta_suspense elo_std i.year, vce(robust)

* --- World Cup ---
di _newline "=== WC — Spec 1a: delta_suspense ~ elo_std ==="
use `paired_wc', clear
regress delta_suspense elo_std, vce(robust)

di _newline "=== WC — Spec 1b: delta_suspense ~ elo_std + year FE ==="
regress delta_suspense elo_std i.year, vce(robust)


* ===========================================================================
* PART II: Specs 2 & 3 — Minute-by-minute LPM
* ===========================================================================

* ---------------------------------------------------------------------------
* 5.  Build stacked MBM datasets
*     For each tournament: enrich FIFA and UEFA separately with Elo ratings,
*     append them (FIFA_rule = 1 / 0), and create derived variables.
* ---------------------------------------------------------------------------

* Helper: build home- and away-team Elo lookup tempfiles
capture program drop prep_elo_lookups
program define prep_elo_lookups
    /*
       args: elo_file  home_out  away_out
    */
    args elo_file home_out away_out

    use "`elo_file'", clear
    rename team       home_team
    rename elo_rating home_elo
    sort year home_team
    save "`home_out'", replace

    use "`elo_file'", clear
    rename team       away_team
    rename elo_rating away_elo
    sort year away_team
    save "`away_out'", replace
end

* --- European Championship MBM ---
tempfile elo_eu_home elo_eu_away
prep_elo_lookups `elo_eu' `elo_eu_home' `elo_eu_away'

* Enrich FIFA side
use `m_eu_fifa', clear
gen FIFA_rule = 1
sort year home_team
merge m:1 year home_team using `elo_eu_home', keep(master match) nogen
sort year away_team
merge m:1 year away_team using `elo_eu_away', keep(master match) nogen
tempfile eu_fifa_enr
save `eu_fifa_enr'

* Enrich UEFA side and stack
use `m_eu_uefa', clear
gen FIFA_rule = 0
sort year home_team
merge m:1 year home_team using `elo_eu_home', keep(master match) nogen
sort year away_team
merge m:1 year away_team using `elo_eu_away', keep(master match) nogen
append using `eu_fifa_enr'

* Use "minute" if it exists, otherwise rename from "goal_minute"
capture confirm variable minute
if _rc {
    capture confirm variable goal_minute
    if !_rc rename goal_minute minute
}

gen minute_sq = minute^2
gen elo_diff  = abs(home_elo - away_elo)
gen elo_avg   = (home_elo + away_elo) / 2
gen group_id  = string(year) + "_" + stage
encode group_id, gen(group_num)   // numeric version for clustering

tempfile mbm_eu
save `mbm_eu'

* --- World Cup MBM ---
tempfile elo_wc_home elo_wc_away
prep_elo_lookups `elo_wc' `elo_wc_home' `elo_wc_away'

use `m_wc_fifa', clear
gen FIFA_rule = 1
sort year home_team
merge m:1 year home_team using `elo_wc_home', keep(master match) nogen
sort year away_team
merge m:1 year away_team using `elo_wc_away', keep(master match) nogen
tempfile wc_fifa_enr
save `wc_fifa_enr'

use `m_wc_uefa', clear
gen FIFA_rule = 0
sort year home_team
merge m:1 year home_team using `elo_wc_home', keep(master match) nogen
sort year away_team
merge m:1 year away_team using `elo_wc_away', keep(master match) nogen
append using `wc_fifa_enr'

capture confirm variable minute
if _rc {
    capture confirm variable goal_minute
    if !_rc rename goal_minute minute
}

gen minute_sq = minute^2
gen elo_diff  = abs(home_elo - away_elo)
gen elo_avg   = (home_elo + away_elo) / 2
gen group_id  = string(year) + "_" + stage
encode group_id, gen(group_num)

tempfile mbm_wc
save `mbm_wc'

* ---------------------------------------------------------------------------
* 6.  Specs 2 & 3 regressions
*     elo_std is computed from FIFA-rule rows only (rule-invariant).
*     SEs are clustered at the group (year × stage) level.
* ---------------------------------------------------------------------------

di ""
di "================================================================"
di "SPECS 2 & 3: MINUTE-BY-MINUTE LPM"
di "================================================================"

foreach dataset in eu wc {

    if "`dataset'" == "eu" {
        local label "EURO"
        use `mbm_eu', clear
    }
    else {
        local label "World Cup"
        use `mbm_wc', clear
    }

    * Compute group-level elo_std using FIFA-rule observations only
    preserve
        keep if FIFA_rule == 1
        collapse (sd) elo_std = elo_avg, by(year stage)
        tempfile elo_std_grp
        save `elo_std_grp'
    restore

    merge m:1 year stage using `elo_std_grp', nogen
    gen FIFA_x_elo_std = FIFA_rule * elo_std

    * Spec 2: baseline LPM
    di _newline "=== `label' — Spec 2 ==="
    di "suspense ~ FIFA_rule + minute + minute^2 + elo_diff + year FE"
    regress suspense FIFA_rule minute minute_sq elo_diff i.year, ///
        vce(cluster group_num)

    * Spec 3: heterogeneous effects by competitive balance
    di _newline "=== `label' — Spec 3 ==="
    di "suspense ~ FIFA_rule + minute + minute^2 + elo_diff + elo_std + FIFA×elo_std + year FE"
    regress suspense FIFA_rule minute minute_sq elo_diff ///
        elo_std FIFA_x_elo_std i.year, vce(cluster group_num)
}

di _newline "All done."


/* ---------------------------------------------------------------------------
   Optional: export regression tables with esttab (requires: ssc install estout)

   Example for Spec 2 & 3 (World Cup):

   use `mbm_wc', clear
   [... add elo_std and FIFA_x_elo_std as above ...]

   estimates store spec2_wc
   estimates store spec3_wc

   esttab spec2_wc spec3_wc using "regression_mbm.tex",                ///
       keep(FIFA_rule minute minute_sq elo_diff elo_std FIFA_x_elo_std) ///
       se star(* 0.10 ** 0.05 *** 0.01)                                 ///
       booktabs replace
   --------------------------------------------------------------------------- */
