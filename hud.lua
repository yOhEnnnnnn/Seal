HUD = Object:extend()

function HUD:init(game)
  self.game = game
  self.ui_font = game.ui_font
  self.colors = game.colors
end

function HUD:draw()
  self:draw_time()
  self:draw_momentum()
  love.graphics.setFont(self.ui_font)
  if self.game.difficulty_level > 0 then
    graphics.set_color(self.colors.red)
    love.graphics.printf(
      "THREAT " .. self.game.difficulty_level,
      aw - 100, 24, 90, "right")
  end

  self:draw_health()
end

function HUD:draw_momentum()
  local player = self.game.arena.player
  local momentum = 0
  for _, projectile in ipairs(self.game.arena.projectiles) do
    momentum = math.max(momentum, projectile.momentum)
  end
  love.graphics.setFont(self.game.small_font)
  graphics.set_color({0, 240 / 255, 1, 1})
  local status = "BALLS " .. player.ball_count ..
    "  M " .. math.floor(momentum)
  if player.luck_state.level > 0 then
    local hits_required = math.max(Data.upgrades.luck_hits_min,
      Data.upgrades.luck_hits_base - player.luck_state.level)
    status = status .. "  LUCK " .. player.luck_state.hits ..
      "/" .. hits_required
  end
  love.graphics.printf(status, aw / 2 - 100, 10, 200, "center")
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

function HUD:draw_death_transition(progress)
  local radius = progress * Data.rules.death_transition_duration *
    Data.rules.death_wave_speed
  local alpha = math.max(0, 1 - progress * 1.35)
  for index = 0, 2 do
    local ring_radius = math.max(0, radius - index * 11)
    graphics.circle(aw / 2, ah / 2, ring_radius,
      {1, 1, 1, alpha * (0.34 - index * 0.08)}, 2 - index * 0.35)
  end
  graphics.circle(aw / 2, ah / 2, 8 + progress * 28,
    {1, 1, 1, math.max(0, 0.22 - progress * 0.3)})
end

function HUD:draw_revive(cost)
  graphics.rectangle(aw / 2, ah / 2, aw, ah, nil, nil,
    {0, 0, 0, 0.68})
  graphics.set_color(self.colors.foreground)
  love.graphics.printf("PLAYER DESTROYED", 0, ah / 2 - 42, aw, "center")
  love.graphics.printf("SCORE " .. self.game.score .. "  " ..
    self:format_time(), 0, ah / 2 - 18, aw, "center")
  local affordable = self.game.coins >= cost
  graphics.rectangle(aw / 2, Data.rules.revive_button_y,
    Data.rules.revive_button_width, Data.rules.revive_button_height, 2, 2,
    affordable and self.colors.background_light or self.colors.background)
  graphics.rectangle(aw / 2, Data.rules.revive_button_y,
    Data.rules.revive_button_width, Data.rules.revive_button_height, 2, 2,
    nil, affordable and self.colors.foreground or
      graphics.color_with_alpha(self.colors.foreground, 0.35), 1)
  graphics.set_color(affordable and self.colors.gold or
    graphics.color_with_alpha(self.colors.foreground, 0.4))
  love.graphics.printf(affordable and "REVIVE  $" .. cost or
    "R  RESTART", 0, Data.rules.revive_button_y - 6, aw, "center")
end
