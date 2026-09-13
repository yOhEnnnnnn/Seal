-- Run from the project root with Lua 5.1 or LuaJIT: lua tests/run.lua
-- Stub only LÖVE's platform APIs; all game logic below uses real modules.
local function noop() end
local font_loads = 0
local font = {setFilter = noop, getWidth = function(_, s) return #s * 8 end,
  getHeight = function() return 16 end}
local source = {setVolume = noop, stop = noop, setPitch = noop, play = noop}
love = {
  graphics = {
    setDefaultFilter = noop, setBackgroundColor = noop, setLineStyle = noop,
    setFont = noop,
    newFont = function() font_loads = font_loads + 1; return font end,
    newCanvas = function() return {setFilter = noop} end,
    getDimensions = function() return 960, 540 end,
  },
  mouse = {setVisible = noop, getPosition = function() return 600, 270 end},
  audio = {newSource = function() return source end},
  math = {random = math.random},
  event = {quit = noop},
}
require("main")
local Collision = require("engine.game.collision")
local passed = 0
local function test(name, action)
  action()
  passed = passed + 1
  print("PASS " .. name)
end
local function near(actual, expected)
  assert(math.abs(actual - expected) < 1e-8, actual .. " ~= " .. expected)
end
local function enemy(x, y, r)
  return Enemy{x = x, y = y, r = r or 0, stationary = true, effects = Group()}
end

test("rotated rectangle contact follows its long axis", function()
  local target = enemy(100, 100, math.pi / 2)
  local player = Player{x = 100, y = 109}
  assert(target:is_colliding_with_object(player))
  player.x, player.y = 109, 100
  assert(not target:is_colliding_with_object(player))
  assert(not player:is_colliding_with_object(target))
end)

test("sweep catches a thin enemy across a 100ms frame", function()
  local target = enemy(100, 100)
  local bullet = Projectile{x = 100, y = 92, r = math.pi / 2}
  bullet:update(0.1, {target})
  near(target.hp, 4.5)
  assert(bullet.dead)
  near(bullet.y, 94.5)
end)

test("sweep respects rounded corners and starting overlap", function()
  local box = {x = 0, y = 0, width = 2, height = 2, r = 0}
  assert(Collision.sweep_circle(1.9, 1.9, 2, 2, 1, box) == math.huge)
  near(Collision.sweep_circle(1.5, 1.5, 1.5, 1.5, 1, box), 0)
  assert(Collision.sweep_circle(4, 4, 4, 4, 1, box) == math.huge)
end)

test("sweep handles rotated rectangles and circles", function()
  local box = {x = 0, y = 0, width = 14, height = 6, r = math.pi / 2}
  near(Collision.sweep_circle(-20, 0, 20, 0, 2, box), 15 / 40)
  local circle = {x = 0, y = 0, radius = 3}
  near(Collision.sweep_circle(-10, 0, 10, 0, 2, circle), 0.25)
end)

test("piercing hits nearest enemies first regardless of list order", function()
  local first, second, third = enemy(80, 100), enemy(100, 100), enemy(120, 100)
  local bullet = Projectile{x = 50, y = 100, speed = 160, pierce = 1,
    damage_decay = 0.5}
  bullet:update(0.5, {third, second, first})
  near(first.hp, 4.5)
  near(second.hp, 8.5)
  near(third.hp, 12.5)
  assert(bullet.dead and bullet.pierce == 0)
end)

test("overlapping enemies are both hit in one frame by piercing", function()
  local a, b = enemy(100, 100), enemy(100, 100)
  local bullet = Projectile{x = 100, y = 100, pierce = 1}
  bullet:update(0.01, {a, b})
  near(a.hp, 4.5)
  near(b.hp, 4.5)
end)

test("a bullet cannot hit the same enemy twice", function()
  local target = enemy(100, 100)
  local bullet = Projectile{x = 100, y = 100, speed = 1, pierce = 3}
  bullet:update(0.01, {target})
  bullet:update(0.01, {target})
  near(target.hp, 4.5)
  assert(bullet.pierce == 2)
end)

