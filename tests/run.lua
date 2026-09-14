-- Run from the project root with Lua 5.1 or LuaJIT: lua tests/run.lua
-- Stub only LÖVE's platform APIs; all game logic below uses real modules.
local function noop() end
local font_loads = 0
local font = {setFilter = noop, getWidth = function(_, s) return #s * 8 end,
  getHeight = function() return 16 end}
local source = {setVolume = noop, stop = noop, setPitch = noop, play = noop}
local draw_text, stack_depth = {}, 0
local function record_text(value) draw_text[#draw_text + 1] = tostring(value) end
love = {
  graphics = {
    setDefaultFilter = noop, setBackgroundColor = noop, setLineStyle = noop,
    setFont = noop,
    newFont = function() font_loads = font_loads + 1; return font end,
    newCanvas = function() return {setFilter = noop} end,
    getDimensions = function() return 960, 540 end,
    push = function() stack_depth = stack_depth + 1 end,
    pop = function() stack_depth = stack_depth - 1; assert(stack_depth >= 0) end,
    setColor = noop, setLineWidth = noop, translate = noop, rotate = noop,
    scale = noop, rectangle = noop, circle = noop, line = noop, polygon = noop,
    print = record_text, printf = record_text,
  },
  mouse = {setVisible = noop, getPosition = function() return 600, 270 end},
  audio = {newSource = function() return source end},
  math = {random = math.random},
  event = {quit = noop},
  timer = {getTime = function() return 1 end},
}
require("main")
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
  local player = Player{x = 100, y = 109, inventory = Inventory()}
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

test("ammo totals come exclusively from shared inventory", function()
  local run = Game()
  run.inventory = Inventory{normal = 0, pierce = 2}
  local player = Player{inventory = run.inventory}
  local shop = run.shop
  assert(run.inventory:get_count() == 2)
  assert(run.inventory:ensure_current() == "pierce")
  assert(player:try_attack(100, 0, Group(), Group()))
  assert(run.inventory:get_count() == 1)
  assert(shop:buy(shop.bullets[2]))
  assert(run.inventory:get_count() == 6 and run.coins == 5)
  assert(not shop:buy(shop.bullets[3]))
  assert(run.inventory:get_count() == 6)
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
  assert(game:is_shop_open())
  game:start_next_level()
  assert(game.level == 1 and game.state == "playing")
  for _ = 1, 10 do game:enemy_killed() end
  game:start_next_level()
  assert(game.level == 2 and game.state == "playing")
end)

local function empty_ammo(game)
  for key in pairs(game.inventory.counts) do game.inventory.counts[key] = 0 end
end

test("empty ammo fails and R resets without reloading assets", function()
  local game = Game()
  game:start_next_level()
  empty_ammo(game)
  game:update(0.01)
  assert(game.state == "failed" and #game.arena.enemies == 0)
  local loads = font_loads
  game:keypressed("r")
  assert(game:is_shop_open() and game.inventory:get_count() == 30)
  assert(game.coins == 10 and font_loads == loads)
end)

test("failure waits for the last projectile", function()
  local game = Game()
  game:start_next_level()
  empty_ammo(game)
  game.arena.projectiles:add(Projectile{x = 240, y = 135})
  game:update(0.01)
  assert(game.state == "playing")
  game:update(2)
  assert(game.state == "failed")
end)

test("last projectile winning kill settles before failure", function()
  local game = Game()
  game:start_next_level()
  empty_ammo(game)
  game.arena.enemies:clear()
  game.score = 9
  local target = enemy(100, 100)
  target.hp = 4.5
  game.arena.enemies:add(target)
  game.arena.projectiles:add(Projectile{x = 100, y = 100})
  game:update(0.01)
  assert(game:is_level_complete() and game.score == 10)
  assert(game.coins == 11 and #game.arena.projectiles == 0)
end)

test("dead enemies do not contribute separation forces", function()
  local target = enemy(100, 100)
  target:steering_separate(16, {target, {x = 101, y = 100, dead = true},
    {x = 1000, y = 1000}})
  near(target.separation_fx, 0)
  near(target.separation_fy, 0)
end)

test("shop enforces purchases without UI or platform APIs", function()
  local platform = love
  local run = Game()
  local shop = run.shop
  love = nil
  local offer = shop.bullets[1]
  assert(not shop:buy({kind = "bullet", key = "normal", price = 0, amount = 99}))
  assert(not shop:buy(nil))
  assert(shop:buy(offer) and offer.sold)
  assert(run.coins == 5 and run.inventory.counts.pierce == 6)
  assert(not shop:buy(offer))
  assert(shop:buy(shop.marks[1]))
  assert(run.coins == 1 and run.enemy_traits.haste == 1)
  assert(not shop:buy(shop.marks[2]))
  assert(not shop.marks[2].sold and run.enemy_traits.armor == 0)
  run:add_coins(100)
  run.state = "playing"
  assert(not shop:buy(shop.bullets[2]))
  run.state, run.level = "level_complete", #levels
  assert(not shop:buy(shop.bullets[2]))
  love = platform
end)

test("inventory switching and rejected attacks preserve ammunition", function()
  local inventory = Inventory{normal = 1, bounce = 1}
  local player = Player{inventory = inventory}
  local projectiles = Group()
  assert(not player:try_attack(0, 0, projectiles, Group()))
  assert(inventory:get_count() == 2)
  assert(player:try_attack(100, 0, projectiles, Group()))
  assert(inventory:get_current() == "bounce" and inventory:get_count() == 1)
  assert(not player:try_attack(100, 0, projectiles, Group()))
  assert(inventory:get_count() == 1)
  player:update(1)
  assert(player:try_attack(100, 0, projectiles, Group()))
  assert(inventory:get_count() == 0 and not inventory:consume())
  assert(inventory:add("chain", 2) and inventory:get_current() == "chain")
  assert(not inventory:add("unknown", 4))
  assert(not inventory:add("normal", -1))
end)

test("successful firing applies directional camera recoil", function()
  local camera = Camera{240, 135, 480, 270}
  local inventory = Inventory{normal = 1}
  local player = Player{inventory = inventory, camera = camera}
  assert(player:try_attack(100, 135, Group(), Group()))
  assert(camera.spring_x.x < 0 and math.abs(camera.spring_y.x) < 1e-8)
end)

test("screen input routes purchases and NEXT without firing", function()
  local game = Game()
  game:mousepressed(120, 188, 1)
  assert(game.coins == 5 and game.inventory.counts.pierce == 6)
  assert(game.shop.bullets[1].sold and #game.arena.projectiles == 0)
  game:mousepressed(120, 188, 1)
  assert(game.coins == 5)
  game:mousepressed(870, 500, 1)
  assert(game.state == "playing" and game.level == 1)
  assert(#game.arena.projectiles == 0)
  game:keypressed("q")
  assert(game.inventory:get_current() == "pierce")
  game:mousepressed(600, 270, 1)
  assert(#game.arena.projectiles == 1 and game.inventory.counts.pierce == 5)
end)

test("hover and drawing leave catalog and run state unchanged", function()
  local game = Game()
  local item = game.shop.bullets[1]
  game.shop:draw(60, 94)
  assert(game.shop.entries[1][1].hovered)
  assert(item.hovered == nil and item.hover_started_at == nil and item.x == nil)
  assert(game.coins == 10 and game.inventory:get_count() == 30)
  assert(not item.sold)
  game.shop:draw(nil, nil)
  assert(not game.shop.entries[1][1].hovered)
  game.hud:draw(426, 40)
  assert(game.inventory:get_current() == "normal")
  assert(stack_depth == 0)
end)

test("all scene states draw through the extracted views", function()
  local game = Game()
  game:draw_scene()
  game:start_next_level()
  game:draw_scene()
  game:fail()
  draw_text = {}
  game:draw_scene()
  assert(table.concat(draw_text, "|"):find("OUT OF AMMO", 1, true))
  game.state, game.level = "level_complete", #levels
  draw_text = {}
  game:draw_scene()
  assert(table.concat(draw_text, "|"):find("RUN COMPLETE", 1, true))
  assert(stack_depth == 0)
end)

test("restart refreshes inventory arena and shop without stale offers", function()
  local game = Game()
  local old_inventory, old_offer = game.inventory, game.shop.bullets[1]
  game.shop:buy(old_offer)
  game:start_next_level()
  local old_arena = game.arena
  game:fail()
  game:keypressed("r")
  assert(game.inventory ~= old_inventory and game.coins == 10)
  assert(game.arena ~= old_arena and game.arena.player.inventory == game.inventory)
  assert(game.shop.game == game and game.hud.game == game)
  assert(not game.shop:buy(old_offer))
  game.shop:mousepressed(60, 94)
  assert(game.inventory.counts.pierce == 6 and game.coins == 5)
  assert(old_inventory.counts.pierce == 6)
end)

test("player has collision but no enemy steering or health behavior", function()
  local game = Game()
  assert(game.arena.player.is_colliding_with_object)
  assert(game.arena.player.seek_point == nil and game.arena.player.hit == nil)
  local target = Enemy{x = 100, y = 100}
  target:update(0.01, game.arena.player, {target})
  assert(target.seek_point and target.hit)
end)

test("level transition replaces battle objects but retains run resources", function()
  local game = Game()
  game.shop:buy(game.shop.bullets[1])
  game.shop:draw(140, 94)
  game:start_next_level()
  local inventory, arena = game.inventory, game.arena
  for _ = 1, 10 do game:enemy_killed() end
  local coins = game.coins
  assert(game:start_next_level())
  assert(game.level == 2 and game.score == 0)
  assert(game.arena ~= arena and #game.arena.enemies == 4)
  assert(game.inventory == inventory and game.arena.player.inventory == inventory)
  assert(game.coins == coins and inventory.counts.pierce == 6)
  assert(not game.shop.entries[1][2].hovered)
  local active_arena = game.arena
  assert(not game:start_next_level() and game.arena == active_arena)
end)

print(passed .. " tests passed")
