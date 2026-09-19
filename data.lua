-- 统一配置入口；运行状态仍由各游戏对象单独保存。
require("data.levels")
require("data.enemies")

return {
  levels = levels,
  bullets = require("data.bullets"),
  enemies = EnemyConfig,
  player = require("data.player"),
  rules = require("data.rules"),
  upgrades = require("data.upgrades"),
  theme = require("data.theme"),
  display = require("data.display"),
}
