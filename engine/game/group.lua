Group = Object:extend()

function Group:init(args)
  self.on_remove = args and args.on_remove
end

function Group:add(object)
  self[#self + 1] = object
  return object
end

function Group:update(dt, ...)
  for _, object in ipairs(self) do
    if not object.dead then object:update(dt, ...) end
  end

  self:remove_dead()
end

function Group:remove_dead()
  -- Keep iteration order while compacting in one pass.
  local count, write_index = #self, 1
  for index = 1, count do
    local object = self[index]
    if object.dead then
      if self.on_remove then self.on_remove(object) end
    else
      self[write_index] = object
      write_index = write_index + 1
    end
  end
  for index = write_index, count do self[index] = nil end
end

function Group:draw()
  for _, object in ipairs(self) do
    if not object.dead then object:draw() end
  end
end

function Group:clear()
  for index = #self, 1, -1 do self[index] = nil end
end
