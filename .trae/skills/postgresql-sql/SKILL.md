---
name: "postgresql-sql"
description: "PostgreSQL/Greenplum SQL 助手，专门针对数据仓库开发场景，支持ETL脚本编写、建表脚本、多表关联查询等。在用户需要编写SQL、优化性能或进行数据仓库开发时调用。"
---

# PostgreSQL/Greenplum 数据仓库 SQL 助手

这是一个专门为 PostgreSQL 和 Greenplum Database 设计的 SQL 助手，针对数据仓库开发场景，支持 ETL 脚本编写、建表脚本、多表关联查询等。

## 使用场景

- 数据仓库 ETL 脚本开发（ODS、DWS、ADS 层）
- 建表脚本编写
- 多表关联查询
- 数据清洗和转换
- 大数据量处理（几百万条记录）

## 支持的数据库版本

- PostgreSQL 9.4.26
- Greenplum Database 6.6.0

## 支持的输入方式

### 1. 描述需求，自动生成 SQL

**示例：**
```
帮我写一个脚本，从 DWS 层表关联数据并插入到 ADS 层表
```

### 2. 提供不完整的 SQL，帮助完善

**示例：**
```
帮我完善这个建表脚本：
CREATE TABLE yanxuan.ods_new_table (
    id VARCHAR(64) NOT NULL,
```

### 3. 提供有问题的 SQL，帮助修复

**示例：**
```
这个脚本有错误，帮我修复：
TRUNCATE TABLE yanxuan.ads_table;
INSERT INTO yanxuan.ads_table SELECT ...
```

## 数据仓库开发模式

### 1. ETL 脚本模式（TRUNCATE + INSERT）

**完整 ETL 模式：**
```sql
-- 清空 ADS 表，以便重新插入最新数据
TRUNCATE TABLE yanxuan.ads_yx_clue_full_detail;

-- 从 DWS 层关联数据并插入 ADS 层
INSERT INTO yanxuan.ads_yx_clue_full_detail
SELECT 
    -- 从 dws_yx_clue_main_info 表选择字段
    main.clue_id, 
    main.created_time, 
    main.customer_name, 
    main.customer_mobile, 
    -- ... 其他字段
    main.etl_load_time
    
FROM 
    yanxuan.dws_yx_clue_main_info AS main 
LEFT JOIN 
    yanxuan.dws_yx_clue_action_record AS action 
    ON main.clue_id = action.clue_id 
LEFT JOIN 
    (SELECT 
        clue_id,
        COUNT(DISTINCT order_code) AS order_cnt,
        SUM(COALESCE(performance_final, 0)) AS performance_final
     FROM yanxuan.dws_yx_all_performance_detail 
     WHERE performance_effect_time IS NOT NULL 
       AND clue_id IS NOT NULL 
     GROUP BY clue_id) AS yj 
    ON main.clue_id::TEXT = yj.clue_id;
```

### 2. 建表脚本模式（CREATE TABLE + COMMENT）

**完整建表模式：**
```sql
-- 创建 ODS 层表
CREATE TABLE yanxuan.ods_repair_task_status_current_year (
    id VARCHAR(64) NOT NULL,
    status VARCHAR(32),
    busi_type VARCHAR(16),
    etl_load_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 添加表注释
COMMENT ON TABLE yanxuan.ods_repair_task_status_current_year IS '维修工单状态表-当年数据（到家+飞鸽）';

-- 添加字段注释
COMMENT ON COLUMN yanxuan.ods_repair_task_status_current_year.id IS '工单ID';
COMMENT ON COLUMN yanxuan.ods_repair_task_status_current_year.status IS '工单状态（中文）';
COMMENT ON COLUMN yanxuan.ods_repair_task_status_current_year.busi_type IS '业务类型（到家/飞鸽）';
```

## PostgreSQL/Greenplum 特有语法

### 1. 窗口函数

**常用窗口函数：**
```sql
-- ROW_NUMBER() - 排名（允许并列）
SELECT 
    customer_name,
    order_amount,
    ROW_NUMBER() OVER (PARTITION BY city ORDER BY order_amount DESC) AS rank
FROM customers;

-- RANK() - 排名（允许并列，跳跃排序）
SELECT 
    customer_name,
    order_amount,
    RANK() OVER (PARTITION BY city ORDER BY order_amount DESC) AS rank
FROM customers;

-- LAG() - 前一行数据
SELECT 
    order_date,
    order_amount,
    LAG(order_amount) OVER (ORDER BY order_date) AS prev_amount
FROM orders;
```

