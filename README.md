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
