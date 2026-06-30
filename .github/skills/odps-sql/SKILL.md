---
name: "odps-sql"
description: "用于编写、续写、修改和排查 MaxCompute/ODPS SQL。用户提到 odps sql、maxcompute sql、dataworks 脚本、离线报表 sql、ads/dws/dwd 开发、insert overwrite、分区脚本、指标口径、需求表转 sql 时都应使用。尤其适用于需要查看当前工作区 odps 目录下已有 SQL 脚本，并沿用现有表命名、字段口径、注释风格和分层习惯继续开发的场景。"
---

# ODPS SQL 助手

这是一个面向 MaxCompute / ODPS / DataWorks 离线数仓开发的 SQL skill，重点服务你当前仓库里的 odps 脚本开发场景。

## 何时使用

- 用户说“帮我写 odps sql”“帮我补一个 dataworks 脚本”
- 用户要开发 ADS、DWS、DWD、标签、周报月报类离线 SQL
- 用户给出需求说明，希望转换成 MaxCompute SQL
- 用户给出已有 SQL，希望继续补字段、补 join、补分区、补口径
- 用户要求参考当前工作区 odps 目录里的已有脚本风格来写

## 不适用场景

- PostgreSQL、MySQL、Oracle、Greenplum 等非 ODPS 方言
- 只需要 Python、Shell 或 Excel 处理，不需要 SQL
- 用户只想要概念解释，不需要落成脚本

## 工作方式

### Step 1：优先参考当前工作区已有脚本
如果用户没有明确要求从零开始写，先查看 odps 目录下相关 SQL，优先沿用已有：

- 表分层习惯，例如 ods / dwd / dws / ads
- 命名方式
- 字段别名风格
- 注释风格
- 分区写法
- 常用函数和业务口径

不要脱离当前仓库风格另起一套写法。

### Step 2：先识别任务类型
优先判断用户属于哪一类需求：

- 新写整段离线 SQL
- 在现有 SQL 上补字段、补逻辑、补分区
- 修复 SQL 报错
- 调整指标口径
- 需求表/字段清单转 SQL
- 基于已有脚本仿写周报、月报、标签脚本

### Step 3：信息不足时的处理
如果直接写 SQL 仍缺关键条件，优先补问这些信息：

- 目标表名
- 分层位置
- 分区字段
- 统计粒度
- 时间范围
- 主表和关联表
- 指标口径

如果当前工作区已有高度相似脚本，先参考相似脚本给出草稿，再标明待确认项。

## 当前仓库的推荐写法

根据当前 odps 目录里的现有脚本，默认优先遵循以下习惯：

- 离线结果表优先使用 `INSERT OVERWRITE TABLE ... PARTITION (...)`
- 长 SQL 可以使用多段 `UNION`、多层子查询和左连接
- 保留中文业务含义别名，例如状态、是否类字段
- 口径说明优先体现在注释和字段命名上
- 对复杂来源拼接、标签拼接、枚举翻译，允许使用较长 `CASE WHEN`
- 能复用现有表和现有口径时，不额外发明新口径

## 当前仓库常见函数和变量习惯

编写时优先沿用当前仓库里已经出现过的 MaxCompute / DataWorks 写法：

- 分区或业务日期变量：`${today}`、`${bizdate}`
- 最新分区：`max_pt('table_name')`
- 空值处理：`nvl()`、`coalesce()`
- 时间函数：`getdate()`、`dateadd()`、`datetrunc()`、`weekofyear()`、`year()`
- JSON 提取：`get_json_object()`
- 字符串拼接或聚合：`wm_concat()`、`concat()`、`regexp_replace()`、`split()`
- 数组或多值拼接：`CONCATNOEMPTY(ARRAY(...), ';')`
- 展开数组：`LATERAL VIEW explode(...)`

如果用户没有明确要求，不要擅自把当前脚本风格改写成另一套函数体系。

## 当前仓库常见开发类型

结合现有 odps 脚本，优先支持以下几类开发：

