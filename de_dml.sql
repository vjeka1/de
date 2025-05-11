-- 1. Сумма вообще всех покупок за 2020 год
SELECT total_amount
FROM sales_cube
WHERE year = '2020'
  AND gender IS NULL
  AND age_group IS NULL
  AND industry IS NULL
  AND month IS NULL;

-- 2. Сумма всех покупок за апрель 2020 года
SELECT total_amount
FROM sales_cube
WHERE year = '2020'
  AND month = '4'
  AND gender IS NULL
  AND age_group IS NULL
  AND industry IS NULL;

-- 3. Сумма покупок всех мужчин за 2020 год
SELECT total_amount
FROM sales_cube
WHERE year = '2020'
  AND gender = 'M'
  AND age_group IS NULL
  AND industry IS NULL
  AND month IS NULL;

-- 4. Сумма покупок всех мужчин в возрасте 19-30 за 2020 год
SELECT total_amount
FROM sales_cube
WHERE year = '2020'
  AND gender = 'M'
  AND age_group = '19-30'
  AND industry IS NULL
  AND month IS NULL;