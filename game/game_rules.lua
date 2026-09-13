GameRules = Object:extend()

function GameRules:init(args)
  self.levels = args.levels
  self.level = args.level or 1
  self.score = 0
  self.state = args.state or "playing"
end

function GameRules:get_target_score()
  return self.levels[self.level].target_score
end

function GameRules:enemy_killed()
  if self.state ~= "playing" then return false end

  self.score = self.score + 1
  if self.score >= self:get_target_score() then
    self.state = "level_complete"
  end
  return true
end

function GameRules:is_level_complete()
  return self.state == "level_complete"
end

function GameRules:is_shop_open()
  return self.state == "shop" or self:is_level_complete()
end

function GameRules:fail()
  if self.state == "playing" then self.state = "failed" end
end

function GameRules:has_next_level()
  return self.state == "shop" or self.levels[self.level + 1] ~= nil
end

function GameRules:next_level()
  if not self:is_shop_open() or not self:has_next_level() then
    return false
  end

  if self.state ~= "shop" then self.level = self.level + 1 end
  self.score = 0
  self.state = "playing"
  return true
end
