Shard = Hero:extend()

function Shard:init(args)
  self.name = "SHARD"
  self.attack_range = 160
  self.attack_interval = 1.2
  self.projectile_speed = 160
  self.projectile_damage = 8
  self.fragment_count = 6
  self.fragment_speed = 190
  self.fragment_damage = 3
  self.fragment_lifetime = 0.65
  self.cluster_range = 48
  Shard.super.init(self, args)
end

function Shard:get_target_priority(enemy, enemies)
  local nearby = 0
  for _, other in ipairs(enemies or {}) do
    if other ~= enemy and not other.dead and
      (other.x - enemy.x)^2 + (other.y - enemy.y)^2 <= self.cluster_range^2 then
      nearby = nearby + 1
    end
  end
  return nearby
end

function Shard:scatter(source, enemy, projectiles, max_projectiles,
    damage_multiplier, fragment_pierce)
  local rotation = love.math.random() * math.pi * 2
  for index = 1, self.fragment_count do
    if #projectiles >= max_projectiles then break end
    local r = rotation + (index - 1) * math.pi * 2 / self.fragment_count
    local spawn_distance = (enemy.width or 6) / 2 + 6
    projectiles[#projectiles + 1] = Projectile{
      x = source.x + math.cos(r) * spawn_distance,
      y = source.y + math.sin(r) * spawn_distance,
      r = r,
      speed = self.fragment_speed,
      damage = self.fragment_damage * damage_multiplier,
      color = self.color,
      pierce = fragment_pierce,
      lifetime = self.fragment_lifetime,
      hit_enemies = {[enemy] = true},
    }
  end
end

function Shard:perform_attack(player, target, enemies, projectiles)
  if #projectiles >= player.max_projectiles then return false end

  local damage_multiplier = self:get_level_damage_multiplier()
  local fragment_pierce = self.level >= 3 and 1 or 0
  projectiles[#projectiles + 1] = Projectile{
    x = player.x,
    y = player.y,
    r = math.atan2(target.y - player.y, target.x - player.x),
    speed = self.projectile_speed,
    damage = self.projectile_damage * damage_multiplier,
    color = self.color,
    owner = self,
    on_hit = function(source, enemy)
      self:scatter(source, enemy, projectiles, player.max_projectiles,
        damage_multiplier, fragment_pierce)
    end,
  }
  self:play_projectile_attack_sound()
  return true
end
