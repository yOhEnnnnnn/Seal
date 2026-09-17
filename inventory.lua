Inventory = Object:extend()

function Inventory:init(counts)
  self.order = Bullets.order
  self.counts = {}
  self.scoring = {}
  for _, key in ipairs(self.order) do
    self.scoring[key] = {operation = Bullets[key].score_operation,
      value = Bullets[key].score_value}
    self.counts[key] = counts and (counts[key] or 0) or
      (Bullets[key].starting_amount or 0)
  end
  self.current_index = 1
  self:ensure_current()
end

function Inventory:get_count()
  local total = 0
  for _, key in ipairs(self.order) do total = total + self.counts[key] end
  return total
end

function Inventory:get_current()
  return self.order[self.current_index]
end

function Inventory:ensure_current()
  if self.counts[self:get_current()] > 0 then return self:get_current() end
  return self:select_next()
end

function Inventory:select_next()
  for offset = 1, #self.order do
    local index = (self.current_index - 1 + offset) % #self.order + 1
    if self.counts[self.order[index]] > 0 then
      self.current_index = index
      break
    end
  end
  return self:get_current()
end

function Inventory:add(key, amount)
  amount = math.max(0, math.floor(amount or 0))
  if self.counts[key] == nil or amount == 0 then return false end
  self.counts[key] = self.counts[key] + amount
  self:ensure_current()
  return true
end

function Inventory:consume()
  local key = self:ensure_current()
  if self.counts[key] == 0 then return false end
  self.counts[key] = self.counts[key] - 1
  if self.counts[key] == 0 then self:select_next() end
  return true
end

-- Enchantments change this run's scoring, never the shared bullet definitions.
function Inventory:set_scoring(key, operation, value)
  if not self.scoring[key] or (operation ~= "add" and operation ~= "multiply") or
    type(value) ~= "number" or value ~= value or value == math.huge or
    value < 1 or value % 1 ~= 0 then return false end
  self.scoring[key].operation = operation
  self.scoring[key].value = value
  return true
end
