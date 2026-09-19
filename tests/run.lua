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
  return Enemy{x = x, y = y, r = r or 0, max_hp = 12.5, def = 25,
    width = 14, height = 6, stationary = true, effects = Group()}
end

test("rotated rectangle contact follows its long axis", function()
  local target = Enemy{x = 100, y = 100, r = math.pi / 2,
    width = 14, height = 6, max_hp = 12.5, def = 25,
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
  near(target.hp, 4.5)
  assert(bullet.dead)
end)

test("wall stops hits beyond the arena and handles long frames", function()
  local outside = enemy(500, 100)
  local bullet = Projectile{x = 470, y = 100, arena_width = gw}
  bullet:update(1, {outside})
  near(outside.hp, 12.5)
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

test("a run starts in combat and completed levels advance", function()
  local game = Game()
  assert(game.level == 1 and game.state == "playing" and
    #game.arena.enemies == 12)
  for _ = 1, game:get_target_score() do game:enemy_killed() end
  assert(game.can_extract and game:finish_level())
  assert(game:start_next_level())
  assert(game.level == 2 and game.state == "playing")
end)

test("reaching the target keeps combat running until extraction", function()
  local game = Game()
  game.score = game:get_target_score()
  game.can_extract = true
  draw_text = {}
  game.hud:draw(nil, nil)
  assert(table.concat(draw_text, "|"):find(
    "PRESS P FOR NEXT LEVEL", 1, true))
  game:keypressed("p")
  assert(game.state == "playing" and game.transition)
  game:update(0.86)
  assert(game.state == "playing" and game.level == 2 and
    game.transition.switched)
end)

test("combo rewards fast kills and danger risks only surplus gold", function()
  local game = Game()
  game.state = "playing"
  game.arena.spawn_timer = 100
  local valuable = {base_score = 10, kill_score = 10}
  game:enemy_killed(valuable)
  game:enemy_killed(valuable)
  assert(game.score == 21)
  near(game.combo_multiplier, 1.2)
  assert(game.hud.combo_flame_shader.path ==
    "assets/shaders/combo_flame.frag")
  game.combo_multiplier = 2
  game.hud:draw(nil, nil)
  assert(stack_depth == 0)
  game:update(2)
  assert(game.combo_multiplier == 1)

  game.can_extract = true
  game.secured_coins = game.coins
  local secured = game.coins
  game:update(10.1)
  assert(game.danger_level == 1)
  game:enemy_killed(valuable)
  assert(game.coins > secured)
  game:fail()
  assert(game.coins == secured)
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

test("extraction transition advances directly to the next level", function()
  local game = Game()
  game.can_extract = true
  assert(game:transition_to_next_level(aw / 2, ah / 2))
  local transition = game.transition
  transition:update(0.25)
  assert(transition.radius == 0 and transition.text_scale == 0)
  transition:update(0.3)
  near(transition.radius, transition.max_radius / 2)
  assert(transition.text_scale == 1 and game.level == 1)
  transition:update(0.3)
  assert(transition.radius == transition.max_radius and transition.switched)
  assert(game.state == "playing" and game.level == 2)
  transition:draw()
  transition:update(0.3)
  assert(transition.x == aw / 2 and transition.y == ah / 2)
  near(transition.radius, transition.max_radius)
  transition:update(0.6)
  assert(transition.dead and transition.radius == 0)
end)

test("level transition randomly uses five pastel colors without repeats", function()
  local game = Game()
  assert(#game.transition_colors == 5)
  local previous
  for _ = 1, 20 do
    local color = game:get_transition_color()
    assert(color ~= previous)
    previous = color
  end
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

test("sidebar upgrades apply immediately and persist across levels", function()
  local game = Game()
  game.coins = 1000
  assert(game.sidebar:buy(shop_card(game, "gold_gain")))
  assert(game.sidebar:buy(shop_card(game, "critical")))
  assert(game.sidebar:buy(shop_card(game, "luck")))
  assert(game.sidebar:buy(shop_card(game, "damage")))
  assert(game.arena.player.base_projectile_damage == 12)
  assert(game.sidebar:buy(shop_card(game, "bounce")))
  assert(game.arena.player.bonus_bounces == 1)
  assert(game.sidebar:buy(shop_card(game, "fire_rate")))
  near(game.arena.player.base_attack_interval, 0.09)
  assert(game.sidebar:buy(shop_card(game, "auto_attack")))
  assert(game.arena.player.auto_attack)
  game.can_extract = true
  assert(game:finish_level() and game:start_next_level())
  assert(game.arena.player.base_projectile_damage == 12 and
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
  game.state, game.level = "level_complete", #levels
  draw_text = {}
  game:draw_scene()
  assert(stack_depth == 0)
end)

test("restart refreshes arena and sidebar", function()
  local game = Game()
  local old_arena = game.arena
  game:fail()
  game:keypressed("r")
  assert(game.coins == 8 and game.arena ~= old_arena)
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

test("enemy health is represented by opacity", function()
  local target = Enemy{x = 100, y = 100, max_hp = 20, hp = 20}
  near(target:get_color()[4], 1)
  target.hp = 10
  near(target:get_color()[4], 0.31)
  target.hp = 1
  near(target:get_color()[4], 0.0823)
  near(target:get_depth_color()[4], 0.06584)
end)

test("enemy marks increase risk and score on newly spawned enemies", function()
  local game = Game()
  game.enemy_traits = {haste = 1, armor = 1, fission = 1}
  game.arena = Arena(game)
  local target = game.arena:add_enemy(100, 100)
  near(target.max_hp, 14)
  near(target.v, EnemyConfig.move_speed * 1.1)
  assert(target.damage == 8 and target.def == 0)
  assert(target.base_score == 7 and target.fission)
  game.enemy_traits.haste = 10
  game.enemy_traits.armor = 10
  local capped = game.arena:add_enemy(120, 100)
  near(capped.v, EnemyConfig.move_speed * 1.3)
  near(capped.max_hp, 20)
end)

test("fission creates two half-health children without recursive splitting", function()
  local game = Game()
  game.state = "playing"
  game.enemy_traits.fission = 1
  game.arena = Arena(game)
  local target = game.arena:add_enemy(100, 100)
  target:hit(target.hp, Projectile{score_bonus = 1})
  game.arena.enemies:remove_dead()
  game.arena:spawn_pending_fissions()
  assert(#game.arena.enemies == 2 and game.coins == 12 and game.score == 5)
  for _, child in ipairs(game.arena.enemies) do
    near(child.max_hp, 5)
    assert(child.hp == child.max_hp and not child.fission and
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
  assert(player.hp == hp - target.damage)
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
  local arena = game.arena
  for _ = 1, game:get_target_score() do game:enemy_killed() end
  local coins = game.coins
  assert(game:finish_level())
  assert(game:start_next_level())
  assert(game.level == 2 and game.score == 0)
  assert(game.arena ~= arena and #game.arena.enemies == 12)
  assert(game.coins == coins)
  local active_arena = game.arena
  assert(not game:start_next_level() and game.arena == active_arena)
end)

test("ordinary shots stop at the nearest enemy", function()
  local first, second = enemy(80, 100), enemy(100, 100)
  local shot = Projectile{x = 50, y = 100}
  shot:update(0.5, {second, first})
  near(first.hp, 4.5)
  near(second.hp, second.max_hp)
  assert(shot.dead)
end)

test("ordinary kill scoring and coins settle once", function()
  local game = Game()
  game.score = 100
  game.arena.enemies:clear()
  local target = enemy(100, 100)
  target.base_score, target.hp = 5, 4.5
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
  target.hp = 1
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

test("critical shots deal double damage", function()
  local shot = Projectile{x = 0, y = 0, critical_chance = 1}
  assert(shot.critical and shot.damage == Data.player.projectile_damage * 2)
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
      assert(neighbor.hp < neighbor.max_hp)
    elseif choice == 2 then
      assert(#effects == 1 and getmetatable(effects[1]) == LuckyEmber)
    else
      assert(#effects == 1 and getmetatable(effects[1]) == LuckyFrost)
    end
  end
  love.math.random = original_random
end)

print(passed .. " tests passed")
