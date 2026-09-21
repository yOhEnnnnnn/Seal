Sidebar = Object:extend()

function Sidebar:init(game)
  self.game = game
  self.font = game.small_font
  self.colors = game.colors
  self.cards = Data.upgrades.cards
end

function Sidebar:get_price(card)
  return math.floor(card.base_price *
    Data.upgrades.price_growth ^ self.game.upgrades[card.key] + 0.5)
end

function Sidebar:buy(card)
  local upgrades = self.game.upgrades
  if upgrades[card.key] >= card.max then return false end
  local price = self:get_price(card)
  if self.game.coins < price then return false end

  self.game.coins = self.game.coins - price
  upgrades[card.key] = upgrades[card.key] + 1
  local arena = self.game.arena
  arena.player:apply_upgrades(upgrades)
  for _, projectile in ipairs(arena.projectiles) do
    arena.player:apply_projectile_upgrades(projectile)
  end
  self.game.audio:play("purchase")
  return true
end

function Sidebar:draw_header()
  love.graphics.setFont(self.font)
  graphics.set_color(self.colors.gold)
  love.graphics.print("DUST " .. self.game.coins, aw + 10, 9)
  graphics.set_color(self.colors.boss)
  love.graphics.printf("BOSS " .. self.game.score .. "/" ..
    self.game.next_boss_score,
    aw + 40, 9, gw - aw - 50, "right")
  graphics.line(aw + 10, 27, gw - 10, 27, self.colors.border, 1)
  graphics.set_color(self.colors.muted)
  love.graphics.print("UPGRADES", aw + 10, 32)
end

function Sidebar:draw_card(card, index, mouse_x, mouse_y)
  local x, y, width, height = aw + 10, 45 + (index - 1) * 38, 130, 32
  local hovered = mouse_x and mouse_y and mouse_x >= x and
    mouse_x <= x + width and mouse_y >= y and mouse_y <= y + height
  local level = self.game.upgrades[card.key]
  local sold_out = level >= card.max
  local price = self:get_price(card)
  local affordable = self.game.coins >= price and not sold_out
  local background = hovered and self.colors.panel_hover or
    self.colors.panel_card
  local border = hovered and self.colors.accent or self.colors.border

  graphics.rectangle(x + width / 2, y + height / 2,
    width, height, 2, 2, background)
  graphics.set_color(border)
  graphics.rectangle(x + width / 2, y + height / 2,
    width, height, 2, 2, nil, 1)
  graphics.line(x + 3, y + 5, x + 3, y + height - 5,
    affordable and self.colors.accent or self.colors.border, 1)
  graphics.set_color(affordable and self.colors.foreground or
    graphics.color_with_alpha(self.colors.foreground, 0.45))
  love.graphics.print(card.label, x + 8, y + 5)
  graphics.set_color(self.colors.muted)
  love.graphics.print("LV " .. level .. "/" .. card.max, x + 8, y + 19)
  graphics.set_color(affordable and self.colors.gold or
    graphics.color_with_alpha(self.colors.foreground, 0.45))
  love.graphics.printf(sold_out and "MAX" or price .. " DUST",
    x + width - 58, y + 19, 50, "right")
end

function Sidebar:draw(mouse_x, mouse_y)
  graphics.rectangle(aw + (gw - aw) / 2, gh / 2,
    gw - aw, gh, nil, nil, self.colors.panel)
  graphics.line(aw, 0, aw, gh, self.colors.border, 2)
  self:draw_header()
  for index, card in ipairs(self.cards) do
    self:draw_card(card, index, mouse_x, mouse_y)
  end
end

function Sidebar:mousepressed(x, y)
  for index, card in ipairs(self.cards) do
    local card_y = 45 + (index - 1) * 38
    if x >= aw + 10 and x <= gw - 10 and
      y >= card_y and y <= card_y + 32 then
      return self:buy(card)
    end
  end
  return false
end
