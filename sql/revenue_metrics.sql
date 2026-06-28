WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', gp.payment_date)::date AS payment_month,
        gp.user_id,
        gp.game_name,
        SUM(gp.revenue_amount_usd) AS total_revenue
    FROM project.games_payments gp
    GROUP BY
        DATE_TRUNC('month', gp.payment_date)::date,
        gp.user_id,
        gp.game_name
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
            PARTITION BY mr.user_id, mr.game_name
            ORDER BY mr.payment_month
        ) AS previous_paid_month,

        LEAD(mr.payment_month) OVER (
            PARTITION BY mr.user_id, mr.game_name
            ORDER BY mr.payment_month
        ) AS next_paid_month,

        LAG(mr.total_revenue) OVER (
            PARTITION BY mr.user_id, mr.game_name
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

        ua.previous_calendar_month,
        ua.next_calendar_month,
        ua.previous_paid_month,
        ua.next_paid_month,
        ua.previous_paid_month_revenue,

        CASE
            WHEN ua.previous_paid_month IS NULL
            THEN 1
            ELSE 0
        END AS new_paid_users,

        CASE
            WHEN ua.previous_paid_month IS NULL
            THEN ua.total_revenue
            ELSE 0
        END AS new_mrr,

        CASE
            WHEN ua.previous_paid_month IS NOT NULL
             AND ua.previous_paid_month <> ua.previous_calendar_month
            THEN 1
            ELSE 0
        END AS back_from_churn_users,

        CASE
            WHEN ua.previous_paid_month IS NOT NULL
             AND ua.previous_paid_month <> ua.previous_calendar_month
            THEN ua.total_revenue
            ELSE 0
        END AS back_from_churn_mrr,

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

        SUM(m.back_from_churn_users) AS back_from_churn_users,
        SUM(m.back_from_churn_mrr) AS back_from_churn_mrr,

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
),

monthly_combined AS (
    SELECT
        COALESCE(mm.payment_month, mc.payment_month) AS payment_month,
        COALESCE(mm.game_name, mc.game_name) AS game_name,
        COALESCE(mm.language, mc.language) AS language,
        COALESCE(mm.has_older_device_model, mc.has_older_device_model) AS has_older_device_model,
        COALESCE(mm.age, mc.age) AS age,

        COALESCE(mm.mrr, 0) AS mrr,
        COALESCE(mm.paid_users, 0) AS paid_users,

        COALESCE(mm.new_paid_users, 0) AS new_paid_users,
        COALESCE(mm.new_mrr, 0) AS new_mrr,

        COALESCE(mm.back_from_churn_users, 0) AS back_from_churn_users,
        COALESCE(mm.back_from_churn_mrr, 0) AS back_from_churn_mrr,

        COALESCE(mc.churned_users, 0) AS churned_users,
        COALESCE(mc.churned_revenue, 0) AS churned_revenue,

        COALESCE(mm.expansion_mrr, 0) AS expansion_mrr,
        COALESCE(mm.contraction_mrr, 0) AS contraction_mrr

    FROM monthly_main mm
    FULL OUTER JOIN monthly_churn mc
        ON mm.payment_month = mc.payment_month
       AND mm.game_name = mc.game_name
       AND mm.language IS NOT DISTINCT FROM mc.language
       AND mm.has_older_device_model IS NOT DISTINCT FROM mc.has_older_device_model
       AND mm.age IS NOT DISTINCT FROM mc.age
),

monthly_with_previous AS (
    SELECT
        mc.*,

        LAG(mc.paid_users) OVER (
            PARTITION BY mc.game_name, mc.language, mc.has_older_device_model, mc.age
            ORDER BY mc.payment_month
        ) AS previous_paid_users,

        LAG(mc.mrr) OVER (
            PARTITION BY mc.game_name, mc.language, mc.has_older_device_model, mc.age
            ORDER BY mc.payment_month
        ) AS previous_mrr

    FROM monthly_combined mc
),

final_metrics AS (
    SELECT
        payment_month,
        game_name,
        language,
        has_older_device_model,
        age,

        mrr,
        paid_users,

        ROUND(mrr::numeric / NULLIF(paid_users, 0), 2) AS arppu,

        new_paid_users,
        new_mrr,

        back_from_churn_users,
        back_from_churn_mrr,

        churned_users,
        churned_revenue,

        previous_paid_users,
        previous_mrr,

        ROUND(
            churned_users::numeric / NULLIF(previous_paid_users, 0),
            4
        ) AS churn_rate,

        ROUND(
            churned_revenue::numeric / NULLIF(previous_mrr, 0),
            4
        ) AS revenue_churn_rate,

        expansion_mrr,
        contraction_mrr,

        new_mrr
        + back_from_churn_mrr
        + expansion_mrr
        + contraction_mrr
        - churned_revenue AS net_mrr_growth

    FROM monthly_with_previous
)

SELECT
    payment_month,
    game_name,
    language,
    has_older_device_model,
    age,

    mrr,
    paid_users,
    arppu,

    new_paid_users,
    new_mrr,

    back_from_churn_users,
    back_from_churn_mrr,

    churned_users,
    churned_revenue,

    previous_paid_users,
    previous_mrr,

    churn_rate,
    revenue_churn_rate,

    expansion_mrr,
    contraction_mrr,
    net_mrr_growth,

    CASE
        WHEN churn_rate > 0
        THEN ROUND(1.0 / churn_rate, 2)
        ELSE NULL
    END AS lt_months,

    CASE
        WHEN churn_rate > 0
        THEN ROUND((1.0 / churn_rate) * arppu, 2)
        ELSE NULL
    END AS ltv

FROM final_metrics
ORDER BY
    payment_month,
    game_name,
    language,
    has_older_device_model,
    age;
