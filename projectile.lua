Projectile = Object:extend()
Projectile:implement(GameObject)
Projectile:implement(Physics)

function Projectile:init(args)
  self:init_game_object(args)
  self:init_physics(args)
  self.speed = self.speed or 160
  self.damage = self.damage or 10
  self.width = self.width or 6
  self.height = self.height or 2
  self.color = self.color or {1, 1, 1, 1}
  self.effects = self.effects or {}
  self.pierce = self.pierce or 0
  self.damage_decay = self.damage_decay or 1
  self.hit_enemies = {}
  self:set_as_circle(2, "dynamic", "projectile")
  self:set_velocity(self.speed * math.cos(self.r), self.speed * math.sin(self.r))
end

function Projectile:update(dt, enemies)
  self:update_game_object(dt)
  self:check_hits(enemies)
  self:check_bounds()
end

function Projectile:check_bounds()
  if self.x < -self.width or self.x > gw + self.width or
    self.y < -self.width or self.y > gh + self.width then
    self.dead = true
  end
end

function Projectile:check_hits(enemies)
  if self.dead then return end

  for _, enemy in ipairs(enemies or {}) do
    if not enemy.dead and not self.hit_enemies[enemy] and
      self:is_colliding_with_object(enemy) then
      enemy:hit(self.damage)
      if self.slow_multiplier and enemy.apply_slow then
        enemy:apply_slow(self.slow_multiplier, self.slow_duration)
      end
      self.hit_enemies[enemy] = true
      if self.on_hit then self.on_hit(self, enemy, enemies) end

      if self.pierce <= 0 then
        self.dead = true
        return
      end

      self.pierce = self.pierce - 1
      self.damage = self.damage * self.damage_decay
      return
    end
  end
end

function Projectile:draw()
  love.graphics.push("all")
  love.graphics.translate(self.x, self.y)
  love.graphics.rotate(self.r)
  graphics.rectangle(0, 0, self.width, self.height, 1, 1, self.color)
  love.graphics.pop()
end

require("projectile.wisp")
