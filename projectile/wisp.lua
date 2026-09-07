WispProjectile = Projectile:extend()

function WispProjectile:init(args)
  WispProjectile.super.init(self, args)
  self.target = args.target
  self.owner = args.owner
  self.chain_range = self.chain_range or 72
  self.remaining_chains = self.remaining_chains or 0
  self.speed_growth = self.speed_growth or 1
  self.turn_rate = self.turn_rate or 12 * math.pi
  self.lifetime = self.lifetime or 4
  self.lifetime_time = 0
end

function WispProjectile:find_target(enemies, x, y)
  local target
  local lowest_hp = math.huge
  local nearest_distance = self.chain_range * self.chain_range

  for _, enemy in ipairs(enemies or {}) do
    if not enemy.dead and not self.hit_enemies[enemy] then
      local dx, dy = enemy.x - x, enemy.y - y
      local distance = dx * dx + dy * dy
      if distance <= self.chain_range * self.chain_range and
        (enemy.hp < lowest_hp or
          enemy.hp == lowest_hp and distance < nearest_distance) then
        target = enemy
        lowest_hp = enemy.hp
        nearest_distance = distance
      end
    end
  end
  return target
end

function WispProjectile:set_target(target)
  self.target = target
  if not target then return end
  self.r = math.atan2(target.y - self.y, target.x - self.x)
  self:set_velocity(self.speed * math.cos(self.r), self.speed * math.sin(self.r))
end

function WispProjectile:update_direction(dt, enemies)
  if not self.target or self.target.dead or self.hit_enemies[self.target] then
    self:set_target(self:find_target(enemies, self.x, self.y))
  end
  if not self.target then
    self.dead = true
    return
  end

  local target_r = math.atan2(self.target.y - self.y, self.target.x - self.x)
  local difference = (target_r - self.r + math.pi) % (2 * math.pi) - math.pi
  local turn = self.turn_rate * dt
  self.r = self.r + math.max(-turn, math.min(difference, turn))
  self:set_velocity(self.speed * math.cos(self.r), self.speed * math.sin(self.r))
end

function WispProjectile:update(dt, enemies)
  self.lifetime_time = self.lifetime_time + dt
  if self.lifetime_time >= self.lifetime then
    self.dead = true
    return
  end

  self:update_direction(dt, enemies)
  if self.dead then return end
  self:update_game_object(dt)
  self:check_hits(enemies)
  self:check_bounds()
end

function WispProjectile:continue_after_kill(enemy, enemies)
  if self.remaining_chains <= 0 then return false end

  local target = self:find_target(enemies, enemy.x, enemy.y)
  if not target then return false end

  self.remaining_chains = self.remaining_chains - 1
  self.damage = self.damage * self.damage_decay
  self.speed = self.speed * self.speed_growth
  self:set_target(target)
  return true
end

function WispProjectile:check_hits(enemies)
  if self.dead then return end

  for _, enemy in ipairs(enemies or {}) do
    if not enemy.dead and not self.hit_enemies[enemy] and
      self:is_colliding_with_object(enemy) then
      enemy:hit(self.damage)
      self.hit_enemies[enemy] = true

      if enemy.dead and self:continue_after_kill(enemy, enemies) then return end
      self.dead = true
      return
    end
  end
end
