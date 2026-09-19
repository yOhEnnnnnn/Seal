Game = Object:extend()

function Game:init()
  self.colors = Data.theme.colors

  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setBackgroundColor(
    self.colors.background[1], self.colors.background[2],
    self.colors.background[3], self.colors.background[4])
  love.graphics.setLineStyle("rough")
  love.mouse.setVisible(false)

  self.ui_font = love.graphics.newFont(Data.display.ui_font, Data.display.ui_font_size)
  self.ui_font:setFilter("nearest", "nearest")
  self.small_font = love.graphics.newFont(
    Data.display.small_font, Data.display.small_font_size)
  self.small_font:setFilter("nearest", "nearest")
  love.graphics.setFont(self.ui_font)

  self.audio = Audio(Data.audio)

  self.canvas = Canvas(gw, gh)
  self.background_canvas = Canvas(gw, gh)
  self.scene_canvas = Canvas(gw, gh)
  self.shadow_canvas = Canvas(gw, gh)
  self.shadow_shader = love.graphics.newShader("assets/shaders/shadow.frag")
  self.camera = Camera(aw / 2, ah / 2, aw, ah)
  self.draw_background_action = function() self:draw_background_scene() end
  self.draw_scene_action = function() self:draw_scene() end
  self.draw_shadow_action = function() self:draw_shadow() end
  self.draw_composite_action = function() self:draw_composite() end
  self:reset_run()
end

function Game:reset_run()
  self.camera:reset()
  self.elapsed_time = 0
  self.difficulty_level = 0
  self.gold_fraction = 0
  self.score, self.state = 0, "playing"
  self.revive_count = 0
  self.death_transition_time = 0
  self.boss_level = 0
  self.next_boss_score = EnemyConfig.boss_score_base
  self.pending_boss_level = nil
  self.coins = Data.rules.starting_coins
  self.upgrades = {
    gold_gain = 0,
    critical = 0,
    luck = 0,
    hit_power = 0,
    ball_count = 0,
    momentum = 0,
    fire_rate = 0,
  }
  self.enemy_traits = {haste = 0, armor = 0, fission = 0}
  self.arena = Arena(self)
  self.hud = HUD(self)
  self.sidebar = Sidebar(self)
  self.arena:start()
end

function Game:enemy_killed(enemy)
  if self.state ~= "playing" then return false end

  local base_score = enemy and enemy.base_score or 1
  local kill_score = enemy and (enemy.kill_score or base_score) or 1
  self.score = self.score + kill_score

  local gold_multiplier = 1 +
    self.upgrades.gold_gain * Data.upgrades.gold_bonus_per_level
  self.gold_fraction = self.gold_fraction + base_score * gold_multiplier
  local gold = math.floor(self.gold_fraction)
  self.gold_fraction = self.gold_fraction - gold
  self:add_coins(gold)
  self:check_boss_spawn()

  return true
end

function Game:check_boss_spawn()
  if self.score < self.next_boss_score then return end
  if self.pending_boss_level or self.arena:has_boss() then return end
  self.boss_level = self.boss_level + 1
  self.pending_boss_level = self.boss_level
  local next_interval = math.floor(EnemyConfig.boss_score_base *
    EnemyConfig.boss_score_growth ^ self.boss_level + 0.5)
  self.next_boss_score = self.next_boss_score + next_interval
end

function Game:fail()
  if self.state ~= "playing" then return end
  self.state = "dying"
  self.death_transition_time = 0
end

function Game:get_revive_cost()
  return math.floor(Data.rules.revive_base_cost *
    Data.rules.revive_cost_growth ^ self.revive_count + 0.5)
end

function Game:revive()
  if self.state ~= "revive" then return false end
  local cost = self:get_revive_cost()
  if self.coins < cost then return false end
  self.coins = self.coins - cost
  self.revive_count = self.revive_count + 1
  self.arena:revive()
  self.state = "playing"
  return true
end

