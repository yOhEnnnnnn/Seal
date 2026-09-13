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
  self.spawn_interval = 0.9
  self.max_enemies = 60
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
  self.rules = GameRules{levels = levels, state = "shop"}
  self.spawn_timer = self.spawn_interval
  self.next_spawn_side = 1
  self.player = Player{x = gw / 2, y = gh / 2, coins = 10}
  self.projectiles = Group()
  self.effects = Group()
  self.enemies = Group{
    on_remove = function(enemy)
      if not enemy.reached_center and self.rules:enemy_killed() then
        self.player:add_coins(1)
      end
    end,
  }
  self.shop = Shop{
    player = self.player,
    rules = self.rules,
    ui_font = self.ui_font,
    item_font = self.shop_item_font,
    colors = self.colors,
    on_next = function() self:start_next_level() end,
  }
end

function Game:spawn_enemy(side)
  if #self.enemies >= self.max_enemies then return end

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

  self.enemies:add(Enemy{
    x = x,
    y = y,
    color = self.colors.red,
    hit_color = self.colors.foreground,
    hp_bar_background = self.colors.hp_bar_background,
    effects = self.effects,
  })
end

function Game:update_enemy_spawning(dt)
  if self.rules.state ~= "playing" then return end

  self.spawn_timer = math.max(self.spawn_timer - dt, 0)
  if self.spawn_timer > 0 or #self.enemies >= self.max_enemies then return end

  self:spawn_enemy(self.next_spawn_side)
  self.next_spawn_side = self.next_spawn_side % 4 + 1
  self.spawn_timer = self.spawn_interval
end

function Game:start_next_level()
  if not self.rules:next_level() then return end

  self.shop:reset()
  self.spawn_timer = self.spawn_interval
  self.next_spawn_side = 1
  for side = 1, 4 do self:spawn_enemy(side) end
end

function Game:update(dt)
  if self.rules.state ~= "playing" then return end
  self.player:update(dt)
  self:update_enemy_spawning(dt)

  self.enemies:update(dt, self.player, self.enemies)
  self.projectiles:update(dt, self.enemies)
  self.effects:update(dt, self.enemies)
  -- Settle this frame's kills before checking whether ammunition ran out.
  self.enemies:remove_dead()

  if self.player:get_ammo_count() == 0 and #self.projectiles == 0 then
    self.rules:fail()
  end

  if self.rules.state ~= "playing" then
    self.enemies:clear()
    self.projectiles:clear()
    self.effects:clear()
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

function Game:draw_aim_ray()
  local mouse_x, mouse_y = self.canvas:to_canvas_position(
    love.mouse.getPosition())
  if not mouse_x then return end

  local dx, dy = mouse_x - self.player.x, mouse_y - self.player.y
  local length = math.sqrt(dx * dx + dy * dy)
  if length < 0.001 then return end

  dx, dy = dx / length, dy / length
  local distance_x = dx > 0 and (gw - self.player.x) / dx or
    (dx < 0 and -self.player.x / dx or math.huge)
  local distance_y = dy > 0 and (gh - self.player.y) / dy or
    (dy < 0 and -self.player.y / dy or math.huge)
  local ray_length = math.min(distance_x, distance_y)
  local dash_length, gap_length = 6, 5

  love.graphics.push("all")
  local color = self.colors.foreground
  love.graphics.setColor(color[1], color[2], color[3], 0.4)
  love.graphics.setLineWidth(2)
  for distance = self.player.size + 5,
    ray_length, dash_length + gap_length do
    local dash_end = math.min(distance + dash_length, ray_length)
    love.graphics.line(
      self.player.x + dx * distance,
      self.player.y + dy * distance,
      self.player.x + dx * dash_end,
      self.player.y + dy * dash_end)
  end
  love.graphics.pop()
end

