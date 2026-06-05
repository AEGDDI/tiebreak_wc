* ============================================================
* regression_check.do
* Outputs fifa_rule coefficient for every model spec
* ============================================================

clear all
set more off

local base "C:/Users/aldi/Documents/GitHub/tb_football"
local out  "`base'/code/estimation/stata_results.txt"

capture erase "`out'"

* helper: append fifa_rule AME or coef to file
program drop _all

* ============================================================
* GOALS DATASET
* ============================================================

import excel using "`base'/data/out/goals_merged.xlsx", firstrow clear

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


* M1 main
quietly logit qual_changed fifa_rule elo_favorite elo_underdog, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "M1_main: " %9.4f (r(b)[1,1]) _n
file close f

* M1 + year_c
quietly logit qual_changed fifa_rule elo_favorite elo_underdog year_c, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "M1_yearc: " %9.4f (r(b)[1,1]) _n
file close f

* M1 two qualifying teams
quietly logit qual_changed fifa_rule elo_favorite elo_underdog year_c if third_qualify == 0, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "M1_two_qual: " %9.4f (r(b)[1,1]) _n
file close f

* M1 three qualifying teams
quietly logit qual_changed fifa_rule elo_favorite elo_underdog year_c if third_qualify == 1, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "M1_three_qual: " %9.4f (r(b)[1,1]) _n
file close f

* M1 2-points rule
quietly logit qual_changed fifa_rule elo_favorite elo_underdog year_c if year <= 1992, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "M1_pts2: " %9.4f (r(b)[1,1]) _n
file close f

* M1 3-points rule
quietly logit qual_changed fifa_rule elo_favorite elo_underdog year_c if year > 1992, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "M1_pts3: " %9.4f (r(b)[1,1]) _n
file close f

* M1 elo common support
quietly logit qual_changed fifa_rule elo_favorite elo_underdog year_c if elo_overlap == 1, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "M1_elo_cs: " %9.4f (r(b)[1,1]) _n
file close f


* M2 main
quietly logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "M2_main: " %9.4f (r(b)[1,1]) _n
file close f

* M2 + year_c
quietly logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "M2_yearc: " %9.4f (r(b)[1,1]) _n
file close f

* M2 two qualifying teams
quietly logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c if third_qualify == 0, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "M2_two_qual: " %9.4f (r(b)[1,1]) _n
file close f

* M2 three qualifying teams
quietly logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c if third_qualify == 1, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "M2_three_qual: " %9.4f (r(b)[1,1]) _n
file close f

* M2 2-points rule
quietly logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c if year <= 1992, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "M2_pts2: " %9.4f (r(b)[1,1]) _n
file close f

* M2 3-points rule
quietly logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c if year > 1992, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "M2_pts3: " %9.4f (r(b)[1,1]) _n
file close f

* M2 elo common support
quietly logit qual_changed fifa_rule elo1st elo2nd elo3rd elo4th year_c if elo_overlap == 1, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "M2_elo_cs: " %9.4f (r(b)[1,1]) _n
file close f


* M3 Poisson (group level)
preserve

collapse (max) qual_count third_qualify elo_overlap ///
         (first) elo1st elo2nd elo3rd elo4th year_c g_elo_min g_elo_max, ///
         by(year stage fifa_rule)

* M3 main
quietly poisson qual_count fifa_rule elo1st elo2nd elo3rd elo4th, vce(robust)
file open f using "`out'", write append
file write f "M3_main: " %9.4f (_b[fifa_rule]) _n
file close f

* M3 + year_c
quietly poisson qual_count fifa_rule elo1st elo2nd elo3rd elo4th year_c, vce(robust)
file open f using "`out'", write append
file write f "M3_yearc: " %9.4f (_b[fifa_rule]) _n
file close f

* M3 two qualifying teams
quietly poisson qual_count fifa_rule elo1st elo2nd elo3rd elo4th year_c if third_qualify == 0, vce(robust)
file open f using "`out'", write append
file write f "M3_two_qual: " %9.4f (_b[fifa_rule]) _n
file close f

* M3 three qualifying teams
capture quietly poisson qual_count fifa_rule elo1st elo2nd elo3rd elo4th year_c if third_qualify == 1, vce(robust)
file open f using "`out'", write append
if _rc == 0 {
    file write f "M3_three_qual: " %9.4f (_b[fifa_rule]) _n
}
else {
    file write f "M3_three_qual: skip" _n
}
file close f

* M3 2-points rule
capture quietly poisson qual_count fifa_rule elo1st elo2nd elo3rd elo4th year_c if year <= 1992, vce(robust)
file open f using "`out'", write append
if _rc == 0 {
    file write f "M3_pts2: " %9.4f (_b[fifa_rule]) _n
}
else {
    file write f "M3_pts2: skip" _n
}
file close f

* M3 3-points rule
quietly poisson qual_count fifa_rule elo1st elo2nd elo3rd elo4th year_c if year > 1992, vce(robust)
file open f using "`out'", write append
file write f "M3_pts3: " %9.4f (_b[fifa_rule]) _n
file close f

* M3 elo common support
quietly poisson qual_count fifa_rule elo1st elo2nd elo3rd elo4th year_c if elo_overlap == 1, vce(robust)
file open f using "`out'", write append
file write f "M3_elo_cs: " %9.4f (_b[fifa_rule]) _n
file close f

restore


* ============================================================
* MBM DATASET
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

* MBM main
quietly logit suspense fifa_rule elo1st elo2nd elo3rd elo4th, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "MBM_main: " %9.4f (r(b)[1,1]) _n
file close f

* MBM + year_c
quietly logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "MBM_yearc: " %9.4f (r(b)[1,1]) _n
file close f

* MBM two qualifying teams
quietly logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c if third_qualify == 0, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "MBM_two_qual: " %9.4f (r(b)[1,1]) _n
file close f

* MBM three qualifying teams
quietly logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c if third_qualify == 1, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "MBM_three_qual: " %9.4f (r(b)[1,1]) _n
file close f

* MBM 2-points rule
quietly logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c if year <= 1992, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "MBM_pts2: " %9.4f (r(b)[1,1]) _n
file close f

* MBM 3-points rule
quietly logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c if year > 1992, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "MBM_pts3: " %9.4f (r(b)[1,1]) _n
file close f

* MBM elo common support
quietly logit suspense fifa_rule elo1st elo2nd elo3rd elo4th year_c if elo_overlap == 1, vce(cluster group_num)
quietly margins, dydx(fifa_rule)
file open f using "`out'", write append
file write f "MBM_elo_cs: " %9.4f (r(b)[1,1]) _n
file close f
