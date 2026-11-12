#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""通用怪 DPS 仇恨规则：给 CharacterDatabase.ai_playerbot_threat_rule 幂等补列并播种。

背景（2026-11-11 站长口径）
- 旧列 rank/pct 是 DungeonAssistLooseAction 的"坦克追仇恨"参数，语义不重定义、不改写。
- 新增三列独立表达"任意生物（普通怪/精英/Boss）的 DPS 仇恨上限"：
    tank_rank  TINYINT UNSIGNED NOT NULL DEFAULT 0  0=关闭该生物的 DPS 机制；N=第 N 个合格存活坦克的威胁作基准
    dps_pct    FLOAT NOT NULL DEFAULT 90            DPS 提前停手百分比
    melee_only TINYINT UNSIGNED NOT NULL DEFAULT 0  1=只把近战可达的坦克算作合格坦克
- CharacterDatabase 是权威；world 库只能作为只读兼容数据源（--world-database），本脚本从不写 world。
- 本脚本不 DROP/DELETE/TRUNCATE，不建 *_bak 表，不改 rank/pct，也不动四条目标行之外的数据。

用法（密码只从环境变量读，默认不打印）:
    $env:PLAYERBOT_DB_PASSWORD='<本地密码>'
    python dev/analyzers/seed_creature_threat.py --database tbccharacters            # 只读计划
    python dev/analyzers/seed_creature_threat.py --database tbccharacters --apply    # 执行迁移
    python dev/analyzers/seed_creature_threat.py --database tbccharacters --world-database tbcmangos

安全闸
- --database 必填，且脚本只写这个库；拒绝 mysql/information_schema 等系统库。
- 非本机 host 必须显式 --allow-remote；脚本里没有任何云端地址。
- --apply 前会探测库形态；像 world 库（有 creature/creature_template 且没有 characters）直接拒绝。
- 默认（不加 --apply）连接后立即 SET SESSION TRANSACTION READ ONLY，只展示计划。
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

try:
    import pymysql
except ImportError:  # pragma: no cover - 环境缺少依赖时给出可操作提示
    print("ERROR: 需要 pymysql（pip install pymysql）", file=sys.stderr)
    sys.exit(2)


SCRIPT = Path(__file__).resolve()
TABLE = "ai_playerbot_threat_rule"
SYSTEM_DATABASES = {"mysql", "information_schema", "performance_schema", "sys"}
LOCAL_HOSTS = {"127.0.0.1", "localhost", "::1"}

# 新增列：定义、类型校验值、默认值。列一律追加在表尾，MySQL 8 下是 INSTANT DDL。
NEW_COLUMNS = (
    {
        "name": "tank_rank",
        "definition": "TINYINT UNSIGNED NOT NULL DEFAULT 0",
        "type": "tinyint unsigned",
        "nullable": "NO",
        "default": "0",
        "fallback": 0,
    },
    {
        "name": "dps_pct",
        "definition": "FLOAT NOT NULL DEFAULT 90",
        "type": "float",
        "nullable": "NO",
        "default": "90",
        "fallback": 90.0,
    },
    {
        "name": "melee_only",
        "definition": "TINYINT UNSIGNED NOT NULL DEFAULT 0",
        "type": "tinyint unsigned",
        "nullable": "NO",
        "default": "0",
        "fallback": 0,
    },
)
NEW_COLUMN_NAMES = tuple(c["name"] for c in NEW_COLUMNS)
NEW_DEFAULTS = {c["name"]: c["fallback"] for c in NEW_COLUMNS}
BASE_COLUMNS = ("map", "entry", "rank", "pct", "note")

# 四条目标行。前三条在卡拉赞(532)，第四条在格鲁尔的巢穴(565)。
# melee_only=1 只对 565/19044 生效；所有行 tank_rank=2、dps_pct=90。
SEEDS = (
    {"map": 532, "entry": 15687, "tank_rank": 2, "dps_pct": 90.0, "melee_only": 0},
    {"map": 532, "entry": 16471, "tank_rank": 2, "dps_pct": 90.0, "melee_only": 0},
    {"map": 532, "entry": 15691, "tank_rank": 2, "dps_pct": 90.0, "melee_only": 0},
    {"map": 565, "entry": 19044, "tank_rank": 2, "dps_pct": 90.0, "melee_only": 1},
)

CREATE_TABLE_SQL = (
    "CREATE TABLE IF NOT EXISTS `{db}`.`{table}` (\n"
    "  `map` SMALLINT UNSIGNED NOT NULL,\n"
    "  `entry` INT UNSIGNED NOT NULL,\n"
    "  `rank` TINYINT UNSIGNED NOT NULL DEFAULT 1,\n"
    "  `pct` FLOAT NOT NULL DEFAULT 100,\n"
    "  `note` VARCHAR(160) NOT NULL DEFAULT '',\n"
    "  `tank_rank` TINYINT UNSIGNED NOT NULL DEFAULT 0,\n"
    "  `dps_pct` FLOAT NOT NULL DEFAULT 90,\n"
    "  `melee_only` TINYINT UNSIGNED NOT NULL DEFAULT 0,\n"
    "  PRIMARY KEY (`map`,`entry`)\n"
    ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
)


class SafetyError(Exception):
    """参数、权限边界或 schema 冲突：不继续写。"""


def configure_output():
    """被管道/工具捕获时强制 UTF-8，避免中文输出乱码；真终端保持系统编码。"""
    for stream in (sys.stdout, sys.stderr):
        try:
            if not stream.isatty():
                stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass


