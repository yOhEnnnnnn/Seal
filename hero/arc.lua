local function next_target(source, enemies, hit, range)
  local candidates = {}
  for _, enemy in ipairs(enemies) do
    if not enemy.dead and not hit[enemy] and
      (enemy.x - source.x)^2 + (enemy.y - source.y)^2 <= range^2 then
      candidates[#candidates + 1] = enemy
    end
  end
  if #candidates > 0 then return candidates[love.math.random(1, #candidates)] end
end

local function strike(source, enemy, effects, color, damage)
  effects[#effects + 1] = LightningArc{
    x = source.x, y = source.y, target_x = enemy.x, target_y = enemy.y, color = color,
  }
  enemy:hit(damage)
end

local function chain(source, enemies, effects, color, damage, jumps, range)
  local hit = {[source] = true}
  for _ = 1, jumps do
    local enemy = next_target(source, enemies, hit, range)
    if not enemy then break end
    hit[enemy] = true
    strike(source, enemy, effects, color, damage * 0.2)
    source = enemy
  end
end

Arc = Hero:extend()

function Arc:init(args)
  self.name = "ARC"
  self.attack_range = 160
  self.attack_interval = 1.0
  self.storm_interval = 2.0
  self.storm_origin_range = 88
  self.storm_chain_range = 128
  self.damage = 10
  Arc.super.init(self, args)
end

function Arc:get_attack_interval()
  if self.level >= 3 then return self.storm_interval end
  return self.attack_interval
end

function Arc:perform_attack(player, target, enemies, projectiles, effects)
  if self.level >= 3 then
    local roots = {}
    local hit = {}
    for _, enemy in ipairs(enemies) do
      if not enemy.dead and
        (enemy.x - player.x)^2 + (enemy.y - player.y)^2 <= self.storm_origin_range^2 then
        roots[#roots + 1] = enemy
        hit[enemy] = true
      end
    end
    if #roots == 0 then return false end

    for _, enemy in ipairs(roots) do
      strike(player, enemy, effects, self.color, self.damage)
    end

    local branches = roots
    for _ = 1, 4 do
      for index, source in ipairs(branches) do
        local enemy = next_target(source, enemies, hit, self.storm_chain_range)
        if enemy then
          hit[enemy] = true
          strike(source, enemy, effects, self.color, self.damage * 0.2)
          branches[index] = enemy
        end
      end
    end
    return true
  end
  if #projectiles >= player.max_projectiles then return false end
  local on_hit
  if self.level >= 2 then
    local color = self.color
    on_hit = function(projectile, enemy, current_enemies)
      chain(enemy, current_enemies, projectile.effects, color, projectile.damage, 2, 64)
    end
  end
  projectiles[#projectiles + 1] = Projectile{
    x = player.x, y = player.y,
    r = math.atan2(target.y - player.y, target.x - player.x),
    damage = self.damage, color = self.color, effects = effects, on_hit = on_hit,
  }
  return true
end
