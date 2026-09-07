Scribe = Hero:extend()

function Scribe:init(args)
  self.name = "SCRIBE"
  self.attack_range = 160
  self.attack_interval = 0.7
  self.summon_interval = 5.0
  self.projectile_damage = 8
  Scribe.super.init(self, args)
end

function Scribe:get_attack_interval()
  if self.level >= 3 then return self.summon_interval end
  return self.attack_interval
end

function Scribe:perform_attack(player, target, enemies, projectiles, effects)
  if self.level >= 3 then
    effects[#effects + 1] = ScribeSwarm{
      owner = player,
      color = {218 / 255, 218 / 255, 218 / 255, 1},
      damage = 5,
      duration = 4.0,
      range = 176,
    }
    return true
  end

  if #projectiles >= player.max_projectiles then return false end
  projectiles[#projectiles + 1] = Projectile{
    x = player.x,
    y = player.y,
    r = math.atan2(target.y - player.y, target.x - player.x),
    damage = self.projectile_damage,
    color = self.color,
    pierce = self.level >= 2 and 2 or 0,
    damage_decay = 0.75,
  }
  return true
end

ScribeSwarm = Object:extend()
ScribeSwarm:implement(GameObject)

function ScribeSwarm:init(args)
  self:init_game_object(args)
  self.time = 0
  self.duration = self.duration or 4
  self.range = self.range or 176
  self.damage = self.damage or 5
  self.speed = self.speed or 230
  self.motes = {}
  for index = 1, 4 do
    self.motes[index] = {
      x = self.owner.x,
      y = self.owner.y,
      state = "inside",
      wait = (index - 1) * 0.08,
    }
  end
end

function ScribeSwarm:find_target(mote, enemies, claimed)
  local target
  local nearest_distance = self.range * self.range
  for _, enemy in ipairs(enemies or {}) do
    local dx, dy = enemy.x - mote.x, enemy.y - mote.y
    local distance = dx * dx + dy * dy
    if not enemy.dead and not claimed[enemy] and distance <= nearest_distance then
      target = enemy
      nearest_distance = distance
    end
  end
  return target
end

function ScribeSwarm:move_towards(mote, x, y, dt)
  local dx, dy = x - mote.x, y - mote.y
  local distance = math.sqrt(dx * dx + dy * dy)
  local step = self.speed * dt
  if distance <= step or distance == 0 then
    mote.x, mote.y = x, y
    return true
  end
  mote.x = mote.x + dx / distance * step
  mote.y = mote.y + dy / distance * step
  return false
end

function ScribeSwarm:update(dt, enemies)
  self.time = self.time + dt
  if self.time >= self.duration then self.ending = true end

  local claimed = {}
  for _, mote in ipairs(self.motes) do
    if mote.target and not mote.target.dead then claimed[mote.target] = true end
  end

  for _, mote in ipairs(self.motes) do
    if mote.state == "attack" then
      if mote.target.dead then
        mote.target = nil
        mote.state = "return"
      elseif self:move_towards(mote, mote.target.x, mote.target.y, dt) then
        mote.target:hit(self.damage)
        mote.target = nil
        mote.state = "return"
      end
    elseif mote.state == "return" then
      if self:move_towards(mote, self.owner.x, self.owner.y, dt) then
        mote.state = "inside"
        mote.wait = 0.12
      end
    else
      mote.x, mote.y = self.owner.x, self.owner.y
      mote.wait = math.max(0, mote.wait - dt)
      if not self.ending and mote.wait == 0 then
        mote.target = self:find_target(mote, enemies, claimed)
        if mote.target then
          claimed[mote.target] = true
          mote.state = "attack"
        end
      end
    end
  end

  if self.ending then
    for _, mote in ipairs(self.motes) do
      if mote.state ~= "inside" then return end
    end
    self.dead = true
  end
end

function ScribeSwarm:draw()
  for _, mote in ipairs(self.motes) do
    if mote.state ~= "inside" then
      graphics.circle(mote.x, mote.y, 2.5, self.color)
    end
  end
end
