"""
regression.py
=============
Spec 1 — Goal-level LPM (baseline)
Spec 2 — Adds elo_std and FIFA_rule × elo_std (heterogeneous effects)

Unit of observation: a goal scored during matchday 3.
Elo ratings are already embedded in the goals files, so no separate merge
is needed. Initial-state rows (goal_minute = 0, no Elo) are dropped
automatically by dropna when fitting the models.
"""

import warnings
import pandas as pd
import statsmodels.formula.api as smf
from pathlib import Path

warnings.filterwarnings("ignore")

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "out" / "wiki" / "men"
OUT  = ROOT / "code" / "tables"
OUT.mkdir(exist_ok=True)

# ---------------------------------------------------------------------------
# 1.  Load goals datasets (matchday 3 only, Elo already embedded)
# ---------------------------------------------------------------------------
goals_eu_fifa = pd.read_excel(DATA / "fifa" / "eu" / "goals_eu_fifa.xlsx")
goals_eu_uefa = pd.read_excel(DATA / "uefa" / "eu" / "goals_eu_uefa.xlsx")
goals_wc_fifa = pd.read_excel(DATA / "fifa" / "wc" / "goals_wc_fifa.xlsx")
goals_wc_uefa = pd.read_excel(DATA / "uefa" / "wc" / "goals_wc_uefa.xlsx")

print("=== Raw dataset sizes ===")
for name, df in [("goals_eu_fifa", goals_eu_fifa), ("goals_eu_uefa", goals_eu_uefa),
                 ("goals_wc_fifa", goals_wc_fifa), ("goals_wc_uefa", goals_wc_uefa)]:
    print(f"  {name}: {len(df):>4} rows  |  initial-state rows (no Elo): {df['elo_home'].isna().sum()}")

# ---------------------------------------------------------------------------
# 2.  Build stacked datasets
# ---------------------------------------------------------------------------
def build_df(goals_fifa, goals_uefa, label):
    goals_fifa = goals_fifa.copy(); goals_fifa["FIFA_rule"] = 1
    goals_uefa = goals_uefa.copy(); goals_uefa["FIFA_rule"] = 0
    df = pd.concat([goals_fifa, goals_uefa], ignore_index=True)

    df["elo_diff"]  = (df["elo_home"] - df["elo_away"]).abs()
    df["elo_avg"]   = (df["elo_home"] + df["elo_away"]) / 2
    df              = df.rename(columns={"goal_minute": "minute"})
    df["minute_sq"] = df["minute"] ** 2
    df["group_id"]  = df["year"].astype(str) + "_" + df["stage"]

    req = ["suspense", "FIFA_rule", "minute", "minute_sq", "elo_diff", "group_id", "year"]
    n_complete = df.dropna(subset=req).shape[0]
    print(f"\n{label}: {len(df)} rows stacked  →  {n_complete} goal events with complete data")
    return df


eu = build_df(goals_eu_fifa, goals_eu_uefa, "EURO")
wc = build_df(goals_wc_fifa, goals_wc_uefa, "WC")

# ---------------------------------------------------------------------------
# 3.  Run Spec 1 and Spec 2
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
    print(f"N = {int(model.nobs)}")


def run_specs(df, label):
    # Group-level elo_std computed from FIFA rows only (rule-invariant)
    elo_std = (
        df[df["FIFA_rule"] == 1]
        .groupby(["year", "stage"])["elo_avg"]
        .std()
        .reset_index()
        .rename(columns={"elo_avg": "elo_std"})
    )
    df = df.merge(elo_std, on=["year", "stage"], how="left")
    df["FIFA_x_elo_std"] = df["FIFA_rule"] * df["elo_std"]

    req1 = ["suspense", "FIFA_rule", "minute", "minute_sq", "elo_diff", "group_id", "year"]
    req2 = req1 + ["elo_std", "FIFA_x_elo_std"]

    df1 = df.dropna(subset=req1)
    df2 = df.dropna(subset=req2)

    print(f"\n{'='*60}")
    print(f"{label} — Spec 1   N = {len(df1)}")
    m1 = smf.ols(
        "suspense ~ FIFA_rule + minute + minute_sq + elo_diff + C(year)",
        data=df1
    ).fit(cov_type="cluster", cov_kwds={"groups": df1["group_id"].values})
    _print_coefs(m1, ["FIFA_rule", "minute", "minute_sq", "elo_diff"])

    print(f"\n{label} — Spec 2   N = {len(df2)}")
    m2 = smf.ols(
        "suspense ~ FIFA_rule + minute + minute_sq + elo_diff"
        " + elo_std + FIFA_x_elo_std + C(year)",
        data=df2
    ).fit(cov_type="cluster", cov_kwds={"groups": df2["group_id"].values})
    _print_coefs(m2, ["FIFA_rule", "minute", "minute_sq", "elo_diff",
                      "elo_std", "FIFA_x_elo_std"])
    return m1, m2


print("\n" + "=" * 60)
print("SPECS 1 & 2: GOAL-LEVEL LPM")
print("=" * 60)
m_eu1, m_eu2 = run_specs(eu, "EURO")
m_wc1, m_wc2 = run_specs(wc, "WC")

print("\nAll done.")
