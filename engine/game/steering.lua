Steering = Object:extend()

function Steering:set_as_steerable(max_v, max_f, max_turn_rate, turn_multiplier)
  self.max_v = max_v or 100
  self.max_f = max_f or 2000
  self.max_turn_rate = max_turn_rate or 2 * math.pi
  self.turn_multiplier = turn_multiplier or 2
  self.max_speed = self.max_v
  self.mass = 1
  self.heading_x, self.heading_y = 0, 0
  self.side_x, self.side_y = 0, 0
  self.seek_fx, self.seek_fy = 0, 0
  self.wander_fx, self.wander_fy = 0, 0
  self.separation_fx, self.separation_fy = 0, 0
  self.wander_r = love.math.random() * 2 * math.pi
  self.wander_x = 40 * math.cos(self.wander_r)
  self.wander_y = 40 * math.sin(self.wander_r)
end

function Steering:seek_point(x, y, deceleration, weight)
  local tx, ty = x - self.x, y - self.y
  local distance = math.sqrt(tx * tx + ty * ty)

  if distance == 0 then
    self.seek_fx, self.seek_fy = 0, 0
    return
  end

  local speed = math.min(distance / ((deceleration or 1) * 0.08), self.max_v)
  self.seek_fx = (speed * tx / distance - self.vx) * self.turn_multiplier * (weight or 1)
  self.seek_fy = (speed * ty / distance - self.vy) * self.turn_multiplier * (weight or 1)
end

function Steering:wander(radius, distance, jitter, dt, weight)
  local jitter_amount = (jitter or 20) * dt * 60
  self.wander_x = self.wander_x + (love.math.random() * 2 - 1) * jitter_amount
  self.wander_y = self.wander_y + (love.math.random() * 2 - 1) * jitter_amount

  local length = math.sqrt(self.wander_x * self.wander_x + self.wander_y * self.wander_y)
  if length > 0 then
    self.wander_x = self.wander_x / length * (radius or 40)
    self.wander_y = self.wander_y / length * (radius or 40)
  end

  local target_x = self.wander_x + (distance or 40)
  local target_y = self.wander_y
  self.wander_fx = (self.heading_x * target_x + self.side_x * target_y) * (weight or 1)
  self.wander_fy = (self.heading_y * target_x + self.side_y * target_y) * (weight or 1)
end

function Steering:steering_separate(radius, objects, weight)
  self.separation_fx, self.separation_fy = 0, 0

  for _, object in ipairs(objects or {}) do
    if object ~= self and not object.dead then
      local tx, ty = self.x - object.x, self.y - object.y
      local distance_squared = tx * tx + ty * ty

      if distance_squared > 0 and distance_squared < 4 * radius * radius then
        local distance = math.sqrt(distance_squared)
        self.separation_fx = self.separation_fx + radius * tx / distance * (weight or 1)
        self.separation_fy = self.separation_fy + radius * ty / distance * (weight or 1)
      end
    end
  end
end

function Steering:update_steering(dt)
  local fx = self.seek_fx + self.wander_fx + self.separation_fx
  local fy = self.seek_fy + self.wander_fy + self.separation_fy
  local force = math.sqrt(fx * fx + fy * fy)

  if force > self.max_f then
    fx = fx / force * self.max_f
    fy = fy / force * self.max_f
  end

  self.ax = fx / self.mass
  self.ay = fy / self.mass
  self:update_physics(dt)

  local speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
  if speed > 0.00001 then
    self.heading_x, self.heading_y = self.vx / speed, self.vy / speed
    self.side_x, self.side_y = -self.heading_y, self.heading_x
  end
end

function Steering:rotate_towards_velocity(dt)
  if self.vx == 0 and self.vy == 0 then return end

  local target = math.atan2(self.vy, self.vx)
  local difference = (target - self.r) % (2 * math.pi)
  if difference > math.pi then difference = difference - 2 * math.pi end
  local max_rotation = self.max_turn_rate * dt
  self.r = self.r + math.max(-max_rotation, math.min(difference, max_rotation))
end
