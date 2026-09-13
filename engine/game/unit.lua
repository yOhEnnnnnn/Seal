Unit = Object:extend()

function Unit:init_unit()
  self.max_hp = self.max_hp or 100
  self.hp = self.hp or self.max_hp
end

function Unit:hit(damage)
  if self.dead then return end
  self.hp = math.max(self.hp - damage, 0)
  if self.hp == 0 then self:die() end
end

function Unit:die()
  if self.dead then return end
  self.dead = true

  if self.on_death then self:on_death() end
end
