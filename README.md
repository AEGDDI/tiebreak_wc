# Suspense in International Football Group Stages: A Comparison of FIFA and UEFA Tie-Breaking Rules

This repository accompanies a research paper that analyzes the impact of tie-breaking rules on suspense levels during the group stages of international football tournaments. The paper compares the criteria used by **FIFA** and **UEFA** when teams are level on points.

## Objective

The goal of the paper is to evaluate how different tie-breaking rules affect the suspense in group standings. Specifically, it compares the following systems:

- **FIFA**: Goal Difference > Goals Scored > Head-to-Head
- **UEFA**: Head-to-Head > Goal Difference > Goals Scored

By applying both rule sets to historical group stage data, the paper investigates which system tends to produce more suspenseful scenarios.

## Defining Suspense

Suspense is defined as the proximity to a potential change in the composition of teams qualifying for the knockout stage. More precisely:

> *A suspenseful moment occurs when a single goal (in any group match) could alter the current qualification outcome.*

For example, in Group F of Euro 2024, entering the third and final matchday, Portugal and Turkey were in qualifying positions for the knockout stage. However, Turkey was playing against Czech Republic, and the match started 0–0. In that situation, a single goal by Czech Republic would have allowed them to overtake Turkey on points and qualify instead. Since the qualification status could change dramatically with just one goal, this scenario is marked as having maximum suspense (suspense = 1).

A full explanation of how suspense has been formally defined can be found in [`suspense.docx`](https://github.com/AEGDDI/tiebreak_wc/tree/main/docx/suspense.docx)
## Data

We collected and processed data from:

- **UEFA European Championships**: from the 1984 edition up to Euro 2020
- **FIFA World Cups**: from the 1994 edition up to the 2022 World Cup

Data sources include both **Wikipedia** and **Kaggle**.

- [`data/in/`](https://github.com/AEGDDI/tiebreak_wc/tree/main/data/in): This folder contains raw data on goals scored during group stage matches in both the UEFA European Championships and FIFA World Cups, along with the **Elo ratings** of the national teams.
- [`data/out/`](https://github.com/AEGDDI/tiebreak_wc/tree/main/data/out/wiki): This folder contains processed datasets built to evaluate minute-by-minute group composition and the potential for changes in qualification, according to both FIFA and UEFA tie-breaking criteria.

## Repository Structure

- `data/in/`: Raw match data and Elo ratings
- `data/out/`: Processed group dynamics data for suspense analysis