def quote_ident(name):
    if not re.fullmatch(r"[A-Za-z0-9_]+", name or ""):
        raise SafetyError("非法标识符: %r" % (name,))
    return "`" + name + "`"


def normalize_type(value):
    text = re.sub(r"\s+", " ", (value or "").strip().lower())
    return re.sub(r"^(tinyint|smallint|mediumint|int|bigint)\(\d+\)", r"\1", text)


def default_matches(actual, expected):
    if actual is None:
        return False
    left = str(actual).strip().strip("'")
    right = str(expected).strip()
    try:
        return abs(float(left) - float(right)) < 1e-9
    except ValueError:
        return left.lower() == right.lower()


def as_int(value, fallback=None):
    try:
        return int(str(value).strip().strip("'"))
    except (TypeError, ValueError):
        return fallback


def as_float(value, fallback=None):
    try:
        return float(str(value).strip().strip("'"))
    except (TypeError, ValueError):
        return fallback


def sql_literal(value):
    if isinstance(value, str):
        return "'" + value.replace("\\", "\\\\").replace("'", "''") + "'"
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, float):
        return "%g" % value
    return str(value)


def parse_args(argv):
    parser = argparse.ArgumentParser(
        description="幂等迁移 ai_playerbot_threat_rule：补 tank_rank/dps_pct/melee_only 并写入四条规则。",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "示例:\n"
            "  set PLAYERBOT_DB_PASSWORD=...   (PowerShell: $env:PLAYERBOT_DB_PASSWORD='...')\n"
            "  python dev/analyzers/seed_creature_threat.py --database tbccharacters\n"
            "  python dev/analyzers/seed_creature_threat.py --database tbccharacters --apply\n"
        ),
    )
    parser.add_argument("--host", default="127.0.0.1", help="数据库主机（默认 127.0.0.1）")
    parser.add_argument("--port", type=int, default=3306, help="端口（默认 3306）")
    parser.add_argument("--user", default="root", help="用户名（默认 root）")
    parser.add_argument(
        "--password-env",
        default="PLAYERBOT_DB_PASSWORD",
        metavar="NAME",
        help="保存密码的环境变量名（默认 PLAYERBOT_DB_PASSWORD；密码值不会输出）",
    )
    parser.add_argument(
        "--database",
        required=True,
        metavar="DB",
        help="必填：要迁移的角色库（CharacterDatabase），例如 tbccharacters；脚本只写这个库",
    )
    parser.add_argument(
        "--world-database",
        metavar="DB",
        help="可选：旧 world 库名，仅只读对照；脚本绝不会写它",
    )
    parser.add_argument("--apply", action="store_true", help="真正执行 DDL/DML；不加只展示计划")
    parser.add_argument("--json", action="store_true", help="以 JSON 输出计划/结果（便于自动验收）")
    parser.add_argument(
        "--allow-remote",
        action="store_true",
        help="允许连接非本机 host；默认拒绝，以免脚本被误指向云端",
    )
    parser.add_argument("--connect-timeout", type=int, default=10, help="连接超时秒数（默认 10）")
    return parser.parse_args(argv)


def validate_args(args):
    args.host = (args.host or "").strip()
    args.user = (args.user or "").strip()
    if not args.host:
        raise SafetyError("--host 不能为空")
    if not 1 <= args.port <= 65535:
        raise SafetyError("--port 超出范围: %d" % args.port)
    if not args.user:
        raise SafetyError("--user 不能为空")
    if not re.fullmatch(r"[A-Za-z0-9_]+", args.database or ""):
        raise SafetyError("--database 只接受字母/数字/下划线: %r" % (args.database,))
    if args.database.lower() in SYSTEM_DATABASES:
        raise SafetyError("拒绝迁移系统库: %s" % args.database)
    if args.world_database and args.world_database == args.database:
        raise SafetyError("--database 与 --world-database 不能相同")
    if args.world_database and not re.fullmatch(r"[A-Za-z0-9_]+", args.world_database):
        raise SafetyError("--world-database 只接受字母/数字/下划线")
    if args.host.lower() not in LOCAL_HOSTS and not args.allow_remote:
        raise SafetyError(
            "拒绝连接非本机 host=%s；如确实需要，必须显式加 --allow-remote" % args.host
        )
    if args.connect_timeout <= 0:
        raise SafetyError("--connect-timeout 必须为正数")


def make_note(seed):
    pct_text = "%g" % seed["dps_pct"]
    melee_text = "坦克仅计近战可达" if seed["melee_only"] else "坦克不限近战"
    return "DPS仇恨机制: 基准=第%d个合格存活坦克的威胁; 达到%s%%提前停手; %s" % (
        seed["tank_rank"],
        pct_text,
        melee_text,
    )


def validate_seeds():
    seen = set()
    for seed in SEEDS:
        key = (seed["map"], seed["entry"])
        if key in seen:
            raise SafetyError("种子重复: %s" % (key,))
        seen.add(key)
        if not 0 <= seed["map"] <= 65535:
            raise SafetyError("map 越界: %s" % (seed,))
        if not 0 < seed["entry"] <= 4294967295:
            raise SafetyError("entry 越界: %s" % (seed,))
        # 与 CreatureThreatRules.h 的运行时校验保持一致：tank_rank 1..40、0<dps_pct<=100、melee_only 0/1。
        if not 1 <= seed["tank_rank"] <= 40:
            raise SafetyError("tank_rank 必须在 1..40: %s" % (seed,))
        if not 0.0 < seed["dps_pct"] <= 100.0:
            raise SafetyError("dps_pct 必须在 (0,100]: %s" % (seed,))
        if seed["melee_only"] not in (0, 1):
            raise SafetyError("melee_only 只能是 0/1: %s" % (seed,))
        note = make_note(seed)
        if len(note) > 160:
            raise SafetyError("note 超过 varchar(160): %s" % note)
        seed["note"] = note


