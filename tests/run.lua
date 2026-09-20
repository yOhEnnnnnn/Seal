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
    setColor = noop, setLineWidth = function(value)
      assert(type(value) == "number")
    end, setShader = noop, draw = noop,
    getCanvas = noop, setCanvas = noop, origin = noop, clear = noop,
    translate = noop, rotate = noop,
    scale = noop, rectangle = noop, circle = noop, arc = arc, line = noop, polygon = noop,
    print = record_text, printf = record_text,
  },
  mouse = {setVisible = noop, getPosition = function() return 600, 270 end},
  audio = {newSource = function() return new_source() end},
  sound = {newSoundData = function()
    return {setSample = noop}
  end},
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
  assert(not bullet.dead and bullet.momentum == 1)
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

test("missed shots die at walls and cannot hit outside enemies", function()
  local outside = enemy(500, 100)
  local bullet = Projectile{x = 470, y = 100, arena_width = gw}
  bullet:update(1, {outside})
  assert(outside.hits_remaining == 2)
  near(bullet.x, gw - bullet.radius)
  assert(bullet.dead)
end)

test("fire cooldown allows later volleys", function()
  local player = Player{}
  local shots = Group()
  local effects = Group()
  assert(player:try_attack(100, 0, shots, effects))
  player:update(1, shots, effects)
  assert(player:try_attack(-100, 0, shots, effects))
  assert(#shots == 2 and shots[2].vx < 0)
end)

test("game actions stay silent when audio events are unconfigured", function()
  local game = Game()
  local audio = game.audio
  for _, name in ipairs({"attack", "wall_hit", "player_hit", "purchase"}) do
    assert(audio.events[name] == nil and not audio:play(name))
  end
  assert(audio.events.enemy_hit and audio.events.enemy_death)

  game.arena.player:update(1)
  assert(game.arena.player:try_attack(300, 135,
    game.arena.projectiles, game.arena.effects))

  local target = game.arena:add_enemy(100, 100, {
    max_hits = 2, hits_remaining = 2,
  })
  target:hit(1)
  target:hit(1)

  local shot = Projectile{x = aw - 3, y = 100, audio = audio}
  shot:update(0.1, {})

  game.arena.player:hit(1)
  game.coins = 100
  assert(game.sidebar:buy(game.sidebar.cards[1]))
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
  assert(game.state == "playing" and
    #game.arena.enemies > game.arena:get_spawn_slot_count() * 0.75)
  for _, target in ipairs(game.arena.enemies) do
    assert(target.x < 0 or target.x > aw or target.y < 0 or target.y > ah)
  end
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

test("fire cooldown rejects rapid volleys", function()
  local player = Player{}
  local projectiles = Group()
  assert(not player:try_attack(0, 0, projectiles, Group()))
  assert(player:try_attack(100, 0, projectiles, Group()))
  assert(not player:try_attack(100, 0, projectiles, Group()))
  player:update(1, projectiles, Group())
  assert(player:try_attack(-100, 0, projectiles, Group()))
  assert(#projectiles == 2 and projectiles[2].vx < 0)
end)

test("successful firing applies directional camera recoil", function()
  local camera = Camera{240, 135, 480, 270}
  local player = Player{x = 0, y = 135, camera = camera}
  assert(player:try_attack(100, 135, Group(), Group()))
  assert(camera.spring_x.x < 0 and math.abs(camera.spring_y.x) < 1e-8)
end)

test("a volley follows the selected direction", function()
  local player = Player{x = 0, y = 0}
  local projectiles = Group()
  assert(player:try_attack(100, 0, projectiles, Group()))
  near(projectiles[1].r, 0)
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
  assert(game.sidebar:buy(shop_card(game, "ball_count")))
  assert(game.arena.player.ball_count == 2)
  assert(game.sidebar:buy(shop_card(game, "momentum")))
  assert(game.arena.player.momentum_gain == 1.25)
  assert(game.sidebar:buy(shop_card(game, "fire_rate")))
  near(game.arena.player.fire_interval, 0.275)
  assert(game.arena.player.base_projectile_hit_power == 2 and
    game.arena.player.critical_chance == 0.05 and
    game.arena.player.luck_state.level == 1)
end)

test("sidebar rejects unaffordable and capped upgrades", function()
  local game = Game()
  local momentum = shop_card(game, "momentum")
  assert(not game.sidebar:buy(momentum))
  game.upgrades.momentum = momentum.max
  local coins = game.coins
  assert(not game.sidebar:buy(momentum) and game.coins == coins)
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
  game:update(Data.rules.death_transition_duration)
  draw_text = {}
  game:draw_scene()
  assert(table.concat(draw_text, "|"):find("YOU DIED...", 1, true))
end)

test("paid revive preserves the run and spends increasing coins", function()
  local game = Game()
  local old_arena = game.arena
  game.elapsed_time = 95
  game.difficulty_level = 3
  game.score = 40
  game:fail()
  game:update(Data.rules.death_transition_duration)
  game:keypressed("r")
  assert(game.coins == 0 and game.arena == old_arena)
  assert(game.elapsed_time == 95 and game.difficulty_level == 3 and
    game.score == 40 and game.state == "playing")
  assert(game.revive_count == 1 and
    game:get_revive_cost() > Data.rules.revive_base_cost)
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

test("broken waves stay spaced while varying their formation", function()
  local game = Game()
  game.arena = Arena(game)
  game.arena:start()
  assert(#game.arena.enemies > game.arena:get_spawn_slot_count() * 0.75)

  for first_index = 1, #game.arena.enemies - 1 do
    local first = game.arena.enemies[first_index]
    for second_index = first_index + 1, #game.arena.enemies do
      local second = game.arena.enemies[second_index]
      local dx, dy = second.x - first.x, second.y - first.y
      assert(dx * dx + dy * dy >= EnemyConfig.width ^ 2,
        math.sqrt(dx * dx + dy * dy) .. " between " ..
          first_index .. " and " .. second_index)
    end
  end
end)

test("entering waves settle into a circular formation", function()
  local game = Game()
  local speed_sum = 0
  for _, enemy in ipairs(game.arena.enemies) do
    speed_sum = speed_sum +
      (enemy.formation_start_radius - enemy.formation_target_radius) /
        enemy.formation_duration
  end
  near(speed_sum / #game.arena.enemies, game.arena:get_enemy_speed())
  local target = game.arena.enemies[1]
  target:update(target.formation_duration / 2,
    game.arena.player, game.arena.enemies)
  near(target.formation_radius,
    (target.formation_start_radius + EnemyConfig.spawn_circle_radius) / 2)
  target:update(target.formation_duration / 2,
    game.arena.player, game.arena.enemies)
  local dx = target.x - game.arena.player.x
  local dy = target.y - game.arena.player.y
  near(math.sqrt(dx * dx + dy * dy), EnemyConfig.spawn_circle_radius)
end)

test("enemy traits modify newly spawned enemies", function()
  local game = Game()
  game.enemy_traits = {haste = 1, armor = 1, fission = 1}
  game.arena = Arena(game)
  local target = game.arena:add_enemy(100, 100)
  assert(target.max_hits == 2 and target.hits_remaining == 2)
  near(target.v, EnemyConfig.move_speed * 1.1)
  assert(target.contact_damage == 8)
  assert(target.base_score == 7 and target.fission)
  game.enemy_traits.haste = 10
  game.enemy_traits.armor = 10
  local capped = game.arena:add_enemy(120, 100)
  near(capped.v, EnemyConfig.move_speed * 1.3)
  assert(capped.max_hits == 4)
end)

test("enemy growth follows elapsed-time difficulty", function()
  local game = Game()
  local base = game.arena:add_enemy(80, 100)
  assert(base.max_hits == 1 and base.hits_remaining == 1)
  near(base.v, EnemyConfig.move_speed)
  assert(base.contact_damage == 8)

  game.difficulty_level = 1
  game.elapsed_time = 30
  local difficulty_one = game.arena:add_enemy(100, 100)
  assert(difficulty_one.max_hits == 3 and
    difficulty_one.hits_remaining == 3)
  near(difficulty_one.v, EnemyConfig.move_speed * 1.04)
  assert(difficulty_one.contact_damage == 9)

  game.difficulty_level = 2
  game.elapsed_time = 60
  local difficulty_two = game.arena:add_enemy(120, 100)
  assert(difficulty_two.max_hits == 4 and
    difficulty_two.hits_remaining == 4)
  near(difficulty_two.v, EnemyConfig.move_speed * 1.08)
  assert(difficulty_two.contact_damage == 10)

  game.difficulty_level = 20
  game.elapsed_time = 600
  game.enemy_traits.armor = 10
  local late = game.arena:add_enemy(140, 100)
  assert(late.max_hits == 26 and late.hits_remaining == 26)
  near(late.v, EnemyConfig.move_speed * 1.4)
  assert(late.contact_damage == 24)
end)

test("late enemies scale against purchased hit power", function()
  local game = Game()
  game.difficulty_level = 20
  game.elapsed_time = 600
  game.arena.player.base_projectile_hit_power = 11
  local target = game.arena:add_enemy(100, 100)
  assert(target.max_hits == 30)
end)

test("late enemies accelerate only after entering the pressure radius", function()
  local game = Game()
  game.difficulty_level = 20
  game.elapsed_time = 600
  local far = game.arena:add_enemy(10, 10)
  local close_enemy = game.arena:add_enemy(
    game.arena.player.x + EnemyConfig.pressure_radius / 2,
    game.arena.player.y)
  far:update(0, game.arena.player, game.arena.enemies)
  close_enemy:update(0, game.arena.player, game.arena.enemies)
  near(far.max_speed, far.v)
  assert(close_enemy.max_speed > close_enemy.v)
end)

test("enemy spawning accelerates to a readable minimum interval", function()
  local game = Game()
  game.arena.enemies:clear()
  game.difficulty_level = 2
  game.elapsed_time = 60
  game.arena.spawn_timer = 0
  game.arena:update_enemy_spawning(0)
  near(game.arena.spawn_timer, game.arena:get_spawn_interval())
  assert(#game.arena.enemies > game.arena:get_spawn_slot_count() * 0.75)

  game.arena.enemies:clear()
  game.difficulty_level = 100
  game.elapsed_time = 3000
  game.arena.spawn_timer = 0
  game.arena:update_enemy_spawning(0)
  near(game.arena.spawn_timer, game.arena:get_spawn_interval())
  assert(game.arena.spawn_timer >= EnemyConfig.spawn_spacing /
    game.arena:get_enemy_speed())
end)

test("late difficulty still spawns one broken wave at a time", function()
  local game = Game()
  game.arena.enemies:clear()
  game.difficulty_level = 100
  game.elapsed_time = 600
  game.arena.spawn_timer = 0
  game.arena:update_enemy_spawning(0)
  assert(#game.arena.enemies > game.arena:get_spawn_slot_count() * 0.75)
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
  local dx = game.arena.enemies[2].x - game.arena.enemies[1].x
  local dy = game.arena.enemies[2].y - game.arena.enemies[1].y
  assert(math.sqrt(dx * dx + dy * dy) >= EnemyConfig.width)
end)

test("one enemy collision kills the player and ends the enemy", function()
  local game = Game()
  local player = game.arena.player
  local target = Enemy{
    x = player.x,
    y = player.y,
    effects = Group(),
  }
  target:update(0, player, {target})
  assert(player.hp == 0)
  assert(target.dead and target.reached_center)
  assert(player.dead)
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
  assert(player.dead and game.state == "dying")
  game:update(Data.rules.death_transition_duration)
  assert(game.state == "revive")
end)

test("death transition freezes enemies before showing the result", function()
  local game = Game()
  game.arena.enemies:clear()
  local target = game.arena:add_enemy(40, 40)
  local x, y = target.x, target.y
  game:fail()
  game:update(Data.rules.death_transition_duration * 0.6)
  assert(target.x == x and target.y == y and game.state == "dying")
  draw_text = {}
  game:draw_scene()
  assert(table.concat(draw_text, "|"):find("YOU DIED...", 1, true))
end)

test("death tiles sweep diagonally from bottom left", function()
  local game = Game()
  local hud = game.hud
  assert(hud:get_death_tile_scale(0.2, 0) > 0)
  assert(hud:get_death_tile_scale(0.2, 1) == 0)
  assert(hud:get_death_tile_scale(0.5, 0) == 1)
  assert(hud:get_death_tile_scale(0.5, 1) == 1)
  assert(hud:get_death_tile_scale(0.8, 0) < 1)
  assert(hud:get_death_tile_scale(0.8, 1) == 1)
end)

test("revive clears nearby enemies without awarding score", function()
  local game = Game()
  local player = game.arena.player
  game.arena.enemies:clear()
  local close_enemy = game.arena:add_enemy(player.x + 20, player.y)
  local far_enemy = game.arena:add_enemy(
    player.x + Data.rules.revive_clear_radius + 20, player.y)
  local score = game.score
  player.dead, player.hp = true, 0
  game.state = "revive"
  assert(game:revive())
  assert(close_enemy.dead and not far_enemy.dead)
  assert(game.score == score and player.invincibility_time > 0)
end)

test("the ball reflects from the nearest enemy", function()
  local first, second = enemy(80, 100), enemy(100, 100)
  local shot = Projectile{x = 50, y = 100}
  shot:update(0.5, {second, first})
  assert(first.hits_remaining == 1)
  assert(second.hits_remaining == second.max_hits)
  assert(not shot.dead and shot.vx < 0)
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

test("same-frame kills merge into one directional camera impulse", function()
  local game = Game()
  local calls, intensity, angle = 0
  game.camera = {spring_shake = function(_, next_intensity, next_angle)
    calls, intensity, angle = calls + 1, next_intensity, next_angle
  end}
  local player = game.arena.player
  game:enemy_killed{x = player.x + 40, y = player.y, base_score = 1}
  game:enemy_killed{x = player.x + 60, y = player.y, base_score = 1}
  game:flush_kill_feedback()
  assert(calls == 1 and intensity > Data.camera.kill_recoil_base)
  near(angle, 0)
  game:flush_kill_feedback()
  assert(calls == 1)
end)

test("enemy hits reflect the ball and build momentum", function()
  local shot = Projectile{x = 100, y = 100, r = 0}
  local first = enemy(120, 100)
  local second = enemy(80, 100)
  first.hits_remaining = 1
  second.hits_remaining = 1
  shot:update(0.1, {first, second})
  assert(first.dead and not shot.dead and shot.momentum == 1)
  assert(shot.vx < 0 and math.abs(shot.vy) < shot.speed * 0.1)
  shot:update(0.2, {first, second})
  assert(second.dead and not shot.dead and shot.momentum == 2)
end)

test("buying ball count expands the next center volley", function()
  local game = Game()
  game.coins = 100
  local player = game.arena.player
  assert(player:try_attack(300, player.y,
    game.arena.projectiles, game.arena.effects))
  assert(#game.arena.projectiles == 1)
  assert(game.sidebar:buy(shop_card(game, "ball_count")))
  assert(#game.arena.projectiles == 1)
  assert(player.ball_count == 2)
  player:update(1)
  assert(player:try_attack(300, player.y,
    game.arena.projectiles, game.arena.effects))
  assert(#game.arena.projectiles == 3)
end)

test("score milestones queue one scaled boss", function()
  local game = Game()
  game.arena.enemies:clear()
  game.score = EnemyConfig.boss_score_base - 1
  game:enemy_killed{base_score = 1, kill_score = 1}
  assert(game.pending_boss_level == 1 and
    game.next_boss_score == 250)
  game.arena:spawn_pending_boss()
  assert(#game.arena.enemies == 1)
  local boss = game.arena.enemies[1]
  assert(boss.is_boss and boss.max_hits == EnemyConfig.boss_hits)
  assert(boss.width == EnemyConfig.boss_size and
    boss.height == EnemyConfig.boss_size)
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
  local target = enemy(20, 0)
  shot:update(0.1, {target})
  assert(target.dead)
end)

test("luck charge creates at most five persistent bouncing orbs", function()
  local effects = Group()
  local luck_state = {hits = 0, level = 8}
  local shot = Projectile{x = 0, y = 0, luck_state = luck_state,
    effects = effects}
  local origin = enemy(100, 100)
  for _ = 1, Data.upgrades.luck_hits_min * 8 do
    shot:trigger_lucky_effect(origin)
  end
  assert(#effects == Data.upgrades.luck_orb_limit)
  assert(luck_state.hits == Data.upgrades.luck_hits_min)
  local orb = effects[1]
  assert(getmetatable(orb) == LuckyOrb and not orb.duration)
  orb.x, orb.vx = aw - orb.radius, math.abs(orb.vx)
  orb:update(0.1, {})
  assert(orb.vx < 0 and not orb.dead)
end)

print(passed .. " tests passed")
