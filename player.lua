Player = Object:extend()
Player:implement(GameObject)
Player:implement(Physics)
Player:implement(Unit)

function Player:init(args)
  self:init_game_object(args)
  self:init_physics(args)
  self:init_unit(args)
  self.size = self.size or 7
  self.shadow_color = self.shadow_color or {0, 0, 0, 0.35}
  self.max_projectiles = self.max_projectiles or 64
  self.inventory = assert(args.inventory, "Player requires an ammo inventory")
  self.current_bullet = self.inventory:get_current()
  self.color = Bullets[self.current_bullet].color
  self.switch_duration, self.switch_time = 0.22, 0
  self.camera = args.camera
  self.base_attack_interval = self.base_attack_interval or 0.10
  self.base_attack_cooldown_time = 0
  self.base_projectile_speed = self.base_projectile_speed or 160
  self.base_projectile_damage = self.base_projectile_damage or 10
  self.hit_color = self.hit_color or {1, 1, 1, 1}
  self.hit_duration = 0.12
  self.hit_time = 0
  self:set_as_rectangle(self.size, self.size, "dynamic", "player")
end

function Player:update(dt)
  self.x, self.y = gw / 2, gh / 2
  self:stop()
  self.switch_time = math.max(self.switch_time - dt, 0)
  self:sync_bullet_visuals()
  self.hit_time = math.max(self.hit_time - dt, 0)
  self.base_attack_cooldown_time = math.max(
    self.base_attack_cooldown_time - dt, 0)
end

function Player:sync_bullet_visuals()
  local bullet = self.inventory:get_current()
  if bullet == self.current_bullet then return end
  self.current_bullet = bullet
  self.color = Bullets[bullet].color
  self.switch_time = self.switch_duration
end

function Player:get_switch_scale()
  if self.switch_time == 0 then return 1 end
  local progress = 1 - self.switch_time / self.switch_duration
  if progress < 0.25 then return 1 - progress end
  if progress < 0.6 then return 0.75 + (progress - 0.25) / 0.35 * 0.4 end
  return 1 + 0.15 * (1 - (progress - 0.6) / 0.4) ^ 2
end

function Player:hit(damage)
  if self.dead then return end
  self.hit_time = self.hit_duration
  Unit.hit(self, damage)
  if self.camera then self.camera:spring_shake(4, 0) end
end

function Player:fire_bullet(aim_x, aim_y, projectiles, effects)
  if self.base_attack_cooldown_time > 0 then return end
  if #projectiles >= self.max_projectiles then return end
  if (aim_x - self.x) ^ 2 + (aim_y - self.y) ^ 2 <= 1 then return end

  local r = math.atan2(aim_y - self.y, aim_x - self.x)
  local bullet = self.inventory:ensure_current()
  projectiles:add(Projectile{
    x = self.x,
    y = self.y,
    r = r,
    speed = self.base_projectile_speed,
    damage = self.base_projectile_damage,
    bullet = bullet,
    score_operation = self.inventory.scoring[bullet].operation,
    score_value = self.inventory.scoring[bullet].value,
    effects = effects,
  })
  self.base_attack_cooldown_time = self.base_attack_interval

  if projectile_attack_sound then
    projectile_attack_sound:stop()
    projectile_attack_sound:setPitch(0.95 + love.math.random() * 0.1)
    projectile_attack_sound:play()
  end
  return true, r
end

function Player:place_bullet(aim_x, aim_y, effects, bullet)
  if self.base_attack_cooldown_time > 0 then return end
  local definition = Bullets[bullet]
  local scoring = self.inventory.scoring[bullet]
  local r = math.atan2(aim_y - self.y, aim_x - self.x)
  definition.place{
    x = aim_x,
    y = aim_y,
    bullet = bullet,
    color = definition.color,
    score_operation = scoring.operation,
    score_value = scoring.value,
    damage = self.base_projectile_damage,
    effects = effects,
  }
  self.base_attack_cooldown_time = self.base_attack_interval
  return true, r
end

function Player:try_attack(aim_x, aim_y, projectiles, effects)
  if not aim_x or not aim_y then return end
  local current_bullet = self.inventory:ensure_current()
  if self.inventory.counts[current_bullet] <= 0 then return end

  local definition = Bullets[current_bullet]
  local fired, angle
  if definition.place then
    fired, angle = self:place_bullet(aim_x, aim_y, effects, current_bullet)
  else
    fired, angle = self:fire_bullet(aim_x, aim_y, projectiles, effects)
  end
  if fired then
    self.inventory:consume()
    self:sync_bullet_visuals()
    if self.camera then self.camera:spring_shake(2, angle) end
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
  local scale = self:get_switch_scale()
  love.graphics.scale(scale, scale)
  self:draw_rounded_square(1, 1, self.size, self.shadow_color)
  self:draw_rounded_square(0, 0, self.size,
    self.hit_time > 0 and self.hit_color or self.color)
  love.graphics.pop()
end
