CREATE DATABASE Customers_transactions;

SELECT * FROM customers;

SET SQL_SAFE_UPDATES = 0;
SET SQL_SAFE_UPDATES = 1;

UPDATE customers SET GENDER = NULL WHERE Gender = "";
UPDATE customers SET Age = NULL WHERE Age = "";
ALTER TABLE customers MODIFY Age INT NULL;

CREATE TABLE transactions
(date_new DATE,
Id_check INT,
ID_client INT,
Count_products DECIMAL(10,3),
Sum_payment DECIMAL(10,2)
);

LOAD DATA INFILE "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\TRANSACTIONS_final.csv"
INTO TABLE transactions
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SHOW VARIABLES LIKE 'secure_file_priv';

SELECT * FROM transactions;





-- Клиенты с покупками во всех 12 месяцах, средний чек за периодс 01.06.2015 по 01.06.2016, средняя сумма покупок за месяц и количество всех операций по клиенту за период

WITH monthly_stats AS (
    SELECT
        ID_client,
        DATE_FORMAT(date_new, '%Y-%m') AS month,
        SUM(Sum_payment) AS monthly_sum,
        COUNT(*) AS operations,
        AVG(Sum_payment) AS avg_check
    FROM transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
    GROUP BY
        ID_client,
        DATE_FORMAT(date_new, '%Y-%m')
),
regular_clients AS (
    SELECT
        ID_client
    FROM monthly_stats
    GROUP BY ID_client
    HAVING COUNT(DISTINCT month) = 12
)
SELECT
    t.ID_client,
    ROUND(AVG(t.Sum_payment), 2) AS avg_check_period,
    ROUND(SUM(t.Sum_payment) / 12, 2) AS avg_monthly_purchases,
    COUNT(*) AS total_operations
FROM transactions t
JOIN regular_clients rc
    ON t.ID_client = rc.ID_client
WHERE t.date_new >= '2015-06-01'
  AND t.date_new < '2016-06-01'
GROUP BY t.ID_client
ORDER BY t.ID_client;




-- Информация в разрезе месяцев

WITH monthly_stats AS (
    SELECT
        ID_client,
        DATE_FORMAT(date_new, '%Y-%m') AS month,
        SUM(Sum_payment) AS monthly_sum,
        COUNT(*) AS operations,
        AVG(Sum_payment) AS avg_check
    FROM transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
    GROUP BY
        ID_client,
        DATE_FORMAT(date_new, '%Y-%m')
),
regular_clients AS (
    SELECT ID_client
    FROM monthly_stats
    GROUP BY ID_client
    HAVING COUNT(DISTINCT month) = 12
)
SELECT
    m.ID_client,
    m.month,
    ROUND(m.avg_check, 2) AS avg_check,
    ROUND(m.monthly_sum, 2) AS monthly_sum,
    m.operations
FROM monthly_stats m
JOIN regular_clients rc
    ON m.ID_client = rc.ID_client
ORDER BY m.ID_client, m.month;



-- a–b. Средняя сумма покупки и среднее количество операций в месяц

WITH client_month AS (
    SELECT
        ID_client,
        DATE_FORMAT(date_new, '%Y-%m') AS month,
        COUNT(*) AS operations,
        SUM(Sum_payment) AS total_sum,
        AVG(Sum_payment) AS avg_check
    FROM transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
    GROUP BY ID_client, DATE_FORMAT(date_new, '%Y-%m')
)
SELECT
    month,
    ROUND(SUM(total_sum) / SUM(operations), 2) AS avg_check,
    ROUND(AVG(operations), 2) AS avg_operations_per_client,
    COUNT(*) AS active_clients,
    SUM(operations) AS total_operations,
    ROUND(SUM(total_sum), 2) AS total_sum
FROM client_month
GROUP BY month
ORDER BY month;



-- c) Среднее количество клиентов, которые совершали операции

WITH monthly_clients AS (
    SELECT
        DATE_FORMAT(date_new, '%Y-%m') AS month,
        COUNT(DISTINCT ID_client) AS active_clients
    FROM transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
    GROUP BY DATE_FORMAT(date_new, '%Y-%m')
)
SELECT
    ROUND(AVG(active_clients), 2) AS avg_active_clients_per_month
FROM monthly_clients;



-- d) Доля от общего количества операций за год и доля в месяц от общей суммы операций

