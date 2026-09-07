function Player:init_player_heroes()
  self.heroes = self.heroes or {}
  self.active_hero_index = self.active_hero_index or 1
  self.switching = false
  self.switch_time = 0
  self.switch_cooldown = self.switch_cooldown or 2
  self.switch_cooldown_time = 0
  self.switch_shrink_end = self.switch_shrink_end or 0.06
  self.switch_pop_end = self.switch_pop_end or 0.14
  self.switch_duration = self.switch_duration or 0.20
end

function Player:get_active_hero()
  return self.heroes[self.active_hero_index]
end

function Player:get_standby_hero()
  if #self.heroes < 2 then return end
  return self.heroes[self.active_hero_index % #self.heroes + 1]
end

function Player:get_color()
  if self:get_active_hero() then return self:get_active_hero().color end
  return self.color
end

function Player:can_switch()
  return #self.heroes > 1 and not self.switching and self.switch_cooldown_time == 0
end

function Player:start_switch()
  if not self:can_switch() then return end
  self.switching = true
  self.hero_switched = false
  self.switch_time = 0
  self.switch_cooldown_time = self.switch_cooldown
end

function Player:set_active_hero_level(level)
  local hero = self:get_active_hero()
  if not hero then return end
  hero:set_level(level)
  hero.attack_cooldown_time = 0
end

function Player:update_switch(dt)
  self.switch_cooldown_time = math.max(self.switch_cooldown_time - dt, 0)
  if not self.switching then return end

  self.switch_time = math.min(self.switch_time + dt, self.switch_duration)
  if not self.hero_switched and self.switch_time >= self.switch_shrink_end then
    self.active_hero_index = self.active_hero_index % #self.heroes + 1
    self.hero_switched = true
  end
  if self.switch_time == self.switch_duration then self.switching = false end
end

function Player:update_heroes(dt)
  for _, hero in ipairs(self.heroes) do hero:update(dt) end
end