def connect(args, readonly):
    password = os.environ.get(args.password_env)
    if password is None:
        raise SafetyError(
            "环境变量 %s 未设置；密码只从环境变量读取，不要放到命令行" % args.password_env
        )
    conn = pymysql.connect(
        host=args.host,
        port=args.port,
        user=args.user,
        password=password,
        charset="utf8mb4",
        autocommit=False,
        connect_timeout=args.connect_timeout,
        read_timeout=120,
        write_timeout=120,
    )
    if readonly:
        try:
            conn.commit()
            with conn.cursor() as cur:
                cur.execute("SET SESSION TRANSACTION READ ONLY")
        except Exception:
            conn.close()
            raise
    return conn


def inspect_schema(conn, database):
    db = quote_ident(database)
    state = {
        "database": database,
        "table": TABLE,
        "exists": False,
        "table_type": None,
        "engine": None,
        "columns": [],
        "primary_key": [],
        "rows": 0,
    }
    with conn.cursor() as cur:
        cur.execute(
            "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=%s",
            (database,),
        )
        if not cur.fetchone():
            raise SafetyError("数据库不存在: %s（脚本不会创建数据库）" % database)

        cur.execute(
            "SELECT TABLE_TYPE, ENGINE FROM information_schema.TABLES "
            "WHERE TABLE_SCHEMA=%s AND TABLE_NAME=%s",
            (database, TABLE),
        )
        found = cur.fetchone()
        if not found:
            return state
        state["exists"] = True
        state["table_type"] = found[0]
        state["engine"] = found[1]
        if str(found[0]).upper() != "BASE TABLE":
            raise SafetyError("%s.%s 不是基表（%s），拒绝迁移" % (database, TABLE, found[0]))

        cur.execute(
            "SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA "
            "FROM information_schema.COLUMNS "
            "WHERE TABLE_SCHEMA=%s AND TABLE_NAME=%s ORDER BY ORDINAL_POSITION",
            (database, TABLE),
        )
        state["columns"] = [
            {
                "name": row[0],
                "type": row[1],
                "nullable": row[2],
                "default": row[3],
                "extra": row[4] or "",
            }
            for row in cur.fetchall()
        ]

        cur.execute(
            "SELECT COLUMN_NAME FROM information_schema.STATISTICS "
            "WHERE TABLE_SCHEMA=%s AND TABLE_NAME=%s AND INDEX_NAME='PRIMARY' "
            "ORDER BY SEQ_IN_INDEX",
            (database, TABLE),
        )
        state["primary_key"] = [row[0] for row in cur.fetchall()]

        cur.execute("SELECT COUNT(*) FROM %s.%s" % (db, quote_ident(TABLE)))
        state["rows"] = int(cur.fetchone()[0])
    return state


def database_shape(conn, database):
    with conn.cursor() as cur:
        cur.execute(
            "SELECT TABLE_NAME FROM information_schema.TABLES "
            "WHERE TABLE_SCHEMA=%s AND TABLE_NAME IN ('characters','creature','creature_template')",
            (database,),
        )
        tables = {row[0].lower() for row in cur.fetchall()}
    if "characters" in tables:
        return "characters"
    if "creature" in tables and "creature_template" in tables:
        return "world"
    return "unknown"


def schema_plan(state):
    """返回 {create_sql, alter_sql, missing, columns_after, warnings}；冲突直接抛 SafetyError。"""
    result = {
        "create_sql": None,
        "alter_sql": None,
        "missing": [],
        "columns_after": [],
        "warnings": [],
    }
    if not state["exists"]:
        result["create_sql"] = CREATE_TABLE_SQL.format(
            db=state["database"], table=TABLE
        )
        result["missing"] = list(NEW_COLUMN_NAMES)
        result["columns_after"] = list(BASE_COLUMNS) + list(NEW_COLUMN_NAMES)
        return result

    names = [c["name"] for c in state["columns"]]
    lowered = {c["name"].lower(): c for c in state["columns"]}
    missing_base = [name for name in BASE_COLUMNS if name not in lowered]
    if missing_base:
        raise SafetyError(
            "已有表缺少旧列 %s；拒绝在未知结构上迁移" % ",".join(missing_base)
        )
    if [c.lower() for c in state["primary_key"]] != ["map", "entry"]:
        raise SafetyError(
            "已有表的主键是 (%s)，不是 (map,entry)；没有该主键无法幂等 upsert，拒绝迁移"
            % ",".join(state["primary_key"])
        )
    if state["engine"] and str(state["engine"]).lower() != "innodb":
        raise SafetyError(
            "已有表引擎是 %s，不是 InnoDB；为保住事务回滚，--apply 拒绝迁移" % state["engine"]
        )

    problems = []
    for spec in NEW_COLUMNS:
        column = lowered.get(spec["name"])
        if not column:
            result["missing"].append(spec["name"])
            continue
        actual_type = normalize_type(column["type"])
        if actual_type != spec["type"]:
            problems.append(
                "%s 类型是 %s，期望 %s（不自动 MODIFY，避免覆盖人工 schema）"
                % (spec["name"], column["type"], spec["definition"])
            )
        if str(column["nullable"]).upper() != spec["nullable"]:
            problems.append("%s 的 NULL 属性是 %s，期望 NOT NULL" % (spec["name"], column["nullable"]))
        if not default_matches(column["default"], spec["default"]):
            problems.append(
                "%s 默认值是 %r，期望 %s（不自动 SET DEFAULT，避免覆盖人工 schema）"
                % (spec["name"], column["default"], spec["default"])
            )
        if column["extra"]:
            problems.append("%s 带 EXTRA=%s，与预期普通列不符" % (spec["name"], column["extra"]))
    if problems:
        raise SafetyError("已有新增列与预期不一致:\n  - " + "\n  - ".join(problems))

    # 旧列类型只告警，不改；本脚本不会触碰 rank/pct。
    expected_base_types = {
        "map": "smallint unsigned",
        "entry": "int unsigned",
        "rank": "tinyint unsigned",
        "pct": "float",
        "note": "varchar",
    }
    for name, expected in expected_base_types.items():
        actual = normalize_type(lowered[name]["type"])
        if actual != expected and not (expected == "varchar" and actual.startswith("varchar")):
            result["warnings"].append(
                "旧列 %s 的类型是 %s（期望 %s）；本脚本不改它，仅提示" % (name, lowered[name]["type"], expected)
            )

    if result["missing"]:
        clauses = [
            "ADD COLUMN `%s` %s" % (spec["name"], spec["definition"])
            for spec in NEW_COLUMNS
            if spec["name"] in result["missing"]
        ]
        result["alter_sql"] = "ALTER TABLE `%s`.`%s` %s" % (
            state["database"],
            TABLE,
            ", ".join(clauses),
        )
    result["columns_after"] = names + result["missing"]
    return result


