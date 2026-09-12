function Player:perform_base_attack(aim_x, aim_y, projectiles, effects)
  if self.base_attack_cooldown_time > 0 then return end
  if #projectiles >= self.max_projectiles then return end
  if (aim_x - self.x) ^ 2 + (aim_y - self.y) ^ 2 <= 1 then return end

  local r = math.atan2(aim_y - self.y, aim_x - self.x)
  projectiles[#projectiles + 1] = Projectile{
    x = self.x,
    y = self.y,
    r = r,
    speed = self.base_projectile_speed,
    damage = self.base_projectile_damage,
    effects = effects,
  }
  self.base_attack_cooldown_time = self.base_attack_interval

  if projectile_attack_sound then
    projectile_attack_sound:stop()
    projectile_attack_sound:setPitch(0.95 + love.math.random() * 0.1)
    projectile_attack_sound:play()
  end
  return true
end

function Player:try_attack(aim_x, aim_y, enemies, projectiles, effects)
  if not aim_x or not aim_y then return end
  if self.ammo <= 0 then return end

  local hero = self:get_active_hero()
  if hero and not hero:can_attack() then return end

  self:set_aim_position(aim_x, aim_y)
  local fired
  if hero then
    fired = hero:attack(self, aim_x, aim_y, enemies, projectiles, effects)
  else
    fired = self:perform_base_attack(aim_x, aim_y, projectiles, effects)
  end
  if fired then self.ammo = self.ammo - 1 end
  return fired
end