test("bounce preserves remaining frame travel", function()
  local a = Projectile{x = 470, y = 100, bounces = 1}
  local b = Projectile{x = 470, y = 100, bounces = 1}
  a:update(0.1, {})
  for _ = 1, 10 do b:update(0.01, {}) end
  near(a.x, 469)
  near(a.x, b.x)
  assert(a.vx < 0 and a.bounces == 0 and not a.dead)
end)

test("bounce can hit an enemy on the return path in the same frame", function()
  local target = enemy(450, 100)
  local bullet = Projectile{x = 470, y = 100, bounces = 1}
  bullet:update(0.2, {target})
  near(target.hp, 4.5)
  assert(bullet.dead)
end)

test("wall stops hits beyond the arena and handles long frames", function()
  local outside = enemy(500, 100)
  local bullet = Projectile{x = 470, y = 100}
  bullet:update(1, {outside})
  near(outside.hp, 12.5)
  near(bullet.x, gw - bullet.radius)
  assert(bullet.dead)
  local bounce = Projectile{x = 240, y = 100, bounces = 1}
  bounce:update(10, {})
  assert(bounce.dead and bounce.bounces == 0)
  near(bounce.x, bounce.radius)
end)

test("ammo totals come exclusively from inventory", function()
  local player = Player{coins = 10, bullets = {normal = 0, pierce = 2,
    bounce = 0, chain = 0}}
  assert(player:get_ammo_count() == 2)
  assert(player:ensure_current_bullet() == "pierce")
  assert(player:try_attack(100, 0, Group(), Group()))
  assert(player:get_ammo_count() == 1)
  assert(player:buy_bullets("bounce", 5, 5))
  assert(player:get_ammo_count() == 6 and player.coins == 5)
  assert(not player:buy_bullets("chain", 3, 7))
  assert(player:get_ammo_count() == 6)
end)

test("compaction preserves survivors and removes each death once", function()
  local removed = 0
  local group = Group{on_remove = function() removed = removed + 1 end}
  local a, b = {update = noop}, {update = noop}
  group:add({dead = true}); group:add(a)
  group:add({dead = true}); group:add(b); group:add({dead = true})
  group:update(0)
  assert(#group == 2 and group[1] == a and group[2] == b and removed == 3)
  group:remove_dead()
  assert(removed == 3)
end)

test("opening shop starts at level one and later shops advance", function()
  local game = Game()
  assert(game.rules:is_shop_open())
  game:start_next_level()
  assert(game.rules.level == 1 and game.rules.state == "playing")
  for _ = 1, 10 do game.rules:enemy_killed() end
  game:start_next_level()
  assert(game.rules.level == 2 and game.rules.state == "playing")
end)

local function empty_ammo(game)
  for key in pairs(game.player.bullets) do game.player.bullets[key] = 0 end
end

test("empty ammo fails and R resets without reloading assets", function()
  local game = Game()
  game:start_next_level()
  empty_ammo(game)
  game:update(0.01)
  assert(game.rules.state == "failed" and #game.enemies == 0)
  local loads = font_loads
  game:keypressed("r")
  assert(game.rules:is_shop_open() and game.player:get_ammo_count() == 30)
  assert(game.player.coins == 10 and font_loads == loads)
end)

test("failure waits for the last projectile", function()
  local game = Game()
  game:start_next_level()
  empty_ammo(game)
  game.projectiles:add(Projectile{x = 240, y = 135})
  game:update(0.01)
  assert(game.rules.state == "playing")
  game:update(2)
  assert(game.rules.state == "failed")
end)

test("last projectile winning kill settles before failure", function()
  local game = Game()
  game:start_next_level()
  empty_ammo(game)
  game.enemies:clear()
  game.rules.score = 9
  local target = enemy(100, 100)
  target.hp = 4.5
  game.enemies:add(target)
  game.projectiles:add(Projectile{x = 100, y = 100})
  game:update(0.01)
  assert(game.rules:is_level_complete() and game.rules.score == 10)
  assert(game.player.coins == 11 and #game.projectiles == 0)
end)

test("dead enemies do not contribute separation forces", function()
  local target = enemy(100, 100)
  target:steering_separate(16, {target, {x = 101, y = 100, dead = true},
    {x = 1000, y = 1000}})
  near(target.separation_fx, 0)
  near(target.separation_fy, 0)
end)

print(passed .. " tests passed")
