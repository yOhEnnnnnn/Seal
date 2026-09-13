Shop = Object:extend()

function Shop:init(game)
  self.game = game
  self.ui_font = game.ui_font
  self.item_font = game.shop_item_font
  self.colors = game.colors
  self.next_button = {x = gw - 58, y = gh - 30, width = 48, height = 20}
  self.bullets = {
    self:create_bullet_item("pierce"),
    self:create_bullet_item("bounce"),
    self:create_bullet_item("chain"),
  }
  self.marks = {
    {
      kind = "mark",
      key = "haste",
      name = "HASTE",
      price = 4,
      amount = 1,
      effect = "SPEED X1.5",
      value = 2,
      color = {1, 107 / 255, 107 / 255, 1},
    },
    {
      kind = "mark",
      key = "armor",
      name = "ARMOR",
      price = 4,
      amount = 1,
      effect = "HP +1",
      value = 3,
      color = {218 / 255, 218 / 255, 218 / 255, 1},
    },
    {
      kind = "mark",
      key = "fission",
      name = "FISSION",
      price = 6,
      amount = 1,
      effect = "SPLIT X2",
      value = 4,
      color = {179 / 255, 136 / 255, 1, 1},
    },
  }
  self.rows = {self.bullets, self.marks}
  self.entries = {}
  for row_index, items in ipairs(self.rows) do
    local row = {}
    for index, item in ipairs(items) do
      row[index] = {item = item, x = 60 + (index - 1) * 80,
        y = row_index == 1 and 94 or 211}
    end
    self.entries[row_index] = row
  end
  self.items = {}
  for _, row in ipairs(self.rows) do
    for _, item in ipairs(row) do self.items[item] = true end
  end
end

function Shop:create_bullet_item(key)
  local bullet = Bullets[key]
  return {
    kind = "bullet",
    key = key,
    name = bullet.name,
    price = bullet.shop_price,
    amount = bullet.shop_amount,
    multiplier = bullet.multiplier,
    color = bullet.color,
  }
end

function Shop:reset()
  for item in pairs(self.items) do item.sold = false end
  for _, row in ipairs(self.entries) do
    for _, entry in ipairs(row) do
      entry.hovered = false
      entry.hover_started_at = nil
    end
  end
  self.next_button.hovered = false
  self.next_button.hover_started_at = nil
end

function Shop:can_buy(item)
  return self.items[item] == true and not item.sold and
    self.game:is_shop_open() and self.game:has_next_level() and
    self.game.coins >= item.price
end

function Shop:buy(item)
  if not self:can_buy(item) then return false end
  if item.kind == "bullet" then
    if not self.game.inventory:add(item.key, item.amount) then return false end
  elseif item.kind == "mark" and self.game.enemy_traits[item.key] ~= nil then
    self.game.enemy_traits[item.key] = self.game.enemy_traits[item.key] + item.amount
  else
    return false
  end
  self.game.coins = self.game.coins - item.price
  item.sold = true
  return true
end

function Shop:is_inside(rect, x, y)
  return x >= rect.x and x <= rect.x + rect.width and
    y >= rect.y and y <= rect.y + rect.height
end

function Shop:is_inside_item(item, x, y)
  return x >= item.x - 40 and x <= item.x + 40 and
    y >= item.y - 45 and y <= item.y + 45
end

function Shop:hover_values(target, hovered)
  if hovered and not target.hovered then
    target.hover_started_at = love.timer.getTime()
  end
  target.hovered = hovered
  if not hovered then return 0, 0 end

  local elapsed = love.timer.getTime() - target.hover_started_at
  return 0.1 * math.sin(math.min(elapsed / 0.16, 1) * math.pi),
    math.sin(elapsed * math.pi / 0.7)
end

function Shop:draw_item(entry, mouse_x, mouse_y)
  local item = entry.item
  if item.sold then return false end

  local can_buy = self:can_buy(item)
  local hovered = mouse_x and self:is_inside_item(entry, mouse_x, mouse_y)
  local pop, pulse = self:hover_values(entry, hovered)
  local alpha = can_buy and (hovered and 1 or 0.78) or 0.3

  love.graphics.push("all")
  love.graphics.translate(entry.x, entry.y)
  love.graphics.rotate(pulse * math.pi / 32)
  love.graphics.scale(1 + 0.03 * pulse + pop)
  if hovered then
    graphics.rectangle(
      0, 0, 80, 90, 6, 6,
      graphics.color_with_alpha(
        self.colors.shop_selected, can_buy and 0.95 or 0.55))
  end
  love.graphics.pop()

  love.graphics.push("all")
  love.graphics.translate(entry.x, entry.y - 26)
  love.graphics.scale(1 + pop, 1 + pop)
  love.graphics.setFont(self.item_font)
  self.game.hud:draw_icon(0, 0, item.color, alpha)
  graphics.set_color(
    graphics.color_with_alpha(self.colors.background_dark, alpha))
  love.graphics.printf(
    item.price, -6,
    -self.item_font:getHeight() / 2 + 1, 14, "center")
  graphics.set_color(graphics.color_with_alpha(self.colors.gold, alpha))
  love.graphics.printf(
    item.price, -7,
    -self.item_font:getHeight() / 2, 14, "center")
  graphics.set_color(
    graphics.color_with_alpha(self.colors.hp_bar_background, alpha * 0.75))
  love.graphics.printf(string.lower(item.name), -39, 11, 80, "center")
  graphics.set_color(graphics.color_with_alpha(item.color, alpha))
  love.graphics.printf(string.lower(item.name), -40, 10, 80, "center")
  if item.kind == "mark" then
    local level_text = tostring(self.game.enemy_traits[item.key])
    graphics.set_color(
      graphics.color_with_alpha(
        self.colors.hp_bar_background, alpha * 0.75))
    love.graphics.printf(level_text, -39, 28, 80, "center")
    graphics.set_color(
      graphics.color_with_alpha(self.colors.foreground, alpha))
    love.graphics.printf(level_text, -40, 27, 80, "center")
  end
  love.graphics.pop()

  return hovered
