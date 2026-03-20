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

metrics AS (
    SELECT
        ua.payment_month,
        ua.user_id,
        ua.game_name,
        ua.total_revenue,

        CASE
            WHEN ua.previous_paid_month IS NULL THEN 1
            ELSE 0
        END AS new_paid_users,

        CASE
            WHEN ua.previous_paid_month IS NULL THEN ua.total_revenue
            ELSE 0
        END AS new_mrr,

        CASE
            WHEN ua.next_paid_month IS NULL
              OR ua.next_paid_month <> ua.next_calendar_month
            THEN ua.next_calendar_month
            ELSE NULL
        END AS churn_month,

        CASE
            WHEN ua.next_paid_month IS NULL
              OR ua.next_paid_month <> ua.next_calendar_month
            THEN 1
            ELSE 0
        END AS churned_users,

        CASE
            WHEN ua.next_paid_month IS NULL
              OR ua.next_paid_month <> ua.next_calendar_month
            THEN ua.total_revenue
            ELSE 0
        END AS churned_revenue,

        CASE
            WHEN ua.previous_paid_month = ua.previous_calendar_month
             AND ua.total_revenue > ua.previous_paid_month_revenue
            THEN ua.total_revenue - ua.previous_paid_month_revenue
            ELSE 0
        END AS expansion_mrr,

        CASE
            WHEN ua.previous_paid_month = ua.previous_calendar_month
             AND ua.total_revenue < ua.previous_paid_month_revenue
            THEN ua.total_revenue - ua.previous_paid_month_revenue
            ELSE 0
        END AS contraction_mrr
    FROM user_activity ua
),

monthly_main AS (
    SELECT
        m.payment_month,
        m.game_name,
        gpu.language,
        gpu.has_older_device_model,
        gpu.age,
        SUM(m.total_revenue) AS mrr,
        COUNT(DISTINCT m.user_id) AS paid_users,
        SUM(m.new_paid_users) AS new_paid_users,
        SUM(m.new_mrr) AS new_mrr,
        SUM(m.expansion_mrr) AS expansion_mrr,
        SUM(m.contraction_mrr) AS contraction_mrr
    FROM metrics m
    LEFT JOIN project.games_paid_users gpu
        ON m.user_id = gpu.user_id
       AND m.game_name = gpu.game_name
    GROUP BY
        m.payment_month,
        m.game_name,
        gpu.language,
        gpu.has_older_device_model,
        gpu.age
),

monthly_churn AS (
    SELECT
        m.churn_month AS payment_month,
        m.game_name,
        gpu.language,
        gpu.has_older_device_model,
        gpu.age,
        SUM(m.churned_users) AS churned_users,
        SUM(m.churned_revenue) AS churned_revenue
    FROM metrics m
    LEFT JOIN project.games_paid_users gpu
        ON m.user_id = gpu.user_id
       AND m.game_name = gpu.game_name
    WHERE m.churn_month IS NOT NULL
    GROUP BY
        m.churn_month,
        m.game_name,
        gpu.language,
        gpu.has_older_device_model,
        gpu.age
)

SELECT
    mm.payment_month,
    mm.game_name,
    mm.language,
    mm.has_older_device_model,
    mm.age,
    mm.mrr,
    mm.paid_users,
    ROUND(mm.mrr::numeric / NULLIF(mm.paid_users, 0), 2) AS arppu,
    mm.new_paid_users,
    mm.new_mrr,
    COALESCE(mc.churned_users, 0) AS churned_users,
    COALESCE(mc.churned_revenue, 0) AS churned_revenue,
    ROUND(
        COALESCE(mc.churned_users, 0)::numeric
        / NULLIF(
            LAG(mm.paid_users) OVER (
                PARTITION BY mm.game_name, mm.language, mm.has_older_device_model, mm.age
                ORDER BY mm.payment_month
            ),
            0
        ),
        4
    ) AS churn_rate,
    ROUND(
        COALESCE(mc.churned_revenue, 0)::numeric
        / NULLIF(
            LAG(mm.mrr) OVER (
                PARTITION BY mm.game_name, mm.language, mm.has_older_device_model, mm.age
                ORDER BY mm.payment_month
            ),
            0
        ),
        4
    ) AS revenue_churn_rate,
    mm.expansion_mrr,
    mm.contraction_mrr
FROM monthly_main mm
LEFT JOIN monthly_churn mc
    ON mm.payment_month = mc.payment_month
   AND mm.game_name = mc.game_name
   AND mm.language = mc.language
   AND mm.has_older_device_model = mc.has_older_device_model
   AND mm.age = mc.age
ORDER BY mm.payment_month, mm.game_name;