### 2. CTE (Common Table Expression)

**复杂查询使用 CTE：**
```sql
-- 统计每个城市的订单量和金额
WITH city_stats AS (
    SELECT 
        city,
        COUNT(*) AS order_count,
        SUM(amount) AS total_amount
    FROM orders
    GROUP BY city
),
city_ranking AS (
    SELECT 
        city,
        order_count,
        total_amount,
        RANK() OVER (ORDER BY total_amount DESC) AS amount_rank
    FROM city_stats
)
SELECT 
    city,
    order_count,
    total_amount,
    amount_rank
FROM city_ranking
WHERE amount_rank <= 10;
```

### 3. 字符串函数

**常用字符串处理：**
```sql
-- 字符串拼接
SELECT CONCAT(first_name, ' ', last_name) AS full_name;
SELECT first_name || ' ' || last_name AS full_name;

-- 字符串截取
SELECT SUBSTRING(customer_mobile, 1, 3) AS mobile_prefix;  -- 手机号前3位

-- 字符串替换
SELECT REPLACE(status, '待处理', 'Pending') AS status_en;

-- 字符串分割
SELECT SPLIT_PART(full_address, '市', 1) AS province;

-- 字符串处理
SELECT 
    TRIM('  hello  ') AS trimmed,      -- 去除首尾空格
    UPPER('hello') AS upper_case,      -- 转大写
    LOWER('HELLO') AS lower_case,      -- 转小写
    LENGTH('hello') AS str_length;     -- 字符长度
```

### 4. 日期时间函数

**常用日期处理：**
```sql
-- 日期计算
SELECT 
    NOW() AS current_time,                    -- 当前时间
    CURRENT_DATE AS current_date,             -- 当前日期
    DATE_TRUNC('month', NOW()) AS month_start, -- 本月第一天
    NOW() + INTERVAL '1 day' AS tomorrow,     -- 明天
    NOW() - INTERVAL '1 week' AS last_week;   -- 一周前

-- 日期格式化
SELECT 
    TO_CHAR(NOW(), 'YYYY-MM-DD') AS date_str,
    TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS') AS datetime_str,
    TO_CHAR(NOW(), 'YYYY"年"MM"月"DD"日"') AS chinese_date;

-- 日期差值
SELECT 
    EXTRACT(DAY FROM (NOW() - '2026-01-01')) AS days_diff,
    AGE(NOW(), '2026-01-01') AS time_interval;

-- 日期解析
SELECT TO_DATE('2026-02-25', 'YYYY-MM-DD') AS parsed_date;
```

### 5. 聚合函数

**常用聚合操作：**
```sql
-- 基础聚合
SELECT 
    COUNT(*) AS total_count,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(order_amount) AS total_amount,
    AVG(order_amount) AS avg_amount,
    MAX(order_amount) AS max_amount,
    MIN(order_amount) AS min_amount
FROM orders;

-- 条件聚合
SELECT 
    SUM(CASE WHEN status = '已完成' THEN order_amount ELSE 0 END) AS completed_amount,
    SUM(CASE WHEN status = '进行中' THEN order_amount ELSE 0 END) AS ongoing_amount,
    COUNT(CASE WHEN status = '已完成' THEN 1 END) AS completed_count
FROM orders;

-- 百分位数
SELECT 
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY order_amount) AS median_amount,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY order_amount) AS p90_amount
FROM orders;
```

### 6. Greenplum 特有功能

**分布式表：**
```sql
-- 创建分布式表（按主键分布）
CREATE TABLE sales (
    id SERIAL,
    product_id INTEGER,
    sale_date DATE,
    amount NUMERIC(10,2)
) DISTRIBUTED BY (product_id);

-- 创建复制表（所有节点都有完整数据）
CREATE TABLE config (
    key VARCHAR(100),
    value TEXT
) DISTRIBUTED REPLICATED;

-- 查看表分布情况
SELECT 
    gp_segment_id,
    COUNT(*) AS row_count
FROM sales
GROUP BY gp_segment_id
ORDER BY gp_segment_id;
```

**分区表：**
```sql
-- 创建范围分区表
CREATE TABLE sales (
    id SERIAL,
    product_id INTEGER,
    sale_date DATE,
    amount NUMERIC(10,2)
) DISTRIBUTED BY (product_id)
PARTITION BY RANGE (sale_date)
(
    START ('2026-01-01') INCLUSIVE
    END ('2027-01-01') EXCLUSIVE
    EVERY (INTERVAL '1 month')
);

-- 添加分区
ALTER TABLE sales ADD PARTITION p202701 VALUES LESS THAN ('2027-02-01');

-- 删除分区
ALTER TABLE sales DROP PARTITION FOR (RANGE ('2026-01-01', '2026-02-01'));
```