def fetch_seed_rows(conn, database, state):
    """按 (map,entry) 取四条目标行；表中还没有新列时只取已有列。"""
    if not state["exists"]:
        return {}
    available = {c["name"].lower() for c in state["columns"]}
    select_columns = ["map", "entry", "rank", "pct", "note"]
    select_columns += [name for name in NEW_COLUMN_NAMES if name in available]
    ordered = []
    for name in select_columns:
        if name not in ordered:
            ordered.append(name)
    where = " OR ".join(["(map=%s AND entry=%s)"] * len(SEEDS))
    params = []
    for seed in SEEDS:
        params.extend([seed["map"], seed["entry"]])
    sql = "SELECT %s FROM `%s`.`%s` WHERE %s" % (
        ",".join("`%s`" % name for name in ordered),
        database,
        TABLE,
        where,
    )
    with conn.cursor() as cur:
        cur.execute(sql, params)
        rows = {}
        for values in cur.fetchall():
            row = {str(name).lower(): value for name, value in zip(ordered, values)}
            rows[(int(row["map"]), int(row["entry"]))] = row
    return rows


def build_seed_plan(conn, database, state):
    columns = {c["name"].lower(): c for c in state["columns"]}
    rank_default = as_int(columns["rank"]["default"]) if "rank" in columns else None
    pct_default = as_float(columns["pct"]["default"]) if "pct" in columns else None
    explicit_base = False
    warnings = []
    if rank_default is None or pct_default is None:
        # 表存在但旧列没有默认值：插入时显式写文档默认值 1/100（只影响新行，不碰既有行）。
        rank_default = 1 if rank_default is None else rank_default
        pct_default = 100.0 if pct_default is None else pct_default
        explicit_base = True
        warnings.append(
            "旧列 rank/pct 没有可用默认值；新插入行将显式写 rank=1/pct=100（既有行仍不改）"
        )

    existing = fetch_seed_rows(conn, database, state)
    count_before = state["rows"]
    items = []
    expected = {}
    inserts = 0

    for seed in SEEDS:
        key = (seed["map"], seed["entry"])
        canonical = {
            "tank_rank": int(seed["tank_rank"]),
            "dps_pct": float(seed["dps_pct"]),
            "melee_only": int(seed["melee_only"]),
            "note": seed["note"],
        }
        row = existing.get(key)
        if row is None:
            inserts += 1
            after = {
                "rank": rank_default,
                "pct": pct_default,
                "tank_rank": canonical["tank_rank"],
                "dps_pct": canonical["dps_pct"],
                "melee_only": canonical["melee_only"],
                "note": canonical["note"],
            }
            expected[key] = after
            insert_columns = ["map", "entry"]
            insert_values = [seed["map"], seed["entry"]]
            if explicit_base:
                insert_columns += ["rank", "pct"]
                insert_values += [rank_default, pct_default]
            insert_columns += ["note", "tank_rank", "dps_pct", "melee_only"]
            insert_values += [
                canonical["note"],
                canonical["tank_rank"],
                canonical["dps_pct"],
                canonical["melee_only"],
            ]
            items.append(
                {
                    "map": seed["map"],
                    "entry": seed["entry"],
                    "action": "insert",
                    "before": None,
                    "after": after,
                    "changes": {},
                    "sql": "INSERT INTO `%s`.`%s` (%s) VALUES (%s);"
                    % (
                        database,
                        TABLE,
                        ",".join("`%s`" % c for c in insert_columns),
                        ",".join(sql_literal(v) for v in insert_values),
                    ),
                    "insert_columns": insert_columns,
                    "insert_values": insert_values,
                }
            )
            continue

        # 已存在的行：rank/pct 原样保留，只比较新三列 + note。
        changes = {}
        for name in ("tank_rank", "dps_pct", "melee_only"):
            before_value = row.get(name)
            if before_value is None:
                before_value = NEW_DEFAULTS[name]  # 列尚未加时，ALTER 后会填这个默认值
            if name in ("tank_rank", "melee_only"):
                before_value = int(before_value)
            else:
                before_value = float(before_value)
            if abs(float(before_value) - float(canonical[name])) > 1e-6:
                changes[name] = {"before": before_value, "after": canonical[name]}
        old_note = row.get("note")
        old_note_text = "" if old_note is None else str(old_note)
        if old_note_text != canonical["note"]:
            changes["note"] = {"before": old_note_text, "after": canonical["note"]}

        after = {
            "rank": as_int(row.get("rank"), 1),
            "pct": as_float(row.get("pct"), 100.0),
            "tank_rank": canonical["tank_rank"],
            "dps_pct": canonical["dps_pct"],
            "melee_only": canonical["melee_only"],
            "note": canonical["note"],
        }
        expected[key] = after
        action = "update" if changes else "noop"
        set_clause = ""
        if changes:
            set_clause = ", ".join(
                "`%s`=%s" % (name, sql_literal(payload["after"]))
                for name, payload in changes.items()
            )
        items.append(
            {
                "map": seed["map"],
                "entry": seed["entry"],
                "action": action,
                "before": {
                    "rank": as_int(row.get("rank"), 1),
                    "pct": as_float(row.get("pct"), 100.0),
                    "tank_rank": row.get("tank_rank", NEW_DEFAULTS["tank_rank"]),
                    "dps_pct": row.get("dps_pct", NEW_DEFAULTS["dps_pct"]),
                    "melee_only": row.get("melee_only", NEW_DEFAULTS["melee_only"]),
                    "note": old_note_text,
                },
                "after": after,
                "changes": changes,
                "sql": (
                    "UPDATE `%s`.`%s` SET %s WHERE `map`=%s AND `entry`=%s;"
                    % (database, TABLE, set_clause, seed["map"], seed["entry"])
                    if changes
                    else ""
                ),
            }
        )

    return {
        "items": items,
        "expected": expected,
        "before": existing,
        "count_before": count_before,
        "inserts": inserts,
        "updates": sum(1 for item in items if item["action"] == "update"),
        "noops": sum(1 for item in items if item["action"] == "noop"),
        "rank_default": rank_default,
        "pct_default": pct_default,
        "explicit_base": explicit_base,
        "warnings": warnings,
    }


