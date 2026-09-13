GameObject = Object:extend()

local next_game_object_id = 0

function GameObject:init_game_object(args)
  for key, value in pairs(args or {}) do
    self[key] = value
  end

  self.x = self.x or 0
  self.y = self.y or 0
  self.r = self.r or 0
  self.sx = self.sx or 1
  self.sy = self.sy or 1
  self.dead = self.dead or false

  if self.id == nil then
    next_game_object_id = next_game_object_id + 1
    self.id = next_game_object_id
  end

  return self
end
