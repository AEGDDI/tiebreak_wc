# Suspense in International Football Group Stages: A Comparison of FIFA and UEFA Tie-Breaking Rules

This repository accompanies a research paper that analyzes the impact of tie-breaking rules on suspense levels during the group stages of international football tournaments. The paper compares the criteria used by **FIFA** and **UEFA** when teams are level on points.

## Objective

The goal of the paper is to evaluate how different tie-breaking rules affect the suspense in group standings. Specifically, it compares the following systems:

- **FIFA**: Goal Difference > Goals Scored > Head-to-Head
- **UEFA**: Head-to-Head > Goal Difference > Goals Scored

By applying both rule sets to historical group stage data, the paper investigates which system tends to produce more suspenseful scenarios.

## Defining Suspense

Suspense is defined as the proximity to a potential change in the composition of teams qualifying for the knockout stage. More precisely:

> *A suspenseful moment occurs when a single goal in a group could alter the composition of teams qualifying to the elimination stage.*

For example, in Group F of Euro 2024, entering the third and final matchday, Portugal and Turkey were in qualifying positions for the knockout stage. However, Turkey was playing against Czech Republic, and the match started 0–0. In that situation, a single goal by Czech Republic would have allowed them to overtake Turkey on points and qualify instead. Since the qualification status could change dramatically with just one goal, this scenario is marked as having maximum suspense (suspense = 1).

  Another example can be drawn from Group A of Euro 2024. In the final matchday, Hungary scored in the 100th minute against Scotland, winning the match 1–0. At that point, this late goal put Hungary at 3 points with a goal difference of -3, making them temporarily one of the best third-placed teams, and therefore potentially qualifying for the knockout stage.

It seems reasonable to assume that before Hungary's goal, the level of suspense was already quite high, as both Hungary and Scotland still had hopes of qualifying as one of the best third-placed teams. A goal from either side could have shifted the standings and affected the third-place rankings across groups.

  At the time of Hungary’s goal, the four best third-placed teams included Hungary, while Albania (Group B) and Czech Republic (Group F) were the ones excluded. However, by the end of the group stage, Georgia (Group F) would overtake Hungary, qualifying instead and eliminating Hungary. This is a posterior development that is not considered in the real-time suspense calculation for Group A. Suspense is evaluated based on the uncertainty during the match, not on outcomes from matches that are played later.

A full explanation of how suspense has been formally defined can be found in [`suspense.docx`](https://github.com/AEGDDI/tiebreak_wc/tree/main/docx/suspense.docx)
## Data

We collected and processed data from:

- **UEFA European Championships**: from the 1984 edition up to Euro 2020
- **FIFA World Cups**: from the 1994 edition up to the 2022 World Cup

Data sources include both **Wikipedia** and **Kaggle**.

- [`data/in/`](https://github.com/AEGDDI/tiebreak_wc/tree/main/data/in): This folder contains raw data on goals scored during group stage matches in both the UEFA European Championships and FIFA World Cups, along with the **Elo ratings** of the teams, **bookings**, and ** substitutions**.
- [`data/out/`](https://github.com/AEGDDI/tiebreak_wc/tree/main/data/out/wiki): This folder contains processed datasets built to evaluate minute-by-minute group composition and the potential for changes in qualification, according to both FIFA and UEFA tie-breaking criteria.

## Repository Structure

- `data/in/`: Raw match data, Elo ratings, bookings, and subsitituions. 
- `data/out/`: Processed group dynamics data for suspense analysis

## Results

### Correlation Analysis

We computed pairwise correlations between the following group-level metrics:

- `elo_std`: the standard deviation of Elo ratings within each group (a proxy for competitive imbalance),
- `avg_qual_count`: average number of changes in the composition of teams qualifying for the elimination stage,
- `avg_suspense`: average suspense in a group

**Key insights from the correlation analysis include:**

- **Qualification Dynamics Drive Suspense**  
  Across datasets, the **number of changes in qualifying teams (`avg_qual_count`) shows a consistent positive correlation with suspense**, especially in **FIFA World Cups**
- **Elo Imbalance Affects Suspense Differently**  
  - In the **European Championships**, particularly with **minute-by-minute (MBM)** data, **Elo imbalance (`elo_std`) appears weakly or not correlated** with suspense.
  - In contrast, for **FIFA World Cups**, **higher Elo imbalance correlates negatively with suspense**: **more balanced groups tend to yield higher suspense**.

- **MBM Data Is More Conservative**  
  The **MBM (minute-by-minute)** datasets show **similar or slightly lower correlations** compared to goal-based summaries.  
  This may be due to the inclusion of many zero-change minutes, which naturally dilute variation in suspense metrics.

### Statistical Tests: FIFA vs UEFA

We applied **paired t-tests** and **Wilcoxon signed-rank tests** to assess whether average qualification dynamics and suspense levels differ under FIFA and UEFA tie-breaking criteria.

#### European Championships

- **Suspense**: Significant difference detected (1% level).  
  → FIFA and UEFA rules yield **different suspense dynamics**.
  → FIFA rules generate more suspense than UEFA rules in the European Championships.
- **Qualification Count**: Weak evidence of difference (10% level).  

![Suspense trajectory](https://raw.githubusercontent.com/AEGDDI/tiebreak_wc/main/png/eu_suspense.png)


#### World Cups

- **No significant differences** were found in either metric.  
  → FIFA and UEFA tiebreak rules behave **similarly**.

![Suspense trajectory](https://raw.githubusercontent.com/AEGDDI/tiebreak_wc/main/png/wc_suspense.png)


These results indicate that **tie-breaking rules have a more pronounced effect in the European Championships** than in the World Cup.

For a full overview of the statistical results and correlations, see: 
- [`corrs.docx`](https://github.com/AEGDDI/tiebreak_wc/tree/main/docx/tables/corrs.docx)
- [`tests.docx`](https://github.com/AEGDDI/tiebreak_wc/tree/main/docx/tables/tests.docx)
