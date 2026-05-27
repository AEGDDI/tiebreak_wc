"""
regression.py
=============
Regression analysis of FIFA vs UEFA tie-breaking rules and group-level suspense.

Two main specifications:
  Spec 1 — Group-level paired design:
    delta_suspense_g = alpha + beta * elo_std_g + gamma * matchday3_share_g + eps_g
    where delta = mean_suspense_FIFA - mean_suspense_UEFA for group g.

  Spec 2 — Minute-by-minute linear probability model (LPM):
    suspense_imt = alpha + beta*FIFA_rule + gamma*minute + delta*minute^2
                 + lambda*elo_diff_im + mu*matchday_im
                 + group_FE + year_FE + eps_imt
    Clustered SEs at group (year x stage) level.

  Spec 3 — Heterogeneous effects by competitive balance:
    Adds FIFA_rule x elo_std interaction to Spec 2.

Run from the repo root or set USER below.  Outputs LaTeX tables to
  code/tables/regression_grp.tex
  code/tables/regression_mbm.tex
"""

import os
import getpass
import warnings
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf
from scipy.stats import ttest_rel, wilcoxon

warnings.filterwarnings("ignore")

# ---------------------------------------------------------------------------
# 0.  Paths
# ---------------------------------------------------------------------------
user = getpass.getuser()
ROOT = rf"C:\Users\{user}\Documents\GitHub\tiebreak_wc"
DATA = os.path.join(ROOT, "data", "out", "wiki", "men")
IN   = os.path.join(ROOT, "data", "in")
OUT  = os.path.join(ROOT, "code", "tables")
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------------------
# 1.  Load data
# ---------------------------------------------------------------------------
goals_eu_uefa = pd.read_excel(os.path.join(DATA, "uefa", "eu", "goals_eu_uefa.xlsx"))
goals_eu_fifa = pd.read_excel(os.path.join(DATA, "fifa", "eu", "goals_eu_fifa.xlsx"))
goals_wc_uefa = pd.read_excel(os.path.join(DATA, "uefa", "wc", "goals_wc_uefa.xlsx"))
goals_wc_fifa = pd.read_excel(os.path.join(DATA, "fifa", "wc", "goals_wc_fifa.xlsx"))

mbm_eu_uefa = pd.read_excel(os.path.join(DATA, "uefa", "eu", "mbm_eu_uefa.xlsx"))
mbm_eu_fifa = pd.read_excel(os.path.join(DATA, "fifa", "eu", "mbm_eu_fifa.xlsx"))
mbm_wc_uefa = pd.read_excel(os.path.join(DATA, "uefa", "wc", "mbm_wc_uefa.xlsx"))
mbm_wc_fifa = pd.read_excel(os.path.join(DATA, "fifa", "wc", "mbm_wc_fifa.xlsx"))

elo_eu = pd.read_excel(os.path.join(IN, "elo_eu.xlsx"))
elo_wc = pd.read_excel(os.path.join(IN, "elo_wc.xlsx"))

# ---------------------------------------------------------------------------
# 2.  Helper: group-level aggregation
# ---------------------------------------------------------------------------
def aggregate_group(df, elo_df):
    """
    Return one row per (year, stage) with:
      avg_suspense, avg_qual_count, elo_std, elo_avg.
    All observations are from matchday 3 by construction.
    """
    # Elo merge for home team
    df = df.merge(
        elo_df[["year", "team", "elo_rating"]].rename(
            columns={"team": "home_team", "elo_rating": "home_elo"}
        ),
        on=["year", "home_team"], how="left",
    )
    df = df.merge(
        elo_df[["year", "team", "elo_rating"]].rename(
            columns={"team": "away_team", "elo_rating": "away_elo"}
        ),
        on=["year", "away_team"], how="left",
    )
    df["elo_avg"] = df[["home_elo", "away_elo"]].mean(axis=1)
    df["elo_diff"] = (df["home_elo"] - df["away_elo"]).abs()

    agg = df.groupby(["year", "stage"]).agg(
        avg_suspense   = ("suspense",   "mean"),
        avg_qual_count = ("qual_count", "mean"),
        elo_avg        = ("elo_avg",    "mean"),
        elo_std        = ("elo_avg",    "std"),
        elo_diff_avg   = ("elo_diff",   "mean"),
        n_obs          = ("suspense",   "count"),
    ).reset_index()
    return agg


