-- Run from the project root with Lua 5.1 or LuaJIT: lua tests/run.lua
-- Stub only LÖVE's platform APIs; all game logic below uses real modules.
local function noop() end
local font_loads = 0
local font = {setFilter = noop, getWidth = function(_, s) return #s * 8 end,
  getHeight = function() return 16 end}
local source = {setVolume = noop, stop = noop, setPitch = noop, play = noop}
local draw_text, stack_depth = {}, 0
local function record_text(value) draw_text[#draw_text + 1] = tostring(value) end
local function arc(mode, arctype)
  assert(mode == "line" or mode == "fill")
  assert(arctype == "open" or arctype == "closed" or arctype == "pie")
end
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
    scale = noop, rectangle = noop, circle = noop, arc = arc, line = noop, polygon = noop,
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
  run.coins = 100
  local offer = shop.bullets[1]
  assert(shop:buy(offer))
  assert(run.inventory:get_count() == 1 + offer.amount and
    run.coins == 100 - offer.price)
  assert(not shop:buy(offer))
  assert(run.inventory:get_count() == 1 + offer.amount)
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
  assert(game:is_level_complete() and game.score == 11)
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
  run.coins = 100
  assert(not shop:buy({kind = "bullet", key = "normal", price = 0, amount = 99}))
  assert(not shop:buy(nil))
  assert(shop:buy(offer) and offer.sold)
  assert(run.coins == 100 - offer.price and
    run.inventory.counts[offer.key] == offer.amount)
  assert(not shop:buy(offer))
  assert(shop:buy(shop.marks[1]))
  assert(run.coins == 100 - offer.price - shop.marks[1].price and
    run.enemy_traits.haste == 1)
  run.coins = 0
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
  local player = Player{x = 0, y = 135, inventory = inventory, camera = camera}
  assert(player:try_attack(100, 135, Group(), Group()))
  assert(camera.spring_x.x < 0 and math.abs(camera.spring_y.x) < 1e-8)
end)

