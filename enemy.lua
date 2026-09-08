Enemy = Object:extend()
Enemy:implement(GameObject)
Enemy:implement(Physics)
Enemy:implement(Unit)

function Enemy:init(args)
  self:init_game_object(args)
  self:init_physics(args)
  self.max_hp = self.max_hp or 12.5
  self:init_unit(args)
  self.hp = self.hp or self.max_hp
  self.v = self.v or self.speed or 21
  self.damage = self.damage or 4.5
  self.def = self.def or 25
  self.width = self.width or 14
  self.height = self.height or 6
  self.color = self.color or {233 / 255, 29 / 255, 57 / 255, 1}
  self.hit_color = self.hit_color or {1, 1, 1, 1}
  self.hp_bar_background = self.hp_bar_background or {32 / 255, 32 / 255, 32 / 255, 1}
  self.effects = self.effects or {}
  self.invincible = self.invincible or false
  self.stationary = self.stationary or false
  self.enemy_type = self.enemy_type or "normal"
  self.slow_multiplier = 1
  self.slow_time = 0
  self.hit_spring = Spring(1)
  self.hit_duration = 0.15
  self.hit_time = 0
  self.hp_bar_time = 0
  self:set_as_rectangle(self.width, self.height, "dynamic", "enemy")
  self.restitution = 0.5
  self:set_as_steerable(self.v, 2000, 4 * math.pi, 4)
  self.base_max_v = self.max_v
end

function Enemy:update(dt, player, enemies)
  if self.dead then return end
  self.hit_spring:update(dt)
  self.hit_time = math.max(self.hit_time - dt, 0)
  self.hp_bar_time = math.max(self.hp_bar_time - dt, 0)
  self:update_statuses(dt)
  if self.stationary then
    self:stop()
    return
  end
  self:seek_point(player.x, player.y)
  self:wander(50, 100, 20, dt)
  self:steering_separate(16, enemies)
  self:update_steering(dt)
  self:rotate_towards_velocity(dt)
end

function Enemy:update_statuses(dt)
  self.slow_time = math.max(self.slow_time - dt, 0)
  if self.slow_time == 0 then
    self.slow_multiplier = 1
  end
  self.max_v = self.base_max_v * self.slow_multiplier
end

function Enemy:apply_slow(multiplier, duration)
  if self.dead then return end
  self.slow_multiplier = math.min(self.slow_multiplier, multiplier)
  self.slow_time = math.max(self.slow_time, duration)
end

function Enemy:is_slowed()
  return self.slow_time > 0
end

function Enemy:hit(damage)
  if self.dead then return end
  self.hit_spring:pull(0.25, 200, 10)
  self.hit_time = self.hit_duration
  self.hp_bar_time = 2
  if self.invincible then return end
  Unit.hit(self, damage * 100 / (100 + self.def))
end

function Enemy:on_death()
  for _ = 1, love.math.random(4, 6) do
    self.effects[#self.effects + 1] = HitParticle{
      x = self.x,
      y = self.y,
      color = self.color,
    }
  end

  self.effects[#self.effects + 1] = HitCircle{
    x = self.x,
    y = self.y,
    radius = 12,
    color = self.hit_color,
    target_color = self.color,
  }
end

function Enemy:get_color()
  return self.hit_time > 0 and self.hit_color or self.color
end

function Enemy:draw_hp_bar()
  if self.hp_bar_time == 0 then return end

  love.graphics.push("all")
  love.graphics.translate(self.x, self.y)
  love.graphics.scale(self.hit_spring.x, self.hit_spring.x)
  graphics.line(-self.width / 2, -self.height,
    self.width / 2, -self.height, self.hp_bar_background, 2)
  graphics.line(-self.width / 2, -self.height,
    -self.width / 2 + self.width * self.hp / self.max_hp,
    -self.height, self:get_color(), 2)
  love.graphics.pop()
end

function Enemy:draw()
  if self.dead then return end
  love.graphics.push("all")
  love.graphics.translate(self.x, self.y)
  love.graphics.rotate(self.r)
  love.graphics.scale(self.hit_spring.x, self.hit_spring.x)
  graphics.rectangle(0, 0, self.width, self.height, 3, 3, self:get_color())
  love.graphics.pop()
  self:draw_hp_bar()
end
