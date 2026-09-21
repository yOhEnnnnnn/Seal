Player = Object:extend()
Player:implement(GameObject)
Player:implement(Physics)
Player:implement(Unit)

function Player:init(args)
  self:init_game_object(args)
  self:init_physics(args)
  self.max_hp = self.max_hp or Data.player.max_hp
  self:init_unit(args)
  self.size = self.size or Data.player.size
  self.color = Data.bullets.color
  self.camera = args.camera
  self.audio = args.audio
  self.base_projectile_speed = self.base_projectile_speed or Data.player.projectile_speed
  self.base_projectile_hit_power = self.base_projectile_hit_power or
    Data.player.projectile_hit_power
  self:apply_upgrades(args.upgrades or {})
  self.hit_color = self.hit_color or Data.theme.colors.foreground
  self.hit_duration = Data.player.hit_duration
  self.hit_time = 0
  self.invincibility_time = 0
  self.ready_flash_time = 0
  self:set_as_rectangle(self.size, self.size, "dynamic", "player")
end

function Player:apply_upgrades(upgrades)
  local previous_ball_count = self.ball_count or Data.player.base_ball_count
  self.base_projectile_hit_power = Data.player.projectile_hit_power +
    (upgrades.hit_power or 0) * Data.upgrades.hit_power_per_level
  self.base_projectile_speed = Data.player.projectile_speed *
    (1 + (upgrades.ball_speed or 0) *
      Data.upgrades.ball_speed_bonus_per_level)
  self.ball_count = Data.player.base_ball_count + (upgrades.ball_count or 0)
  if self.balls_loaded == nil then
    self.balls_loaded = self.ball_count
  elseif self.ball_count > previous_ball_count then
    self.balls_loaded = self.balls_loaded +
      self.ball_count - previous_ball_count
  end
end

function Player:spawn_ball(r, projectiles, effects)
  local projectile = projectiles:add(Projectile{
    x = self.x,
    y = self.y,
    r = r,
    speed = self.base_projectile_speed,
    effects = effects,
    audio = self.audio,
    arena_width = aw,
    arena_height = ah,
    on_bounce = self.on_projectile_bounce,
  })
  self:apply_projectile_upgrades(projectile)
  return projectile
end

function Player:apply_projectile_upgrades(projectile)
  projectile.base_speed = self.base_projectile_speed
  projectile.base_hit_power = self.base_projectile_hit_power
  projectile:update_momentum_stats()
end

function Player:update(dt)
  self.x, self.y = aw / 2, ah / 2
  self:stop()
  self.hit_time = math.max(self.hit_time - dt, 0)
  self.invincibility_time = math.max(self.invincibility_time - dt, 0)
  self.ready_flash_time = math.max(self.ready_flash_time - dt, 0)
end

function Player:on_volley_ready()
  self.balls_loaded = self.ball_count
  self.ready_flash_time = Data.player.ready_flash_duration
  if self.audio then self.audio:play("volley_ready") end
end

function Player:hit(damage)
  if self.dead or self.invincibility_time > 0 then return end
  self.hit_time = self.hit_duration
  self.hp = 0
  self:die()
  if self.audio then self.audio:play("player_hit") end
  if self.camera then self.camera:spring_shake(Data.player.hit_shake, 0) end
end

function Player:fire_bullet(aim_x, aim_y, projectiles, effects)
  if self.balls_loaded <= 0 then return end
  if (aim_x - self.x) ^ 2 + (aim_y - self.y) ^ 2 <= 1 then return end

  local r = math.atan2(aim_y - self.y, aim_x - self.x)
  self:spawn_ball(r, projectiles, effects)
  self.balls_loaded = self.balls_loaded - 1

  if self.audio then self.audio:play("attack") end
  return true, r
end

function Player:try_attack(aim_x, aim_y, projectiles, effects)
  if not aim_x or not aim_y then return end
  local fired, angle = self:fire_bullet(aim_x, aim_y, projectiles, effects)
  if fired then
    if self.camera then self.camera:spring_shake(Data.player.attack_shake, angle) end
  end
  return fired
end

function Player:draw_rounded_square(x, y, size, color)
  graphics.rectangle(x, y, size, size - 2, nil, nil, color)
  graphics.rectangle(x, y, size - 2, size, nil, nil, color)
end

function Player:draw()
  love.graphics.push("all")
  love.graphics.translate(self.x, self.y)
  if self.revive_progress then
    local reform = math.min(self.revive_progress *
      Data.rules.revive_transition_duration /
      Data.rules.revive_reform_duration, 1)
    local eased = 1 - (1 - reform) ^ 3
    love.graphics.rotate((1 - eased) * -0.8)
    love.graphics.scale(eased, eased)
  end
  if self.invincibility_time > 0 then
    love.graphics.setColor(1, 1, 1,
      0.45 + 0.35 * math.abs(math.sin(self.invincibility_time * 14)))
  end
  self:draw_rounded_square(0, 0, self.size,
    self.hit_time > 0 and self.hit_color or self.color)
  if self.ready_flash_time > 0 then
    local progress = 1 - self.ready_flash_time /
      Data.player.ready_flash_duration
    graphics.circle(0, 0, self.size + progress * 10,
      graphics.color_with_alpha(
        Data.theme.colors.foreground, 1 - progress), 1.5)
  end
  love.graphics.pop()
end
