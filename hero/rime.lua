Rime = Hero:extend()

function Rime:init(args)
  self.name = "RIME"
  self.attack_range = 176
  self.attack_interval = 0.65
  self.projectile_speed = 190
  self.projectile_damage = 7
  self.slow_multiplier = 0.45
  self.slow_duration = 1.6
  self.frost_area_interval = 5.5
  self.frost_area_radius = 64
  self.frost_area_duration = 4.0
  self.frost_area_damage = 5
  self.frost_area_slow_multiplier = 0.4
  Rime.super.init(self, args)
end

function Rime:get_attack_interval()
  if self.level >= 3 then return self.frost_area_interval end
  return self.attack_interval
end

function Rime:get_target_priority(enemy)
  if not enemy:is_slowed() and enemy.enemy_type == "rusher" then return 3 end
  if not enemy:is_slowed() then return 2 end
  if enemy.enemy_type == "rusher" then return 1 end
  return 0
end

function Rime:find_secondary_target(player, primary_target, enemies)
  local target
  local target_priority
  local nearest_distance = self.attack_range * self.attack_range

  for _, enemy in ipairs(enemies) do
    if not enemy.dead and enemy ~= primary_target then
      local dx, dy = enemy.x - player.x, enemy.y - player.y
      local distance = dx * dx + dy * dy
      local priority = self:get_target_priority(enemy)
      if distance <= self.attack_range * self.attack_range and
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

function Rime:fire_needle(player, target, projectiles, damage)
  if #projectiles >= player.max_projectiles then return false end

  projectiles[#projectiles + 1] = Projectile{
    x = player.x,
    y = player.y,
    r = math.atan2(target.y - player.y, target.x - player.x),
    speed = self.projectile_speed,
    damage = damage,
    width = 7,
    height = 2,
    color = self.color,
    slow_multiplier = self.slow_multiplier,
    slow_duration = self.slow_duration,
  }
  return true
end

function Rime:perform_attack(player, target, enemies, projectiles, effects)
  if self.level >= 3 then
    effects[#effects + 1] = FrostCircleArea{
      x = target.x,
      y = target.y,
      radius = self.frost_area_radius,
      duration = self.frost_area_duration,
      damage = self.frost_area_damage,
      slow_multiplier = self.frost_area_slow_multiplier,
      color = self.color,
    }
    return true
  end

  if not self:fire_needle(player, target, projectiles, self.projectile_damage) then
    return false
  end

  if self.level >= 2 then
    local secondary_target = self:find_secondary_target(player, target, enemies)
    if secondary_target then
      self:fire_needle(player, secondary_target, projectiles,
        self.projectile_damage * 0.5)
    end
  end
  return true
end
