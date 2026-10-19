# baseline —— 分叉时刻的 world 库快照（2026-10-18）

> 目的：把"我们还没动上游更新"这一刻的库整份冻起来。以后无论是对上游合并，
> 还是回头看"这个改动是我们什么时候引入的"，都以这份快照为原点做差分。
> 目录名：`Nmangos-tbc\dev\baseline\`

## 一、快照代表什么位置（以 MySQL 为准）

| 维度 | 值 | 上游对应 |
|---|---|---|
| 内容更新 | 更新到 **0740**（`content_0740_trigger_while_charmed` 书签；0741 的改列已被 core `s2491` 带上） | tbc-db `13b1403e`（1.11.0 Release，2026-08-09） |
| core 同步 | **`required_s2492_01_mangos_gobject_near_link`** | core 仓 `f0168395c`（2026-08-23） |
| 1.11.0 之后的 44 条上游更新（`0001`～`0044`） | **一条都没上** | 上游最新 `8967839f`（2026-10-17） |
| 本地 `dev\*.sql` 自制补丁 | 已全部应用（001～189 那批） | —— |

判定依据是数据探针，不是 `db_version` 的书签列（书签列没人维护，`tbcmangos_orig` /
`tbcdb_ref` 里还有人工造的名字）。本项目探针见 `verify_fork_position.sql`（只读）。

## 二、文件清单

| 文件 | 大小 | 说明 |
|---|---|---|
| `tbcmangos_fork_20261018_upstream-1.11.0-0740.sql.gz` | 102.3 MB（解压后 410.8 MB） | tbcmangos 全量逻辑备份，241 张表，含 routines/events |
| `tbcmangos_table_fingerprint_20261018.tsv` | 241 行 | 每表 `行数 + CHECKSUM`，用来快速找"哪天之后哪张表变了" |
| `verify_fork_position.sql` | 1.6 KB | 只读探针：查 core 同步列 + 内容侧三条数据探针 |
| `README.md` | 本文件 | —— |

- 快照 md5：`46ecd9a7fa9853a9d673a0ff1608bce1`
- 生成命令（原样）：

```powershell
mysqldump --host=127.0.0.1 --port=3306 --user=root --protocol=TCP `
  --default-character-set=utf8 --routines --events --max-allowed-packet=1G `
  --result-file=<...>.sql tbcmangos
gzip -9 -f <...>.sql
```

- `.sql.gz` 不会被 `.gitignore` 之外的任何脚本误执行：`run_dev_sql.ps1` 只取 `dev\` **根目录**的
  `*.sql`，`InstallFullDB.sh` 的 `apply_dev_content` 只取 `dev/*.sql` 和 `dev/*/*.sql`，
  而本目录里唯一的 `.sql` 是只读探针。**注意：以后往这套体系里加"要被执行的补丁"仍放 `dev\` 根目录。**

## 三、恢复

先停 mangosd（**云端恢复必须站长点头，见 P0 铁律**），再：

```cmd
mysql --host=127.0.0.1 --port=3306 --user=root -p -e "DROP DATABASE IF EXISTS tbcmangos; CREATE DATABASE tbcmangos DEFAULT CHARACTER SET utf8;"
gzip -dc tbcmangos_fork_20261018_upstream-1.11.0-0740.sql.gz | mysql --host=127.0.0.1 --port=3306 --user=root -p tbcmangos
```

> Windows PowerShell 不支持 `<` 重定向，用 `cmd /c` 或上面这种管道。

## 四、怎么用它差分（"从这以后改了什么"）

1. **先比指纹**（秒级，不用解压）：

```sql
-- 生成和 tsv 同格式的当前指纹，然后和 tsv 逐行 diff
CHECKSUM TABLE tbcmangos.<表名>;  SELECT COUNT(*) FROM tbcmangos.<表名>;
```

2. **再看具体行**：只把可疑的那几张表从快照里捞出来对比

```cmd
gzip -dc ...sql.gz > all.sql
findstr /C:"CREATE TABLE `creature_template`" all.sql
```

3. **schema 差分**：`mysqldump --no-data tbcmangos` 对比快照里的建表语句。
