Player = Object:extend()
Player:implement(GameObject)
Player:implement(Physics)
Player:implement(Unit)

require("player.combat")
require("player.renderer")

function Player:init(args)
  self:init_game_object(args)
  self:init_physics(args)
  self:init_unit(args)
  self.size = self.size or 7
  self.color = self.color or {250 / 255, 207 / 255, 0, 1}
  self.shadow_color = self.shadow_color or {0, 0, 0, 0.35}
  self.max_projectiles = self.max_projectiles or 64
  self.coins = self.coins or 0
  self.bullet_order = Bullets.order
  self.bullets = self.bullets or {
    normal = Bullets.normal.starting_amount,
    pierce = 0,
    bounce = 0,
    chain = 0,
  }
  self.current_bullet_index = self.current_bullet_index or 1
  self.enemy_traits = self.enemy_traits or {haste = 0, armor = 0, fission = 0}
  self.base_attack_interval = self.base_attack_interval or 0.10
  self.base_attack_cooldown_time = 0
  self.base_projectile_speed = self.base_projectile_speed or 160
  self.base_projectile_damage = self.base_projectile_damage or 10
  self:set_as_rectangle(self.size, self.size, "dynamic", "player")
end

function Player:get_ammo_count()
  local total = 0
  for _, bullet in ipairs(self.bullet_order) do
    total = total + self.bullets[bullet]
  end
  return total
end

function Player:add_ammo(amount)
  amount = math.max(0, math.floor(amount or 0))
  self.bullets.normal = self.bullets.normal + amount
  self:ensure_current_bullet()
end

function Player:add_coins(amount)
  self.coins = self.coins + math.max(0, math.floor(amount or 0))
end

function Player:buy_ammo(amount, cost)
  amount = math.max(0, math.floor(amount or 0))
  cost = math.max(0, math.floor(cost or 0))
  if amount == 0 or self.coins < cost then return false end

  self.coins = self.coins - cost
  self:add_ammo(amount)
  return true
end

function Player:buy_bullets(bullet, amount, cost)
  amount = math.max(0, math.floor(amount or 0))
  cost = math.max(0, math.floor(cost or 0))
  if self.bullets[bullet] == nil or bullet == "normal" or
    amount == 0 or self.coins < cost then
    return false
  end

  self.coins = self.coins - cost
  self.bullets[bullet] = self.bullets[bullet] + amount
  self:ensure_current_bullet()
  return true
end

function Player:buy_enemy_trait(trait, amount, cost)
  amount = math.max(0, math.floor(amount or 0))
  cost = math.max(0, math.floor(cost or 0))
  if not self.enemy_traits[trait] or amount == 0 or self.coins < cost then
    return false
  end

  self.coins = self.coins - cost
  self.enemy_traits[trait] = self.enemy_traits[trait] + amount
  return true
end

function Player:get_bullet_definition(bullet)
  return Bullets[bullet]
end

function Player:get_current_bullet()
  return self.bullet_order[self.current_bullet_index]
end

function Player:ensure_current_bullet()
  local current = self:get_current_bullet()
  if self.bullets[current] > 0 then return current end
  return self:select_next_bullet()
end

function Player:select_next_bullet()
  local count = #self.bullet_order
  for offset = 1, count do
    local index = (self.current_bullet_index - 1 + offset) % count + 1
    local bullet = self.bullet_order[index]
    if self.bullets[bullet] > 0 then
      self.current_bullet_index = index
      return bullet
    end
  end
  return self:get_current_bullet()
end

function Player:consume_current_bullet()
  local bullet = self:ensure_current_bullet()
  if self.bullets[bullet] <= 0 then return false end

  self.bullets[bullet] = self.bullets[bullet] - 1
  if self.bullets[bullet] == 0 then self:select_next_bullet() end
  return true
end

function Player:update(dt)
  self.x, self.y = gw / 2, gh / 2
  self:stop()
  self.base_attack_cooldown_time = math.max(
    self.base_attack_cooldown_time - dt, 0)
end
