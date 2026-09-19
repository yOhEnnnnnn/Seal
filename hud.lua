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

function HUD:get_death_tile_scale(progress, order)
  local covering = progress < 0.52
  local phase = covering and
    math.max(0, math.min((progress - 0.04) / 0.44, 1)) or
    math.max(0, math.min((progress - 0.56) / 0.44, 1))
  local amount = math.max(0, math.min((phase - order * 0.72) / 0.28, 1))
  local eased = amount * amount * (3 - 2 * amount)
  return covering and eased or 1 - eased
end

function HUD:draw_death_transition(progress)
  local size = 20
  local columns = math.ceil(gw / size)
  local rows = math.ceil(gh / size)
  for row = 1, rows do
    for column = 1, columns do
      local diagonal = ((column - 1) / (columns - 1) +
        (rows - row) / (rows - 1)) / 2
      local scale = self:get_death_tile_scale(progress, diagonal)
      if scale > 0 then
        local x = (column - 0.5) * size
        local y = (row - 0.5) * size
        graphics.rectangle(x, y, (size + 1) * scale, (size + 1) * scale,
          nil, nil, self.colors.enemy)
      end
    end
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