def inspect_package():
    """只读检查 contrib/playerbot-data 的 manifest，提示打包兼容性。"""
    try:
        path = SCRIPT.parents[2] / "contrib" / "playerbot-data" / "tbc" / "manifest.json"
    except IndexError:
        return {"path": None, "exists": False}
    result = {"path": str(path), "exists": False}
    try:
        if not path.is_file():
            return result
        manifest = json.loads(path.read_text(encoding="utf-8"))
        entry = (manifest.get("tables") or {}).get(TABLE)
        if not entry:
            result["exists"] = True
            result["missing_table"] = True
            return result
        result.update(
            {
                "exists": True,
                "columns": entry.get("columns"),
                "rows": entry.get("rows"),
                "policy": entry.get("policy"),
            }
        )
    except Exception as error:
        result["error"] = str(error)
    return result


def inspect_world(args):
    """world 库只读对照：只 SELECT，不复制、不写。任何异常都降级为 warning。"""
    info = {"database": args.world_database, "readonly": True, "exists": False}
    conn = None
    try:
        conn = connect(args, readonly=True)
        state = inspect_schema(conn, args.world_database)
        info.update(
            {
                "exists": state["exists"],
                "columns": [c["name"] for c in state["columns"]],
                "rows": state["rows"],
                "primary_key": state["primary_key"],
            }
        )
        if state["exists"]:
            with conn.cursor() as cur:
                available = {c["name"].lower() for c in state["columns"]}
                select_columns = [name for name in ("map", "entry", "rank", "pct", "note") if name in available]
                select_columns += [name for name in NEW_COLUMN_NAMES if name in available]
                if "map" in select_columns and "entry" in select_columns:
                    where = " OR ".join(["(map=%s AND entry=%s)"] * len(SEEDS))
                    params = []
                    for seed in SEEDS:
                        params.extend([seed["map"], seed["entry"]])
                    cur.execute(
                        "SELECT %s FROM `%s`.`%s` WHERE %s"
                        % (
                            ",".join("`%s`" % name for name in select_columns),
                            args.world_database,
                            TABLE,
                            where,
                        ),
                        params,
                    )
                    info["target_rows"] = [
                        dict(zip(select_columns, row)) for row in cur.fetchall()
                    ]
    except Exception as error:
        info["error"] = str(error)
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass
    return info


