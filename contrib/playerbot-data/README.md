# PlayerBots 独立数据导入（TBC）

当前入口为 `playerbot_data.py` 与 `tbc/manifest.json`，目标是角色数据库。不要执行旧的 bot SQL，不使用 dev SQL 编号、最大编号标记或“缺表时回退世界库”。世界库只保留原生生物、物品、地图与副本数据。

运行环境：Python 3 与 PyMySQL（`python -m pip install PyMySQL`）。口令通过 `PLAYERBOT_DB_PASSWORD` 环境变量提供，不写入参数、数据包或日志。

```sh
# 离线检查包；不需要数据库连接
python playerbot_data.py check --package tbc

# 预览：不修改数据库
python playerbot_data.py import --package tbc --characters tbccharacters

# 停止游戏进程后导入，备份放在数据库外的专用目录
python playerbot_data.py import --package tbc --characters tbccharacters --apply --backup-dir /path/to/release/backup

# 逐表验证，静态表逐行哈希必须一致
python playerbot_data.py verify --package tbc --characters tbccharacters

# 新二进制验证通过后，先预览世界库旧表退役，再执行
python playerbot_data.py retire-world --package tbc --characters tbccharacters
python playerbot_data.py retire-world --package tbc --characters tbccharacters --apply --backup-dir /path/to/release/backup
```

`--world`、`--characters`、`--host`、`--port` 可指定实例；工具不推断库名。角色库与世界库必须不同。首次迁移必须同时切换配套二进制；旧二进制仍从世界库读 bot 策略。

数据规则写在 manifest 中：

- `replace`：完整静态基线，事务内 DELETE + INSERT；导入后按包内行数与 SHA-256 验证。公共自定义策略仅覆盖 owner=0，私人策略保留。
- `preserve`：角色、缓存、日志、观测与职责等环境状态，不把本地运行行复制给生产；原有角色库表保留，世界库独有运行表复制到角色库；原表保留到单独退役，供首次切换失败时回滚旧二进制，缺表才建空结构。
- `seed`：名字池仅新建时填充；已有池不替换，避免角色名称与运行记录失配。

包中不保存角色、账号、物品实例、背包、天赋、密码和历史备份表。装备固定清单由配套源码定义，旧 BIS 表留作兼容参考；不能用 BIS 表行数证明角色已穿装。

每份压缩 JSONL 都同时校验文件 SHA-256、解压行数与规范化行哈希。升级已有 `ai_playerbot_avoid_spell` 表时，先只读检查 `break_los`：缺列才执行 `migrations/20261112_avoid_spell_break_los.sql`，已有该列则跳过；新建库由 manifest 建表，不需要该迁移。导入器保留结构不一致即拒绝的规则，不会自行改生产结构。导入前验证整个包，遇错退出；需要按实际错误修复，不使用忽略错误继续执行。`export` 用于维护者从已审查环境生成下一版包，生成后必须复核差异并完成空库导入、重复导入及运行测试，才能发布。导出逐表优先角色库的结构与内容（即使该表为空），只有角色库缺表才从世界库兼容导出；同名旧副本不覆盖权威数据，`--dry-run` 可查看来源及差异提示。通用怪物仇恨表 `ai_playerbot_threat_rule` 的 `tank_rank/dps_pct/melee_only` 分别控制第N坦克上限、DPS百分比和近战坦克筛选，`tank_rank=0`关闭；适用于普通怪、精英和Boss，原 `rank/pct` 保留原坦克追仇恨语义。

此工具是维护工具，不在运行中的地图线程里执行迁移，不通过 `.reload` 生效。生产发布纪律和实际验证记录统一见主仓库的 `dev/KNOWN_ISSUES.md` → PlayerBots 章节。