end

function Shop:draw_details(item)
  if not item then return end

  local y = item.kind == "bullet" and 67 or 184
  love.graphics.push("all")
  love.graphics.setFont(self.item_font)
  graphics.set_color(item.color)
  love.graphics.print(item.name, 292, y)
  graphics.set_color(self.colors.foreground)
  if item.kind == "bullet" then
    love.graphics.print("+" .. item.amount .. " BULLETS", 292, y + 13)
    love.graphics.print("SCORE X" .. item.multiplier, 292, y + 26)
  else
    love.graphics.print("+" .. item.amount .. " MARK", 292, y + 13)
    love.graphics.print(item.effect, 292, y + 26)
    love.graphics.print("VALUE +" .. item.value, 292, y + 39)
  end
  love.graphics.pop()
end

function Shop:draw_next(mouse_x, mouse_y)
  if not self.game:has_next_level() then
    graphics.set_color(self.colors.foreground)
    love.graphics.printf(
      "RUN COMPLETE - R TO RESTART", 0, self.next_button.y + 3, gw, "center")
    return
  end

  local hovered = mouse_x and
    self:is_inside(self.next_button, mouse_x, mouse_y)
  local pop = self:hover_values(self.next_button, hovered)

  love.graphics.push("all")
  love.graphics.translate(
    self.next_button.x + self.next_button.width / 2,
    self.next_button.y + self.next_button.height / 2)
  love.graphics.scale(1 + pop, 1 + pop)
  graphics.rectangle(
    1, 1, self.next_button.width, self.next_button.height, 4, 4,
    self.colors.hp_bar_background)
  graphics.rectangle(
    0, 0, self.next_button.width, self.next_button.height, 4, 4,
    hovered and self.colors.foreground or self.colors.green)
  love.graphics.setFont(self.item_font)
  graphics.set_color(self.colors.background_dark)
  love.graphics.printf(
    "NEXT", -self.next_button.width / 2,
    -self.item_font:getHeight() / 2 + 1,
    self.next_button.width, "center")
  love.graphics.pop()
end

function Shop:draw(mouse_x, mouse_y)
  local title = "SHOP"
  local title_x = 10
  local title_time = love.timer.getTime() * 3

  graphics.set_color(self.colors.foreground)
  for index = 1, #title do
    local letter = title:sub(index, index)
    local letter_y = 9 + math.sin(title_time + (index - 1) * 0.8) * 2
    love.graphics.print(letter, title_x, letter_y)
    title_x = title_x + self.ui_font:getWidth(letter)
  end
  graphics.set_color(self.colors.foreground)
  love.graphics.print(" - GOLD:", title_x, 9)
  title_x = title_x + self.ui_font:getWidth(" - GOLD: ")
  graphics.set_color(self.colors.gold)
  love.graphics.print(self.game.coins, title_x, 9)

  graphics.set_color(self.colors.foreground)
  love.graphics.print("SEAL", 10, 31)
  local hovered_item
  for _, entry in ipairs(self.entries[1]) do
    if self:draw_item(entry, mouse_x, mouse_y) then
      hovered_item = entry.item
    end
  end

  graphics.set_color(self.colors.foreground)
  love.graphics.print("MARK", 10, 148)
  for _, entry in ipairs(self.entries[2]) do
    if self:draw_item(entry, mouse_x, mouse_y) then
      hovered_item = entry.item
    end
  end
  self:draw_details(hovered_item)
  self:draw_next(mouse_x, mouse_y)
end

function Shop:mousepressed(x, y)
  for _, row in ipairs(self.entries) do
    for _, entry in ipairs(row) do
      if self:is_inside_item(entry, x, y) and self:buy(entry.item) then
        return true
      end
    end
  end
  if self:is_inside(self.next_button, x, y) then
    self.game:start_next_level()
    return true
  end
  return false
end
