HUD = Object:extend()

function HUD:init(game)
  self.game = game
  self.ui_font = game.ui_font
  self.colors = game.colors
end

function HUD:draw()
  self:draw_time()
  if self.game.difficulty_level > 0 then
    graphics.set_color(self.colors.red)
    love.graphics.printf(
      "THREAT " .. self.game.difficulty_level,
      aw - 100, 24, 90, "right")
  end

  self:draw_health()
end

function HUD:format_time()
  local minutes = math.floor(self.game.elapsed_time / 60)
  local seconds = math.floor(self.game.elapsed_time % 60)
  return string.format("%02d:%02d", minutes, seconds)
end

function HUD:draw_time()
  love.graphics.setFont(self.ui_font)
  graphics.set_color(self.colors.foreground)
  love.graphics.printf(self:format_time(), aw - 76, 8, 66, "right")
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
  love.graphics.printf("PLAYER DESTROYED", 0, ah / 2 - 28, aw, "center")
  love.graphics.printf("SCORE " .. self.game.score .. "  " ..
    self:format_time(), 0, ah / 2 - 4, aw, "center")
  love.graphics.printf("PRESS R TO RESTART", 0, ah / 2 + 20, aw, "center")
end
