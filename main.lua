gw, gh = 480, 270

require("engine.object")
require("engine.math.spring")
require("engine.graphics.graphics")
require("engine.graphics.canvas")
require("engine.game.gameobject")
require("effect")
require("engine.game.physics")
require("engine.game.steering")
require("engine.game.unit")
require("projectile")
require("enemy")
require("hero")
require("player")

local player
local projectiles
local enemies
local effects
local game_canvas
local ui_font
local score
local coins
local spawn_timer
local spawn_interval
local next_spawn_side
local max_enemies

local colors = {
  background = {43 / 255, 46 / 255, 46 / 255, 1},
  background_dark = {41 / 255, 44 / 255, 44 / 255, 1},
  background_light = {48 / 255, 51 / 255, 51 / 255, 1},
  hp_bar_background = {12 / 255, 14 / 255, 15 / 255, 1},
  foreground = {218 / 255, 218 / 255, 218 / 255, 1},
  red = {233 / 255, 29 / 255, 57 / 255, 1},
}

local function spawn_enemy(side)
  if #enemies >= max_enemies then return end

  local margin = 9
  local x, y
  if side == 1 then
    x, y = margin, love.math.random(18, gh - 18)
  elseif side == 2 then
    x, y = gw - margin, love.math.random(18, gh - 18)
  elseif side == 3 then
    x, y = love.math.random(18, gw - 18), margin
  else
    x, y = love.math.random(18, gw - 18), gh - margin
  end

  enemies[#enemies + 1] = Enemy{
    x = x,
    y = y,
    color = colors.red,
    hit_color = colors.foreground,
    hp_bar_background = colors.hp_bar_background,
    effects = effects,
    score_value = 1,
    on_coin_collected = function(value) coins = coins + value end,
  }
end

local function update_enemy_spawning(dt)
  spawn_timer = math.max(spawn_timer - dt, 0)
  if spawn_timer > 0 or #enemies >= max_enemies then return end

  spawn_enemy(next_spawn_side)
  next_spawn_side = next_spawn_side % 4 + 1
  spawn_timer = spawn_interval
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setBackgroundColor(0, 0, 0, 1)
  love.graphics.setLineStyle("rough")

  ui_font = love.graphics.newFont("assets/fonts/BoiledPasta.ttf", 16)
  ui_font:setFilter("nearest", "nearest")
  love.graphics.setFont(ui_font)

  projectile_attack_sound = love.audio.newSource(
    "assets/sounds/projectile_attack.wav", "static")
  projectile_attack_sound:setVolume(0.2)

  game_canvas = Canvas(gw, gh)
  projectiles = {}
  enemies = {}
  effects = {}
  score = 0
  coins = 0
  spawn_timer = 0.9
  spawn_interval = 0.9
  next_spawn_side = 1
  max_enemies = 60

  player = Player{
    x = gw / 2,
    y = gh / 2,
    heroes = {},
  }

  for side = 1, 4 do spawn_enemy(side) end
end

function love.update(dt)
  local mouse_x, mouse_y = game_canvas:to_canvas_position(love.mouse.getPosition())
  player:set_aim_position(mouse_x, mouse_y)
  player:update(dt, enemies, projectiles, effects)
  update_enemy_spawning(dt)

  for index = #enemies, 1, -1 do
    local enemy = enemies[index]
    enemy:update(dt, player, enemies)
    if not enemy.dead and enemy:is_colliding_with_object(player) then
      enemy.reached_center = true
      enemy.dead = true
    end
    if enemy.dead then
      if not enemy.reached_center then
        score = score + (enemy.score_value or 1)
      end
      table.remove(enemies, index)
    end
  end

  for index = #projectiles, 1, -1 do
    projectiles[index]:update(dt, enemies)
    if projectiles[index].dead then table.remove(projectiles, index) end
  end

  for index = #effects, 1, -1 do
    effects[index]:update(dt, enemies)
    if effects[index].dead then table.remove(effects, index) end
  end
end

local function draw_background()
  local x, y = gw / 2, gh / 2
  graphics.polygon({x, y, 0, 0, 170, 0}, colors.background_dark)
  graphics.polygon({x, y, gw, 212, gw, gh, 310, gh}, colors.background_dark)
  graphics.polygon({x, y, 310, 0, gw, 0, gw, 58}, colors.background_light)
  graphics.polygon({x, y, 170, gh, 0, gh, 0, 212}, colors.background_light)
end

local function draw_ui()
  graphics.set_color(colors.foreground)
  local line_height = ui_font:getHeight() + 2
  love.graphics.print("SCORE: " .. score, 10, 9)
  love.graphics.print("COINS: " .. coins, 10, 9 + line_height)
  love.graphics.print("HERO: NONE", 10, 9 + line_height * 2)
end

local function draw_game()
  draw_background()
  for _, projectile in ipairs(projectiles) do projectile:draw() end
  for _, enemy in ipairs(enemies) do enemy:draw() end
  player:draw()
  for _, effect in ipairs(effects) do effect:draw() end
  draw_ui()
end

function love.draw()
  game_canvas:draw_to(draw_game, colors.background)
  game_canvas:draw_to_window()
end

function love.keypressed(key, scancode)
  player:keypressed(key, scancode)
  if key == "escape" then love.event.quit() end
end

function love.mousepressed(x, y, button)
  if button ~= 1 then return end

  local mouse_x, mouse_y = game_canvas:to_canvas_position(x, y)
  if not mouse_x then return end

  for index = #effects, 1, -1 do
    local effect = effects[index]
    if effect.is_coin and effect:contains_point(mouse_x, mouse_y) then
      local pickup_x, pickup_y = effect.x, effect.y
      local pickup_color = effect.color
      effect:collect()
      table.remove(effects, index)
      effects[#effects + 1] = CoinPickupEffect{
        x = pickup_x,
        y = pickup_y,
        color = pickup_color,
      }
      break
    end
  end
end
