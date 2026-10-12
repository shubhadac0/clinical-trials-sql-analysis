# Clinical Trial Landscape Analysis — SQL Project

## Project Summary

This project uses SQL to analyze the **AACT database** (Aggregate Analysis of ClinicalTrials.gov), a public PostgreSQL copy of the official US clinical trials registry with more than 500,000 registered studies. Across 10 questions (plus 2 follow-ups), I explored how clinical trials are registered, who sponsors them, where they run, how large and how long they are, and which ones end early, and why.

I chose this dataset because it is real, large and messy, and it connects SQL practice to the pharma and biotech domain.

### Key Takeaways

- **Registrations keep growing:** trials registered per year rose about 53% from 2016 to 2024 (26,504 to 40,522), with no visible COVID-related dip.
- **Most registered studies are not phased drug trials:** over half are non-interventional ("NA") or have no phase recorded.
- **Geography:** the US hosts roughly 3x more industry-sponsored trials than the next country (Germany).
- **Sponsor behavior differs:** industry concentrates on Phase 1 and Phase 3, while academic and hospital sponsors dominate volume and skew toward non-interventional studies. Only one pharma company (AstraZeneca) is among the top 10 lead sponsors by trial count since 2020.
- **Phase 2 has the highest termination rate overall (~16%)**, but about 70% of the top stated reasons are recruitment problems, and only about 7% are explicitly lack of efficacy.
- **Risk is concentrated in specific segments:** Alzheimer's Phase 3 industry trials (53.5% terminated) and industry-sponsored Phase 1 oncology trials (roughly 40-46%) lead the list. Overall averages hide this.
- **Cancer trials are the longest**, averaging 3.5 to 4.7 years to completion.
- **Real-world data is inconsistent:** the same condition or reason is often typed several ways, which fragments counts unless cleaned.

### SQL Skills Demonstrated

Aggregation (`COUNT`, `AVG`, `SUM`), multi-table `JOIN`s, `GROUP BY` and `HAVING`, Common Table Expressions (`WITH`), window functions (`LAG` with `PARTITION BY`), `CASE WHEN` and conditional aggregation, date arithmetic, and basic text cleaning (`LOWER`, `TRIM`, `LIKE`).

---

## Tools and Data

- **Database:** AACT, a public PostgreSQL database (schema `ctgov`)
- **Tools:** PostgreSQL, DBeaver
- **Data snapshot:** queried in September and October 2026. AACT is refreshed regularly, so re-running the queries later may give slightly different numbers.

### Key Tables Used

| Table | What it holds |
|---|---|
| `ctgov.studies` | Core trial info: NCT ID, phase, status, sponsor class, dates, enrollment, reason stopped |
| `ctgov.sponsors` | Sponsor name and role (lead or collaborator) |
| `ctgov.countries` | Country or countries where each trial is conducted |
| `ctgov.conditions` | Condition or disease each trial studies (one trial can list several) |

### Project Structure

```
clinical-trials-sql-analysis/
├── README.md        <- this file
├── queries.sql      <- all queries, numbered (Query 1 to Query 10, plus 5b and 7b)
└── results/         <- CSV output of each query
    ├── 01_trials_per_year.csv
    ├── 02_phase_distribution.csv
    ├── ...
    └── 10_hero_termination_rate.csv
```

---

## How to Run the Queries

1. **Create a free AACT account** at `aact.ctti-clinicaltrials.org` (this gives you a database username and password).
2. **Install DBeaver** (free, from `dbeaver.io`), then create a new connection and choose **PostgreSQL**. Enter:
   - Host: `aact-db.ctti-clinicaltrials.org`
   - Port: `5432`
   - Database: `aact`
   - Username and password: the ones from your AACT account
   
   DBeaver will offer to download the PostgreSQL driver the first time. Click Download, then use **Test Connection** to confirm it works.
3. **Open a SQL editor** (right-click the connection, then SQL Editor, then New SQL Script) and open `queries.sql`.
4. **Run one query at a time:** click inside a query and press `Ctrl+Enter`. Each query is labeled with a comment (`-- Query 1: ...`).
5. **Export a result** (optional): in the results panel, click **Export data**, choose CSV, and save it with the matching file name.

The AACT login is read-only, so you can't change the data. All table names include the `ctgov.` schema prefix.

---

## Findings

### 1. Trial Registration Growth (2016–2024)
*Query 1 in `queries.sql` · Result: `results/01_trials_per_year.csv`*

Clinical trial registrations grew steadily from 26,504 (2016) to 40,522 (2024) — roughly 53% growth over 8 years, with no visible COVID-related dip. Numbers for 2027 onward drop off sharply, reflecting estimated future start dates rather than reduced activity. A handful of outlier entries (e.g., trials dated 2097, 2099) suggest data entry errors in the raw registry — worth flagging as a data quality note.

### 2. Trial Phase Distribution
*Query 2 in `queries.sql` · Result: `results/02_phase_distribution.csv`*

