HUD = Object:extend()

function HUD:init(game)
  self.game = game
  self.ui_font = game.ui_font
  self.item_font = game.shop_item_font
  self.colors = game.colors
  self.combo_canvas = love.graphics.newCanvas(160, 48, {msaa = 0})
  self.combo_canvas:setFilter("nearest", "nearest")
  self.combo_flame_shader = love.graphics.newShader(
    "assets/shaders/combo_flame.frag")
end

function HUD:draw_bullet_inventory(mouse_x, mouse_y)
  local x, y = gw - 54, 40
  local current = self.game.inventory:get_current()

  love.graphics.push("all")
  love.graphics.setFont(self.item_font)

  local row = 0
  for _, bullet in ipairs(self.game.inventory.order) do
    local count = self.game.inventory.counts[bullet]
    if count > 0 then
      local row_y = y + row * 30
      local definition = Bullets[bullet]
      local alpha = bullet == current and 1 or 0.78
      local count_text = tostring(count)
      local count_x = x + 17
      local group_left = x - 7
      local group_right = count_x + self.item_font:getWidth(count_text)
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
      self:draw_icon(x, row_y, definition.color, alpha)
      graphics.set_color(self.colors.hp_bar_background)
      love.graphics.print(
        count_text, count_x + 1,
        row_y - self.item_font:getHeight() / 2 + 2)
      graphics.set_color(self.colors.foreground)
      love.graphics.print(
        count_text, count_x,
        row_y - self.item_font:getHeight() / 2 + 1)
      row = row + 1
    end
  end
  love.graphics.pop()
end

function HUD:draw(mouse_x, mouse_y)
  graphics.set_color(self.colors.foreground)
  love.graphics.print("GOLD:", 10, 9)
  graphics.set_color(self.colors.gold)
  love.graphics.print(
    self.game.coins, 10 + self.ui_font:getWidth("GOLD: "), 9)

  graphics.set_color(self.colors.foreground)
  love.graphics.printf(
    "SCORE: " .. self.game.score .. " / " ..
      self.game:get_target_score(),
    gw - 150,
    9,
    140,
    "right")

  self:draw_combo()
  if self.game.danger_level > 0 then
    graphics.set_color(self.colors.red)
    love.graphics.printf(
      "DANGER " .. self.game.danger_level,
      0, 27, gw, "center")
  end

  self:draw_health()
  self:draw_bullet_inventory(mouse_x, mouse_y)
  if self.game.can_extract then
    graphics.set_color(self.colors.foreground)
    love.graphics.printf(
      self.game.level == #levels and
        "TARGET REACHED - PRESS P TO COMPLETE RUN" or
        "TARGET REACHED - PRESS P TO ENTER SHOP",
      0, gh - 25, gw, "center")
  end
end

function HUD:draw_combo()
  if self.game.combo_multiplier <= 1 then return end
  local text = string.format("COMBO X%.1f", self.game.combo_multiplier)
  local intensity = math.max(0,
    math.min((self.game.combo_multiplier - 1.4) / 1.6, 1))
  local previous_canvas = love.graphics.getCanvas()

  love.graphics.push("all")
  love.graphics.setCanvas(self.combo_canvas)
  love.graphics.origin()
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setFont(self.ui_font)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf(text, 0, 24, 160, "center")
  love.graphics.setCanvas(previous_canvas)
  love.graphics.pop()

  local x, y = (gw - 160) / 2, -6
  if intensity > 0 then
    love.graphics.push("all")
    self.combo_flame_shader:send("time", love.timer.getTime())
    self.combo_flame_shader:send("intensity", intensity)
    love.graphics.setShader(self.combo_flame_shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.combo_canvas, x, y)
    love.graphics.pop()
  end

  local scale = 1 + 0.15 * self.game.combo_pulse
  love.graphics.push("all")
  love.graphics.translate(gw / 2, 18)
  love.graphics.scale(scale, scale)
  love.graphics.setFont(self.ui_font)
  graphics.set_color(intensity == 1 and self.colors.foreground or
    self.colors.gold)
  love.graphics.printf(text, -80, 0, 160, "center")
  love.graphics.pop()
end

function HUD:draw_health()
  local player = self.game.arena.player
  local ratio = math.max(0, player.hp / player.max_hp)
  local color = ratio > 0.5 and self.colors.green or
    (ratio > 0.25 and self.colors.gold or self.colors.red)
  local width = 84

  graphics.rectangle(10 + width / 2, 35, width, 6, nil, nil,
    self.colors.hp_bar_background)
  graphics.rectangle(10 + width * ratio / 2, 35, width * ratio, 6,
    nil, nil, color)
  graphics.set_color(self.colors.foreground)
  love.graphics.print(
    "HP: " .. math.ceil(player.hp) .. " / " .. player.max_hp, 10, 40)
end

function HUD:draw_failure()
  local message = self.game.arena.player.dead and
    "PLAYER DESTROYED" or "OUT OF AMMO"
  graphics.set_color(self.colors.foreground)
  love.graphics.printf(message, 0, gh / 2 - 20, gw, "center")
  love.graphics.printf("PRESS R TO RESTART", 0, gh / 2 + 4, gw, "center")
end

function HUD:draw_icon(x, y, color, alpha, size)
  size = size or 14
  graphics.rectangle(x + 1, y + 1, size, size, 3, 3,
    graphics.color_with_alpha(self.colors.hp_bar_background, alpha * 0.65))
  graphics.rectangle(x, y, size, size, 3, 3,
    graphics.color_with_alpha(color, alpha))
end
