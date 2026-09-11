GameRules = Object:extend()

function GameRules:init(args)
  self.levels = args.levels
  self.level = args.level or 1
  self.score = 0
  self.state = "playing"
end

function GameRules:get_target_score()
  return self.levels[self.level].target_score
end

function GameRules:enemy_killed()
  if self.state ~= "playing" then return end

  self.score = self.score + 1
  if self.score >= self:get_target_score() then
    self.state = "level_complete"
  end
end

function GameRules:is_level_complete()
  return self.state == "level_complete"
end
