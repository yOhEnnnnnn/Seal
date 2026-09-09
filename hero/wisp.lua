Wisp = Hero:extend()

function Wisp:init(args)
  self.name = "WISP"
  self.attack_range = 160
  self.attack_interval = 0.9
  self.projectile_speed = 130
  self.projectile_damage = 8
  self.chain_range = 72
  Wisp.super.init(self, args)
end

function Wisp:get_target_priority(enemy)
  return -enemy.hp
end

function Wisp:has_active_projectile(projectiles)
  for _, projectile in ipairs(projectiles) do
    if not projectile.dead and projectile.owner == self then return true end
  end
  return false
end

function Wisp:get_chain_count()
  if self.level >= 3 then return 3 end
  if self.level >= 2 then return 2 end
  return 0
end

function Wisp:get_speed_growth()
  if self.level >= 3 then return 1.25 end
  return 1
end

function Wisp:get_damage_decay()
  if self.level >= 3 then return 1 end
  return 0.75
end

function Wisp:perform_attack(player, target, enemies, projectiles, effects)
  if #projectiles >= player.max_projectiles then return false end
  if self:has_active_projectile(projectiles) then return false end

  projectiles[#projectiles + 1] = WispProjectile{
    x = player.x,
    y = player.y,
    r = math.atan2(target.y - player.y, target.x - player.x),
    target = target,
    owner = self,
    speed = self.projectile_speed,
    damage = self.projectile_damage,
    damage_decay = self:get_damage_decay(),
    chain_range = self.chain_range,
    remaining_chains = self:get_chain_count(),
    speed_growth = self:get_speed_growth(),
    color = self.color,
    effects = effects,
  }
  return true
end
