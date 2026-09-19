-- Run from the project root with Lua 5.1 or LuaJIT: lua tests/run.lua
-- Stub only LÖVE's platform APIs; all game logic below uses real modules.
local function noop() end
local font_loads = 0
local font = {setFilter = noop, getWidth = function(_, s) return #s * 8 end,
  getHeight = function() return 16 end}
local function new_source()
  return {setVolume = noop, stop = noop, setPitch = noop, play = noop}
end
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
    newShader = function(path) return {path = path, send = noop} end,
    getDimensions = function() return 960, 540 end,
    push = function() stack_depth = stack_depth + 1 end,
    pop = function() stack_depth = stack_depth - 1; assert(stack_depth >= 0) end,
    setColor = noop, setLineWidth = noop, setShader = noop, draw = noop,
    getCanvas = noop, setCanvas = noop, origin = noop, clear = noop,
    translate = noop, rotate = noop,
    scale = noop, rectangle = noop, circle = noop, arc = arc, line = noop, polygon = noop,
    print = record_text, printf = record_text,
  },
  mouse = {setVisible = noop, getPosition = function() return 600, 270 end},
  audio = {newSource = function() return new_source() end},
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
  return Enemy{x = x, y = y, r = r or 0, max_hits = 2,
    width = 14, height = 6, stationary = true, effects = Group()}
end