WITH monthly_stats AS (
    SELECT
        DATE_FORMAT(date_new, '%Y-%m') AS month,
        COUNT(*) AS operations,
        SUM(Sum_payment) AS total_sum
    FROM transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
    GROUP BY DATE_FORMAT(date_new, '%Y-%m')
)
SELECT
    month,
    operations,
    ROUND(
        100.0 * operations / SUM(operations) OVER (), 2
    ) AS operations_share_pct,
    ROUND(total_sum, 2) AS total_sum,
    ROUND(
        100.0 * total_sum / SUM(total_sum) OVER (), 2
    ) AS sum_share_pct
FROM monthly_stats
ORDER BY month;



-- e) Соотношение M/F/NA по месяцам и доля затрат

WITH gender_month AS (
    SELECT
        DATE_FORMAT(t.date_new, '%Y-%m') AS month,
        CASE
            WHEN UPPER(TRIM(c.Gender)) = 'M' THEN 'M'
            WHEN UPPER(TRIM(c.Gender)) = 'F' THEN 'F'
            ELSE 'NA'
        END AS gender,
        COUNT(DISTINCT t.ID_client) AS clients,
        COUNT(*) AS operations,
        SUM(t.Sum_payment) AS total_sum
    FROM transactions t
    LEFT JOIN customers c
        ON t.ID_client = c.Id_client
    WHERE t.date_new >= '2015-06-01'
      AND t.date_new < '2016-06-01'
    GROUP BY
        DATE_FORMAT(t.date_new, '%Y-%m'),
        CASE
            WHEN UPPER(TRIM(c.Gender)) = 'M' THEN 'M'
            WHEN UPPER(TRIM(c.Gender)) = 'F' THEN 'F'
            ELSE 'NA'
        END
)
SELECT
    month,
    gender,
    clients,
    ROUND(
        100.0 * clients /
        SUM(clients) OVER (PARTITION BY month), 2
    ) AS clients_share_pct,
    operations,
    ROUND(total_sum, 2) AS total_sum,
    ROUND(
        100.0 * total_sum /
        SUM(total_sum) OVER (PARTITION BY month), 2
    ) AS spending_share_pct
FROM gender_month
ORDER BY month, gender;



-- 3. Возрастные группы клиентов с шагом 10 лет и отдельно клиенты, у которых нет данной информации, 
-- с параметрами сумма и количество операций за весь период,и поквартально - средние показатели и %

WITH age_data AS (
    SELECT
        CASE
            WHEN c.Age IS NULL THEN 'NA'
            ELSE CONCAT(
                FLOOR(c.Age / 10) * 10,
                '-',
                FLOOR(c.Age / 10) * 10 + 9
            )
        END AS age_group,
        t.date_new,
        t.Sum_payment
    FROM transactions t
    LEFT JOIN customers c
        ON t.ID_client = c.Id_client
    WHERE t.date_new >= '2015-06-01'
      AND t.date_new < '2016-06-01'
),
prepared_data AS (
    SELECT
        age_group,
        date_new,
        Sum_payment,
        CONCAT(
            YEAR(date_new),
            '-Q',
            QUARTER(date_new)
        ) AS period
    FROM age_data
),
period_data AS (
    SELECT
        age_group,
        'Весь период' AS period,
        0 AS period_order,
        COUNT(*) AS operations,
        SUM(Sum_payment) AS total_sum,
        AVG(Sum_payment) AS avg_check
    FROM prepared_data
    GROUP BY age_group

    UNION ALL

    SELECT
        age_group,
        period,
        YEAR(MIN(date_new)) * 10
            + QUARTER(MIN(date_new)) AS period_order,
        COUNT(*) AS operations,
        SUM(Sum_payment) AS total_sum,
        AVG(Sum_payment) AS avg_check
    FROM prepared_data
    GROUP BY age_group, period
)
SELECT
    age_group,
    period,
    operations,
    ROUND(total_sum, 2) AS total_sum,
    ROUND(avg_check, 2) AS avg_check,
    ROUND(
        100.0 * operations /
        SUM(operations) OVER (PARTITION BY period), 2
    ) AS operations_share_pct,
    ROUND(
        100.0 * total_sum /
        SUM(total_sum) OVER (PARTITION BY period), 2
    ) AS spending_share_pct
FROM period_data
ORDER BY period_order, age_group;