function Game:is_revive_button(x, y)
  return math.abs(x - aw / 2) <= Data.rules.revive_button_width / 2 and
    math.abs(y - Data.rules.revive_button_y) <=
      Data.rules.revive_button_height / 2
end

function Game:add_coins(amount)
  self.coins = self.coins + math.max(0, math.floor(amount or 0))
end

function Game:update_mouse_cursor()
  local mouse_x = self.canvas:to_canvas_position(love.mouse.getPosition())
  love.mouse.setVisible(self.state ~= "playing" or not mouse_x or mouse_x > aw)
end

function Game:update(dt)
  self:update_mouse_cursor()
  if self.state == "playing" then
    self.elapsed_time = self.elapsed_time + dt
    self.difficulty_level = math.floor(
      self.elapsed_time / EnemyConfig.difficulty_seconds)
    local screen_x, screen_y = self.canvas:to_canvas_position(
      love.mouse.getPosition())
    local aim_x, aim_y
    if screen_x and screen_x <= aw then
      aim_x, aim_y = self.camera:to_world(screen_x, screen_y)
    end
    self.arena:update(dt, aim_x, aim_y)
  elseif self.state == "dying" then
    self.death_transition_time = math.min(
      self.death_transition_time + dt,
      Data.rules.death_transition_duration)
    if self.death_transition_time == Data.rules.death_transition_duration then
      self.state = "revive"
    end
  end
  if self.state == "playing" or self.state == "dying" then self.camera:update(dt)
  else self.camera:reset() end
end

function Game:draw_background()
  graphics.rectangle(
    gw / 2, gh / 2, gw, gh, nil, nil, self.colors.background)
end

function Game:draw_background_scene()
  self:draw_background()
end

function Game:draw_scene()
  local x, y = self.canvas:to_canvas_position(love.mouse.getPosition())
  local world_x, world_y = self.camera:to_world(x, y)

  self.camera:attach()
  self.arena:draw(self.state == "playing" and x and x <= aw and world_x or nil,
    world_y)
  self.camera:detach()

  local death_progress = self.death_transition_time /
    Data.rules.death_transition_duration
  if self.state == "playing" then
    self.hud:draw(x, y)
  elseif self.state == "dying" and death_progress >= 0.5 then
    self.hud:draw_revive(self:get_revive_cost())
  elseif self.state == "revive" then
    self.hud:draw_revive(self:get_revive_cost())
  end
  self.sidebar:draw(x, y)
  if self.state == "dying" then
    self.hud:draw_death_transition(death_progress)
  end
end

function Game:draw_shadow()
  love.graphics.push("all")
  love.graphics.setShader(self.shadow_shader)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.scene_canvas.canvas, 0, 0)
  love.graphics.pop()
end

function Game:draw_composite()
  love.graphics.push("all")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.background_canvas.canvas, 0, 0)
  love.graphics.draw(self.shadow_canvas.canvas, 1.5, 1.5)
  love.graphics.draw(self.scene_canvas.canvas, 0, 0)
  love.graphics.pop()
end

function Game:draw()
  self.background_canvas:draw_to(
    self.draw_background_action, self.colors.background)
  self.scene_canvas:draw_to(self.draw_scene_action)
  self.shadow_canvas:draw_to(self.draw_shadow_action)
  self.canvas:draw_to(self.draw_composite_action)
  self.canvas:draw_to_window()
end

function Game:keypressed(key)
  if key == "escape" then love.event.quit() end
  if key == "r" and self.state == "revive" then
    if not self:revive() then self:reset_run() end
  end
end

function Game:mousepressed(x, y, button)
  if button ~= 1 then return end
  local mouse_x, mouse_y = self.canvas:to_canvas_position(x, y)
  if not mouse_x then return end
  if self.state == "playing" then
    if mouse_x > aw then
      self.sidebar:mousepressed(mouse_x, mouse_y)
      return
    end
    local world_x, world_y = self.camera:to_world(mouse_x, mouse_y)
    self.arena:mousepressed(world_x, world_y)
  elseif self.state == "revive" and self:is_revive_button(mouse_x, mouse_y) then
    self:revive()
  end
end
