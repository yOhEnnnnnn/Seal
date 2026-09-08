Rime = Hero:extend()

function Rime:init(args)
  self.name = "RIME"
  self.attack_range = 176
  self.attack_interval = 5.5
  self.area_radius = 64
  self.area_duration = 4.0
  self.area_damage = 5
  self.slow_multiplier = 0.45
  self.slow_duration = 1.6
  Rime.super.init(self, args)
end

function Rime:get_target_priority(enemy)
  if not enemy:is_slowed() and enemy.enemy_type == "rusher" then return 3 end
  if not enemy:is_slowed() then return 2 end
  if enemy.enemy_type == "rusher" then return 1 end
  return 0
end

function Rime:perform_attack(player, target, enemies, projectiles, effects)
  effects[#effects + 1] = FrostCircleArea{
    x = target.x,
    y = target.y,
    radius = self.area_radius,
    duration = self.area_duration,
    damage = self.area_damage * self:get_level_damage_multiplier(),
    slow_multiplier = self.slow_multiplier,
    initial_slow_duration = self.slow_duration,
    persistent_slow = self.level >= 3,
    color = self.color,
  }
  return true
end
