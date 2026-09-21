HUD = Object:extend()

function HUD:init(game)
  self.game = game
  self.ui_font = game.ui_font
  self.colors = game.colors
end

function HUD:draw()
  self:draw_header()
  self:draw_combat_status()
  if self.game.difficulty_level > 0 then
    love.graphics.setFont(self.game.small_font)
    graphics.set_color(self.colors.red)
    love.graphics.printf(
      "THREAT " .. self.game.difficulty_level,
      aw - 90, 29, 80, "right")
  end
end

function HUD:draw_header()
  love.graphics.setFont(self.ui_font)
  graphics.set_color(self.colors.foreground)
  love.graphics.print("STAR", 9, 6)

  love.graphics.setFont(self.game.small_font)
  graphics.set_color(self.colors.muted)
  love.graphics.printf("SCORE " .. string.format("%06d", self.game.score),
    aw - 118, 8, 108, "right")
  love.graphics.printf(self:format_time(), aw - 64, 19, 54, "right")
end

function HUD:get_total_momentum()
  local momentum = 0
  for _, projectile in ipairs(self.game.arena.projectiles) do
    momentum = momentum + projectile.momentum
  end
  return math.floor(momentum)
end

function HUD:draw_ammo(player)
  love.graphics.setFont(self.game.small_font)
  graphics.set_color(self.colors.muted)
  love.graphics.print("AMMO", 10, gh - 17)

  local active = #self.game.arena.projectiles
  for index = 1, player.ball_count do
    local color
    if index <= player.balls_loaded then
      color = self.colors.foreground
    elseif index <= player.balls_loaded + active then
      color = self.colors.accent
    else
      color = graphics.color_with_alpha(self.colors.muted, 0.28)
    end
    graphics.circle(45 + (index - 1) * 7, gh - 13, 2.2, color)
  end
end

function HUD:draw_combat_status()
  local player = self.game.arena.player
  graphics.rectangle(aw / 2, gh - 10, aw, 20, nil, nil,
    graphics.color_with_alpha(self.colors.background_dark, 0.74))
  graphics.line(0, gh - 20, aw, gh - 20, self.colors.border, 1)
  self:draw_ammo(player)

  love.graphics.setFont(self.game.small_font)
  local charge = self.game.arena.shockwave_charge
  local required = Data.player.shockwave_charge_required
  local shockwave_ready = self.game.arena:is_shockwave_ready()
  graphics.set_color(shockwave_ready and self.colors.gold or self.colors.muted)
  love.graphics.printf(shockwave_ready and "Q READY" or
    "Q " .. charge .. "/" .. required,
    128, gh - 17, 58, "center")

  graphics.set_color(self.colors.accent)
  love.graphics.printf("NOVA " .. self:get_total_momentum(),
    190, gh - 17, 70, "center")

  local status
  if #self.game.arena.projectiles == 0 then
    status = "READY"
  else
    status = "SPACE  NOVA"
  end
  graphics.set_color(#self.game.arena.projectiles == 0 and
    self.colors.muted or self.colors.foreground)
  love.graphics.printf(status, 270, gh - 17, aw - 280, "right")
end

function HUD:format_time()
  local minutes = math.floor(self.game.elapsed_time / 60)
  local seconds = math.floor(self.game.elapsed_time % 60)
  return string.format("%02d:%02d", minutes, seconds)
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
      graphics.color_with_alpha(
        self.colors.accent, 0.7 * (1 - pull_eased)), 1.5)
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
  love.graphics.printf("STAR COLLAPSED", 0, ah / 2 - 42, aw, "center")
  love.graphics.setFont(self.game.small_font)
  graphics.set_color(self.colors.muted)
  love.graphics.printf("SCORE " .. string.format("%06d", self.game.score) ..
    "   TIME " .. self:format_time(), 0, ah / 2 - 16, aw, "center")
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
  love.graphics.printf(affordable and "REVIVE  " .. cost .. " DUST" or
    "R  NEW STAR", 0, Data.rules.revive_button_y - 4, aw, "center")
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
      graphics.color_with_alpha(self.colors.accent, flash * 0.2))
  end
end
