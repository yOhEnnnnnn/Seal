Player = Object:extend()
Player:implement(GameObject)
Player:implement(Physics)
Player:implement(Unit)

function Player:init(args)
  self:init_game_object(args)
  self:init_physics(args)
  self.max_hp = self.max_hp or Data.player.max_hp
  self:init_unit(args)
  self.size = self.size or Data.player.size
  self.max_projectiles = self.max_projectiles or Data.player.max_projectiles
  self.color = Data.bullets.color
  self.camera = args.camera
  self.audio = args.audio
  self.base_attack_interval = self.base_attack_interval or Data.player.attack_interval
  self.base_attack_cooldown_time = 0
  self.base_projectile_speed = self.base_projectile_speed or Data.player.projectile_speed
  self.base_projectile_hit_power = self.base_projectile_hit_power or
    Data.player.projectile_hit_power
  self.projectile_spread = self.projectile_spread or Data.player.projectile_spread
  self:apply_upgrades(args.upgrades or {})
  self.hit_color = self.hit_color or {1, 1, 1, 1}
  self.hit_duration = Data.player.hit_duration
  self.hit_time = 0
  self:set_as_rectangle(self.size, self.size, "dynamic", "player")
end

function Player:apply_upgrades(upgrades)
  self.base_projectile_hit_power = Data.player.projectile_hit_power +
    (upgrades.hit_power or 0) * Data.upgrades.hit_power_per_level
  self.base_projectile_speed = Data.player.projectile_speed
  self.base_attack_interval = math.max(
    Data.upgrades.min_attack_interval, Data.player.attack_interval -
      (upgrades.fire_rate or 0) * Data.upgrades.fire_interval_reduction)
  self.bonus_bounces = upgrades.bounce or 0
  self.auto_attack = upgrades.auto_attack == 1
  self.critical_chance = (upgrades.critical or 0) *
    Data.upgrades.critical_chance_per_level
  self.luck_chance = (upgrades.luck or 0) *
    Data.upgrades.luck_chance_per_level
end

function Player:update(dt)
  self.x, self.y = aw / 2, ah / 2
  self:stop()
  self.hit_time = math.max(self.hit_time - dt, 0)
  self.base_attack_cooldown_time = math.max(
    self.base_attack_cooldown_time - dt, 0)
end

function Player:hit(damage)
  if self.dead then return end
  self.hit_time = self.hit_duration
  Unit.hit(self, damage)
  if self.audio then self.audio:play("player_hit") end
  if self.camera then self.camera:spring_shake(Data.player.hit_shake, 0) end
end

function Player:fire_bullet(aim_x, aim_y, projectiles, effects)
  if self.base_attack_cooldown_time > 0 then return end
  if #projectiles >= self.max_projectiles then return end
  if (aim_x - self.x) ^ 2 + (aim_y - self.y) ^ 2 <= 1 then return end

  local aim_r = math.atan2(aim_y - self.y, aim_x - self.x)
  local r = aim_r + (love.math.random() * 2 - 1) * self.projectile_spread
  projectiles:add(Projectile{
    x = self.x,
    y = self.y,
    r = r,
    speed = self.base_projectile_speed,
    hit_power = self.base_projectile_hit_power,
    bounces = self.bonus_bounces,
    critical_chance = self.critical_chance,
    luck_chance = self.luck_chance,
    effects = effects,
    audio = self.audio,
    arena_width = aw,
    arena_height = ah,
  })
  self.base_attack_cooldown_time = self.base_attack_interval

  if self.audio then self.audio:play("attack") end
  return true, r
end

function Player:try_attack(aim_x, aim_y, projectiles, effects)
  if not aim_x or not aim_y then return end
  local fired, angle = self:fire_bullet(aim_x, aim_y, projectiles, effects)
  if fired then
    if self.camera then self.camera:spring_shake(Data.player.attack_shake, angle) end
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
  self:draw_rounded_square(0, 0, self.size,
    self.hit_time > 0 and self.hit_color or self.color)
  love.graphics.pop()
end
