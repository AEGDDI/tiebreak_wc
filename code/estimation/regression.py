"""
regression.py
=============
Regression analysis of FIFA vs UEFA tie-breaking rules and group-level suspense.

Spec 1 — Minute-by-minute LPM:
    suspense_imt = alpha + beta*FIFA_rule + gamma*minute + delta*minute^2
                 + lambda*elo_diff_im + year_FE + eps_imt
    Clustered SEs at group (year x stage) level.

Spec 2 — Heterogeneous effects by competitive balance:
    Adds elo_std and FIFA_rule x elo_std interaction to Spec 1.

Outputs LaTeX table to  code/tables/regression_mbm.tex
"""

import warnings
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf
from pathlib import Path

warnings.filterwarnings("ignore")

# ---------------------------------------------------------------------------
# 0.  Paths  (derived automatically from this file's location)
#     regression.py lives at  <repo>/code/estimation/regression.py
#     so parents[2] is the repo root regardless of who runs it or from where.
# ---------------------------------------------------------------------------
ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "out" / "wiki" / "men"
IN   = ROOT / "data" / "in"
OUT  = ROOT / "code" / "tables"
OUT.mkdir(exist_ok=True)

# ---------------------------------------------------------------------------
# 1.  Load data
# ---------------------------------------------------------------------------
mbm_eu_uefa = pd.read_excel(DATA / "uefa" / "eu" / "mbm_eu_uefa.xlsx")
mbm_eu_fifa = pd.read_excel(DATA / "fifa" / "eu" / "mbm_eu_fifa.xlsx")
mbm_wc_uefa = pd.read_excel(DATA / "uefa" / "wc" / "mbm_wc_uefa.xlsx")
mbm_wc_fifa = pd.read_excel(DATA / "fifa" / "wc" / "mbm_wc_fifa.xlsx")

elo_eu = pd.read_excel(IN / "elo_eu.xlsx")
elo_wc = pd.read_excel(IN / "elo_wc.xlsx")

# ---------------------------------------------------------------------------
# 2.  Build stacked MBM datasets
#     For each tournament: enrich FIFA and UEFA data with Elo ratings,
#     stack them (FIFA_rule = 1 / 0), and create derived variables.
# ---------------------------------------------------------------------------
def prepare_mbm(mbm_fifa, mbm_uefa, elo_df):
    """Stack FIFA and UEFA mbm frames; add Elo and derived columns."""
    def enrich(df, rule):
        df = df.copy()
        df["FIFA_rule"] = int(rule)
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

    # Use 'minute' if present, otherwise rename from 'goal_minute'
    if "minute" not in stacked.columns and "goal_minute" in stacked.columns:
        stacked = stacked.rename(columns={"goal_minute": "minute"})

    stacked["minute_sq"] = stacked["minute"] ** 2
    stacked["group_id"]  = stacked["year"].astype(str) + "_" + stacked["stage"]

    return stacked


mbm_eu = prepare_mbm(mbm_eu_fifa, mbm_eu_uefa, elo_eu)
mbm_wc = prepare_mbm(mbm_wc_fifa, mbm_wc_uefa, elo_wc)

# ---------------------------------------------------------------------------
# 3.  Specs 1 & 2: Minute-by-minute LPM
# ---------------------------------------------------------------------------
def _print_coefs(model, vars_of_interest):
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


def run_mbm_specs(df, label):
    results = {}

    # Compute group-level elo_std from FIFA rows only (rule-invariant)
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
            "1",
            "suspense ~ FIFA_rule + minute + minute_sq + elo_diff + C(year)",
            ["suspense", "FIFA_rule", "minute", "minute_sq",
             "elo_diff", "group_id", "year"],
        ),
        (
            "2",
            "suspense ~ FIFA_rule + minute + minute_sq + elo_diff"
            " + elo_std + FIFA_x_elo_std + C(year)",
            ["suspense", "FIFA_rule", "minute", "minute_sq",
             "elo_diff", "elo_std", "FIFA_x_elo_std",
             "group_id", "year"],
        ),
    ]

    for spec, formula, req_cols in specs:
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
print("SPECS 1 & 2: MINUTE-BY-MINUTE LPM")
print("=" * 60)
res_eu_mbm, mbm_eu = run_mbm_specs(mbm_eu, "EURO")
res_wc_mbm, mbm_wc = run_mbm_specs(mbm_wc, "WC")

# ---------------------------------------------------------------------------
# 4.  LaTeX table output
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


def write_latex_table_mbm(res_eu, res_wc, path):
    vars_of_interest = [
        ("FIFA\\_rule",            "FIFA_rule"),
        ("Minute",                 "minute"),
        ("Minute$^2$",             "minute_sq"),
        ("Elo diff",               "elo_diff"),
        ("Elo std",                "elo_std"),
        ("FIFA $\\times$ Elo std", "FIFA_x_elo_std"),
    ]

    def n(m): return f"{int(m.nobs):,}"

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
 & Spec 1 & Spec 2 & Spec 1 & Spec 2 \\
\midrule
"""
    body = ""
    for label, varname in vars_of_interest:
        c_eu1 = coef_row(res_eu["1"], varname)
        c_eu2 = coef_row(res_eu["2"], varname)
        c_wc1 = coef_row(res_wc["1"], varname)
        c_wc2 = coef_row(res_wc["2"], varname)
        body += f"{label} & {c_eu1[0]} & {c_eu2[0]} & {c_wc1[0]} & {c_wc2[0]} \\\\\n"
        body += f"       & {c_eu1[1]} & {c_eu2[1]} & {c_wc1[1]} & {c_wc2[1]} \\\\\n"

    footer = r"""\midrule
""" + \
f"Year FE        & Yes & Yes & Yes & Yes \\\\\n" + \
f"N (obs)        & {n(res_eu['1'])} & {n(res_eu['2'])} & {n(res_wc['1'])} & {n(res_wc['2'])} \\\\\n" + \
r"""\bottomrule
\end{tabular}
\begin{tablenotes}
\small
\item Linear probability model. Standard errors clustered at the group
(year $\times$ stage) level. Outcome is the binary suspense indicator.
All observations are from matchday 3. Spec 2 adds Elo std and its
interaction with FIFA\_rule. $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.
\end{tablenotes}
\end{threeparttable}
\end{table}
"""
    with open(path, "w", encoding="utf-8") as f:
        f.write(header + body + footer)
    print(f"Written: {path}")


write_latex_table_mbm(res_eu_mbm, res_wc_mbm, OUT / "regression_mbm.tex")

print("\nAll done.")
