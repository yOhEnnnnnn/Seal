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
  local x, y = gw / 2, gh / 2
  self.background_polygons = {
    {x, y, 0, 0, 170, 0},
    {x, y, gw, 212, gw, gh, 310, gh},
    {x, y, 310, 0, gw, 0, gw, 58},
    {x, y, 170, gh, 0, gh, 0, 212},
  }
  self.draw_scene_action = function() self:draw_scene() end
  self:reset_run()
end

function Game:reset_run()
  self.level, self.score, self.state = 1, 0, "shop"
  self.coins = 10
  self.inventory = Inventory()
  self.enemy_traits = {haste = 0, armor = 0, fission = 0}
  self.arena = Arena(self)
  self.hud = HUD(self)
  self.shop = Shop(self)
end

function Game:get_target_score()
  return levels[self.level].target_score
end

function Game:enemy_killed()
  if self.state ~= "playing" then return false end

  self:add_coins(1)
  self.score = self.score + 1
  if self.score >= self:get_target_score() then
    self.state = "level_complete"
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
  if self.state == "playing" then self.state = "failed" end
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
  self.score, self.state = 0, "playing"
  self.shop:reset()
  self.arena = Arena(self)
  self.arena:start()
  return true
end

function Game:update(dt)
  if self.state == "playing" then self.arena:update(dt) end
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

function Game:draw_scene()
  self:draw_background()
  local x, y = self.canvas:to_canvas_position(love.mouse.getPosition())
  if self.state == "failed" then
    self.hud:draw_failure()
  elseif self:is_shop_open() then
    self.shop:draw(x, y)
    self.hud:draw_bullet_inventory(x, y)
  else
    self.arena:draw(x, y)
    self.hud:draw(x, y)
  end
  if x then graphics.circle(x, y, 1.5, self.colors.foreground) end
end

function Game:draw()
  self.canvas:draw_to(self.draw_scene_action, self.colors.background)
  self.canvas:draw_to_window()
end

function Game:keypressed(key)
  if key == "r" and (self.state == "failed" or
    (self:is_level_complete() and not self:has_next_level())) then
    self:reset_run()
  end
  if key == "q" and self.state == "playing" then
    self.inventory:select_next()
  end
  if key == "escape" then love.event.quit() end
end

function Game:mousepressed(x, y, button)
  if button ~= 1 then return end
  local mouse_x, mouse_y = self.canvas:to_canvas_position(x, y)
  if not mouse_x then return end
  if self:is_shop_open() then
    self.shop:mousepressed(mouse_x, mouse_y)
  elseif self.state == "playing" then
    self.arena:mousepressed(mouse_x, mouse_y)
  end
end
