* Merge together goals_wc_fifa.xlsx and goals_eu_uefa.xlsx
    * replace elo_home and elo_away with elo_favorite and elo_underdog for each observation where favorite is the highest elo and underdog the lowest between the two
    * Add four other variables for each observations: elo1st, elo2nd, elo3rd, elo4th that will be the elo from highest to lowest of the team in a group (grouping by year and stage)
* Merge mbm_wc_fifa_xlsx and mbm_eu_eufa.xlsx
    * Also here we create elo1st, elo2nd, elo3rd, elo4th following the same logic
* In both datasets, create the variable fifa_rule thaking value 1 for World Cup (wc) observations and 0 for European Championship (eu).
* Keep track of the merging and variables creation process in a separate file in the folder code/merge and save the final datasets in the folder data/out
* Update the summary_stats.ipynb and  create the corresponding do file 
* Models for goals dataset:
    * First:

    qualification_changed = fifa_rule + elo favorite + elo underdog 

    Cluster at group level standard deviation
    
    * Second: 

     qualification_changed = fifa_rule + elo1st + elo2nd + elo3rd + elo4th

     * Robustness checks:

        * Filter only groups with two qualifying teams (no wc edition from 1984 to 1994 and no eu from 2016 to 2024)
        * Filter only groups with three qualifying teams
        * Filter only 2 points victory (year <= 1992)
        * Filter only 3 poins victory ( year >1992)
        * Define elo max and min for both wc and eu and take only those groups in the overlapping range, presumably between the max elo min and min elo max. 

        to the main and robustness estimations add year (that is not i.year or year fixed effect) and the interaction between year and fifa_rule 

        do not add year fixed effects beacuse they would kill the treatment effect (fifa_rule) and explain me why

    * Third: 

    Poisson count, keep the max value of qualification_count for each group (year, stage)

     qualification_count = fifa_rule + elo1st + elo2nd + elo3rd + elo4th

     same robustness checks

* Models for mbm dataset: 

    Suspense = fifa_rule + elo1st + elo2nd + elo3rd + elo4th

    same robustness checks


all models except the poisson count are logit models and should come with marginal effects (margins)

create a regression.ipynb and regression.do file

try to keep the merging and model simple and accessible. just do what I have asked.



------------------------------
Add as control elo 1,2,3,4
------------------------------