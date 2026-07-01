* ============================================================
* regression.do
* ============================================================

clear all
set more off

local base "C:/Users/`c(username)'/Documents/GitHub/tb_football"


* ============================================================
* GOALS DATASET
* ============================================================

import excel using "`base'/data/out/goals_merged.xlsx", firstrow clear

gen group_id = string(year) + "_" + stage + "_" + string(fifa_rule)
encode group_id, gen(group_num)
gen year_c = year - 2000

* Group-level elo min and max (weakest and strongest team in each group)
bysort year stage fifa_rule: gen g_elo_min = elo4th[1]
bysort year stage fifa_rule: gen g_elo_max = elo1st[1]

* Elo common-support filter: keep groups whose elo range falls within the
* interval [max(wc_floor, eu_floor), min(wc_ceiling, eu_ceiling)]
quietly summarize elo4th if fifa_rule == 1
scalar wc_min = r(min)
quietly summarize elo1st if fifa_rule == 1
scalar wc_max = r(max)
quietly summarize elo4th if fifa_rule == 0
scalar eu_min = r(min)
quietly summarize elo1st if fifa_rule == 0
scalar eu_max = r(max)

scalar elo_lower = max(wc_min, eu_min)
scalar elo_upper = min(wc_max, eu_max)
gen elo_overlap = (g_elo_min >= elo_lower) & (g_elo_max <= elo_upper)


* -------------------------------------------------------
* Model 1 — qual_changed = f(fifa_rule, elo_favorite, elo_underdog)
* Logit, average marginal effects, clustered SE at group level
* -------------------------------------------------------

* Main
logit qual_changed fifa_rule elo_favorite elo_underdog, vce(cluster group_num)
margins, dydx(*)

* With year trend and year x fifa_rule interaction
* (Year fixed effects omitted: WC and EU alternate years, so year dummies
*  would be collinear with fifa_rule and the treatment would be unidentified)
logit qual_changed fifa_rule elo_favorite elo_underdog year_c, vce(cluster group_num)
margins, dydx(*)

* Robustness: two qualifying teams per group
logit qual_changed fifa_rule elo_favorite elo_underdog year_c if third_qualify == 0, vce(cluster group_num)
margins, dydx(*)

* Robustness: three qualifying teams per group
logit qual_changed fifa_rule elo_favorite elo_underdog year_c if third_qualify == 1, vce(cluster group_num)
margins, dydx(*)

* Robustness: 2-points rule (year <= 1992)
logit qual_changed fifa_rule elo_favorite elo_underdog year_c if year <= 1992, vce(cluster group_num)
margins, dydx(*)

* Robustness: 3-points rule (year > 1992)
logit qual_changed fifa_rule elo_favorite elo_underdog year_c if year > 1992, vce(cluster group_num)
margins, dydx(*)

* Robustness: elo common support
logit qual_changed fifa_rule elo_favorite elo_underdog year_c if elo_overlap == 1, vce(cluster group_num)
margins, dydx(*)


* -------------------------------------------------------
* Model 2 — qual_changed = f(fifa_rule, elo1st, ..., elo4th)
* Logit, average marginal effects, clustered SE at group level
* -------------------------------------------------------

* Main
logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th, vce(cluster group_num)
margins, dydx(*)

* With year trend
logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c, vce(cluster group_num)
margins, dydx(*)

* Robustness: two qualifying teams
logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c if third_qualify == 0, vce(cluster group_num)
margins, dydx(*)

* Robustness: three qualifying teams
logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c if third_qualify == 1, vce(cluster group_num)
margins, dydx(*)

* Robustness: 2-points rule
logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c if year <= 1992, vce(cluster group_num)
margins, dydx(*)

* Robustness: 3-points rule
logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c if year > 1992, vce(cluster group_num)
margins, dydx(*)

* Robustness: elo common support
logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c if elo_overlap == 1, vce(cluster group_num)
margins, dydx(*)


* -------------------------------------------------------
* Model 3 — Poisson count, group level
* Collapse to one row per group using max(qual_count)
* -------------------------------------------------------

preserve

collapse (max) qual_count third_qualify elo_overlap ///
         (first) elo1st elo2nd elo3rd elo4th year_c g_elo_min g_elo_max, ///
         by(year stage fifa_rule)

* Main
poisson qual_count fifa_rule elo1st elo2nd elo3rd elo4th, vce(robust)

* With year trend
poisson qual_count fifa_rule elo1st elo2nd elo3rd elo4th year_c, vce(robust)

* Robustness: two qualifying teams
poisson qual_count fifa_rule elo1st elo2nd elo3rd elo4th year_c if third_qualify == 0, vce(robust)

* Robustness: three qualifying teams
poisson qual_count fifa_rule elo1st elo2nd elo3rd elo4th year_c if third_qualify == 1, vce(robust)

* Robustness: 2-points rule
poisson qual_count fifa_rule elo1st elo2nd elo3rd elo4th year_c if year <= 1992, vce(robust)

* Robustness: 3-points rule
poisson qual_count fifa_rule elo1st elo2nd elo3rd elo4th year_c if year > 1992, vce(robust)

* Robustness: elo common support
poisson qual_count fifa_rule elo1st elo2nd elo3rd elo4th year_c if elo_overlap == 1, vce(robust)