agg_eu_fifa = aggregate_group(goals_eu_fifa, elo_eu)
agg_eu_uefa = aggregate_group(goals_eu_uefa, elo_eu)
agg_wc_fifa = aggregate_group(goals_wc_fifa, elo_wc)
agg_wc_uefa = aggregate_group(goals_wc_uefa, elo_wc)

# ---------------------------------------------------------------------------
# 3.  Spec 1: Group-level paired regression
# ---------------------------------------------------------------------------
# Delta = FIFA - UEFA for each group
def make_paired(agg_fifa, agg_uefa):
    paired = agg_fifa.merge(
        agg_uefa,
        on=["year", "stage"],
        suffixes=("_fifa", "_uefa"),
    )
    paired["delta_suspense"]   = paired["avg_suspense_fifa"]   - paired["avg_suspense_uefa"]
    paired["delta_qual_count"] = paired["avg_qual_count_fifa"] - paired["avg_qual_count_uefa"]
    # Use FIFA-side Elo (identical under both rules)
    paired["elo_std"]          = paired["elo_std_fifa"]
    paired["elo_diff_avg"]     = paired["elo_diff_avg_fifa"]
    paired["group_id"]         = paired["year"].astype(str) + "_" + paired["stage"]
    return paired

paired_eu = make_paired(agg_eu_fifa, agg_eu_uefa)
paired_wc = make_paired(agg_wc_fifa, agg_wc_uefa)

# Spec 1a — simple: delta ~ elo_std
# Spec 1b — full: delta ~ elo_std + C(year)  (year FEs absorb tournament-level trends)
def _print_coefs(model, vars_of_interest):
    """Print coefficient table using model attributes (version-agnostic)."""
    header = f"{'Variable':<28} {'Coef':>10} {'SE':>10} {'t':>8} {'p':>8}"
    print(header)
    print("-" * len(header))
    for v in vars_of_interest:
        if v not in model.params.index:
            continue
        stars = ("***" if model.pvalues[v] < 0.01 else
                 "**"  if model.pvalues[v] < 0.05 else
                 "*"   if model.pvalues[v] < 0.10 else "")
        print(f"{v:<28} {model.params[v]:>10.4f} {model.bse[v]:>10.4f}"
              f" {model.tvalues[v]:>8.3f} {model.pvalues[v]:>8.3f}{stars}")
    print(f"N={int(model.nobs)}")


def run_paired_specs(paired, label):
    results = {}
    for spec, formula in [
        ("1a", "delta_suspense ~ elo_std"),
        ("1b", "delta_suspense ~ elo_std + C(year)"),
    ]:
        m = smf.ols(formula, data=paired).fit(cov_type="HC1")
        results[spec] = m
        print(f"\n=== {label} — Spec {spec} ===")
        _print_coefs(m, ["elo_std"])
    return results

print("\n" + "=" * 60)
print("SPEC 1: GROUP-LEVEL PAIRED REGRESSIONS")
print("=" * 60)
res_eu_grp = run_paired_specs(paired_eu, "EURO")
res_wc_grp = run_paired_specs(paired_wc, "WC")

# ---------------------------------------------------------------------------
# 4.  Spec 2 & 3: Minute-by-minute LPM
# ---------------------------------------------------------------------------
def prepare_mbm(mbm_fifa, mbm_uefa, elo_df):
    """Stack FIFA and UEFA mbm frames; add Elo and derived columns."""
    def enrich(df, rule):
        df = df.copy()
        df["FIFA_rule"] = int(rule)
        # Elo merge
        df = df.merge(
            elo_df[["year", "team", "elo_rating"]].rename(
                columns={"team": "home_team", "elo_rating": "home_elo"}
            ),
            on=["year", "home_team"], how="left",
        )
        df = df.merge(
            elo_df[["year", "team", "elo_rating"]].rename(
                columns={"team": "away_team", "elo_rating": "away_elo"}
            ),
            on=["year", "away_team"], how="left",
        )
        df["elo_diff"] = (df["home_elo"] - df["away_elo"]).abs()
        df["elo_avg"]  = df[["home_elo", "away_elo"]].mean(axis=1)
        return df

    stacked = pd.concat([enrich(mbm_fifa, 1), enrich(mbm_uefa, 0)], ignore_index=True)

    # Minute column: use 'minute' if present, else 'goal_minute'
    if "minute" not in stacked.columns and "goal_minute" in stacked.columns:
        stacked = stacked.rename(columns={"goal_minute": "minute"})

    stacked["minute_sq"] = stacked["minute"] ** 2

    # Group identifier for clustering
    stacked["group_id"] = stacked["year"].astype(str) + "_" + stacked["stage"]

    return stacked


