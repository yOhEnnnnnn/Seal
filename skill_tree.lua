SkillTree = Object:extend()

local NODE_WIDTH = 132
local NODE_HEIGHT = 32
local NODE_START_Y = 66
local NODE_GAP = 43
local START_BUTTON_Y = 242

function SkillTree:init(game)
  self.game = game
  self.font = game.small_font
  self.colors = game.colors
  self.branches = Data.upgrades.branches
end

function SkillTree:get_node_rect(branch_index, node_index)
  local column_width = aw / #self.branches
  local center_x = column_width * (branch_index - 0.5)
  local y = NODE_START_Y + (node_index - 1) * NODE_GAP
  return center_x - NODE_WIDTH / 2, y, NODE_WIDTH, NODE_HEIGHT
end

function SkillTree:is_inside(x, y, left, top, width, height)
  return x >= left and x <= left + width and
    y >= top and y <= top + height
end

function SkillTree:can_upgrade(branch, node_index)
  local node = branch.nodes[node_index]
  if self.game.star_points <= 0 then return false end
  if self.game.upgrades[node.key] >= node.max then return false end
  if node_index == 1 then return true end
  return self.game.upgrades[branch.nodes[node_index - 1].key] > 0
end

function SkillTree:upgrade(branch, node_index)
  if not self:can_upgrade(branch, node_index) then return false end
  local node = branch.nodes[node_index]
  self.game.star_points = self.game.star_points - 1
  self.game.upgrades[node.key] = self.game.upgrades[node.key] + 1
  return true
end

function SkillTree:draw_branch(branch, branch_index, mouse_x, mouse_y)
  local column_width = aw / #self.branches
  local center_x = column_width * (branch_index - 0.5)
  graphics.set_color(self.colors.accent)
  love.graphics.printf(branch.label, center_x - NODE_WIDTH / 2, 48,
    NODE_WIDTH, "center")

  for node_index, node in ipairs(branch.nodes) do
    local x, y, width, height = self:get_node_rect(branch_index, node_index)
    local level = self.game.upgrades[node.key]
    local unlocked = node_index == 1 or
      self.game.upgrades[branch.nodes[node_index - 1].key] > 0
    local available = self:can_upgrade(branch, node_index)
    local hovered = mouse_x and mouse_y and
      self:is_inside(mouse_x, mouse_y, x, y, width, height)
    local background = hovered and unlocked and self.colors.panel_hover or
      self.colors.panel_card
    local border = available and self.colors.accent or self.colors.border
    if level >= node.max then border = self.colors.gold end

    if node_index > 1 then
      graphics.line(center_x, y - NODE_GAP + NODE_HEIGHT,
        center_x, y, unlocked and self.colors.accent or self.colors.border, 1)
    end
    graphics.rectangle(x + width / 2, y + height / 2,
      width, height, 2, 2, background)
    graphics.set_color(border)
    graphics.rectangle(x + width / 2, y + height / 2,
      width, height, 2, 2, nil, 1)
    graphics.set_color(unlocked and self.colors.foreground or
      graphics.color_with_alpha(self.colors.foreground, 0.3))
    love.graphics.print(node.label, x + 8, y + 6)
    graphics.set_color(level >= node.max and self.colors.gold or border)
    love.graphics.printf(level .. "/" .. node.max,
      x + width - 38, y + 6, 30, "right")
    graphics.set_color(self.colors.muted)
    local hint = node_index == 1 and "ROOT" or
      (unlocked and "CONNECTED" or "LOCKED")
    love.graphics.print(hint, x + 8, y + 19)
  end
end

function SkillTree:draw(mouse_x, mouse_y)
  love.graphics.push("all")
  graphics.rectangle(aw / 2, ah / 2, aw, ah, nil, nil,
    self.colors.background)
  love.graphics.setFont(self.game.ui_font)
  graphics.set_color(self.colors.foreground)
  love.graphics.print("CONSTELLATION", 12, 9)
  love.graphics.setFont(self.font)
  graphics.set_color(self.colors.gold)
  love.graphics.printf("STAR POINTS  " .. self.game.star_points,
    aw - 150, 12, 138, "right")
  graphics.set_color(self.colors.muted)
  love.graphics.printf("SCORE " .. string.format("%06d", self.game.score) ..
    "   EARNED +" .. self.game.run_star_points,
    0, 31, aw, "center")

  for branch_index, branch in ipairs(self.branches) do
    self:draw_branch(branch, branch_index, mouse_x, mouse_y)
  end

  local button_x, button_width, button_height = aw / 2 - 70, 140, 24
  local hovered = mouse_x and mouse_y and self:is_inside(
    mouse_x, mouse_y, button_x, START_BUTTON_Y, button_width, button_height)
  graphics.rectangle(aw / 2, START_BUTTON_Y + button_height / 2,
    button_width, button_height, 2, 2,
    hovered and self.colors.panel_hover or self.colors.background_light)
  graphics.set_color(hovered and self.colors.accent or self.colors.border)
  graphics.rectangle(aw / 2, START_BUTTON_Y + button_height / 2,
    button_width, button_height, 2, 2, nil, 1)
  graphics.set_color(self.colors.foreground)
  love.graphics.printf("ENTER  NEW STAR", button_x,
    START_BUTTON_Y + 8, button_width, "center")
  love.graphics.pop()
end

function SkillTree:mousepressed(x, y)
  for branch_index, branch in ipairs(self.branches) do
    for node_index in ipairs(branch.nodes) do
      local left, top, width, height =
        self:get_node_rect(branch_index, node_index)
      if self:is_inside(x, y, left, top, width, height) then
        return self:upgrade(branch, node_index)
      end
    end
  end

  if self:is_inside(x, y, aw / 2 - 70, START_BUTTON_Y, 140, 24) then
    self.game:reset_run()
    return true
  end
  return false
end
