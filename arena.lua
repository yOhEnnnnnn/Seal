Arena = Object:extend()

function Arena:init(game)
  self.game = game
  self.colors = game.colors
  self.spawn_interval = 0.9
  self.spawn_timer = self.spawn_interval
  self.next_spawn_side = 1
  self.max_enemies = 60
  self.player = Player{
    x = gw / 2,
    y = gh / 2,
    inventory = game.inventory,
    camera = game.camera,
  }
  self.projectiles = Group()
  self.effects = Group()
  self.enemies = Group{on_remove = function(enemy)
    if not enemy.reached_center then game:enemy_killed() end
  end}
end

function Arena:start()
  for side = 1, 4 do self:spawn_enemy(side) end
end

function Arena:spawn_enemy(side)
  if #self.enemies >= self.max_enemies then return end

  local margin = 9
  local x, y
  if side == 1 then
    x, y = margin, love.math.random(18, gh - 18)
  elseif side == 2 then
    x, y = gw - margin, love.math.random(18, gh - 18)
  elseif side == 3 then
    x, y = love.math.random(18, gw - 18), margin
  else
    x, y = love.math.random(18, gw - 18), gh - margin
  end

  self.enemies:add(Enemy{
    x = x,
    y = y,
    color = self.colors.red,
    hit_color = self.colors.foreground,
    hp_bar_background = self.colors.hp_bar_background,
    effects = self.effects,
  })
end

function Arena:update_enemy_spawning(dt)
  if self.game.state ~= "playing" then return end

  self.spawn_timer = math.max(self.spawn_timer - dt, 0)
  if self.spawn_timer > 0 or #self.enemies >= self.max_enemies then return end

  self:spawn_enemy(self.next_spawn_side)
  self.next_spawn_side = self.next_spawn_side % 4 + 1
  self.spawn_timer = self.spawn_interval
end

function Arena:update(dt)
  if self.game.state ~= "playing" then return end
  self.player:update(dt)
  self:update_enemy_spawning(dt)

  self.enemies:update(dt, self.player, self.enemies)
  self.projectiles:update(dt, self.enemies)
  self.effects:update(dt, self.enemies)
  -- Settle this frame's kills before checking whether ammunition ran out.
  self.enemies:remove_dead()

  if self.game.inventory:get_count() == 0 and #self.projectiles == 0 then
    self.game:fail()
  end

  if self.game.state ~= "playing" then
    self.enemies:clear()
    self.projectiles:clear()
    self.effects:clear()
  end
end

function Arena:draw_aim_ray(mouse_x, mouse_y)
  if not mouse_x then return end

  local dx, dy = mouse_x - self.player.x, mouse_y - self.player.y
  local length = math.sqrt(dx * dx + dy * dy)
  if length < 0.001 then return end

  dx, dy = dx / length, dy / length
  local distance_x = dx > 0 and (gw - self.player.x) / dx or
    (dx < 0 and -self.player.x / dx or math.huge)
  local distance_y = dy > 0 and (gh - self.player.y) / dy or
    (dy < 0 and -self.player.y / dy or math.huge)
  local ray_length = math.min(distance_x, distance_y)
  local dash_length, gap_length = 6, 5

  love.graphics.push("all")
  local color = self.colors.foreground
  love.graphics.setColor(color[1], color[2], color[3], 0.4)
  love.graphics.setLineWidth(2)
  for distance = self.player.size + 5,
    ray_length, dash_length + gap_length do
    local dash_end = math.min(distance + dash_length, ray_length)
    love.graphics.line(
      self.player.x + dx * distance,
      self.player.y + dy * distance,
      self.player.x + dx * dash_end,
      self.player.y + dy * dash_end)
  end
  love.graphics.pop()
end

function Arena:draw(mouse_x, mouse_y)
  self:draw_aim_ray(mouse_x, mouse_y)
  self.projectiles:draw()
  self.enemies:draw()
  self.player:draw()
  self.effects:draw()
end

function Arena:mousepressed(x, y)
  self.player:try_attack(x, y, self.projectiles, self.effects)
end
