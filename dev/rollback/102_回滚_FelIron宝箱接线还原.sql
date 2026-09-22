-- dev/rollback/102 回滚：把 Fel Iron Chest（181798）的掉落 id 还原为自引用 181798
-- ⛔ 全静态：写死字面量。放 rollback/ 子目录 ⇒ `apply_dev_sql.sh` 不递归、不会被自动执行。
-- 生效：需重启 mangosd。

UPDATE `gameobject_template` SET `data1` = 181798 WHERE `entry` = 181798 AND `data1` = 9933;
