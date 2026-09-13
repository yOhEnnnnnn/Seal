function Player:draw_rounded_square(x, y, size, color)
  graphics.rectangle(x, y, size, size - 2, nil, nil, color)
  graphics.rectangle(x, y, size - 2, size, nil, nil, color)
end

function Player:draw()
  love.graphics.push("all")
  love.graphics.translate(self.x, self.y)
  self:draw_rounded_square(1, 1, self.size, self.shadow_color)
  self:draw_rounded_square(0, 0, self.size, self.color)
  love.graphics.pop()
end
