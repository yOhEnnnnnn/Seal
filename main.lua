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
local colors = {
  background = {43 / 255, 46 / 255, 46 / 255, 1},
  background_dark = {41 / 255, 44 / 255, 44 / 255, 1},
  background_light = {48 / 255, 51 / 255, 51 / 255, 1},
  hp_bar_background = {12 / 255, 14 / 255, 15 / 255, 1},
  foreground = {218 / 255, 218 / 255, 218 / 255, 1},
  yellow = {250 / 255, 207 / 255, 0, 1},
  blue = {1 / 255, 155 / 255, 214 / 255, 1},
  red = {233 / 255, 29 / 255, 57 / 255, 1},
}

function love.load(args)
  local arc_test = false
  for _, arg in ipairs(args or {}) do
    if arg == "--arc-test" then arc_test = true end
  end
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setBackgroundColor(0, 0, 0, 1)
  love.graphics.setLineStyle("rough")

  ui_font = love.graphics.newFont("assets/fonts/BoiledPasta.ttf", 16)
  ui_font:setFilter("nearest", "nearest")
  love.graphics.setFont(ui_font)

  game_canvas = Canvas(gw, gh)
  projectiles = {}
  effects = {}
  enemies = {
    Enemy{
      x = 284,
      y = 135,
      color = colors.red,
      hit_color = colors.foreground,
      hp_bar_background = colors.hp_bar_background,
      effects = effects,
      invincible = true,
      stationary = true,
    },
    Enemy{
      x = 360,
      y = 85,
      color = colors.red,
      hit_color = colors.foreground,
      hp_bar_background = colors.hp_bar_background,
      effects = effects,
    },
    Enemy{
      x = 400,
      y = 135,
      color = colors.red,
      hit_color = colors.foreground,
      hp_bar_background = colors.hp_bar_background,
      effects = effects,
    },
    Enemy{
      x = 360,
      y = 185,
      color = colors.red,
      hit_color = colors.foreground,
      hp_bar_background = colors.hp_bar_background,
      effects = effects,
    },
  }
  if arc_test then
    enemies = {}
    for _, position in ipairs({{285, 110}, {285, 160}, {365, 85}, {385, 135}, {365, 185}, {440, 135}}) do
      enemies[#enemies + 1] = Enemy{
        x = position[1], y = position[2], color = colors.red,
        hit_color = colors.foreground, hp_bar_background = colors.hp_bar_background,
        effects = effects, invincible = true, stationary = true,
      }
    end
  end
  player = Player{
    x = 240,
    y = 135,
    heroes = {
      arc_test and Arc{color = colors.blue, level = 3} or Cinder{color = colors.yellow},
      Guard{color = colors.blue},
    },
  }
end

function love.update(dt)
  local mouse_x, mouse_y = game_canvas:to_canvas_position(love.mouse.getPosition())
  player:set_aim_position(mouse_x, mouse_y)
  player:update(dt, enemies, projectiles, effects)

  for index = #enemies, 1, -1 do
    enemies[index]:update(dt, player, enemies)
    if enemies[index].dead then table.remove(enemies, index) end
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
  local hero = player:get_active_hero()
  love.graphics.print("HERO: " .. hero.name .. " LV." .. hero.level, 10, 9)
  love.graphics.print("DASH: LEFT CLICK", 10, 9 + line_height)
  if player:can_switch() then
    love.graphics.print("Q: READY", 10, 9 + line_height * 2)
  else
    love.graphics.print(string.format("Q: %.1f", player.switch_cooldown_time),
      10, 9 + line_height * 2)
  end
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
  if key == "escape" then
    love.event.quit()
  end
end

function love.mousepressed(x, y, button)
  if button ~= 1 then return end
  local mouse_x, mouse_y = game_canvas:to_canvas_position(x, y)
  if not mouse_x then return end
  player:set_aim_position(mouse_x, mouse_y)
  player:start_dash()
end
