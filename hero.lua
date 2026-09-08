Hero = Object:extend()

function Hero:init(args)
  for key, value in pairs(args or {}) do self[key] = value end
  self.name = self.name or "HERO"
  self.level = self.level or 1
  self.color = self.color or {1, 1, 1, 1}
  self.attack_cooldown_time = 0
end

function Hero:set_level(level)
  self.level = math.max(1, math.min(level, 3))
end

function Hero:update(dt)
  self.attack_cooldown_time = math.max(self.attack_cooldown_time - dt, 0)
end

function Hero:can_attack()
  return self.attack_cooldown_time == 0
end

function Hero:get_attack_interval()
  return self.attack_interval
end

function Hero:get_level_damage_multiplier()
  return self.level >= 2 and 1.2 or 1
end

function Hero:get_shared_health_bonus()
  return self.level >= 2 and 5 or 0
end

function Hero:get_target_priority()
  return 0
end

function Hero:attack(player, target, enemies, projectiles, effects)
  if not self:can_attack() then return end
  if not self:perform_attack(player, target, enemies, projectiles, effects) then return end
  self.attack_cooldown_time = self:get_attack_interval()
  return true
end

function Hero:perform_attack()
  return false
end

require("hero.cinder")
require("hero.arc")
require("hero.rime")
require("hero.wisp")
