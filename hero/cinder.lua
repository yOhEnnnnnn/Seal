Cinder = Hero:extend()

function Cinder:init(args)
  self.name = "CINDER"
  self.attack_range = 160
  self.attack_interval = 4.0
  self.area_radius = 48
  self.effect_duration = 3.0
  self.area_damage = 10
  self.burn_tick_damage = 2
  Cinder.super.init(self, args)
end

function Cinder:perform_attack(player, target, enemies, projectiles, effects)
  local damage_multiplier = self:get_level_damage_multiplier()
  effects[#effects + 1] = CinderCircleArea{
    x = target.x,
    y = target.y,
    radius = self.area_radius,
    duration = self.effect_duration,
    damage = self.area_damage * damage_multiplier,
    burning = self.level >= 3,
    burn_damage = self.burn_tick_damage * damage_multiplier,
    color = self.color,
  }
  return true
end
