Player = Object:extend()
Player:implement(GameObject)
Player:implement(Physics)

function Player:init(args)
  self:init_game_object(args)
  self:init_physics(args)
  self.size = self.size or 7
  self.color = self.color or {250 / 255, 207 / 255, 0, 1}
  self.shadow_color = self.shadow_color or {0, 0, 0, 0.35}
  self.max_projectiles = self.max_projectiles or 64
  self.inventory = assert(args.inventory, "Player requires an ammo inventory")
  self.camera = args.camera
  self.base_attack_interval = self.base_attack_interval or 0.10
  self.base_attack_cooldown_time = 0
  self.base_projectile_speed = self.base_projectile_speed or 160
  self.base_projectile_damage = self.base_projectile_damage or 10
  self:set_as_rectangle(self.size, self.size, "dynamic", "player")
end

function Player:update(dt)
  self.x, self.y = gw / 2, gh / 2
  self:stop()
  self.base_attack_cooldown_time = math.max(
    self.base_attack_cooldown_time - dt, 0)
end

function Player:fire_bullet(aim_x, aim_y, projectiles, effects)
  if self.base_attack_cooldown_time > 0 then return end
  if #projectiles >= self.max_projectiles then return end
  if (aim_x - self.x) ^ 2 + (aim_y - self.y) ^ 2 <= 1 then return end

  local r = math.atan2(aim_y - self.y, aim_x - self.x)
  local bullet = self.inventory:ensure_current()
  local definition = Bullets[bullet]
  projectiles:add(Projectile{
    x = self.x,
    y = self.y,
    r = r,
    speed = self.base_projectile_speed,
    damage = self.base_projectile_damage,
    bullet = bullet,
    color = definition.color,
    pierce = definition.pierce,
    bounces = definition.bounces,
    effects = effects,
  })
  self.base_attack_cooldown_time = self.base_attack_interval

  if projectile_attack_sound then
    projectile_attack_sound:stop()
    projectile_attack_sound:setPitch(0.95 + love.math.random() * 0.1)
    projectile_attack_sound:play()
  end
  return true, r
end

function Player:try_attack(aim_x, aim_y, projectiles, effects)
  if not aim_x or not aim_y then return end
  local current_bullet = self.inventory:ensure_current()
  if self.inventory.counts[current_bullet] <= 0 then return end

  local fired, angle = self:fire_bullet(aim_x, aim_y, projectiles, effects)
  if fired then
    self.inventory:consume()
    if self.camera then self.camera:spring_shake(2, angle) end
  end
  return fired
end

function Player:draw_rounded_square(x, y, size, color)
  graphics.rectangle(x, y, size, size - 2, nil, nil, color)
  graphics.rectangle(x, y, size - 2, size, nil, nil, color)
end

function Player:draw()
  love.graphics.push("all")
  love.graphics.translate(self.x, self.y)
  self:draw_rounded_square(1, 1, self.size, self.shadow_color)
  self:draw_rounded_square(0, 0, self.size, self.color)
  love.graphics.pop()
end