test("screen input routes purchases and NEXT without firing", function()
  local game = Game()
  game.coins = 100
  local offer = game.shop.bullets[1]
  game:mousepressed(120, 188, 1)
  assert(game.coins == 100 - offer.price and
    game.inventory.counts[offer.key] == offer.amount)
  assert(offer.sold and #game.arena.projectiles == 0)
  game:mousepressed(120, 188, 1)
  assert(game.coins == 100 - offer.price)
  game:mousepressed(870, 500, 1)
  assert(game.state == "playing" and game.level == 1)
  assert(#game.arena.projectiles == 0)
  game:keypressed("q")
  assert(game.inventory:get_current() == offer.key)
  game:mousepressed(600, 270, 1)
  assert(game.inventory.counts[offer.key] == offer.amount - 1)
  assert(#game.arena.projectiles + #game.arena.effects > 0)
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
  local new_offer = game.shop.bullets[1]
  local old_count = old_inventory.counts[new_offer.key]
  game.coins = 100
  game.shop:mousepressed(60, 94)
  assert(game.inventory.counts[new_offer.key] == new_offer.amount and
    game.coins == 100 - new_offer.price)
  assert(old_inventory.counts[new_offer.key] == old_count)
end)

test("player has collision and no enemy steering behavior", function()
  local game = Game()
  assert(game.arena.player.is_colliding_with_object)
  assert(game.arena.player.seek_point == nil and game.arena.player.hit)
  local target = Enemy{x = 100, y = 100}
  target:update(0.01, game.arena.player, {target})
  assert(target.seek_point and target.hit)
end)

test("enemy collision damages player and ends the enemy", function()
  local game = Game()
  local player = game.arena.player
  local target = Enemy{
    x = player.x,
    y = player.y,
    effects = Group(),
  }
  local hp = player.hp
  target:update(0, player, {target})
  assert(player.hp == hp - target.damage)
  assert(target.dead and target.reached_center)
  assert(not player.dead)
  assert(player.hit_time == player.hit_duration)
end)

test("player death fails the battle", function()
  local game = Game()
  assert(game:start_next_level())
  local player = game.arena.player
  local target = Enemy{
    x = player.x,
    y = player.y,
    damage = player.hp,
    effects = Group(),
  }
  game.arena.enemies:add(target)
  game.arena:update(0)
  assert(player.dead and game.state == "failed")
end)

test("level transition replaces battle objects but retains run resources", function()
  local game = Game()
  game.coins = 100
  local offer = game.shop.bullets[1]
  game.shop:buy(offer)
  game.shop:draw(140, 94)
  game:start_next_level()
  local inventory, arena = game.inventory, game.arena
  for _ = 1, 10 do game:enemy_killed() end
  local coins = game.coins
  assert(game:start_next_level())
  assert(game.level == 2 and game.score == 0)
  assert(game.arena ~= arena and #game.arena.enemies == 4)
  assert(game.inventory == inventory and game.arena.player.inventory == inventory)
  assert(game.coins == coins and inventory.counts[offer.key] == offer.amount)
  assert(not game.shop.entries[1][2].hovered)
  local active_arena = game.arena
  assert(not game:start_next_level() and game.arena == active_arena)
end)

test("normal ammo repeats with doubling prices and no charge on failure", function()
  local game = Game()
  game.coins = 10
  local item = game.shop.ammo
  assert(game.shop:buy(item))
  assert(game.coins == 7 and item.price == 6 and game.inventory.counts.normal == 40)
  assert(game.shop:buy(item))
  assert(game.coins == 1 and item.price == 12 and game.inventory.counts.normal == 50)
  assert(not item.sold and not game.shop:buy(item))
  assert(game.coins == 1 and item.price == 12 and game.inventory.counts.normal == 50)
end)

test("supply click does not buy MARK and price resets next shop", function()
  local game = Game()
  local button = game.shop.ammo_button
  game:mousepressed((button.x + 10) * 2, (button.y + 10) * 2, 1)
  assert(game.inventory.counts.normal == 40 and game.coins == 7)
  assert(game.enemy_traits.haste == 0 and not game.shop.marks[1].sold)
  game:start_next_level()
  assert(not game.shop:buy(game.shop.ammo))
  for _ = 1, 10 do game:enemy_killed() end
  assert(game.shop.ammo.price == 3 and game.inventory.counts.normal == 40)
  assert(game.shop:buy(game.shop.ammo))
  game.level, game.state = #levels, "level_complete"
  assert(not game.shop:buy(game.shop.ammo))
end)

test("normal ammo sells out after five purchases and resets next shop", function()
  local game = Game()
  game.coins = 1000
  local item = game.shop.ammo
  for index = 1, 5 do
    assert(item.price == 3 * 2 ^ (index - 1))
    assert(game.shop:buy(item))
  end
  assert(item.sold and item.purchases == 5)
  assert(game.coins == 907 and game.inventory.counts.normal == 80)
  assert(not game.shop:buy(item))
  assert(game.coins == 907 and game.inventory.counts.normal == 80)
  draw_text = {}
  game.shop:draw_ammo(nil, nil)
  assert(table.concat(draw_text, "|"):find("SOLD OUT", 1, true))
  game:start_next_level()
  for _ = 1, 10 do game:enemy_killed() end
  assert(not item.sold and item.purchases == 0 and item.price == 3)
  assert(game.shop:buy(item) and item.purchases == 1)
end)

test("kill scoring adds or multiplies the enemy value, not the total", function()
  for _, operation in ipairs({"add", "multiply"}) do
    local game = Game()
    game:start_next_level()
    game.score = 100
    game.arena.enemies:clear()
    local target = enemy(100, 100)
    target.base_score, target.hp = 5, 4.5
    game.arena.enemies:add(target)
    game.arena.projectiles:add(Projectile{x = 100, y = 100,
      score_operation = operation, score_value = 2})
    game:update(0.01)
    assert(game.score == (operation == "add" and 107 or 110))
    assert(game.coins == 11)
    game:update(0.01)
    assert(game.coins == 11)
  end
end)

test("only the lethal projectile sets the enemy reward", function()
  local target = enemy(100, 100)
  target.base_score = 5
  target:hit(10, Projectile{score_operation = "multiply", score_value = 10})
  assert(not target.dead and target.kill_score == nil)
  target:hit(10, Projectile{score_operation = "add", score_value = 2})
  assert(target.dead and target.kill_score == 7)
  target:hit(10, Projectile{score_operation = "multiply", score_value = 10})
  assert(target.kill_score == 7)
end)

test("scoring enchantment is local to the run and captured on firing", function()
  local game = Game()
  game:start_next_level()
  assert(game.inventory:set_scoring("normal", "multiply", 2))
  game.arena.player:try_attack(300, 135, game.arena.projectiles, game.arena.effects)
  local shot = game.arena.projectiles[1]
  assert(shot.score_operation == "multiply" and shot.score_value == 2)
  assert(game.inventory:set_scoring("normal", "add", 3))
  assert(shot.score_operation == "multiply" and shot.score_value == 2)
  assert(not game.inventory:set_scoring("normal", "bad", 2))
  assert(not game.inventory:set_scoring("normal", "multiply", 0))
  assert(not game.inventory:set_scoring("unknown", "add", 2))
  local fresh = Inventory()
  assert(fresh.scoring.normal.operation == "add" and fresh.scoring.normal.value == 1)
end)

test("piercing rewards each kill using the original projectile scoring", function()
  local a, b = enemy(100, 100), enemy(100, 100)
  a.hp, b.hp, a.base_score, b.base_score = 1, 1, 5, 8
  local shot = Projectile{x = 100, y = 100, pierce = 1,
    score_operation = "multiply", score_value = 2}
  shot:update(0.01, {a, b})
  assert(a.kill_score == 10 and b.kill_score == 16)
end)

test("bullet enum provides isolated projectile defaults", function()
  local a = Projectile{bullet = BulletType.PIERCE}
  local b = Projectile{bullet = BulletType.PIERCE}
  assert(a.pierce == 1 and a.score_value == 2)
  a.pierce = 0
  assert(b.pierce == 1 and Bullets.pierce.pierce == 1)
  local bounce = Projectile{bullet = BulletType.BOUNCE, x = 470, y = 100}
  bounce:update(0.1, {})
  assert(bounce.bounces == 0 and bounce.vx < 0 and not bounce.dead)
end)

test("chain hits only the nearest living unhit enemy and preserves scoring", function()
  local origin, near_enemy, far_enemy = enemy(100, 100), enemy(120, 100), enemy(150, 100)
  origin.hp, near_enemy.hp = 1, 1
  origin.base_score, near_enemy.base_score = 5, 8
  local shot = Projectile{bullet = BulletType.CHAIN, x = 100, y = 100,
    score_operation = "multiply", score_value = 2}
  shot:update(0.01, {origin, far_enemy, near_enemy})
  assert(origin.kill_score == 10 and near_enemy.kill_score == 16)
  assert(far_enemy.hp == far_enemy.max_hp and shot.dead)
  assert(shot.hit_enemies[near_enemy])
  local lightning = shot.effects[#shot.effects]
  assert(getmetatable(lightning) == ChainLightning)
  lightning:draw()
  lightning:update(0.2)
  assert(lightning.dead)
end)

test("chain skips dead targets and does not travel outside its range", function()
  local origin, dead, outside = enemy(100, 100), enemy(110, 100), enemy(181, 100)
  dead.dead = true
  local shot = Projectile{bullet = BulletType.CHAIN, x = 100, y = 100}
  shot:update(0.01, {origin, dead, outside})
  near(origin.hp, 4.5)
  near(outside.hp, outside.max_hp)
  assert(not shot.hit_enemies[dead] and #shot.effects == 0)
end)

test("firing chain inventory activates its enum effect", function()
  local inventory = Inventory{chain = 1}
  local player = Player{x = 100, y = 100, inventory = inventory}
  local shots = Group()
  assert(player:try_attack(200, 100, shots, Group()))
  local origin, neighbor = enemy(110, 100), enemy(110, 120)
  shots:update(0.1, {origin, neighbor})
  near(origin.hp, 4.5)
  near(neighbor.hp, 4.5)
  assert(inventory:get_count() == 0)
end)

test("ember creates a square damage area with projectile scoring", function()
  local effects = Group()
  local inside = enemy(100, 100)
  local outside = enemy(180, 100)
  inside.hp, inside.base_score = 11, 8
  local inventory = Inventory{ember = 1}
  inventory:set_scoring(BulletType.EMBER, "multiply", 2)
  local player = Player{x = 240, y = 135, inventory = inventory}
  local projectiles = Group()
  assert(player:try_attack(100, 100, projectiles, effects))
  assert(#projectiles == 0 and getmetatable(effects[1]) == BurningArea)
  assert(effects[1].x == 100 and effects[1].y == 100)
  assert(effects[1].r >= 0 and effects[1].r < 2 * math.pi)
  effects:draw()
  effects:update(0.8, {inside, outside})
  assert(inside.dead and inside.kill_score == 16)
  near(outside.hp, outside.max_hp)
end)

test("frost creates a circular slow area and speed recovers", function()
  local effects = Group()
  local inside = enemy(120, 100)
  local outside = enemy(165, 100)
  local inventory = Inventory{frost = 1}
  local player = Player{x = 240, y = 135, inventory = inventory}
  local projectiles = Group()
  assert(player:try_attack(100, 100, projectiles, effects))
  assert(#projectiles == 0 and getmetatable(effects[1]) == FrostArea)
  assert(effects[1].x == 100 and effects[1].y == 100)
  effects:draw()
  effects:update(0.01, {inside, outside})
  assert(inside.slow_multiplier == 0.45 and outside.slow_multiplier == 1)
  near(inside.hp, 4.5)
  near(outside.hp, outside.max_hp)
  inside:update(0.01, {x = 240, y = 135}, {inside})
  near(inside.max_v, inside.v * 0.45)
  inside:update(0.2, {x = 240, y = 135}, {inside})
  assert(inside.slow_multiplier == 1 and inside.max_v == inside.v)
end)

test("shop offers ember and frost ammunition", function()
  local game = Game()
  local found = {}
  for _, item in ipairs(game.shop.bullet_catalog) do found[item.key] = item end
  assert(found.ember and found.frost)
  assert(found.ember.amount == Bullets.ember.shop_amount)
  assert(found.frost.amount == Bullets.frost.shop_amount)
end)

test("shop rolls three unique active SEAL offers", function()
  local shop = Game().shop
  local active = {}
  assert(#shop.bullets == 3 and #shop.entries[1] == 3)
  for _, item in ipairs(shop.bullets) do
    assert(not active[item.key] and shop.items[item])
    active[item.key] = true
  end
  for _, item in ipairs(shop.bullet_catalog) do
    if not active[item.key] then assert(not shop:can_buy(item)) end
  end
end)

test("shop rows share one card grid", function()
  local shop = Game().shop
  for row_index, row in ipairs(shop.entries) do
    for index, entry in ipairs(row) do
      assert(entry.x == 52 + (index - 1) * 90)
      assert(entry.height == 90)
      assert(entry.y == (row_index == 1 and 118 or 221))
    end
  end
  assert(shop.entries[2][1].y - shop.entries[1][1].y == 103)
end)

test("the last ember keeps the run alive until its damage area expires", function()
  local game = Game()
  for key in pairs(game.inventory.counts) do game.inventory.counts[key] = 0 end
  game.inventory.counts.ember = 1
  game:start_next_level()
  game.arena.enemies:clear()
  game.arena.spawn_timer = 100
  assert(game.arena.player:try_attack(100, 100,
    game.arena.projectiles, game.arena.effects))
  game:update(0.1)
  assert(game.state == "playing" and #game.arena.projectiles == 0)
  game:update(2.4)
  assert(game.state == "failed")
end)

test("player follows selected ammo and animates without changing collision size", function()
  local game = Game()
  game.inventory:add(BulletType.PIERCE, 2)
  game:start_next_level()
  local player = game.arena.player
  assert(player.color == Bullets.normal.color and player.switch_time == 0)
  game:keypressed("q")
  assert(player.color == Bullets.pierce.color and player.switch_time > 0)
  player:update(0.04)
  assert(player:get_switch_scale() < 1)
  player:update(0.08)
  assert(player:get_switch_scale() > 1)
  player:update(1)
  assert(player:get_switch_scale() == 1 and player.shape.width == player.size)
end)

test("automatic ammo switch updates player and one-type switching does not animate", function()
  local inventory = Inventory{normal = 1, chain = 2}
  local player = Player{x = 0, y = 0, inventory = inventory}
  player:try_attack(100, 0, Group(), Group())
  assert(player.color == Bullets.chain.color and player.switch_time > 0)
  player:update(1)
  inventory:select_next()
  player:sync_bullet_visuals()
  assert(player.switch_time == 0)
  player:hit(1)
  player:update(0.2)
  assert(player.hit_time == 0 and player.color == Bullets.chain.color)
end)

print(passed .. " tests passed")
