CREATE TABLE IF NOT EXISTS c (
    client_id BIGINT CHECK (client_id >= 0) PRIMARY KEY, -- Уникальный идентификатор клиента
    gender CHAR(1) CHECK (gender IN ('M', 'F', 'U')),    -- Пол: M - мужской, F - женский, U - неизвестно
    age INTEGER CHECK (age >= 0)                        -- Возраст: 0 - неизвестно
);

CREATE TABLE IF NOT EXISTS m (
    merchant_id BIGINT CHECK (merchant_id >= 0) PRIMARY KEY, -- Уникальный идентификатор торговой точки
    latitude DECIMAL(10, 6),                                -- Географическая широта (точность до ~11 см)
    longtitude DECIMAL(10, 6),                              -- Географическая долгота (точность до ~11 см)
    mcc_cd smallint                                         -- Код категории торговой точки (MCC)
);

CREATE TABLE IF NOT EXISTS t (
    transaction_id SERIAL PRIMARY KEY,               -- Автоинкрементный ID транзакции
    merchant_id BIGINT REFERENCES m(merchant_id),    -- ID торговой точки (внешний ключ)
    client_id BIGINT REFERENCES c(client_id),        -- ID клиента (внешний ключ)
    transaction_dttm TIMESTAMP,                      -- Дата и время совершения транзакции
    transaction_amt DECIMAL(15, 2)                   -- Сумма транзакции в валюте (до триллионов)
);

-- Заполнение таблицы клиентов (c)
DO $$
DECLARE
    num_clients INTEGER := 100000; -- Параметр: количество клиентов для генерации
    max_client_id INTEGER := (select max(client_id) from c);
    num_for_generate INTEGER;
    start_id INTEGER;
BEGIN
    -- Обработка случая, когда таблица пуста (max_client_id IS NULL)
    IF max_client_id IS NULL THEN
        max_client_id := 0;
        start_id := 1;
        num_for_generate := num_clients;
    ELSE
        start_id := max_client_id + 1;
        num_for_generate := max_client_id + num_clients;
    END IF;

    INSERT INTO c (client_id, gender, age)
    SELECT
        id, -- Уникальный ID клиента
        CASE
            WHEN random() < 0.02 THEN 'U' -- 2% шанс неизвестного пола
            ELSE (ARRAY['M', 'F'])[1 + floor(random() * 2)::int] -- Случайный пол (M, F)
        END,
        CASE
            WHEN random() < 0.04 THEN 0 -- 4% шанс неизвестного возраста
            ELSE floor(random() * 70 + 14)::int -- Случайный возраст от 14 до 88
        END
    FROM generate_series(start_id, num_for_generate) AS id
    ON CONFLICT (client_id) DO NOTHING; -- Игнорировать дубликаты
END $$;

-- Заполнение таблицы торговых точек (m)
DO $$
DECLARE
    num_merchants INTEGER := 500; -- Параметр: количество торговых точек для генерации
    max_merchant_id INTEGER := (select max(merchant_id) from m);
    num_for_generate INTEGER := max_merchant_id+num_merchants;
    mcc_codes SMALLINT[] := ARRAY[
        5411, -- Продуктовые магазины
        5812, -- Рестораны
        5912, -- Аптеки
        5541, -- АЗС
        5311, -- Универмаги
        5691, -- Магазины одежды
        5945, -- Игрушки и хобби
        7011, -- Отели
        4121, -- Такси
        7832  -- Кинотеатры
    ];
BEGIN
    -- Обработка случая, когда таблица пуста (max_merchant_id IS NULL)
    IF max_merchant_id IS NULL THEN
        max_merchant_id := 0;
        num_for_generate := num_merchants;
    END IF;

    INSERT INTO m (merchant_id, latitude, longtitude, mcc_cd)
    SELECT
        id, -- Уникальный ID торговой точки
        55 + random() * 10, -- Широта (приблизительно Россия: 55-65°)
        37 + random() * 10, -- Долгота (приблизительно Россия: 37-47°)
        mcc_codes[1 + floor(random() * array_length(mcc_codes, 1))::int] -- Случайный MCC код из массива
    FROM generate_series(max_merchant_id+1, num_for_generate) AS id
    ON CONFLICT (merchant_id) DO NOTHING; -- Игнорировать дубликаты
END $$;

-- Заполнение таблицы транзакций (t)
DO $$
DECLARE
    num_transactions INTEGER := 100000; -- Параметр: количество транзакций для генерации
    min_client_id BIGINT;
    max_client_id BIGINT;
    min_merchant_id BIGINT;
    max_merchant_id BIGINT;
    start_date TIMESTAMP := '2020-01-01 00:00:00'::TIMESTAMP; -- Начальная дата для транзакций
    end_date TIMESTAMP := '2023-12-31 23:59:59'::TIMESTAMP;   -- Конечная дата для транзакций
BEGIN
    -- Получение диапазонов ID клиентов и торговых точек для использования в транзакциях
    SELECT MIN(client_id), MAX(client_id) INTO min_client_id, max_client_id FROM c;
    SELECT MIN(merchant_id), MAX(merchant_id) INTO min_merchant_id, max_merchant_id FROM m;
    
    -- Добавляем проверку, чтобы избежать ошибок, если таблицы c или m пусты
    IF min_client_id IS NULL OR min_merchant_id IS NULL THEN
        RAISE EXCEPTION 'Таблицы клиентов или торговых точек пусты. Заполните их перед генерацией транзакций.';
    END IF;
    
    INSERT INTO t (merchant_id, client_id, transaction_dttm, transaction_amt)
    SELECT
        floor(random() * (max_merchant_id - min_merchant_id + 1) + min_merchant_id)::BIGINT, -- Случайный ID торговой точки
        floor(random() * (max_client_id - min_client_id + 1) + min_client_id)::BIGINT,       -- Случайный ID клиента
        start_date + (random() * (end_date - start_date)),                                    -- Случайная дата/время между start_date и end_date
        (random() * 9990 + 10)::NUMERIC(15,2)                                                -- Случайная сумма от 10 до 10000 с двумя десятичными разрядами
    FROM generate_series(1, num_transactions);
END $$;



-- Создаем таблицу с агрегированными данными (OLAP-куб)
CREATE TABLE sales_cube AS
WITH sales_data AS (
    SELECT 
        c.gender,
        CASE 
            WHEN c.age < 19 THEN 'До 18'
            WHEN c.age BETWEEN 19 AND 30 THEN '19-30'
            WHEN c.age > 30 THEN 'От 31'
        END AS age_group,
        m.mcc_cd AS industry,
        EXTRACT(YEAR FROM t.transaction_dttm)::INTEGER AS year,
        EXTRACT(MONTH FROM t.transaction_dttm)::INTEGER AS month,
        t.transaction_amt
    FROM 
        t
    INNER JOIN 
        c ON t.client_id = c.client_id
    INNER JOIN 
        m ON t.merchant_id = m.merchant_id
)
SELECT 
    gender,
    age_group,
    industry,
    year,
    month,
    SUM(transaction_amt) AS total_amount,
    AVG(transaction_amt) AS avg_amount,
    COUNT(transaction_amt) AS transaction_count
FROM 
    sales_data
GROUP BY 
    CUBE(gender, age_group, industry, year, month);