Over half of all registered studies are either non-interventional ("NA" — 237,074) or have no phase recorded (143,090) — meaning most ClinicalTrials.gov entries aren't classic drug-phase testing. Among trials that do have a phase, **Phase 2** is most common (65,580), followed by Phase 1, Phase 3, and Phase 4 — consistent with the natural drug-development funnel where fewer candidates advance to later stages.

### 3. Geographic Concentration of Industry-Sponsored Trials
*Query 3 in `queries.sql` · Result: `results/03_country_industry_trials.csv`*

The United States hosts nearly 3x more industry-sponsored trials (62,947) than the next-highest country, Germany (18,699). Western Europe (Germany, UK, Spain, France, Italy) forms a clear second cluster. Notably, India does not appear in the top 15 despite its scale as a global generics manufacturer — a potential angle for further investigation.

### 4. Sponsor Class vs. Phase Behavior
*Query 4 in `queries.sql` · Result: `results/04_sponsor_class_phase_breakdown.csv`*

Industry sponsors concentrate investment in **Phase 1 and Phase 3** — the highest-cost, highest-stakes stages tied directly to regulatory approval. Academic/hospital sponsors ("OTHER," the largest category by volume) skew heavily toward non-interventional (NA) studies rather than phased drug trials. NIH and federal sponsors show a Phase 2-heavy pattern, consistent with their role funding exploratory/early-stage research rather than late-stage commercial trials. A small set of trials (982) have neither sponsor class nor phase recorded — noted as a data completeness gap.

### 5. Top Conditions Studied (2021–Present)
*Query 5 in `queries.sql` · Result: `results/05_top_conditions_recent.csv`*

Beyond studies recruiting healthy volunteers, **Breast Cancer, Stroke, and Obesity** lead recent trial activity, with **Anxiety and Depression** also ranking high — reflecting strong recent focus on oncology, metabolic health, and mental health. Raw results showed "COVID-19" and "Covid19" logged as separate conditions due to inconsistent naming in the source data.

### 5b. Standardizing Condition Names (COVID-19 Example)
*Query 5b in `queries.sql` · Result: `results/05b_top_conditions_standardized.csv`*

Used a `CASE WHEN ... LIKE '%covid%'` pattern to merge COVID-19 naming variants into a single category before re-counting. This is a small but important step: raw registry text fields aren't standardized, and drawing conclusions without cleaning can meaningfully understate a condition's true trial volume. Demonstrates basic text normalization technique alongside aggregation.

### 6. Average Enrollment by Phase and Sponsor Class
*Query 6 in `queries.sql` · Result: `results/06_avg_enrollment_by_phase_sponsor.csv`*

Average enrollment scales predictably with trial phase: smallest in Phase 1 (early safety testing, typically tens of participants) and largest in Phase 3 (large-scale efficacy confirmation, typically several hundred to over a thousand), consistently across sponsor types. Studies with no recorded phase show far larger averages, likely large non-interventional registry or observational studies, and should be interpreted separately from phased drug trials.

### 7. Completion vs. Termination Rates by Phase
*Query 7 in `queries.sql` · Result: `results/07_completion_termination_by_phase.csv`*

Filtering to finished trials (completed, terminated, withdrawn, suspended), **Phase 2 shows the highest termination rate (~16%)**, compared with roughly 10-12% for Phase 1, Phase 3 and Phase 4. This is consistent with the well-known "Phase 2 valley of death" in drug development: Phase 1 mainly tests safety, while Phase 2 is the first real test of whether a drug works.

### 7b. Why Phase 2 Trials Are Terminated
*Query 7b in `queries.sql` · Result: `results/07b_phase2_termination_reasons.csv`*

Grouping the top 20 free-text termination reasons by theme: roughly **70% relate to recruitment or enrollment problems** (slow, low or poor accrual/enrollment), about 17% to business, sponsor or funding decisions, and only about 7% explicitly to lack of efficacy or futility. This adds nuance to the Phase 2 finding in #7: Phase 2 trials end early more often, but the stated reason is usually operational rather than the drug failing. Because "sponsor decision" and "business decision" are vague, some efficacy-related stops may be hidden in those categories. Free-text entries also contain spelling and punctuation variants of the same reason (e.g., "slow accrual" vs. "slow accrual."), which would need further standardization for a precise breakdown.

### 8. Top Sponsors and Year-over-Year Growth (2020–2025)
*Query 8 in `queries.sql` · Result: `results/08_top_sponsors_yoy_growth.csv`*

Used a CTE and the `LAG()` window function to rank the 10 lead sponsors with the most trials and calculate their year-over-year change. **Only one pharmaceutical company (AstraZeneca) makes the top 10**; the rest are universities and hospitals, including four Egyptian universities (Cairo, Assiut, Ain Shams, Sohag) and Riphah International University in Pakistan. A plausible explanation is that many journals require trial registration before publication, so institutions running many smaller studies register heavily. Cairo University grew from 369 trials (2020) to 638 (2025), and Assiut from 417 to 598. Established institutions such as Assistance Publique - Hôpitaux de Paris (256 to 235) and Mayo Clinic (177 to 190) stayed roughly flat. Sohag University's jump from 29 to 166 trials in 2021 (+472%) likely reflects a change in registration practice rather than a real surge in research, a reminder that percentage growth from a very small base can mislead. Several sponsors show a drop in 2025, which may partly reflect trials not yet registered for the most recent year.