mbm_eu = prepare_mbm(mbm_eu_fifa, mbm_eu_uefa, elo_eu)
mbm_wc = prepare_mbm(mbm_wc_fifa, mbm_wc_uefa, elo_wc)


def run_mbm_specs(df, label):
    results = {}

    # Build group elo_std once (use FIFA-side rows so it's rule-invariant)
    elo_by_group = (
        df[df["FIFA_rule"] == 1]
        .groupby(["year", "stage"])["elo_avg"]
        .std()
        .reset_index()
        .rename(columns={"elo_avg": "elo_std"})
    )
    df = df.merge(elo_by_group, on=["year", "stage"], how="left")
    df["FIFA_x_elo_std"] = df["FIFA_rule"] * df["elo_std"]

    specs = [
        (
            "2",
            "suspense ~ FIFA_rule + minute + minute_sq + elo_diff + C(year)",
            ["suspense", "FIFA_rule", "minute", "minute_sq",
             "elo_diff", "group_id", "year"],
        ),
        (
            "3",
            "suspense ~ FIFA_rule + minute + minute_sq + elo_diff"
            " + elo_std + FIFA_x_elo_std + C(year)",
            ["suspense", "FIFA_rule", "minute", "minute_sq",
             "elo_diff", "elo_std", "FIFA_x_elo_std",
             "group_id", "year"],
        ),
    ]

    for spec, formula, req_cols in specs:
        # Drop rows with any NaN in required columns so that the groups
        # array length always matches the model's observation count.
        df_fit = df.dropna(subset=req_cols).copy()
        m = smf.ols(formula, data=df_fit).fit(
            cov_type="cluster",
            cov_kwds={"groups": df_fit["group_id"].values},
        )
        results[spec] = m
        print(f"\n=== {label} — Spec {spec} ===")
        _print_coefs(m, ["FIFA_rule", "minute", "minute_sq", "elo_diff",
                         "elo_std", "FIFA_x_elo_std"])
    return results, df


print("\n" + "=" * 60)
print("SPEC 2 & 3: MINUTE-BY-MINUTE LPM")
print("=" * 60)
res_eu_mbm, mbm_eu = run_mbm_specs(mbm_eu, "EURO")
res_wc_mbm, mbm_wc = run_mbm_specs(mbm_wc, "WC")

# ---------------------------------------------------------------------------
# 5.  LaTeX table output
# ---------------------------------------------------------------------------
def coef_row(model, varname, fmt="{:.4f}"):
    """Return (coef_str, se_str, stars) for a variable in a fitted model."""
    try:
        coef = model.params[varname]
        se   = model.bse[varname]
        pval = model.pvalues[varname]
    except KeyError:
        return "---", "---", ""
    stars = (
        "***" if pval < 0.01 else
        "**"  if pval < 0.05 else
        "*"   if pval < 0.10 else ""
    )
    return fmt.format(coef) + stars, "(" + fmt.format(se) + ")", stars


