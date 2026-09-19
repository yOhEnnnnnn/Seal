HUD = Object:extend()

function HUD:init(game)
  self.game = game
  self.ui_font = game.ui_font
  self.colors = game.colors
  self.combo_canvas = love.graphics.newCanvas(160, 48, {msaa = 0})
  self.combo_canvas:setFilter("nearest", "nearest")
  self.combo_flame_shader = love.graphics.newShader(
    "assets/shaders/combo_flame.frag")
end

function HUD:draw()
  self:draw_combo()
  if self.game.danger_level > 0 then
    graphics.set_color(self.colors.red)
    love.graphics.printf(
      "DANGER " .. self.game.danger_level,
      0, 27, aw, "center")
  end

  self:draw_health()
  if self.game.can_extract then
    graphics.set_color(self.colors.foreground)
    love.graphics.printf(
      self.game.level == #levels and
        "TARGET REACHED - PRESS P TO COMPLETE RUN" or
        "TARGET REACHED - PRESS P FOR NEXT LEVEL",
      0, ah - 25, aw, "center")
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

  local x, y = (aw - 160) / 2, -6
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
  love.graphics.translate(aw / 2, 18)
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
  graphics.set_color(self.colors.foreground)
  love.graphics.printf("PLAYER DESTROYED", 0, ah / 2 - 20, aw, "center")
  love.graphics.printf("PRESS R TO RESTART", 0, ah / 2 + 4, aw, "center")
end
