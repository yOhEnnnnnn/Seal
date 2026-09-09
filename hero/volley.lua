Volley = Hero:extend()

function Volley:init(args)
  self.name = "VOLLEY"
  self.attack_range = 176
  self.attack_interval = 0.9
  self.projectile_speed = 180
  self.projectile_damage = 4
  self.projectile_spacing = 2
  self.spread = math.rad(8)
  Volley.super.init(self, args)
end

function Volley:perform_attack(player, target, enemies, projectiles, effects)
  if #projectiles + 3 > player.max_projectiles then return false end

  local base_r = math.atan2(target.y - player.y, target.x - player.x)
  local damage = self.projectile_damage * self:get_level_damage_multiplier()
  local bounces = self.level >= 3 and 1 or nil

  for offset = -1, 1 do
    local r = base_r + offset * self.spread
    local side_r = base_r + math.pi / 2
    projectiles[#projectiles + 1] = Projectile{
      x = player.x + math.cos(side_r) * offset * self.projectile_spacing,
      y = player.y + math.sin(side_r) * offset * self.projectile_spacing,
      r = r,
      speed = self.projectile_speed,
      damage = damage,
      color = self.color,
      effects = effects,
      owner = self,
      bounces = bounces,
    }
  end
  self:play_projectile_attack_sound()
  return true
end
