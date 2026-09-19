Game = Object:extend()

function Game:init()
  self.colors = Data.theme.colors

  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setBackgroundColor(
    self.colors.background[1], self.colors.background[2],
    self.colors.background[3], self.colors.background[4])
  love.graphics.setLineStyle("rough")
  love.mouse.setVisible(false)

  self.ui_font = love.graphics.newFont(Data.display.ui_font, Data.display.ui_font_size)
  self.ui_font:setFilter("nearest", "nearest")
  self.small_font = love.graphics.newFont(
    Data.display.small_font, Data.display.small_font_size)
  self.small_font:setFilter("nearest", "nearest")
  love.graphics.setFont(self.ui_font)

  self.audio = Audio(Data.audio)

  self.canvas = Canvas(gw, gh)
  self.background_canvas = Canvas(gw, gh)
  self.scene_canvas = Canvas(gw, gh)
  self.shadow_canvas = Canvas(gw, gh)
  self.shadow_shader = love.graphics.newShader("assets/shaders/shadow.frag")
  self.camera = Camera(aw / 2, ah / 2, aw, ah)
  self.draw_background_action = function() self:draw_background_scene() end
  self.draw_scene_action = function() self:draw_scene() end
  self.draw_shadow_action = function() self:draw_shadow() end
  self.draw_composite_action = function() self:draw_composite() end
  self:reset_run()
end

function Game:reset_run()
  self.camera:reset()
  self.elapsed_time = 0
  self.difficulty_level = 0
  self.gold_fraction = 0
  self.score, self.state = 0, "playing"
  self.coins = Data.rules.starting_coins
  self.upgrades = {
    gold_gain = 0,
    critical = 0,
    luck = 0,
    hit_power = 0,
    bounce = 0,
    fire_rate = 0,
    auto_attack = 0,
  }
  self.enemy_traits = {haste = 0, armor = 0, fission = 0}
  self.arena = Arena(self)
  self.hud = HUD(self)
  self.sidebar = Sidebar(self)
  self.arena:start()
end

function Game:enemy_killed(enemy)
  if self.state ~= "playing" then return false end

  local base_score = enemy and enemy.base_score or 1
  local kill_score = enemy and (enemy.kill_score or base_score) or 1
  self.score = self.score + kill_score

  local gold_multiplier = 1 +
    self.upgrades.gold_gain * Data.upgrades.gold_bonus_per_level
  self.gold_fraction = self.gold_fraction + base_score * gold_multiplier
  local gold = math.floor(self.gold_fraction)
  self.gold_fraction = self.gold_fraction - gold
  self:add_coins(gold)

  return true
end

function Game:fail()
  if self.state ~= "playing" then return end
  self.state = "failed"
end

function Game:add_coins(amount)
  self.coins = self.coins + math.max(0, math.floor(amount or 0))
end

function Game:update_mouse_cursor()
  local mouse_x = self.canvas:to_canvas_position(love.mouse.getPosition())
  love.mouse.setVisible(not mouse_x or mouse_x > aw)
end

function Game:update(dt)
  self:update_mouse_cursor()
  if self.state == "playing" then
    self.elapsed_time = self.elapsed_time + dt
    self.difficulty_level = math.floor(
      self.elapsed_time / EnemyConfig.difficulty_seconds)
    local screen_x, screen_y = self.canvas:to_canvas_position(
      love.mouse.getPosition())
    local aim_x, aim_y
    if screen_x and screen_x <= aw then
      aim_x, aim_y = self.camera:to_world(screen_x, screen_y)
    end
    self.arena:update(dt, aim_x, aim_y)
  end
  if self.state == "playing" then self.camera:update(dt)
  else self.camera:reset() end
end

function Game:draw_background()
  graphics.rectangle(
    gw / 2, gh / 2, gw, gh, nil, nil, self.colors.background)
end

function Game:draw_background_scene()
  self:draw_background()
end

function Game:draw_scene()
  local x, y = self.canvas:to_canvas_position(love.mouse.getPosition())
  local world_x, world_y = self.camera:to_world(x, y)

  self.camera:attach()
  if self.state ~= "failed" then
    self.arena:draw(x and x <= aw and world_x or nil, world_y)
  end
  self.camera:detach()

  if self.state == "failed" then
    self.hud:draw_failure()
  else
    self.hud:draw(x, y)
  end
  self.sidebar:draw(x, y)
end

function Game:draw_shadow()
  love.graphics.push("all")
  love.graphics.setShader(self.shadow_shader)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.scene_canvas.canvas, 0, 0)
  love.graphics.pop()
end

function Game:draw_composite()
  love.graphics.push("all")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.background_canvas.canvas, 0, 0)
  love.graphics.draw(self.shadow_canvas.canvas, 1.5, 1.5)
  love.graphics.draw(self.scene_canvas.canvas, 0, 0)
  love.graphics.pop()
end

function Game:draw()
  self.background_canvas:draw_to(
    self.draw_background_action, self.colors.background)
  self.scene_canvas:draw_to(self.draw_scene_action)
  self.shadow_canvas:draw_to(self.draw_shadow_action)
  self.canvas:draw_to(self.draw_composite_action)
  self.canvas:draw_to_window()
end

function Game:keypressed(key)
  if key == "escape" then love.event.quit() end
  if key == "r" and self.state == "failed" then self:reset_run() end
end

function Game:mousepressed(x, y, button)
  if button ~= 1 then return end
  local mouse_x, mouse_y = self.canvas:to_canvas_position(x, y)
  if not mouse_x then return end
  if self.state == "playing" then
    if mouse_x > aw then
      self.sidebar:mousepressed(mouse_x, mouse_y)
      return
    end
    local world_x, world_y = self.camera:to_world(mouse_x, mouse_y)
    self.arena:mousepressed(world_x, world_y)
  end
end
