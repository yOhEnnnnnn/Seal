function Player:get_attack_target(enemies)
  local hero = self:get_active_hero()
  if not hero then return end

  local target
  local target_priority
  local nearest_distance = hero.attack_range * hero.attack_range
  for _, enemy in ipairs(enemies) do
    if not enemy.dead then
      local dx, dy = enemy.x - self.x, enemy.y - self.y
      local distance = dx * dx + dy * dy
      local priority = hero:get_target_priority(enemy, enemies)
      if distance <= hero.attack_range * hero.attack_range and
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

function Player:update_attack(enemies, projectiles, effects)
  local hero = self:get_active_hero()
  if not hero or not hero:can_attack() then return end

  local target = self:get_attack_target(enemies)
  if not target then return end
  hero:attack(self, target, enemies, projectiles, effects)
end
