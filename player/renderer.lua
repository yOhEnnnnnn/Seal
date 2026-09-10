function Player:get_draw_size()
  if not self.switching then return self.size end

  if self.switch_time <= self.switch_shrink_end then
    return math.floor(self.size - 2 * self.switch_time / self.switch_shrink_end + 0.5)
  end

  if self.switch_time <= self.switch_pop_end then
    return math.floor(self.size - 2 + 3 *
      (self.switch_time - self.switch_shrink_end) /
      (self.switch_pop_end - self.switch_shrink_end) + 0.5)
  end

  return math.floor(self.size + 1 -
    (self.switch_time - self.switch_pop_end) /
    (self.switch_duration - self.switch_pop_end) + 0.5)
end

function Player:draw_rounded_square(x, y, size, color)
  graphics.rectangle(x, y, size, size - 2, nil, nil, color)
  graphics.rectangle(x, y, size - 2, size, nil, nil, color)
end

function Player:get_dash_scale()
  if not self.dashing then return 1, 1 end

  if self.dash_time < self.dash_windup then
    local progress = self.dash_time / self.dash_windup
    return 1 - 0.35 * progress, 1 + 0.15 * progress
  end

  if self.dash_time < self.dash_windup + self.dash_travel then
    local progress = self:get_dash_travel_progress()
    local stretch = math.sin(progress * math.pi)
    return 0.65 + 0.35 * progress + 0.9 * stretch,
      1.15 - 0.15 * progress - 0.55 * stretch
  end

  local progress = (self.dash_time - self.dash_windup - self.dash_travel) / self.dash_land
  local pop = math.sin(progress * math.pi)
  return 1 + 0.2 * pop, 1 + 0.2 * pop
end

function Player:draw_core(size)
  local sx, sy = self:get_dash_scale()
  love.graphics.push("all")
  love.graphics.translate(self.x, self.y)
  if self.dashing then love.graphics.rotate(self.aim_r) end
  love.graphics.scale(sx, sy)
  self:draw_rounded_square(1, 1, size, self.shadow_color)
  self:draw_rounded_square(0, 0, size, self:get_color())
  love.graphics.pop()
end

function Player:draw_dash_trail(size)
  if not self.dashing or self.dash_time <= self.dash_windup then return end

  local progress = self:get_dash_travel_progress()
  local land_progress = math.max(0, (self.dash_time - self.dash_windup - self.dash_travel) / self.dash_land)
  local fade = 1 - math.min(land_progress, 1)

  for index = 1, 2 do
    local trail_progress = math.max(progress - index * 0.14, 0)
    trail_progress = 1 - (1 - trail_progress) ^ 3
    local x = self.dash_start_x + (self.dash_target_x - self.dash_start_x) * trail_progress
    local y = self.dash_start_y + (self.dash_target_y - self.dash_start_y) * trail_progress

    love.graphics.push("all")
    love.graphics.translate(x, y)
    love.graphics.rotate(self.aim_r)
    love.graphics.scale(1.25, 0.6)
    self:draw_rounded_square(0, 0, size,
      graphics.color_with_alpha(self:get_color(), 0.18 * fade / index))
    love.graphics.pop()
  end
end

function Player:draw_aim_arrow()
  if not self:get_active_hero() then return end
  if self.dashing then return end
  local scale = 1 - 0.35 * self.dash_cooldown_time / self.dash_cooldown
  local x = self.x + math.cos(self.aim_r) * self.arrow_distance
  local y = self.y + math.sin(self.aim_r) * self.arrow_distance

  love.graphics.push("all")
  love.graphics.translate(x, y)
  love.graphics.rotate(self.aim_r)
  love.graphics.scale(scale, scale)
  graphics.polygon({4, 0, -3, -3, -1, 0, -3, 3}, self:get_color())
  love.graphics.pop()
end

function Player:draw()
  local size = self:get_draw_size()
  self:draw_dash_trail(size)
  self:draw_core(size)
  self:draw_aim_arrow()
end