restore


* -------------------------------------------------------
* Model 4 — Logit for suspense, match-level Elo (goals dataset)
* suspense = f(fifa_rule, elo_favorite, elo_underdog)
* -------------------------------------------------------

* Main
logit suspense fifa_rule elo_favorite elo_underdog, vce(cluster group_num)
margins, dydx(*)

* With year trend
logit suspense fifa_rule elo_favorite elo_underdog year_c, vce(cluster group_num)
margins, dydx(*)

* Robustness: two qualifying teams
logit suspense fifa_rule elo_favorite elo_underdog year_c if third_qualify == 0, vce(cluster group_num)
margins, dydx(*)

* Robustness: three qualifying teams
logit suspense fifa_rule elo_favorite elo_underdog year_c if third_qualify == 1, vce(cluster group_num)
margins, dydx(*)

* Robustness: 2-points rule
logit suspense fifa_rule elo_favorite elo_underdog year_c if year <= 1992, vce(cluster group_num)
margins, dydx(*)

* Robustness: 3-points rule
logit suspense fifa_rule elo_favorite elo_underdog year_c if year > 1992, vce(cluster group_num)
margins, dydx(*)

* Robustness: elo common support
logit suspense fifa_rule elo_favorite elo_underdog year_c if elo_overlap == 1, vce(cluster group_num)
margins, dydx(*)


* -------------------------------------------------------
* Model 5 — Logit for suspense, group-level Elo (goals dataset)
* suspense = f(fifa_rule, elo1st, ..., elo4th)
* -------------------------------------------------------

* Main
logit suspense fifa_rule elo1st elo2nd elo3rd elo4th, vce(cluster group_num)
margins, dydx(*)

* With year trend
logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c, vce(cluster group_num)
margins, dydx(*)

* Robustness: two qualifying teams
logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c if third_qualify == 0, vce(cluster group_num)
margins, dydx(*)

* Robustness: three qualifying teams
logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c if third_qualify == 1, vce(cluster group_num)
margins, dydx(*)

* Robustness: 2-points rule
logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c if year <= 1992, vce(cluster group_num)
margins, dydx(*)

* Robustness: 3-points rule
logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c if year > 1992, vce(cluster group_num)
margins, dydx(*)

* Robustness: elo common support
logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c if elo_overlap == 1, vce(cluster group_num)
margins, dydx(*)


* ============================================================
* MBM DATASET — Suspense model
* suspense = f(fifa_rule, elo1st, ..., elo4th)
* Logit, average marginal effects, clustered SE at group level
* ============================================================

import excel using "`base'/data/out/mbm_merged.xlsx", firstrow clear

gen group_id = string(year) + "_" + stage + "_" + string(fifa_rule)
encode group_id, gen(group_num)
gen year_c = year - 2000

bysort year stage fifa_rule: gen g_elo_min = elo4th[1]
bysort year stage fifa_rule: gen g_elo_max = elo1st[1]

quietly summarize elo4th if fifa_rule == 1
scalar wc_min = r(min)
quietly summarize elo1st if fifa_rule == 1
scalar wc_max = r(max)
quietly summarize elo4th if fifa_rule == 0
scalar eu_min = r(min)
quietly summarize elo1st if fifa_rule == 0
scalar eu_max = r(max)

scalar elo_lower = max(wc_min, eu_min)
scalar elo_upper = min(wc_max, eu_max)
gen elo_overlap = (g_elo_min >= elo_lower) & (g_elo_max <= elo_upper)

* Main
logit suspense fifa_rule elo1st elo2nd elo3rd elo4th, vce(cluster group_num)
margins, dydx(*)

* With year trend
logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c, vce(cluster group_num)
margins, dydx(*)

* Robustness: two qualifying teams
logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c if third_qualify == 0, vce(cluster group_num)
margins, dydx(*)

* Robustness: three qualifying teams
logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c if third_qualify == 1, vce(cluster group_num)
margins, dydx(*)

* Robustness: 2-points rule
logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c if year <= 1992, vce(cluster group_num)
margins, dydx(*)

* Robustness: 3-points rule
logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c if year > 1992, vce(cluster group_num)
margins, dydx(*)

* Robustness: elo common support
logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c if elo_overlap == 1, vce(cluster group_num)
margins, dydx(*)


* -------------------------------------------------------
* MBM Model B — Logit for qualification change (MBM dataset)
* qual_changed = f(fifa_rule, elo1st, ..., elo4th)
* Logit, average marginal effects, clustered SE at group level
* -------------------------------------------------------

* Main
logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th, vce(cluster group_num)
margins, dydx(*)

* With year trend
logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c, vce(cluster group_num)
margins, dydx(*)

* Robustness: two qualifying teams
logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c if third_qualify == 0, vce(cluster group_num)
margins, dydx(*)

* Robustness: three qualifying teams
logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c if third_qualify == 1, vce(cluster group_num)
margins, dydx(*)

* Robustness: 2-points rule
logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c if year <= 1992, vce(cluster group_num)
margins, dydx(*)

* Robustness: 3-points rule
logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c if year > 1992, vce(cluster group_num)
margins, dydx(*)

* Robustness: elo common support
logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c if elo_overlap == 1, vce(cluster group_num)
margins, dydx(*)