def collect_warnings(args, plan):
    warnings = []
    package = plan.get("package") or {}
    if not package.get("exists"):
        warnings.append(
            "未找到 contrib/playerbot-data/tbc/manifest.json；打包前请确认数据包已包含本表的8列和4行"
        )
    elif package.get("missing_table"):
        warnings.append("数据包 manifest 中没有 ai_playerbot_threat_rule；打包前需重新 export")
    else:
        columns = package.get("columns") or []
        rows = package.get("rows")
        policy = package.get("policy")
        if list(columns) != list(BASE_COLUMNS) + list(NEW_COLUMN_NAMES):
            warnings.append(
                "playerbot-data 包 manifest 仍按 %d 列描述本表（policy=%s, rows=%s）；"
                "迁移后 playerbot_data.py 的 import/verify 会因 schema 不一致拒绝。"
                "请在本库 --apply 后重新 export 数据包。"
                % (len(columns), policy, rows)
            )
        elif (rows or 0) < len(SEEDS):
            warnings.append(
                "数据包 manifest 已是8列但本表只有 %s 行（policy=%s）；"
                "若用该包导入会按 replace 清空本表并写回包内行数。务必先重新 export 带上这4行。"
                % (rows, policy)
            )
        if (
            list(columns) != list(BASE_COLUMNS) + list(NEW_COLUMN_NAMES)
            and plan.get("world")
            and plan["world"].get("exists")
        ):
            warnings.append(
                "打包风险: 当前 manifest 尚未包含本次8列结构，需重新导出角色库权威数据。"
                "playerbot_data.py 的 export_package 应优先 characters，world 同名旧表仅兼容源；"
                "先用 export --dry-run 核对来源，再更新包内本表；本脚本绝不写 world。"
            )

    if plan.get("world"):
        world = plan["world"]
        if world.get("error"):
            warnings.append("world 库只读对照失败（不影响本次迁移）: %s" % world["error"])
        else:
            warnings.append(
                "world 库只读对照: %s 表%s，%d 行；差异不会自动复制，CharacterDatabase 才是权威"
                % (
                    args.world_database,
                    "存在" if world.get("exists") else "不存在",
                    world.get("rows", 0),
                )
            )

    if plan["table"]["exists"] and plan["table"]["rows"] > len(plan["seeds"]):
        warnings.append(
            "表内还有其他 %d 行；脚本只处理四条目标行，其他行不 UPDATE/DELETE"
            % (plan["table"]["rows"] - len(plan["seeds"]))
        )

    if not args.apply:
        warnings.append("当前是只读计划模式（会话已设为 READ ONLY）；复核后加 --apply 才会写入")
    else:
        warnings.append("已使用 --apply；脚本不会创建 *_bak 表，也不会 DROP/DELETE/TRUNCATE")

    warnings.append(
        "rank/pct 保持原样；UPDATE 只包含新三列与 note。"
        "DPS 规则由 CreatureThreatRules.h 读取，tank_rank=0 表示该生物关闭此机制"
    )
    return warnings


def expected_columns(state):
    return [c["name"] for c in state["columns"]]


def apply_plan(conn, args, plan):
    database = args.database
    db = quote_ident(database)
    ddl_done = []
    dml_done = []

    if not plan["table"]["exists"]:
        with conn.cursor() as cur:
            cur.execute(plan["schema"]["create_sql"])
        conn.commit()
        ddl_done.append({"kind": "create_table", "sql": plan["schema"]["create_sql"]})
    elif plan["schema"]["missing"]:
        with conn.cursor() as cur:
            cur.execute(plan["schema"]["alter_sql"])
        conn.commit()
        ddl_done.append({"kind": "add_columns", "sql": plan["schema"]["alter_sql"]})

    state = inspect_schema(conn, database)
    schema = schema_plan(state)
    if schema["create_sql"] or schema["alter_sql"]:
        raise SafetyError("DDL 执行后仍检测到缺失结构，停止（可重复执行本脚本）")
    columns = {c["name"].lower(): c for c in state["columns"]}
    for spec in NEW_COLUMNS:
        column = columns.get(spec["name"])
        if not column:
            raise SafetyError("DDL 后缺少列 %s，停止" % spec["name"])
        if normalize_type(column["type"]) != spec["type"]:
            raise SafetyError("DDL 后列 %s 类型不符: %s" % (spec["name"], column["type"]))

    seed_data = build_seed_plan(conn, database, state)
    plan["table"]["columns_after"] = expected_columns(state)
    plan["schema"]["missing"] = []
    plan["seeds"] = seed_data["items"]
    plan["rows_before"] = seed_data["count_before"]
    plan["rows_after_expected"] = seed_data["count_before"] + seed_data["inserts"]
    plan["warnings"] = list(plan.get("warnings", [])) + seed_data["warnings"]

    dml_items = [item for item in seed_data["items"] if item["action"] in ("insert", "update")]
    if dml_items:
        conn.commit()  # 结束前面的只读事务
        conn.begin()
        try:
            with conn.cursor() as cur:
                for item in seed_data["items"]:
                    if item["action"] == "insert":
                        placeholders = ",".join(["%s"] * len(item["insert_columns"]))
                        cur.execute(
                            "INSERT INTO %s.%s (%s) VALUES (%s)"
                            % (
                                db,
                                quote_ident(TABLE),
                                ",".join("`%s`" % name for name in item["insert_columns"]),
                                placeholders,
                            ),
                            item["insert_values"],
                        )
                    elif item["action"] == "update":
                        fields = list(item["changes"].keys())
                        sql = "UPDATE %s.%s SET %s WHERE `map`=%s AND `entry`=%s" % (
                            db,
                            quote_ident(TABLE),
                            ",".join("`%s`=%%s" % name for name in fields),
                            "%s",
                            "%s",
                        )
                        params = [item["changes"][name]["after"] for name in fields]
                        params += [item["map"], item["entry"]]
                        cur.execute(sql, params)
                errors = verify_rows(cur, database, state, seed_data)
            if errors:
                conn.rollback()
                raise SafetyError("写入后复核失败，数据已回滚:\n  - " + "\n  - ".join(errors))
            conn.commit()
            dml_done = [
                {"map": item["map"], "entry": item["entry"], "action": item["action"]}
                for item in seed_data["items"]
                if item["action"] in ("insert", "update")
            ]
        except Exception:
            conn.rollback()
            raise
    else:
        conn.commit()

    # 事务提交后再做一次持久化复核。
    final_state = inspect_schema(conn, database)
    with conn.cursor() as cur:
        errors = verify_rows(cur, database, final_state, seed_data)
    plan["table"].update(
        {
            "exists": final_state["exists"],
            "table_type": final_state["table_type"],
            "engine": final_state["engine"],
            "rows": final_state["rows"],
            "columns_after": expected_columns(final_state),
            "primary_key": final_state["primary_key"],
        }
    )
    plan["verification"] = {
        "ok": not errors,
        "errors": errors,
        "rows_after": final_state["rows"],
        "rank_pct_preserved": not any("旧列" in error for error in errors),
    }
    if errors:
        raise SafetyError("已提交，但最终复核失败:\n  - " + "\n  - ".join(errors))

    plan["ddl_applied"] = ddl_done
    plan["dml_applied"] = dml_done
    plan["changed"] = bool(ddl_done or dml_items)
    plan["applied"] = True