function Game:draw_bullet_inventory()
  local x, y = gw - 54, 40
  local current = self.player:get_current_bullet()
  local mouse_x, mouse_y = self.canvas:to_canvas_position(
    love.mouse.getPosition())

  love.graphics.push("all")
  love.graphics.setFont(self.shop_item_font)

  local row = 0
  for _, bullet in ipairs(self.player.bullet_order) do
    local count = self.player.bullets[bullet]
    if count > 0 then
      local row_y = y + row * 30
      local definition = self.player:get_bullet_definition(bullet)
      local alpha = bullet == current and 1 or 0.78
      local count_text = tostring(count)
      local count_x = x + 17
      local group_left = x - 7
      local group_right = count_x + self.shop_item_font:getWidth(count_text)
      local hover_width = group_right - group_left + 20
      local hover_x = (group_left + group_right) / 2
      local hovered = mouse_x and
        mouse_x >= hover_x - hover_width / 2 and
        mouse_x <= hover_x + hover_width / 2 and
        mouse_y >= row_y - 13 and mouse_y <= row_y + 13
      if hovered then
        graphics.rectangle(
          hover_x, row_y, hover_width, 26, 5, 5,
          self.colors.shop_selected)
      end
      self.shop:draw_icon(x, row_y, definition.color, alpha)
      graphics.set_color(self.colors.hp_bar_background)
      love.graphics.print(
        count_text, count_x + 1,
        row_y - self.shop_item_font:getHeight() / 2 + 2)
      graphics.set_color(self.colors.foreground)
      love.graphics.print(
        count_text, count_x,
        row_y - self.shop_item_font:getHeight() / 2 + 1)
      row = row + 1
    end
  end
  love.graphics.pop()
end

function Game:draw_ui()
  graphics.set_color(self.colors.foreground)
  love.graphics.print("GOLD:", 10, 9)
  graphics.set_color(self.colors.gold)
  love.graphics.print(
    self.player.coins, 10 + self.ui_font:getWidth("GOLD: "), 9)

  graphics.set_color(self.colors.foreground)
  love.graphics.printf(
    "SCORE: " .. self.rules.score .. " / " ..
      self.rules:get_target_score(),
    gw - 150,
    9,
    140,
    "right")

  self:draw_bullet_inventory()
end

function Game:draw_aim_dot()
  local x, y = self.canvas:to_canvas_position(love.mouse.getPosition())
  if not x then return end
  graphics.circle(x, y, 1.5, self.colors.foreground)
end

function Game:draw_scene()
  self:draw_background()
  if self.rules.state == "failed" then
    graphics.set_color(self.colors.foreground)
    love.graphics.printf("OUT OF AMMO", 0, gh / 2 - 20, gw, "center")
    love.graphics.printf("PRESS R TO RESTART", 0, gh / 2 + 4, gw, "center")
    self:draw_aim_dot()
    return
  end
  if self.rules:is_shop_open() then
    local mouse_x, mouse_y = self.canvas:to_canvas_position(
      love.mouse.getPosition())
    self.shop:draw(mouse_x, mouse_y)
    self:draw_bullet_inventory()
    self:draw_aim_dot()
    return
  end

  self:draw_aim_ray()
  self.projectiles:draw()
  self.enemies:draw()
  self.player:draw()
  self.effects:draw()
  self:draw_ui()
  self:draw_aim_dot()
end

function Game:draw()
  self.canvas:draw_to(self.draw_scene_action, self.colors.background)
  self.canvas:draw_to_window()
end

function Game:keypressed(key)
  if key == "r" and (self.rules.state == "failed" or
    (self.rules:is_level_complete() and not self.rules:has_next_level())) then
    self:reset_run()
  end
  if key == "q" and self.rules.state == "playing" then
    self.player:select_next_bullet()
  end
  if key == "escape" then love.event.quit() end
end

function Game:mousepressed(x, y, button)
  if button ~= 1 then return end

  local mouse_x, mouse_y = self.canvas:to_canvas_position(x, y)
  if not mouse_x then return end

  if self.rules:is_shop_open() then
    self.shop:mousepressed(mouse_x, mouse_y)
    return
  end
  if self.rules.state ~= "playing" then return end

  self.player:try_attack(
    mouse_x, mouse_y, self.projectiles, self.effects)
end
