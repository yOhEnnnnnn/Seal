gw, gh = 480, 270

require("engine.object")
require("engine.math.spring")
require("engine.graphics.graphics")
require("engine.graphics.canvas")
require("engine.game.gameobject")
levels = require("data.levels")
require("game.game_rules")
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
local rules
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

local ammo_button = {
  x = gw - 52,
  y = 8,
  width = 42,
  height = 20,
}

local function is_inside_ammo_button(x, y)
  return x >= ammo_button.x and x <= ammo_button.x + ammo_button.width and
    y >= ammo_button.y and y <= ammo_button.y + ammo_button.height
end

local function draw_coin_icon(x, y, alpha)
  graphics.circle(
    x, y, 3,
    graphics.color_with_alpha({250 / 255, 207 / 255, 0, 1}, alpha))
  graphics.circle(
    x - 0.8, y - 0.8, 0.6,
    graphics.color_with_alpha(colors.foreground, alpha * 0.8))
end

local function draw_bullet_icon(x, y, alpha)
  graphics.circle(
    x, y, 2.5,
    graphics.color_with_alpha({1, 1, 1, 1}, alpha))
end

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
  }
end

local function update_enemy_spawning(dt)
  if rules:is_level_complete() then return end

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
  love.mouse.setVisible(false)

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
  rules = GameRules{levels = levels, level = 1}
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
        rules:enemy_killed()
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

local function draw_aim_ray()
  local mouse_x, mouse_y = game_canvas:to_canvas_position(
    love.mouse.getPosition())
  if not mouse_x then return end

  local dx, dy = mouse_x - player.x, mouse_y - player.y
  local length = math.sqrt(dx * dx + dy * dy)
  if length < 0.001 then return end

  dx, dy = dx / length, dy / length
  local distance_x = dx > 0 and (gw - player.x) / dx or
    (dx < 0 and -player.x / dx or math.huge)
  local distance_y = dy > 0 and (gh - player.y) / dy or
    (dy < 0 and -player.y / dy or math.huge)
  local ray_length = math.min(distance_x, distance_y)
  local color = graphics.color_with_alpha(colors.foreground, 0.4)
  local dash_length, gap_length = 6, 5

  for distance = player.size + 5, ray_length, dash_length + gap_length do
    local dash_end = math.min(distance + dash_length, ray_length)
    graphics.line(
      player.x + dx * distance,
      player.y + dy * distance,
      player.x + dx * dash_end,
      player.y + dy * dash_end,
      color,
      2)
  end
end

local function draw_ui()
  graphics.set_color(colors.foreground)
  local line_height = ui_font:getHeight() + 2
  love.graphics.print(
    "SCORE: " .. rules.score .. " / " .. rules:get_target_score(), 10, 9)
  draw_bullet_icon(14, 17 + line_height, 1)
  love.graphics.print(player.ammo, 23, 9 + line_height)
  draw_coin_icon(14, 17 + line_height * 2, 1)
  love.graphics.print(player.coins, 23, 9 + line_height * 2)
  love.graphics.print("HERO: NONE", 10, 9 + line_height * 3)

  local mouse_x, mouse_y = game_canvas:to_canvas_position(love.mouse.getPosition())
  local enabled = player:can_buy_ammo() and not rules:is_level_complete()
  local hovered = enabled and mouse_x and
    is_inside_ammo_button(mouse_x, mouse_y)
  local icon_alpha = enabled and (hovered and 1 or 0.75) or 0.35
  local text_color = graphics.color_with_alpha(colors.foreground, icon_alpha)
  local center_y = ammo_button.y + ammo_button.height / 2
  draw_bullet_icon(ammo_button.x + 10, center_y, icon_alpha)
  graphics.set_color(text_color)
  love.graphics.print(
    "/ " .. player.ammo_purchase_cost,
    ammo_button.x + 17,
    ammo_button.y + 1)

  if rules:is_level_complete() then
    love.graphics.printf("LEVEL COMPLETE", 0, gh / 2 - 8, gw, "center")
  end
end

local function draw_aim_dot()
  local x, y = game_canvas:to_canvas_position(love.mouse.getPosition())
  if not x then return end
  graphics.circle(x, y, 1.5, colors.foreground)
end

local function draw_game()
  draw_background()
  draw_aim_ray()
  for _, projectile in ipairs(projectiles) do projectile:draw() end
  for _, enemy in ipairs(enemies) do enemy:draw() end
  player:draw()
  for _, effect in ipairs(effects) do effect:draw() end
  draw_ui()
  draw_aim_dot()
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

  if is_inside_ammo_button(mouse_x, mouse_y) then
    if not rules:is_level_complete() then player:buy_ammo() end
    return
  end

  if not rules:is_level_complete() then
    player:try_attack(
      mouse_x, mouse_y, enemies, projectiles, effects)
  end
end
