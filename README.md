# Revenue Metrics Analysis

Revenue Metrics Analysis nalysis using SQL and Tableau

--- 

## Project Overview
This project analyzes subscription-based revenue using SQL and Tableau.
The goal is to understand revenue dynamics, user behavior, and key drivers of growth and decline.
The dataset contains user payments, allowing tracking of monthly revenue, user retention, and churn.

--- 

##  Business Problem 

**The main objective is to identify:**
- What drives revenue growth?
- How user behavior affects revenue stability?
- Where the business loses money (churn)?

This analysis helps product managers make data-driven decisions.

--- 

##  SQL Analysis

The analysis is based on monthly aggregated user revenue.

**Key steps:**
1. Aggregated revenue per user per month;
2. Used window functions (LAG, LEAD) to track user behavior;
3. Calculated key metrics:
    - MRR (Monthly Recurring Revenue);
    - Paid Users;
    - ARPPU;
    - New Paid Users;
    - New MRR;
    - Churned Users;
    - Churned Revenue;
    - Churn Rate;
    - Revenue Churn Rate;
    - Expansion MRR;
    - Contraction MRR.

  

**Example SQL snippet:**

```  
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', gp.payment_date)::date AS payment_month,
        gp.user_id,
        gp.game_name,
        SUM(gp.revenue_amount_usd) AS total_revenue
    FROM project.games_payments gp
    GROUP BY 1, 2, 3
),

user_activity AS (
    SELECT
        mr.payment_month,
        mr.user_id,
        mr.game_name,
        mr.total_revenue,
        (mr.payment_month - INTERVAL '1 month')::date AS previous_calendar_month,
        (mr.payment_month + INTERVAL '1 month')::date AS next_calendar_month,
        LAG(mr.payment_month) OVER (
            PARTITION BY mr.user_id
            ORDER BY mr.payment_month
        ) AS previous_paid_month,
        LEAD(mr.payment_month) OVER (
            PARTITION BY mr.user_id
            ORDER BY mr.payment_month
        ) AS next_paid_month,
        LAG(mr.total_revenue) OVER (
            PARTITION BY mr.user_id
            ORDER BY mr.payment_month
        ) AS previous_paid_month_revenue
    FROM monthly_revenue mr
),
```
--- 

## Logic Highlights

- New users are identified as users with no previous payment history;
- Churn is assigned to the next calendar month if the user does not return;
- Expansion/Contraction is calculated only for consecutive months;
- Window functions are used to track previous and next payments.

--- 

## Dashboard Plan

**The dashboard will include:**

- KPI section (MRR, Users, ARPPU, Churn Rate);
- Revenue trend over time;
- User growth and decline;
- Revenue breakdown (New, Expansion, Contraction, Churn);
- User flow (New vs Churned users);
- Churn rate trend.

**Filters:**
- Language;
- Age;
- Device type;
- Game name.

--- 

## Repository Structure

```
revenue-metrics-analysis
│
├── README.md
│
├── data
│   └── 
│
├── sql
│   └── revenue_metrics.sql
│
└── dashboard
    └── 
```
