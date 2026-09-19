# 游戏数据配置

统一入口为根目录 `data.lua`，游戏启动后通过 `Data` 访问。修改配置后重启游戏生效。

| 文件 | 配置内容 |
| --- | --- |
| `audio.lua` | 六类基础音效的文件、音量、并发声部与音高变化 |
| `player.lua` | 玩家生命、大小、射速、弹速、击打强度、散射、弹丸半径与震屏 |
| `bullets.lua` | 普通子弹颜色、击杀加分和反弹加分 |
| `enemies.lua` | 敌人属性、时间难度成长、刷怪、强化、分裂、剩余击打次数透明度 |
| `upgrades.lua` | 商店卡片、价格增长、购买上限与升级增量 |
| `rules.lua` | 初始金币 |
| `theme.lua` | 游戏配色 |
| `display.lua` | 逻辑尺寸、战场尺寸、窗口尺寸与字体 |

例如：调整基础击打强度修改 `player.lua` 的 `projectile_hit_power`；调整击打强度升级幅度修改 `upgrades.lua` 的 `hit_power_per_level`；调整难度提升周期修改 `enemies.lua` 的 `difficulty_seconds`。

配置表视为只读，生命、金币和升级等级等运行状态保存在各实例中。Demo 使用无限普通子弹，幸运属性可触发烬火、霜痕或闪电链；子弹行为位于 `projectile.lua`。商店文字 `label` 是独立配置，修改升级增量时应同步更新文字。

音效接口保留 `attack`、`enemy_hit`、`enemy_death`、`wall_hit`、`player_hit` 和 `purchase` 六个事件，当前未配置素材。取得明确授权后，在 `audio.lua` 的 `events` 中使用 `path` 配置单文件，或使用 `paths` 轮换多个文件；战斗代码无需调整。

此次抽取集中于游戏调参和资源配置；绘制坐标、粒子动画细节、引擎默认值和算法常量仍在对应实现中。`conf.lua` 保留 LÖVE 引擎启动选项，并从 `display.lua` 读取窗口尺寸。