def verify_rows(cur, database, state, seed_data):
    """在事务内或提交后复核：四条目标行的新三列/note、rank/pct、总行数。"""
    errors = []
    columns = {c["name"].lower(): c for c in state["columns"]}
    for spec in NEW_COLUMNS:
        column = columns.get(spec["name"])
        if not column:
            errors.append("缺少列 %s" % spec["name"])
    if errors:
        return errors

    db = quote_ident(database)
    select_columns = ["map", "entry", "rank", "pct", "note"] + list(NEW_COLUMN_NAMES)
    where = " OR ".join(["(map=%s AND entry=%s)"] * len(SEEDS))
    params = []
    for seed in SEEDS:
        params.extend([seed["map"], seed["entry"]])
    cur.execute(
        "SELECT %s FROM %s.%s WHERE %s"
        % (
            ",".join("`%s`" % name for name in select_columns),
            db,
            quote_ident(TABLE),
            where,
        ),
        params,
    )
    found = {}
    for values in cur.fetchall():
        row = {str(name).lower(): value for name, value in zip(select_columns, values)}
        found[(int(row["map"]), int(row["entry"]))] = row
    if len(found) != len(SEEDS):
        errors.append("目标行数量是 %d，期望 %d" % (len(found), len(SEEDS)))

    for key, expected in seed_data["expected"].items():
        row = found.get(key)
        if not row:
            errors.append("缺少目标行 %s" % (key,))
            continue
        before = seed_data["before"].get(key)
        if before is not None:
            if as_int(row.get("rank")) != as_int(before.get("rank")):
                errors.append("%s 的旧列 rank 被改动" % (key,))
            if abs(as_float(row.get("pct"), 0.0) - as_float(before.get("pct"), 0.0)) > 1e-6:
                errors.append("%s 的旧列 pct 被改动" % (key,))
        else:
            if as_int(row.get("rank")) != as_int(expected.get("rank")):
                errors.append("%s 插入后的 rank 不符" % (key,))
            if abs(as_float(row.get("pct"), 0.0) - as_float(expected.get("pct"), 0.0)) > 1e-6:
                errors.append("%s 插入后的 pct 不符" % (key,))
        for name in ("tank_rank", "melee_only"):
            if as_int(row.get(name)) != as_int(expected[name]):
                errors.append("%s 的 %s=%r，期望 %r" % (key, name, row.get(name), expected[name]))
        if abs(as_float(row.get("dps_pct"), 0.0) - float(expected["dps_pct"])) > 1e-6:
            errors.append("%s 的 dps_pct=%r，期望 %r" % (key, row.get("dps_pct"), expected["dps_pct"]))
        if str(row.get("note") or "") != expected["note"]:
            errors.append("%s 的 note 不符" % (key,))

    cur.execute("SELECT COUNT(*) FROM %s.%s" % (db, quote_ident(TABLE)))
    count_after = int(cur.fetchone()[0])
    expected_count = seed_data["count_before"] + seed_data["inserts"]
    if count_after != expected_count:
        errors.append(
            "总行数 %d，期望 %d（before=%d, inserts=%d）；其他行被改动或存在并发写"
            % (count_after, expected_count, seed_data["count_before"], seed_data["inserts"])
        )
    return errors


def build_plan(args, state, shape, conn):
    schema = schema_plan(state)
    seed_data = build_seed_plan(conn, args.database, state)
    plan = {
        "script": str(SCRIPT),
        "mode": "apply" if args.apply else "plan",
        "connection": {
            "host": args.host,
            "port": args.port,
            "user": args.user,
            "database": args.database,
            "password_env": args.password_env,
            "password": "<hidden>",
            "database_shape": shape,
        },
        "safety": {
            "writes_only_to": args.database,
            "world_writable": False,
            "ddl_only_additive": True,
            "touches_rank_pct": False,
            "touches_other_rows": False,
            "creates_backup_tables": False,
            "plan_session_read_only": not args.apply,
        },
        "table": {
            "exists": state["exists"],
            "table_type": state["table_type"],
            "engine": state["engine"],
            "rows": state["rows"],
            "columns_before": [c["name"] for c in state["columns"]],
            "columns_after": schema["columns_after"],
            "primary_key": state["primary_key"],
        },
        "schema": schema,
        "seeds": seed_data["items"],
        "rows_before": seed_data["count_before"],
        "rows_after_expected": seed_data["count_before"] + seed_data["inserts"],
        "inserts": seed_data["inserts"],
        "updates": seed_data["updates"],
        "noops": seed_data["noops"],
        "package": inspect_package(),
        "world": None,
        "warnings": list(schema["warnings"]) + list(seed_data["warnings"]),
        "applied": False,
        "changed": False,
        "ddl_applied": [],
        "dml_applied": [],
        "verification": None,
    }
    return plan