## 数据仓库最佳实践

### 1. ETL 性能优化

**使用子查询预聚合：**
```sql
-- 好的做法：子查询预聚合
INSERT INTO ads_summary
SELECT 
    main.customer_id,
    main.customer_name,
    agg.total_orders,
    agg.total_amount
FROM dws_customer_info AS main
LEFT JOIN (
    SELECT 
        customer_id,
        COUNT(*) AS total_orders,
        SUM(amount) AS total_amount
    FROM dws_order_detail
    WHERE order_date >= '2026-01-01'
    GROUP BY customer_id
) AS agg ON main.customer_id = agg.customer_id;

-- 避免：直接大表 JOIN
INSERT INTO ads_summary
SELECT 
    main.customer_id,
    main.customer_name,
    (SELECT COUNT(*) FROM dws_order_detail WHERE customer_id = main.customer_id) AS total_orders
FROM dws_customer_info AS main;
```

**NULL 值处理：**
```sql
-- 使用 COALESCE 处理 NULL
SELECT 
    customer_name,
    COALESCE(phone, '未知') AS phone_display,
    COALESCE(order_amount, 0) AS amount_safe
FROM customers;

-- 使用 CASE 处理 NULL
SELECT 
    customer_name,
    CASE 
        WHEN phone IS NULL THEN '未知'
        ELSE phone
    END AS phone_display
FROM customers;
```

**类型转换：**
```sql
-- 使用 :: 操作符转换类型
SELECT 
    id::TEXT AS id_text,
    amount::NUMERIC(10,2) AS amount_decimal
FROM orders;

-- 使用 CAST 转换类型
SELECT 
    CAST(id AS TEXT) AS id_text,
    CAST(amount AS NUMERIC(10,2)) AS amount_decimal
FROM orders;
```

### 2. 建表最佳实践

**字段设计：**
```sql
CREATE TABLE yanxuan.ods_example_table (
    -- 主键和业务键
    id VARCHAR(64) NOT NULL,                    -- 业务主键
    record_id SERIAL PRIMARY KEY,               -- 自增主键
    
    -- 业务字段
    business_field1 VARCHAR(100),               -- 业务字段
    business_field2 NUMERIC(10,2),              -- 金额字段
    business_field3 DATE,                       -- 日期字段
    
    -- 时间戳字段
    created_time TIMESTAMP DEFAULT NOW(),       -- 创建时间
    updated_time TIMESTAMP DEFAULT NOW(),       -- 更新时间
    etl_load_time TIMESTAMP DEFAULT NOW(),      -- ETL 加载时间
    
    -- 状态字段
    status VARCHAR(32) DEFAULT 'active',        -- 状态字段
    is_deleted BOOLEAN DEFAULT FALSE            -- 逻辑删除标志
);
```

**添加注释：**
```sql
-- 表注释
COMMENT ON TABLE yanxuan.ods_example_table IS '示例表-数据仓库ODS层';

-- 字段注释
COMMENT ON COLUMN yanxuan.ods_example_table.id IS '业务主键';
COMMENT ON COLUMN yanxuan.ods_example_table.record_id IS '自增主键';
COMMENT ON COLUMN yanxuan.ods_example_table.business_field1 IS '业务字段1';
COMMENT ON COLUMN yanxuan.ods_example_table.etl_load_time IS 'ETL加载时间';
```

### 3. 索引优化

**常用索引策略：**
```sql
-- 业务主键索引
CREATE INDEX idx_ods_example_id ON yanxuan.ods_example_table(id);

-- 日期范围查询索引
CREATE INDEX idx_ods_example_date ON yanxuan.ods_example_table(created_time);

-- 复合索引（JOIN 条件）
CREATE INDEX idx_ods_example_composite ON yanxuan.ods_example_table(id, created_time);

-- 部分索引（常用查询条件）
CREATE INDEX idx_ods_example_active ON yanxuan.ods_example_table(id) 
WHERE status = 'active';
```

## 数据清洗和转换

### 1. 常见数据清洗

**去重处理：**
```sql
-- 使用 DISTINCT ON 去重（保留最新记录）
CREATE TABLE cleaned_table AS
SELECT DISTINCT ON (business_key)
    business_key,
    data_field,
    update_time
FROM raw_table
ORDER BY business_key, update_time DESC;

-- 使用窗口函数去重
WITH ranked_data AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY business_key ORDER BY update_time DESC) AS rn
    FROM raw_table
)
SELECT 
    business_key,
    data_field,
    update_time
FROM ranked_data
WHERE rn = 1;
```

