Player = Object:extend()
Player:implement(GameObject)
Player:implement(Physics)
Player:implement(Unit)

require("player.dash")
require("player.heroes")
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
  self.base_attack_range = self.base_attack_range or 160
  self.base_attack_interval = self.base_attack_interval or 0.6
  self.base_attack_cooldown_time = 0
  self.base_projectile_speed = self.base_projectile_speed or 160
  self.base_projectile_damage = self.base_projectile_damage or 10
  self:set_as_rectangle(self.size, self.size, "dynamic", "player")
  self:init_player_dash()
  self:init_player_heroes()
end

function Player:update(dt, enemies, projectiles, effects)
  self.x, self.y = gw / 2, gh / 2
  self:stop()
  self.base_attack_cooldown_time = math.max(
    self.base_attack_cooldown_time - dt, 0)
  self:update_switch(dt)
  self:update_heroes(dt)
  self:update_attack(enemies, projectiles, effects)
end

function Player:keypressed(key, scancode)
  local input = scancode or key
  if input == "space" then self:start_switch() end
  if input == "i" then self:set_active_hero_level(1) end
  if input == "o" then self:set_active_hero_level(2) end
  if input == "p" then self:set_active_hero_level(3) end
end
