Game = Object:extend()

function Game:init()
  self.colors = {
    background = {43 / 255, 46 / 255, 46 / 255, 1},
    background_dark = {41 / 255, 44 / 255, 44 / 255, 1},
    background_light = {48 / 255, 51 / 255, 51 / 255, 1},
    shop_selected = {35 / 255, 38 / 255, 38 / 255, 1},
    hp_bar_background = {12 / 255, 14 / 255, 15 / 255, 1},
    foreground = {218 / 255, 218 / 255, 218 / 255, 1},
    gold = {250 / 255, 207 / 255, 0, 1},
    green = {126 / 255, 231 / 255, 135 / 255, 1},
    red = {233 / 255, 29 / 255, 57 / 255, 1},
    enemy = {233 / 255, 29 / 255, 57 / 255, 1},
  }
  self.transition_colors = {
    {247 / 255, 214 / 255, 218 / 255, 1},
    {244 / 255, 216 / 255, 206 / 255, 1},
    {246 / 255, 224 / 255, 208 / 255, 1},
    {239 / 255, 214 / 255, 222 / 255, 1},
    {242 / 255, 217 / 255, 210 / 255, 1},
  }

  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setBackgroundColor(0, 0, 0, 1)
  love.graphics.setLineStyle("rough")
  love.mouse.setVisible(false)

  self.ui_font = love.graphics.newFont("assets/fonts/BoiledPasta.ttf", 16)
  self.ui_font:setFilter("nearest", "nearest")
  self.shop_item_font = love.graphics.newFont(
    "assets/fonts/PixulBrush.ttf", 8)
  self.shop_item_font:setFilter("nearest", "nearest")
  love.graphics.setFont(self.ui_font)

  projectile_attack_sound = love.audio.newSource(
    "assets/sounds/projectile_attack.wav", "static")
  projectile_attack_sound:setVolume(0.2)

  self.canvas = Canvas(gw, gh)
  self.background_canvas = Canvas(gw, gh)
  self.scene_canvas = Canvas(gw, gh)
  self.shadow_canvas = Canvas(gw, gh)
  self.shadow_shader = love.graphics.newShader("assets/shaders/shadow.frag")
  self.camera = Camera(gw / 2, gh / 2, gw, gh)
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
  self.danger_level = 0
  self.danger_time = 0
  self.gold_fraction = 0
  self.secured_coins = nil
  self.level, self.score, self.state = 1, 0, "shop"
  self.coins = 8
  self.inventory = Inventory()
  self.enemy_traits = {haste = 0, armor = 0, fission = 0}
  self.arena = Arena(self)
  self.hud = HUD(self)
  self.shop = Shop(self)
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
  local source = enemy and enemy.killed_by
  local combo_gain = 0.1
  if source and source.bullet == BulletType.PIERCE and
    enemy.kill_sequence > 1 then combo_gain = 0.2 end
  self.combo_multiplier = math.min(3, self.combo_multiplier + combo_gain)
  self.combo_timer = 1.5 + math.min(self.enemy_traits.haste * 0.15, 0.45)
  if source and source.bullet == BulletType.EMBER then
    self.combo_timer = math.max(self.combo_timer, 2.5)
  end

  self.gold_fraction = self.gold_fraction +
    base_score * (1 + self.danger_level * 0.15)
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

function Game:is_shop_open()
  return self.state == "shop" or self:is_level_complete()
end

function Game:fail()
  if self.state ~= "playing" then return end
  if self.can_extract and self.secured_coins then
    self.coins = self.secured_coins
  end
  self.state = "failed"
end

function Game:has_next_level()
  return self.state == "shop" or levels[self.level + 1] ~= nil
end

function Game:add_coins(amount)
  self.coins = self.coins + math.max(0, math.floor(amount or 0))
end

function Game:start_next_level()
  if not self:is_shop_open() or not self:has_next_level() then return false end
  if self.state ~= "shop" then self.level = self.level + 1 end
  self.score, self.state, self.can_extract = 0, "playing", false
  self.combo_multiplier, self.combo_timer = 1, 0
  self.danger_level, self.danger_time = 0, 0
  self.gold_fraction, self.secured_coins = 0, nil
  self.shop:reset()
  self.arena = Arena(self)
  self.arena:start()
  return true
end

function Game:finish_level()
  if self.state ~= "playing" or not self.can_extract then return false end
  self.state = "level_complete"
  return true
end

function Game:transition_to_shop(x, y)
  if self.transition or self.state ~= "playing" or
    not self.can_extract then return false end
  self.transition = SceneTransition{
    x = x,
    y = y,
    color = self:get_transition_color(),
    text_color = self.colors.background_dark,
    font = self.ui_font,
    text = self.level == #levels and "RUN COMPLETE" or "EXTRACT",
    transition_action = function() self:finish_level() end,
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

function Game:transition_to_next_level(x, y)
  if self.transition or not self:is_shop_open() or
    not self:has_next_level() then return false end
  local target_level = self.state == "shop" and self.level or self.level + 1
  self.transition = SceneTransition{
    x = x,
    y = y,
    color = self:get_transition_color(),
    text_color = self.colors.background_dark,
    font = self.ui_font,
    text = "LEVEL " .. target_level .. " / " .. #levels,
    transition_action = function() self:start_next_level() end,
  }
  return true
end

function Game:update(dt)
  if self.state == "playing" and not self.transition then
    self.combo_timer = math.max(self.combo_timer - dt, 0)
    if self.combo_timer == 0 then
      self.combo_multiplier = math.max(1, self.combo_multiplier - dt * 1.5)
    end
    if self.can_extract then
      self.danger_time = self.danger_time + dt
      self.danger_level = math.min(5, math.floor(self.danger_time / 10))
    end
    self.arena:update(dt)
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
  self.camera:attach()
  self:draw_background()
  self.camera:detach()
end

function Game:draw_scene()
  local x, y = self.canvas:to_canvas_position(love.mouse.getPosition())
  local world_x, world_y = self.camera:to_world(x, y)

  self.camera:attach()
  if self.state == "playing" then
    self.arena:draw(world_x, world_y)
  end
  self.camera:detach()

  if self.state == "failed" then
    self.hud:draw_failure()
  elseif self:is_shop_open() then
    self.shop:draw(x, y)
    self.hud:draw_bullet_inventory(x, y)
  else
    self.hud:draw(x, y)
  end
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
    self:transition_to_shop(gw / 2, gh / 2)
    return
  end
  if key == "r" and (self.state == "failed" or
    (self:is_level_complete() and not self:has_next_level())) then
    self:reset_run()
  end
  if key == "q" and self.state == "playing" then
    self.inventory:select_next()
    self.arena.player:sync_bullet_visuals()
  end
end

function Game:mousepressed(x, y, button)
  if self.transition then return end
  if button ~= 1 then return end
  local mouse_x, mouse_y = self.canvas:to_canvas_position(x, y)
  if not mouse_x then return end
  if self:is_shop_open() then
    self.shop:mousepressed(mouse_x, mouse_y)
  elseif self.state == "playing" then
    local world_x, world_y = self.camera:to_world(mouse_x, mouse_y)
    self.arena:mousepressed(world_x, world_y)
  end
end