def write_latex_table_grp(res_eu, res_wc, path):
    rows_eu_1a = coef_row(res_eu["1a"], "elo_std")
    rows_eu_1b = coef_row(res_eu["1b"], "elo_std")
    rows_wc_1a = coef_row(res_wc["1a"], "elo_std")
    rows_wc_1b = coef_row(res_wc["1b"], "elo_std")

    def n(m):  return str(int(m.nobs))

    tex = r"""
\begin{table}[H]
\centering
\caption{Group-level paired regression: $\Delta\,\overline{\text{suspense}}_g = \overline{\text{suspense}}^{\text{FIFA}}_g - \overline{\text{suspense}}^{\text{UEFA}}_g$}
\label{tab:regression_grp}
\begin{threeparttable}
\begin{tabular}{lcccc}
\toprule
 & \multicolumn{2}{c}{European Championship} & \multicolumn{2}{c}{World Cup} \\
\cmidrule(lr){2-3}\cmidrule(lr){4-5}
 & (1a) & (1b) & (2a) & (2b) \\
\midrule
""" + \
f"Elo std & {rows_eu_1a[0]} & {rows_eu_1b[0]} & {rows_wc_1a[0]} & {rows_wc_1b[0]} \\\\\n" + \
f"        & {rows_eu_1a[1]} & {rows_eu_1b[1]} & {rows_wc_1a[1]} & {rows_wc_1b[1]} \\\\\n" + \
r"\midrule" + "\n" + \
f"Year FE & No & Yes & No & Yes \\\\\n" + \
f"N groups & {n(res_eu['1a'])} & {n(res_eu['1b'])} & {n(res_wc['1a'])} & {n(res_wc['1b'])} \\\\\n" + \
r"""\bottomrule
\end{tabular}
\begin{tablenotes}
\small
\item OLS with HC1 robust standard errors. All observations are from matchday 3.
Dependent variable is the within-group difference in mean suspense (FIFA minus UEFA).
$^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.
\end{tablenotes}
\end{threeparttable}
\end{table}
"""
    with open(path, "w", encoding="utf-8") as f:
        f.write(tex)
    print(f"Written: {path}")


def write_latex_table_mbm(res_eu, res_wc, path):
    vars_of_interest = [
        ("FIFA\\_rule",            "FIFA_rule"),
        ("Minute",                 "minute"),
        ("Minute$^2$",             "minute_sq"),
        ("Elo diff",               "elo_diff"),
        ("Elo std",                "elo_std"),
        ("FIFA $\\times$ Elo std", "FIFA_x_elo_std"),
    ]

    def n(m):  return f"{int(m.nobs):,}"

    header = r"""
\begin{table}[H]
\centering
\caption{Minute-by-minute LPM: effect of FIFA tie-breaking rule on suspense}
\label{tab:regression_mbm}
\begin{threeparttable}
\begin{tabular}{lcccc}
\toprule
 & \multicolumn{2}{c}{European Championship} & \multicolumn{2}{c}{World Cup} \\
\cmidrule(lr){2-3}\cmidrule(lr){4-5}
 & Spec 2 & Spec 3 & Spec 2 & Spec 3 \\
\midrule
"""
    body = ""
    for label, varname in vars_of_interest:
        c_eu2 = coef_row(res_eu["2"], varname)
        c_eu3 = coef_row(res_eu["3"], varname)
        c_wc2 = coef_row(res_wc["2"], varname)
        c_wc3 = coef_row(res_wc["3"], varname)
        body += f"{label} & {c_eu2[0]} & {c_eu3[0]} & {c_wc2[0]} & {c_wc3[0]} \\\\\n"
        body += f"       & {c_eu2[1]} & {c_eu3[1]} & {c_wc2[1]} & {c_wc3[1]} \\\\\n"

    footer = r"""\midrule
""" + \
f"Year FE        & Yes & Yes & Yes & Yes \\\\\n" + \
f"N (obs)        & {n(res_eu['2'])} & {n(res_eu['3'])} & {n(res_wc['2'])} & {n(res_wc['3'])} \\\\\n" + \
r"""\bottomrule
\end{tabular}
\begin{tablenotes}
\small
\item Linear probability model. Standard errors clustered at the group
(year $\times$ stage) level. Outcome is the binary suspense indicator.
All observations are from matchday 3. Spec 3 adds Elo std and its
interaction with FIFA\_rule. $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.
\end{tablenotes}
\end{threeparttable}
\end{table}
"""
    with open(path, "w", encoding="utf-8") as f:
        f.write(header + body + footer)
    print(f"Written: {path}")


write_latex_table_grp(res_eu_grp, res_wc_grp,
                      os.path.join(OUT, "regression_grp.tex"))
write_latex_table_mbm(res_eu_mbm, res_wc_mbm,
                      os.path.join(OUT, "regression_mbm.tex"))

print("\nAll done.")