def print_human(plan):
    mode = plan["mode"]
    conn = plan["connection"]
    table = plan["table"]
    print("=== 通用怪 DPS 仇恨规则迁移 (%s) ===" % mode)
    print("script: %s" % plan["script"])
    print(
        "target: host=%s port=%s user=%s database=%s password_env=%s (value hidden)"
        % (
            conn["host"],
            conn["port"],
            conn["user"],
            conn["database"],
            conn["password_env"],
        )
    )
    print(
        "table: `%s`.`%s` exists=%s columns=%d->%d rows=%s engine=%s pk=(%s)"
        % (
            conn["database"],
            TABLE,
            "yes" if table["exists"] else "no",
            len(table["columns_before"]),
            len(table["columns_after"]),
            table["rows"],
            table["engine"] or "-",
            ",".join(table["primary_key"]) or "-",
        )
    )
    print(
        "safety: writes_only=%s world_writable=no rank/pct=untouched other_rows=untouched"
        % conn["database"]
    )
    print("schema (applied):" if plan["applied"] else "schema:")
    if plan["applied"]:
        if plan["ddl_applied"]:
            for action in plan["ddl_applied"]:
                print("  [%s] %s" % (action["kind"], action["sql"]))
        else:
            print("  no DDL needed (3 columns already present)")
    elif plan["schema"]["create_sql"]:
        print("  CREATE TABLE (missing table):")
        for line in plan["schema"]["create_sql"].splitlines():
            print("    " + line)
    elif plan["schema"]["alter_sql"]:
        print("  " + plan["schema"]["alter_sql"])
    else:
        print("  no schema change (3 columns already present)")
    print("seed rows (%d):" % len(plan["seeds"]))
    for item in plan["seeds"]:
        key = "(%s,%s)" % (item["map"], item["entry"])
        if item["action"] == "insert":
            values = "tank_rank=%s dps_pct=%s melee_only=%s rank=%s pct=%s" % (
                item["after"]["tank_rank"],
                item["after"]["dps_pct"],
                item["after"]["melee_only"],
                item["after"]["rank"],
                item["after"]["pct"],
            )
            print("  [INSERT] %s %s" % (key, values))
        elif item["action"] == "update":
            changes = "; ".join(
                "%s: %r -> %r" % (name, payload["before"], payload["after"])
                for name, payload in item["changes"].items()
            )
            print("  [UPDATE] %s %s" % (key, changes))
        else:
            print("  [NOOP]   %s already matches (rank/pct untouched)" % key)
    print(
        "rows: before=%d -> expected=%d (inserts=%d updates=%d noops=%d; other rows untouched)"
        % (
            plan["rows_before"],
            plan["rows_after_expected"],
            plan["inserts"],
            plan["updates"],
            plan["noops"],
        )
    )
    package = plan.get("package") or {}
    if package.get("exists"):
        print(
            "package: columns=%s rows=%s policy=%s path=%s"
            % (
                package.get("columns"),
                package.get("rows"),
                package.get("policy"),
                package.get("path"),
            )
        )
    else:
        print("package: manifest not found at %s" % package.get("path"))
    if plan.get("world"):
        world = plan["world"]
        if world.get("error"):
            print("world: %s (read-only report failed: %s)" % (world["database"], world["error"]))
        else:
            print(
                "world: %s exists=%s columns=%s rows=%s (READ ONLY, no copy)"
                % (
                    world["database"],
                    world.get("exists"),
                    world.get("columns"),
                    world.get("rows"),
                )
            )
    if plan.get("verification"):
        verification = plan["verification"]
        print(
            "verification: %s rows_after=%s"
            % ("PASS" if verification["ok"] else "FAIL", verification["rows_after"])
        )
        for error in verification["errors"]:
            print("  - " + error)
    if plan["warnings"]:
        print("warnings:")
        for warning in plan["warnings"]:
            print("  - " + warning)
    if not plan["applied"]:
        print("next: 复核后加 --apply 才会写库")
    elif not plan["changed"]:
        print("result: 已经是目标状态，本次没有写入（幂等）")


def emit(plan, as_json):
    if as_json:
        print(json.dumps(plan, ensure_ascii=False, indent=2, sort_keys=False))
    else:
        print_human(plan)


def main(argv=None):
    configure_output()
    args = parse_args(argv)
    try:
        validate_args(args)
        validate_seeds()
    except SafetyError as error:
        print("ERROR: %s" % error, file=sys.stderr)
        return 2

    target = None
    try:
        target = connect(args, readonly=not args.apply)
        state = inspect_schema(target, args.database)
        shape = database_shape(target, args.database)
        if args.apply and shape == "world":
            raise SafetyError(
                "%s 看起来是 world 库（有 creature/creature_template、没有 characters）；"
                "本脚本只写 CharacterDatabase，拒绝执行" % args.database
            )
        plan = build_plan(args, state, shape, target)
        if args.world_database:
            plan["world"] = inspect_world(args)
        if args.apply:
            apply_plan(target, args, plan)
        extra_warnings = collect_warnings(args, plan)
        plan["warnings"] = list(
            dict.fromkeys(list(plan.get("warnings", [])) + extra_warnings)
        )
        emit(plan, args.json)
        return 0
    except SafetyError as error:
        print("ERROR: %s" % error, file=sys.stderr)
        return 2
    except pymysql.MySQLError as error:
        print("ERROR: 数据库操作失败: %s" % error, file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("ERROR: 已中断", file=sys.stderr)
        return 130
    except Exception as error:  # pragma: no cover - 最后一道保险
        print("ERROR: %s: %s" % (type(error).__name__, error), file=sys.stderr)
        return 1
    finally:
        if target is not None:
            try:
                target.close()
            except Exception:
                pass


if __name__ == "__main__":
    sys.exit(main())
