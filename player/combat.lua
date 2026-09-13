function Player:fire_bullet(aim_x, aim_y, projectiles, effects)
  if self.base_attack_cooldown_time > 0 then return end
  if #projectiles >= self.max_projectiles then return end
  if (aim_x - self.x) ^ 2 + (aim_y - self.y) ^ 2 <= 1 then return end

  local r = math.atan2(aim_y - self.y, aim_x - self.x)
  local bullet = self:ensure_current_bullet()
  local definition = self:get_bullet_definition(bullet)
  projectiles:add(Projectile{
    x = self.x,
    y = self.y,
    r = r,
    speed = self.base_projectile_speed,
    damage = self.base_projectile_damage,
    bullet = bullet,
    color = definition.color,
    pierce = definition.pierce,
    bounces = definition.bounces,
    effects = effects,
  })
  self.base_attack_cooldown_time = self.base_attack_interval

  if projectile_attack_sound then
    projectile_attack_sound:stop()
    projectile_attack_sound:setPitch(0.95 + love.math.random() * 0.1)
    projectile_attack_sound:play()
  end
  return true
end

function Player:try_attack(aim_x, aim_y, projectiles, effects)
  if not aim_x or not aim_y then return end
  local current_bullet = self:ensure_current_bullet()
  if self.bullets[current_bullet] <= 0 then return end

  local fired = self:fire_bullet(aim_x, aim_y, projectiles, effects)
  if fired then self:consume_current_bullet() end
  return fired
end