### 9. Average Duration of Completed Trials by Condition
*Query 9 in `queries.sql` · Result: `results/09_avg_duration_by_condition.csv`*

Calculated trial duration (completion date minus start date, converted to months) for completed trials that started in 2010 or later, keeping only conditions with at least 200 trials (using `HAVING`) so that small samples don't distort the averages. **All 20 longest-running conditions are cancers**, averaging 42 to 57 months (3.5 to 4.7 years), with blood cancers such as Chronic Lymphocytic Leukemia (56.9 months), Multiple Myeloma (54.7) and Leukemia (51.8) at the top. A likely reason is that oncology trials track survival or progression outcomes that require long follow-up. Two caveats: only completed trials were counted, so very long trials still in progress are excluded and true durations may be longer; and a trial can list several conditions, so categories overlap. Non-small cell lung cancer appears under three different spellings, again showing the need for text standardization (combined, roughly 736 trials averaging about 47 months).

### 10. Hero Query: Which Trial Types Get Terminated Most?
*Query 10 in `queries.sql` · Result: `results/10_hero_termination_rate.csv`*

Combined condition, phase and sponsor class (CTE plus conditional aggregation with `SUM(CASE WHEN ...)`, keeping only groups with at least 40 finished trials) to find where termination is most common. **Alzheimer's Disease Phase 3 industry trials top the list at 53.5% terminated (23 of 43).** The rest of the top 20 is dominated by **industry-sponsored Phase 1 oncology trials** (e.g., myelodysplastic syndromes 46.3%, non-small cell lung cancer ~42% across spelling variants, acute myeloid leukemia 43.1%, melanoma 40.2%): 15 of the top 20 rows are industry-sponsored, 15 are cancers, and 11 are Phase 1. COVID-19 trials also appear with termination rates of 36-39%, but they ran only about 12-16 months whether completed or terminated. This refines the earlier finding in #7: Phase 2 has the highest termination rate overall, but the highest-risk segments are specific condition and sponsor combinations that an overall average hides. In most groups terminated trials ran noticeably shorter than completed ones (e.g., melanoma Phase 2: 26.8 vs. 47.9 months), which is expected since terminated trials stop early; duration is an outcome of termination, not a way to predict it. A possible explanation for the industry pattern, consistent with the "sponsor decision" and "business decision" reasons in #7b, is that companies drop early drug candidates for portfolio or strategic reasons, but this data does not prove the cause. Group sizes are modest (40 to 117 finished trials), so treat the rates as indicative rather than precise.

---

## Data Quality Notes and Limitations
- A meaningful share of records have NULL phase or sponsor class values. They were treated as "unspecified" rather than excluded, to avoid skewing counts.
- A few far-future start dates (e.g., year 2097) appear to be data entry anomalies in the source registry.
- Free-text fields (conditions, termination reasons) contain spelling and punctuation variants of the same value (e.g., "COVID-19" vs. "Covid19", multiple spellings of non-small cell lung cancer). Counts for those fields are fragmented unless standardized first.
- A trial that lists several conditions is counted once under each condition, so condition-level totals overlap.
- This is a descriptive analysis. It shows patterns in registry data but does not prove their causes; explanations given above are plausible interpretations, not tested conclusions.

---

## What I Learned

**Technical skills**
- Moving from single-table queries to multi-table joins, CTEs and window functions, and when each is the right tool.
- The difference between `WHERE` (filters rows before grouping) and `HAVING` (filters groups after), and using `HAVING COUNT(*)` to avoid conclusions from tiny samples.
- Conditional aggregation (`SUM(CASE WHEN ...)`) to calculate rates such as termination percentage inside a single query.
- Cleaning messy text with `LOWER`, `TRIM` and `LIKE` before counting.

**About working with real data**
- Check the output for oddities before trusting it. Examples here: trials dated 2097, "Healthy" appearing as a condition, and one condition spelled several ways.
- Percentages from small bases can mislead (one university's +472% growth), and the most recent year is often incomplete.
- An overall average can hide the segments that matter. Phase 2 had the highest termination rate overall, but specific condition and sponsor combinations were far higher.
- Be careful about what a result can and cannot say. Terminated trials running shorter than completed ones is expected by definition, so duration doesn't predict termination.

---

## Possible Next Steps
- Standardize condition names more fully (for example, grouping all lung cancer spellings) and re-run the condition-based queries.
- Build a small dashboard (Power BI or Tableau Public) from two or three of the results.
- Extend the termination-reason analysis by grouping the free-text reasons into themes directly in SQL.
