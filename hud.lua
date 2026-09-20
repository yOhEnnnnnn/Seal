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
  if #self.game.arena.projectiles == 0 then
    status = status .. "  READY"
  else
    local total_momentum = self.game.arena:get_convergence_stats()
    status = status .. "  FOCUS " .. math.floor(total_momentum)
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
  local hit_stop_ratio = Data.rules.death_hit_stop /
    Data.rules.death_transition_duration
  local hit_flash = math.max(0, 1 - progress / hit_stop_ratio)
  local motion_progress = math.max(0,
    (progress - hit_stop_ratio) / (1 - hit_stop_ratio))
  local pull = math.max(0, math.min(
    motion_progress / Data.rules.death_pull_end, 1))
  local pull_eased = pull * pull * (3 - 2 * pull)
  if motion_progress < Data.rules.death_pull_end then
    local size = Data.player.size * (1 - pull_eased)
    graphics.rectangle(aw / 2, ah / 2, size, size,
      nil, nil, {1, 1, 1, 1 - pull_eased})
    graphics.circle(aw / 2, ah / 2, 12 - pull_eased * 8,
      {0, 240 / 255, 1, 0.7 * (1 - pull_eased)}, 1.5)
  else
    local burst = math.max(0, math.min(
      (motion_progress - Data.rules.death_pull_end) /
        (Data.rules.death_wave_duration + Data.rules.death_wave_delay), 1))
    local eased = 1 - (1 - burst) ^ 3
    local radius = eased * aw / 2
    for index = 0, 2 do
      graphics.circle(aw / 2, ah / 2,
        math.max(0, radius - index * 13),
        {1, 1, 1, (1 - burst) * (0.5 - index * 0.12)},
        2 - index * 0.4)
    end
  end

  if progress > Data.rules.death_result_start then
    local fade = math.min((progress - Data.rules.death_result_start) /
      (1 - Data.rules.death_result_start), 1)
    graphics.rectangle(aw / 2, ah / 2, aw, ah, nil, nil,
      {0, 0, 0, fade * 0.28})
  end

  local burst_flash = math.max(0, 1 - math.abs(
    motion_progress - Data.rules.death_pull_end) / 0.055)
  local flash = math.max(hit_flash * 0.72, burst_flash * 0.48)
  if flash > 0 then
    graphics.rectangle(aw / 2, ah / 2, aw, ah, nil, nil,
      {1, 1, 1, flash})
  end
end

function HUD:draw_revive(cost)
  love.graphics.push("all")
  graphics.rectangle(aw / 2, ah / 2, aw, ah, nil, nil,
    {0, 0, 0, 0.62})
  love.graphics.setFont(self.ui_font)
  graphics.set_color(self.colors.foreground)
  love.graphics.printf("YOU DIED...", 0, ah / 2 - 42, aw, "center")
  love.graphics.printf("SCORE " .. self.game.score .. "  " ..
    self:format_time(), 0, ah / 2 - 18, aw, "center")
  local affordable = self.game.coins >= cost
  graphics.rectangle(aw / 2, Data.rules.revive_button_y,
    Data.rules.revive_button_width, Data.rules.revive_button_height, 2, 2,
    affordable and self.colors.background_light or self.colors.background)
  graphics.rectangle(aw / 2, Data.rules.revive_button_y,
    Data.rules.revive_button_width, Data.rules.revive_button_height, 2, 2,
    affordable and self.colors.foreground or
      graphics.color_with_alpha(self.colors.foreground, 0.35), 1)
  graphics.set_color(affordable and self.colors.gold or
    graphics.color_with_alpha(self.colors.foreground, 0.4))
  love.graphics.printf(affordable and "REVIVE  $" .. cost or
    "R  RESTART", 0, Data.rules.revive_button_y - 6, aw, "center")
  love.graphics.pop()
end

function HUD:draw_revive_transition(progress)
  local fade = 1 - math.min(progress * 2.5, 1)
  if fade > 0 then
    graphics.rectangle(aw / 2, ah / 2, aw, ah, nil, nil,
      {0, 0, 0, fade * 0.62})
  end
  local flash = math.max(0, 1 - math.abs(progress - 0.12) / 0.08)
  if flash > 0 then
    graphics.rectangle(aw / 2, ah / 2, aw, ah, nil, nil,
      {0, 240 / 255, 1, flash * 0.2})
  end
end
