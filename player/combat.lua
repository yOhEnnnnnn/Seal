function Player:get_attack_target(enemies)
  local hero = self:get_active_hero()
  local attack_range = hero and hero.attack_range or self.base_attack_range

  local target
  local target_priority
  local nearest_distance = attack_range * attack_range
  for _, enemy in ipairs(enemies) do
    if not enemy.dead then
      local dx, dy = enemy.x - self.x, enemy.y - self.y
      local distance = dx * dx + dy * dy
      local priority = hero and hero:get_target_priority(enemy, enemies) or 0
      if distance <= attack_range * attack_range and
        (target_priority == nil or priority > target_priority or
          priority == target_priority and distance <= nearest_distance) then
        target = enemy
        target_priority = priority
        nearest_distance = distance
      end
    end
  end
  return target
end

function Player:perform_base_attack(target, projectiles, effects)
  if self.base_attack_cooldown_time > 0 then return end
  if #projectiles >= self.max_projectiles then return end

  local r = math.atan2(target.y - self.y, target.x - self.x)
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

function Player:update_attack(enemies, projectiles, effects)
  local hero = self:get_active_hero()
  if hero and not hero:can_attack() then return end

  local target = self:get_attack_target(enemies)
  if not target then return end
  self.aim_r = math.atan2(target.y - self.y, target.x - self.x)
  if hero then
    hero:attack(self, target, enemies, projectiles, effects)
  else
    self:perform_base_attack(target, projectiles, effects)
  end
end