test("rotated rectangle contact follows its long axis", function()
  local target = Enemy{x = 100, y = 100, r = math.pi / 2,
    width = 14, height = 6, max_hits = 2,
    stationary = true, effects = Group()}
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
  assert(target.hits_remaining == 1)
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

test("bounce preserves remaining frame travel", function()
  local a = Projectile{x = 470, y = 100, bounces = 1, arena_width = gw}
  local b = Projectile{x = 470, y = 100, bounces = 1, arena_width = gw}
  a:update(0.1, {})
  for _ = 1, 10 do b:update(0.01, {}) end
  near(a.x, 469)
  near(a.x, b.x)
  assert(a.vx < 0 and a.bounces == 0 and not a.dead)
end)

test("bounce can hit an enemy on the return path in the same frame", function()
  local target = enemy(450, 100)
  local bullet = Projectile{x = 470, y = 100, bounces = 1, arena_width = gw}
  bullet:update(0.2, {target})
  assert(target.hits_remaining == 1)
  assert(bullet.dead)
end)

test("wall stops hits beyond the arena and handles long frames", function()
  local outside = enemy(500, 100)
  local bullet = Projectile{x = 470, y = 100, arena_width = gw}
  bullet:update(1, {outside})
  assert(outside.hits_remaining == 2)
  near(bullet.x, gw - bullet.radius)
  assert(bullet.dead)
  local bounce = Projectile{x = 240, y = 100, bounces = 1}
  bounce:update(10, {})
  assert(bounce.dead and bounce.bounces == 0)
  near(bounce.x, bounce.radius)
end)

test("attacks use infinite ammunition", function()
  local player = Player{}
  local shots = Group()
  assert(player:try_attack(100, 0, shots, Group()))
  player:update(1)
  assert(player:try_attack(100, 0, shots, Group()))
  assert(#shots == 2)
end)

test("six audio events play from their owning game actions", function()
  local game = Game()
  local audio = game.audio
  for _, name in ipairs({"attack", "enemy_hit", "enemy_death",
      "wall_hit", "player_hit", "purchase"}) do
    assert(audio.events[name] and audio.events[name].play_count == 0)
  end

  game.arena.player:update(1)
  assert(game.arena.player:try_attack(300, 135,
    game.arena.projectiles, game.arena.effects))
  assert(audio.events.attack.play_count == 1)

  local target = game.arena:add_enemy(100, 100, {
    max_hits = 2, hits_remaining = 2,
  })
  target:hit(1)
  assert(audio.events.enemy_hit.play_count == 1 and
    audio.events.enemy_death.play_count == 0)
  target:hit(1)
  assert(audio.events.enemy_hit.play_count == 1 and
    audio.events.enemy_death.play_count == 1)

  local shot = Projectile{x = aw - 3, y = 100, audio = audio}
  shot:update(0.1, {})
  assert(audio.events.wall_hit.play_count == 1)

  game.arena.player:hit(1)
  assert(audio.events.player_hit.play_count == 1)
  game.coins = 100
  assert(game.sidebar:buy(game.sidebar.cards[1]))
  assert(audio.events.purchase.play_count == 1)
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

test("an endless run starts in combat without level targets", function()
  local game = Game()
  assert(game.state == "playing" and #game.arena.enemies == 12)
  assert(game.elapsed_time == 0 and game.difficulty_level == 0)
  assert(game.level == nil and game.get_target_score == nil)
  game:enemy_killed()
  assert(game.state == "playing" and game.score == 1)
end)

test("kills award fixed score and time raises endless difficulty", function()
  local game = Game()
  game.state = "playing"
  game.arena.spawn_timer = 100
  local valuable = {base_score = 10, kill_score = 10}
  game:enemy_killed(valuable)
  game:enemy_killed(valuable)
  assert(game.score == 20)
  game.hud:draw(nil, nil)
  assert(stack_depth == 0)
  game:update(2)

  game.arena.enemies:clear()
  game.arena.spawn_timer = 1000
  game.elapsed_time = EnemyConfig.difficulty_seconds - 0.1
  game:update(0.2)
  assert(game.difficulty_level == 1)
  local coins = game.coins
  game:enemy_killed(valuable)
  assert(game.coins > coins)
  game:fail()
  assert(game.coins > coins)
end)

test("attack cooldown rejects rapid shots without an ammo resource", function()
  local player = Player{}
  local projectiles = Group()
  assert(not player:try_attack(0, 0, projectiles, Group()))
  assert(player:try_attack(100, 0, projectiles, Group()))
  assert(not player:try_attack(100, 0, projectiles, Group()))
  player:update(1)
  assert(player:try_attack(100, 0, projectiles, Group()))
  assert(#projectiles == 2)
end)

test("successful firing applies directional camera recoil", function()
  local camera = Camera{240, 135, 480, 270}
  local player = Player{x = 0, y = 135, camera = camera,
    projectile_spread = 0}
  assert(player:try_attack(100, 135, Group(), Group()))
  assert(camera.spring_x.x < 0 and math.abs(camera.spring_y.x) < 1e-8)
end)

test("projectiles receive bounded random spread", function()
  local player = Player{x = 0, y = 0}
  local projectiles = Group()
  assert(player:try_attack(100, 0, projectiles, Group()))
  assert(math.abs(projectiles[1].r) <= math.pi / 60)
end)

test("screen input fires only inside the combat panel", function()
  local game = Game()
  game:mousepressed((aw + 20) * 2, 135 * 2, 1)
  assert(#game.arena.projectiles == 0)
  game:mousepressed(200 * 2, 135 * 2, 1)
  assert(#game.arena.projectiles == 1)
end)

test("hud formats elapsed survival time", function()
  local game = Game()
  game.elapsed_time = 125.9
  assert(game.hud:format_time() == "02:05")
  draw_text = {}
  game.hud:draw()
  assert(table.concat(draw_text, "|"):find("02:05", 1, true))
end)

test("sidebar drawing leaves run state unchanged", function()
  local game = Game()
  game.sidebar:draw()
  assert(game.coins == 8)
  game.hud:draw(426, 40)
  assert(stack_depth == 0)
end)

local function shop_card(game, key)
  for _, card in ipairs(game.sidebar.cards) do
    if card.key == key then return card end
  end
end

test("sidebar upgrades apply immediately during an endless run", function()
  local game = Game()
  game.coins = 1000
  assert(game.sidebar:buy(shop_card(game, "gold_gain")))
  assert(game.sidebar:buy(shop_card(game, "critical")))
  assert(game.sidebar:buy(shop_card(game, "luck")))
  assert(game.sidebar:buy(shop_card(game, "hit_power")))
  assert(game.arena.player.base_projectile_hit_power == 2)
  assert(game.sidebar:buy(shop_card(game, "bounce")))
  assert(game.arena.player.bonus_bounces == 1)
  assert(game.sidebar:buy(shop_card(game, "fire_rate")))
  near(game.arena.player.base_attack_interval, 0.09)
  assert(game.sidebar:buy(shop_card(game, "auto_attack")))
  assert(game.arena.player.auto_attack)
  assert(game.arena.player.base_projectile_hit_power == 2 and
    game.arena.player.bonus_bounces == 1 and
    game.arena.player.auto_attack and
    game.arena.player.critical_chance == 0.05 and
    game.arena.player.luck_chance == 0.03)
end)

test("sidebar rejects unaffordable and capped upgrades", function()
  local game = Game()
  local auto = shop_card(game, "auto_attack")
  assert(not game.sidebar:buy(auto))
  game.coins = 100
  assert(game.sidebar:buy(auto))
  local coins = game.coins
  assert(not game.sidebar:buy(auto) and game.coins == coins)
end)

test("auto fire targets the nearest living enemy without mouse input", function()
  local game = Game()
  game.arena.enemies:clear()
  local far = game.arena:add_enemy(20, 20)
  local near_target = game.arena:add_enemy(
    game.arena.player.x + 20, game.arena.player.y)
  game.arena.player.auto_attack = true
  game.arena:update(0.01)
  assert(#game.arena.projectiles == 1)
  local shot = game.arena.projectiles[1]
  assert(shot.vx > 0 and math.abs(shot.vy) < shot.speed * 0.1)
  assert(game.arena:get_nearest_enemy() == near_target and far ~= near_target)
end)

test("all scene states draw through the extracted views", function()
  local game = Game()
  assert(game.shadow_shader.path == "assets/shaders/shadow.frag")
  assert(game.canvas ~= game.background_canvas and
    game.canvas ~= game.scene_canvas and game.canvas ~= game.shadow_canvas)
  game:draw()
  assert(stack_depth == 0)
  game:draw_scene()
  game:fail()
  draw_text = {}
  game:draw_scene()
  assert(table.concat(draw_text, "|"):find("PLAYER DESTROYED", 1, true))
end)

test("restart refreshes arena and sidebar", function()
  local game = Game()
  local old_arena = game.arena
  game.elapsed_time = 95
  game.difficulty_level = 3
  game.score = 40
  game:fail()
  game:keypressed("r")
  assert(game.coins == 8 and game.arena ~= old_arena)
  assert(game.elapsed_time == 0 and game.difficulty_level == 0 and
    game.score == 0)
  assert(game.sidebar.game == game and game.hud.game == game)
end)

test("enemies face one edge toward the player and move straight", function()
  local game = Game()
  assert(game.arena.player.is_colliding_with_object)
  assert(game.arena.player.seek_point == nil and game.arena.player.hit)
  local target = Enemy{x = 100, y = 100}
  assert(target.width == 16 and target.height == 16)
  near(target.color[1], 1)
  near(target.color[2], 1)
  near(target.color[3], 1)
  local x, y = target.x, target.y
  target:update(0.01, game.arena.player, {target})
  assert(target.hit and target.x > x and target.y > y)
  near(target.r, math.atan2(
    game.arena.player.y - y, game.arena.player.x - x))
  near(target.vx / target.vy,
    (game.arena.player.x - x) / (game.arena.player.y - y))
end)

test("enemy remaining hits are represented by opacity", function()
  local target = Enemy{x = 100, y = 100, max_hits = 4}
  assert(target.hp == nil and target.max_hp == nil)
  near(target:get_color()[4], 1)
  target.hits_remaining = 2
  near(target:get_color()[4], 0.31)
  target.hits_remaining = 1
  near(target:get_color()[4], 0.1375)
  near(target:get_depth_color()[4], 0.11)
end)

test("enemy traits modify newly spawned enemies", function()
  local game = Game()
  game.enemy_traits = {haste = 1, armor = 1, fission = 1}
  game.arena = Arena(game)
  local target = game.arena:add_enemy(100, 100)
  assert(target.max_hits == 4 and target.hits_remaining == 4)
  near(target.v, EnemyConfig.move_speed * 1.1)
  assert(target.contact_damage == 8)
  assert(target.base_score == 7 and target.fission)
  game.enemy_traits.haste = 10
  game.enemy_traits.armor = 10
  local capped = game.arena:add_enemy(120, 100)
  near(capped.v, EnemyConfig.move_speed * 1.3)
  assert(capped.max_hits == 6)
end)

test("enemy growth follows elapsed-time difficulty", function()
  local game = Game()
  local base = game.arena:add_enemy(80, 100)
  assert(base.max_hits == 3 and base.hits_remaining == 3)
  near(base.v, EnemyConfig.move_speed)
  assert(base.contact_damage == 8)

  game.difficulty_level = 1
  local difficulty_one = game.arena:add_enemy(100, 100)
  assert(difficulty_one.max_hits == 3 and
    difficulty_one.hits_remaining == 3)
  near(difficulty_one.v, EnemyConfig.move_speed * 1.04)
  assert(difficulty_one.contact_damage == 9)

  game.difficulty_level = 2
  local difficulty_two = game.arena:add_enemy(120, 100)
  assert(difficulty_two.max_hits == 4 and
    difficulty_two.hits_remaining == 4)
  near(difficulty_two.v, EnemyConfig.move_speed * 1.08)
  assert(difficulty_two.contact_damage == 10)

  game.difficulty_level = 20
  game.enemy_traits.armor = 10
  local late = game.arena:add_enemy(140, 100)
  assert(late.max_hits == 16 and late.hits_remaining == 16)
  near(late.v, EnemyConfig.move_speed * 1.4)
  assert(late.contact_damage == 28)
end)

test("enemy spawning accelerates to a readable minimum interval", function()
  local game = Game()
  game.arena.enemies:clear()
  game.difficulty_level = 2
  game.arena.spawn_timer = 0
  game.arena:update_enemy_spawning(0)
  near(game.arena.spawn_timer, EnemyConfig.spawn_interval * 0.88)

  game.arena.enemies:clear()
  game.difficulty_level = 100
  game.arena.spawn_timer = 0
  game.arena:update_enemy_spawning(0)
  near(game.arena.spawn_timer, EnemyConfig.min_spawn_interval)
end)

test("fission creates two half-hit children without recursive splitting", function()
  local game = Game()
  game.state = "playing"
  game.enemy_traits.fission = 1
  game.arena = Arena(game)
  local target = game.arena:add_enemy(100, 100, {max_hits = 4})
  target:hit(target.hits_remaining, Projectile{score_bonus = 1})
  game.arena.enemies:remove_dead()
  game.arena:spawn_pending_fissions()
  assert(#game.arena.enemies == 2 and game.coins == 12 and game.score == 5)
  for _, child in ipairs(game.arena.enemies) do
    assert(child.max_hits == 2 and child.hits_remaining == 2)
    assert(not child.fission and
      child.base_score == 1)
  end
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
  assert(player.hp == hp - target.contact_damage)
  assert(target.dead and target.reached_center)
  assert(not player.dead)
  assert(player.hit_time == player.hit_duration)
end)

test("player death fails the battle", function()
  local game = Game()
  local player = game.arena.player
  local target = Enemy{
    x = player.x,
    y = player.y,
    contact_damage = player.hp,
    effects = Group(),
  }
  game.arena.enemies:add(target)
  game.arena:update(0)
  assert(player.dead and game.state == "failed")
end)

test("ordinary shots stop at the nearest enemy", function()
  local first, second = enemy(80, 100), enemy(100, 100)
  local shot = Projectile{x = 50, y = 100}
  shot:update(0.5, {second, first})
  assert(first.hits_remaining == 1)
  assert(second.hits_remaining == second.max_hits)
  assert(shot.dead)
end)

test("ordinary kill scoring and coins settle once", function()
  local game = Game()
  game.score = 100
  game.arena.enemies:clear()
  local target = enemy(100, 100)
  target.base_score, target.hits_remaining = 5, 1
  game.arena.enemies:add(target)
  game.arena.projectiles:add(Projectile{x = 100, y = 100})
  game:update(0.01)
  assert(game.score == 106 and game.coins == 13)
  game:update(0.01)
  assert(game.score == 106 and game.coins == 13)
end)

test("bounce upgrades affect infinite-ammo shots", function()
  local game = Game()
  game.coins = 100
  assert(game.sidebar:buy(shop_card(game, "bounce")))
  local player = game.arena.player
  player.projectile_spread = 0
  assert(player:try_attack(300, player.y, game.arena.projectiles, game.arena.effects))
  local shot = game.arena.projectiles[1]
  assert(shot.bounces == 1)
  shot:update(1.1, {})
  assert(shot.bounces == 0 and shot.vx < 0 and not shot.dead)
  assert(shot.score_bonus == 2 and Data.bullets.score_bonus == 1)
  local target = enemy(shot.x - 10, shot.y)
  target.hits_remaining = 1
  shot:update(0.1, {target})
  assert(target.dead and target.kill_score == target.base_score + 2)
end)

test("gold gain upgrades multiply kill income", function()
  local game = Game()
  game.coins = 100
  assert(game.sidebar:buy(shop_card(game, "gold_gain")))
  local coins = game.coins
  game:enemy_killed{base_score = 10, kill_score = 10}
  assert(game.coins == coins + 11)
end)

test("critical shots count as double hit power", function()
  local shot = Projectile{x = 0, y = 0, critical_chance = 1}
  assert(shot.critical and
    shot.hit_power == Data.player.projectile_hit_power * 2)
  assert(shot.color == Data.theme.colors.gold)
  assert(shot.visual_width == Data.player.projectile_width * 1.25 and
    shot.visual_height == Data.player.projectile_height * 1.25)
end)

test("luck can trigger chain ember and frost effects", function()
  local original_random = love.math.random
  for choice = 1, 3 do
    love.math.random = function(minimum, maximum)
      if minimum then return choice end
      return 0
    end
    local effects = Group()
    local shot = Projectile{x = 0, y = 0, luck_chance = 1, effects = effects}
    local origin, neighbor = enemy(10, 0), enemy(20, 0)
    shot:trigger_lucky_effect(origin, {origin, neighbor})
    if choice == 1 then
      assert(#effects == 1 and getmetatable(effects[1]) == LuckyChain)
      assert(neighbor.hits_remaining < neighbor.max_hits)
    elseif choice == 2 then
      assert(#effects == 1 and getmetatable(effects[1]) == LuckyEmber)
    else
      assert(#effects == 1 and getmetatable(effects[1]) == LuckyFrost)
    end
  end
  love.math.random = original_random
end)

print(passed .. " tests passed")