- 自营维修日报、周报、月报 ADS 报表脚本
- DWD 明细宽表加工
- DWS 汇总层服务单统计
- 标签明细和画像类脚本
- 跨业务系统主数据 / 身份打通类脚本

如果用户要写周报、月报、区域报表、项目画像，优先先看 odps 目录里同类型现有脚本再续写。

## 常见任务模板

### 1. 分区覆盖脚本

```sql
INSERT OVERWRITE TABLE target_table PARTITION (ds = ${bizdate})
SELECT  ...
FROM    source_table
WHERE   ds = ${bizdate}
;
```

### 2. 指标汇总脚本

```sql
INSERT OVERWRITE TABLE ads_xxx PARTITION (ds = ${bizdate})
SELECT  dim_1
        ,dim_2
        ,COUNT(1) AS xxx_cnt
        ,SUM(amount) AS xxx_amount
FROM    dwd_xxx
WHERE   ds = ${bizdate}
GROUP BY dim_1
         ,dim_2
;
```

### 3. 标签明细脚本

```sql
INSERT OVERWRITE TABLE dws_xxx_label_detail PARTITION (ds = ${bizdate})
SELECT  user_id
        ,CASE WHEN ... THEN '是' ELSE '否' END AS label_flag
        ,CASE WHEN ... THEN '高' ELSE '低' END AS label_level
FROM    source_table
WHERE   ds = ${bizdate}
;
```

## 编写规则

1. 优先输出完整可执行 SQL，不只给片段。
2. 保留关键过滤条件和分区条件，不要漏写 `ds` 等业务日期字段。
3. 涉及口径判断时，优先沿用当前 odps 目录现有脚本中的字段定义和状态映射。
4. 修改现有 SQL 时，优先做最小改动，不要重写整段无关逻辑。
5. 不确定字段或表是否存在时，要明确指出待确认项，不能硬编。
8. 如果当前工作区已有高相似脚本，优先“仿写 + 改字段/改维度/改时间粒度”，不要凭空重构。

## 口径和风格注意事项

- 对“已完成、已取消、已退款、已接单、已上门”等状态口径，优先参考现有脚本中的 `CASE WHEN` 映射。
- 对周环比、月环比、转化率、及时率等指标，优先复用现有脚本中的分母保护逻辑，例如分母为 0 时返回 `null`。
- 对组织字段如大区、城市、阵地、项目，优先沿用现有别名和字段顺序。
- 对维修、研选、自营、收费/免费等业务分类，优先复用已有脚本中的判断条件。

## 排错规则

如果用户说 SQL 报错，优先排查：

- 字段名是否不存在
- 分组字段是否缺失
- 分区条件是否遗漏
- join 条件是否导致重复或丢数
- 类型转换是否缺失
- MaxCompute 函数是否与其他数据库函数混用

输出时优先说明：

- 错误点在哪里
- 为什么错
- 应该改成什么

## 输出要求

- 如果用户要脚本：直接给完整 SQL
- 如果用户要改现有脚本：先说明改动点，再给修改后的关键 SQL
- 如果用户要查问题：先给结论，再给修复后的 SQL
- 尽量沿用当前仓库已有风格，不要无故改成另一套排版或命名

## 示例

### 示例 1：参考现有脚本仿写

用户请求：

```text
参考 odps 目录里的周报脚本，帮我写一个区域月报 SQL
```

处理方式：

- 先查看 odps 目录里已有周报和月报脚本
- 找到最相近的 ads 脚本作为模板
- 沿用现有字段口径、时间过滤和组织维度

### 示例 2：补现有 SQL 字段

用户请求：

```text
在这个 odps sql 里补一个是否超时完工字段
```

处理方式：

- 先读当前 SQL
- 找出完工时间、预约时间或 SLA 字段
- 只补最小必要字段和逻辑，不改无关部分

### 示例 3：需求表转 SQL

用户请求：

```text
我给你一个需求说明，帮我写成 odps sql
```

处理方式：

- 先抽取目标表、来源表、维度、指标、分区和时间粒度
- 如果仓库里已有类似脚本，优先按类似脚本结构生成
- 缺信息时先补问关键口径