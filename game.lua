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
  self.star_points = Data.rules.starting_star_points
  self.upgrades = {}
  for _, branch in ipairs(Data.upgrades.branches) do
    for _, node in ipairs(branch.nodes) do self.upgrades[node.key] = 0 end
  end
  self.skill_tree = SkillTree(self)
  self:reset_run()
end

function Game:reset_run()
  self.camera:reset()
  self:reset_kill_feedback()
  self.elapsed_time = 0
  self.difficulty_level = 0
  self.score, self.state = 0, "playing"
  self.death_transition_time = 0
  self.boss_level = 0
  self.boss_kills = 0
  self.run_star_points = 0
  self.next_star_point_score = Data.rules.star_point_score_step
  self.next_boss_score = EnemyConfig.boss_score_base
  self.pending_boss_level = nil
  self.enemy_traits = {haste = 0, armor = 0, fission = 0}
  self.arena = Arena(self)
  self.hud = HUD(self)
  self.arena:start()
end

function Game:award_star_points(amount)
  amount = math.max(0, math.floor(amount or 0))
  self.star_points = self.star_points + amount
  self.run_star_points = self.run_star_points + amount
  return amount
end

function Game:check_star_point_awards(enemy)
  while self.score >= self.next_star_point_score do
    self:award_star_points(1)
    self.next_star_point_score = self.next_star_point_score +
      Data.rules.star_point_score_step
  end
  if enemy and enemy.is_boss then
    self.boss_kills = self.boss_kills + 1
    self:award_star_points(Data.rules.star_point_boss_bonus)
  end
end

function Game:enemy_killed(enemy)
  if self.state ~= "playing" then return false end

  local base_score = enemy and enemy.base_score or 1
  local kill_score = enemy and (enemy.kill_score or base_score) or 1
  self.score = self.score + kill_score

  self:check_star_point_awards(enemy)
  self:queue_kill_feedback(enemy)
  self:check_boss_spawn()

  return true
end

function Game:reset_kill_feedback()
  self.kill_feedback_count = 0
  self.kill_feedback_weight = 0
  self.kill_feedback_x = 0
  self.kill_feedback_y = 0
  self.kill_feedback_angle = 0
  self.kill_feedback_has_boss = false
end

function Game:queue_kill_feedback(enemy)
  if not enemy or not enemy.x or not enemy.y then return end
  local weight = enemy.is_boss and Data.camera.kill_weight_max or
    math.min(enemy.base_score or 1, Data.camera.kill_weight_max)
  self.kill_feedback_count = self.kill_feedback_count + 1
  self.kill_feedback_weight = self.kill_feedback_weight + weight
  self.kill_feedback_x = self.kill_feedback_x + enemy.x * weight
  self.kill_feedback_y = self.kill_feedback_y + enemy.y * weight
  self.kill_feedback_angle = math.atan2(
    enemy.y - self.arena.player.y, enemy.x - self.arena.player.x)
  self.kill_feedback_has_boss = self.kill_feedback_has_boss or enemy.is_boss
end

function Game:flush_kill_feedback()
  if self.kill_feedback_count == 0 then return end
  local x = self.kill_feedback_x / self.kill_feedback_weight
  local y = self.kill_feedback_y / self.kill_feedback_weight
  local dx, dy = x - self.arena.player.x, y - self.arena.player.y
  local angle = dx * dx + dy * dy > 1 and math.atan2(dy, dx) or
    self.kill_feedback_angle
  local intensity = self.kill_feedback_has_boss and
    Data.camera.boss_kill_recoil or math.min(
      Data.camera.kill_recoil_max,
      Data.camera.kill_recoil_base +
        math.sqrt(self.kill_feedback_weight - 1) *
          Data.camera.kill_recoil_growth)
  self.camera:spring_shake(intensity, angle)
  self:reset_kill_feedback()
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
  self.arena:start_death_transition()
  self.audio:play("death_snap")
end

function Game:update_mouse_cursor()
  local mouse_x = self.canvas:to_canvas_position(love.mouse.getPosition())
  love.mouse.setVisible(self.state ~= "playing" or not mouse_x)
end

function Game:update(dt)
  self:update_mouse_cursor()
  if self.state == "playing" then
    dt = math.min(math.max(dt, 0), Data.rules.max_playing_dt)
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
    self:flush_kill_feedback()
  elseif self.state == "dying" then
    self.death_transition_time = math.min(
      self.death_transition_time + dt,
      Data.rules.death_transition_duration)
    self.arena:update_death_transition(
      self.death_transition_time / Data.rules.death_transition_duration, dt)
    if self.death_transition_time == Data.rules.death_transition_duration then
      self.state = "skill_tree"
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
  if self.state == "skill_tree" then
    self.skill_tree:draw(x, y)
    return
  end
  local world_x, world_y = self.camera:to_world(x, y)

  self.camera:attach()
  self.arena:draw(self.state == "playing" and x and x <= aw and world_x or nil,
    world_y)
  self.camera:detach()

  local death_progress = self.death_transition_time /
    Data.rules.death_transition_duration
  if self.state == "playing" then
    self.hud:draw(x, y)
  elseif self.state == "dying" and
      death_progress >= Data.rules.death_result_start then
    self.hud:draw_death_summary()
  end
  if self.state == "dying" then
    self.hud:draw_death_transition(death_progress)
  end
end

function Game:draw_shadow()
  if self.state == "skill_tree" then return end
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
  if key == "space" and self.state == "playing" then
    self.arena:detonate_volley()
  end
  if key == "q" and self.state == "playing" then
    self.arena:start_shockwave_charge()
  end
  if (key == "return" or key == "r") and self.state == "skill_tree" then
    self:reset_run()
  end
end

function Game:keyreleased(key)
  if key == "q" then
    if self.state == "playing" then
      self.arena:release_shockwave()
    else
      self.arena:cancel_shockwave_charge()
    end
  end
end

function Game:focus(focused)
  if not focused then self.arena:cancel_shockwave_charge() end
end

function Game:mousepressed(x, y, button)
  if button ~= 1 then return end
  local mouse_x, mouse_y = self.canvas:to_canvas_position(x, y)
  if not mouse_x then return end
  if self.state == "playing" then
    local world_x, world_y = self.camera:to_world(mouse_x, mouse_y)
    self.arena:mousepressed(world_x, world_y)
  elseif self.state == "skill_tree" then
    self.skill_tree:mousepressed(mouse_x, mouse_y)
  end
end
