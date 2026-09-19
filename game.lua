Game = Object:extend()

function Game:init()
  self.colors = Data.theme.colors
  self.transition_colors = Data.theme.transition_colors

  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setBackgroundColor(0, 0, 0, 1)
  love.graphics.setLineStyle("rough")
  love.mouse.setVisible(false)

  self.ui_font = love.graphics.newFont(Data.display.ui_font, Data.display.ui_font_size)
  self.ui_font:setFilter("nearest", "nearest")
  self.small_font = love.graphics.newFont(
    Data.display.small_font, Data.display.small_font_size)
  self.small_font:setFilter("nearest", "nearest")
  love.graphics.setFont(self.ui_font)

  projectile_attack_sound = love.audio.newSource(
    Data.display.attack_sound, "static")
  projectile_attack_sound:setVolume(Data.display.attack_volume)

  self.canvas = Canvas(gw, gh)
  self.background_canvas = Canvas(gw, gh)
  self.scene_canvas = Canvas(gw, gh)
  self.shadow_canvas = Canvas(gw, gh)
  self.shadow_shader = love.graphics.newShader("assets/shaders/shadow.frag")
  self.camera = Camera(aw / 2, ah / 2, aw, ah)
  local x, y = gw / 2, gh / 2
  local padding = 16
  self.background_polygons = {
    {x, y, -padding, -padding, 170, -padding},
    {x, y, gw + padding, 212, gw + padding, gh + padding, 310, gh + padding},
    {x, y, 310, -padding, gw + padding, -padding, gw + padding, 58},
    {x, y, 170, gh + padding, -padding, gh + padding, -padding, 212},
  }
  self.draw_background_action = function() self:draw_background_scene() end
  self.draw_scene_action = function() self:draw_scene() end
  self.draw_shadow_action = function() self:draw_shadow() end
  self.draw_composite_action = function() self:draw_composite() end
  self:reset_run()
end

function Game:reset_run()
  self.camera:reset()
  self.transition = nil
  self.can_extract = false
  self.combo_multiplier = 1
  self.combo_timer = 0
  self.combo_pulse = 0
  self.danger_level = 0
  self.danger_time = 0
  self.gold_fraction = 0
  self.secured_coins = nil
  self.level, self.score, self.state = 1, 0, "playing"
  self.coins = Data.rules.starting_coins
  self.upgrades = {
    gold_gain = 0,
    critical = 0,
    luck = 0,
    damage = 0,
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

function Game:get_target_score()
  return levels[self.level].target_score
end

function Game:enemy_killed(enemy)
  if self.state ~= "playing" then return false end

  local base_score = enemy and enemy.base_score or 1
  local kill_score = enemy and (enemy.kill_score or base_score) or 1
  self.score = self.score + math.floor(
    kill_score * self.combo_multiplier + 0.5)
  local combo = Data.rules.combo
  self.combo_multiplier = math.min(combo.max_multiplier, self.combo_multiplier + combo.gain)
  self.combo_pulse = 1
  self.combo_timer = combo.duration + math.min(
    self.enemy_traits.haste * combo.haste_duration_bonus, combo.max_haste_duration_bonus)

  local gold_multiplier = 1 +
    self.upgrades.gold_gain * Data.upgrades.gold_bonus_per_level
  self.gold_fraction = self.gold_fraction + base_score * gold_multiplier *
    (1 + self.danger_level * Data.rules.danger.gold_bonus_per_level)
  local gold = math.floor(self.gold_fraction)
  self.gold_fraction = self.gold_fraction - gold
  self:add_coins(gold)

  if not self.can_extract and self.score >= self:get_target_score() then
    self.can_extract = true
    self.secured_coins = self.coins
  end
  return true
end

function Game:is_level_complete()
  return self.state == "level_complete"
end

function Game:fail()
  if self.state ~= "playing" then return end
  if self.can_extract and self.secured_coins then
    self.coins = self.secured_coins
  end
  self.state = "failed"
end

function Game:has_next_level()
  return levels[self.level + 1] ~= nil
end

function Game:add_coins(amount)
  self.coins = self.coins + math.max(0, math.floor(amount or 0))
end

function Game:start_next_level()
  if not self:is_level_complete() or not self:has_next_level() then return false end
  self.level = self.level + 1
  self.score, self.state, self.can_extract = 0, "playing", false
  self.combo_multiplier, self.combo_timer, self.combo_pulse = 1, 0, 0
  self.danger_level, self.danger_time = 0, 0
  self.gold_fraction, self.secured_coins = 0, nil
  self.arena = Arena(self)
  self.arena:start()
  return true
end

function Game:finish_level()
  if self.state ~= "playing" or not self.can_extract then return false end
  self.state = "level_complete"
  self.arena.enemies:clear()
  self.arena.projectiles:clear()
  self.arena.effects:clear()
  return true
end

function Game:transition_to_next_level(x, y)
  if self.transition or self.state ~= "playing" or
    not self.can_extract then return false end
  self.transition = SceneTransition{
    x = x,
    y = y,
    color = self:get_transition_color(),
    text_color = self.colors.background_dark,
    font = self.ui_font,
    text = self.level == #levels and "RUN COMPLETE" or
      "LEVEL " .. (self.level + 1) .. " / " .. #levels,
    transition_action = function()
      self:finish_level()
      if self:has_next_level() then self:start_next_level() end
    end,
  }
  return true
end

function Game:get_transition_color()
  local count = #self.transition_colors
  local index
  if self.last_transition_color_index then
    index = love.math.random(1, count - 1)
    if index >= self.last_transition_color_index then index = index + 1 end
  else
    index = love.math.random(1, count)
  end
  self.last_transition_color_index = index
  return self.transition_colors[index]
end

function Game:update_mouse_cursor()
  local mouse_x = self.canvas:to_canvas_position(love.mouse.getPosition())
  love.mouse.setVisible(not mouse_x or mouse_x > aw)
end

function Game:update(dt)
  self:update_mouse_cursor()
  if self.state == "playing" and not self.transition then
    self.combo_timer = math.max(self.combo_timer - dt, 0)
    self.combo_pulse = math.max(self.combo_pulse - dt / Data.rules.combo.pulse_duration, 0)
    if self.combo_timer == 0 then
      self.combo_multiplier = math.max(1, self.combo_multiplier - dt * Data.rules.combo.decay_per_second)
    end
    if self.can_extract then
      self.danger_time = self.danger_time + dt
      self.danger_level = math.min(Data.rules.danger.max_level,
        math.floor(self.danger_time / Data.rules.danger.seconds_per_level))
    end
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
  if self.transition then
    self.transition:update(dt)
    if self.transition.dead then self.transition = nil end
  end
end

function Game:draw_background()
  love.graphics.push("all")
  for index, vertices in ipairs(self.background_polygons) do
    graphics.set_color(index <= 2 and self.colors.background_dark or
      self.colors.background_light)
    love.graphics.polygon("fill", vertices)
  end
  love.graphics.pop()
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
  if self.transition then self.transition:draw() end
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
  if self.transition then return end
  if key == "p" and self.state == "playing" and self.can_extract then
    self:transition_to_next_level(aw / 2, ah / 2)
    return
  end
  if key == "r" and (self.state == "failed" or
    (self:is_level_complete() and not self:has_next_level())) then
    self:reset_run()
  end
end

function Game:mousepressed(x, y, button)
  if self.transition then return end
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
