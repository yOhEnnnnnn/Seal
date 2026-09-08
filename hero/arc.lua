local function next_target(source, enemies, hit, range)
  local target
  local nearest_distance = range * range
  for _, enemy in ipairs(enemies) do
    if not enemy.dead and not hit[enemy] then
      local distance = (enemy.x - source.x)^2 + (enemy.y - source.y)^2
      if distance <= nearest_distance then
        target = enemy
        nearest_distance = distance
      end
    end
  end
  return target
end

local function random_target(source, enemies, hit, range)
  local candidates = {}
  for _, enemy in ipairs(enemies) do
    if not enemy.dead and not hit[enemy] and
      (enemy.x - source.x)^2 + (enemy.y - source.y)^2 <= range^2 then
      candidates[#candidates + 1] = enemy
    end
  end
  if #candidates > 0 then
    return candidates[love.math.random(1, #candidates)]
  end
end

local function strike(source, enemy, effects, color, damage)
  effects[#effects + 1] = LightningArc{
    x = source.x, y = source.y, target_x = enemy.x, target_y = enemy.y, color = color,
  }
  enemy:hit(damage)
end

local function chain(player, target, enemies, effects, color,
    initial_damage, chain_damage, jumps, range)
  local hit = {[target] = true}
  local hit_count = 1
  strike(player, target, effects, color, initial_damage)
  local source = target

  for _ = 1, jumps do
    local enemy = next_target(source, enemies, hit, range)
    if not enemy then break end
    hit[enemy] = true
    strike(source, enemy, effects, color, chain_damage)
    source = enemy
    hit_count = hit_count + 1
  end
  return hit_count
end

Arc = Hero:extend()

function Arc:init(args)
  self.name = "ARC"
  self.attack_range = 160
  self.attack_interval = 1.0
  self.storm_interval = 2.0
  self.storm_origin_range = 88
  self.storm_chain_range = 128
  self.storm_chain_rounds = 4
  self.damage = 10
  self.chain_damage = 5
  self.chain_jumps = 2
  self.chain_range = 64
  Arc.super.init(self, args)
end

function Arc:get_attack_interval()
  if self.level >= 3 then return self.storm_interval end
  return self.attack_interval
end

function Arc:perform_attack(player, target, enemies, projectiles, effects)
  local damage_multiplier = self:get_level_damage_multiplier()
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
      strike(player, enemy, effects, self.color, self.damage * damage_multiplier)
    end

    local branches = roots
    for _ = 1, self.storm_chain_rounds do
      for index, source in ipairs(branches) do
        local enemy = random_target(source, enemies, hit, self.storm_chain_range)
        if enemy then
          hit[enemy] = true
          strike(source, enemy, effects, self.color,
            self.damage * damage_multiplier * 0.2)
          branches[index] = enemy
        end
      end
    end
    return true
  end

  chain(player, target, enemies, effects, self.color,
    self.damage * damage_multiplier,
    self.chain_damage * damage_multiplier,
    self.chain_jumps,
    self.chain_range)
  return true
end