**NULL 值清洗：**
```sql
-- 更新 NULL 值
UPDATE table_name
SET field_name = '默认值'
WHERE field_name IS NULL;

-- 数据标准化
UPDATE table_name
SET phone = REGEXP_REPLACE(phone, '[^0-9]', '', 'g')  -- 只保留数字
WHERE phone IS NOT NULL;

-- 数据验证
SELECT 
    COUNT(*) AS total_records,
    COUNT(CASE WHEN phone ~ '^[0-9]{11}$' THEN 1 END) AS valid_phones,
    COUNT(CASE WHEN email ~ '.*@.*' THEN 1 END) AS valid_emails
FROM table_name;
```

### 2. 数据转换

**日期格式转换：**
```sql
-- 字符串转日期
UPDATE orders
SET order_date = TO_DATE(date_string, 'YYYY-MM-DD')
WHERE order_date IS NULL;

-- 日期转字符串
SELECT TO_CHAR(NOW(), 'YYYYMMDD') AS date_format;
```

**数据透视转换：**
```sql
-- 行转列（数据透视）
SELECT 
    customer_id,
    SUM(CASE WHEN month = '2026-01' THEN amount ELSE 0 END) AS jan_amount,
    SUM(CASE WHEN month = '2026-02' THEN amount ELSE 0 END) AS feb_amount,
    SUM(CASE WHEN month = '2026-03' THEN amount ELSE 0 END) AS mar_amount
FROM monthly_sales
GROUP BY customer_id;
```

## 使用方法

### 描述需求，生成 SQL

**示例 1：ETL 脚本**
```
帮我写一个脚本，从 DWS 层表关联数据并插入到 ADS 层表
```

**输出：**
```sql
-- 清空 ADS 表
TRUNCATE TABLE yanxuan.ads_target_table;

-- 从 DWS 层关联数据并插入
INSERT INTO yanxuan.ads_target_table
SELECT 
    main.field1,
    main.field2,
    detail.field3
FROM yanxuan.dws_source_table AS main
LEFT JOIN yanxuan.dws_detail_table AS detail
    ON main.id = detail.main_id;
```

### 提供不完整的 SQL，帮助完善

**示例：**
```
帮我完善这个建表脚本：
CREATE TABLE yanxuan.ods_new_table (
    id VARCHAR(64) NOT NULL,
```

**输出：**
```sql
CREATE TABLE yanxuan.ods_new_table (
    id VARCHAR(64) NOT NULL,
    status VARCHAR(32),
    busi_type VARCHAR(16),
    etl_load_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_time TIMESTAMP DEFAULT NOW(),
    updated_time TIMESTAMP DEFAULT NOW()
);

-- 添加表注释
COMMENT ON TABLE yanxuan.ods_new_table IS '新表-数据仓库ODS层';

-- 添加字段注释
COMMENT ON COLUMN yanxuan.ods_new_table.id IS '业务主键';
COMMENT ON COLUMN yanxuan.ods_new_table.status IS '状态字段';
COMMENT ON COLUMN yanxuan.ods_new_table.busi_type IS '业务类型';
COMMENT ON COLUMN yanxuan.ods_new_table.etl_load_time IS 'ETL加载时间';
```

### 提供有问题的 SQL，帮助修复

**示例：**
```
这个脚本有错误，帮我修复：
TRUNCATE TABLE yanxuan.ads_table;
INSERT INTO yanxuan.ads_table SELECT ...
```

**输出：**
```sql
-- 清空 ADS 表
TRUNCATE TABLE yanxuan.ads_table;

-- 插入数据
INSERT INTO yanxuan.ads_table
SELECT 
    field1,
    field2,
    field3
FROM source_table;
```

**说明：** 原查询缺少字段选择，已补全。

## 注意事项

- Greenplum 是分布式数据库，注意数据分布策略
- ETL 脚本使用 TRUNCATE + INSERT 模式
- 大表查询注意性能，使用子查询预聚合
- 使用 COALESCE 处理 NULL 值
- 定期执行 ANALYZE 更新统计信息
- 建表时添加注释说明
- 注意字段类型选择
- 使用适当的索引优化查询
- 遵循数据仓库分层规范（ODS、DWS、ADS）
- 使用有意义的命名规范
- 保持 ETL 脚本的可维护性