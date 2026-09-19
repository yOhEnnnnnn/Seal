Arena = Object:extend()

function Arena:init(game)
  self.game = game
  self.colors = game.colors
  self.spawn_interval = EnemyConfig.spawn_intervals[game.level] or
    EnemyConfig.spawn_intervals[#EnemyConfig.spawn_intervals]
  self.spawn_timer = self.spawn_interval
  self.next_spawn_side = 1
  self.max_enemies = EnemyConfig.max_enemies
  self.player = Player{
    x = aw / 2,
    y = ah / 2,
    camera = game.camera,
    upgrades = game.upgrades,
  }
  self.projectiles = Group()
  self.effects = Group()
  self.enemies = Group{on_remove = function(enemy)
    self:on_enemy_removed(enemy)
  end}
  self.pending_fissions = {}
end

function Arena:start()
  for _ = 1, EnemyConfig.initial_per_side do
    for side = 1, 4 do self:spawn_enemy(side) end
  end
end

function Arena:spawn_enemy(side)
  if #self.enemies >= self.max_enemies then return end

  local margin = EnemyConfig.spawn_margin
  local corner = EnemyConfig.spawn_corner_margin
  local x, y
  if side == 1 then
    x, y = margin, love.math.random(corner, ah - corner)
  elseif side == 2 then
    x, y = aw - margin, love.math.random(corner, ah - corner)
  elseif side == 3 then
    x, y = love.math.random(corner, aw - corner), margin
  else
    x, y = love.math.random(corner, aw - corner), ah - margin
  end

  self:add_enemy(x, y)
end

function Arena:add_enemy(x, y, overrides)
  if #self.enemies >= self.max_enemies then return end
  overrides = overrides or {}
  local traits = self.game.enemy_traits
  local armor = traits.armor
  local haste = traits.haste
  local fission = traits.fission
  return self.enemies:add(Enemy{
    x = x,
    y = y,
    max_hp = overrides.max_hp or EnemyConfig.max_hp +
      math.min(armor * EnemyConfig.armor_hp_per_level, EnemyConfig.armor_max_hp_bonus),
    hp = overrides.hp,
    v = overrides.v or EnemyConfig.move_speed *
      (1 + math.min(haste * EnemyConfig.haste_per_level,
        EnemyConfig.haste_max_bonus)),
    damage = overrides.damage or EnemyConfig.damage,
    def = 0,
    base_score = overrides.base_score or
      EnemyConfig.base_score + haste * EnemyConfig.haste_score +
      armor * EnemyConfig.armor_score + fission * EnemyConfig.fission_score,
    fission = overrides.fission == nil and fission > 0 or overrides.fission,
    color = self.colors.enemy,
    hit_color = self.colors.foreground,
    effects = self.effects,
  })
end

function Arena:on_enemy_removed(enemy)
  if enemy.reached_center then return end
  self.game:enemy_killed(enemy)
  if enemy.fission and self.game.state == "playing" then
    self.pending_fissions[#self.pending_fissions + 1] = enemy
  end
end

function Arena:spawn_pending_fissions()
  if self.game.state ~= "playing" then
    self.pending_fissions = {}
    return
  end
  local margin = EnemyConfig.spawn_margin
  for _, parent in ipairs(self.pending_fissions) do
    local child_hp = math.max(1, parent.max_hp * EnemyConfig.fission_hp_ratio)
    for direction = -1, 1, 2 do
      self:add_enemy(
        math.max(margin, math.min(aw - margin,
          parent.x + direction * EnemyConfig.fission_offset_x)),
        math.max(margin, math.min(ah - margin,
          parent.y + direction * EnemyConfig.fission_offset_y)), {
          max_hp = child_hp,
          hp = child_hp,
          v = parent.v,
          damage = parent.damage,
          base_score = EnemyConfig.base_score,
          fission = false,
        })
    end
  end
  self.pending_fissions = {}
end

function Arena:update_enemy_spawning(dt)
  if self.game.state ~= "playing" then return end

  self.spawn_timer = math.max(self.spawn_timer - dt, 0)
  if self.spawn_timer > 0 or #self.enemies >= self.max_enemies then return end

  self:spawn_enemy(self.next_spawn_side)
  self.next_spawn_side = self.next_spawn_side % 4 + 1
  self.spawn_timer = self.spawn_interval *
    (1 - self.game.danger_level * Data.rules.danger.spawn_reduction_per_level)
end

function Arena:get_nearest_enemy()
  local player = self.player
  local nearest, nearest_distance
  for _, enemy in ipairs(self.enemies) do
    if not enemy.dead then
      local dx, dy = enemy.x - player.x, enemy.y - player.y
      local distance = dx * dx + dy * dy
      if not nearest_distance or distance < nearest_distance then
        nearest, nearest_distance = enemy, distance
      end
    end
  end
  return nearest
end

function Arena:update(dt, aim_x, aim_y)
  if self.game.state ~= "playing" then return end
  self.player:update(dt)
  if self.player.auto_attack then
    local target = self:get_nearest_enemy()
    if target then
      self.player:try_attack(
        target.x, target.y, self.projectiles, self.effects)
    end
  end
  self:update_enemy_spawning(dt)

  self.enemies:update(dt, self.player, self.enemies)
  if self.player.dead then self.game:fail() end
  self.projectiles:update(dt, self.enemies)
  self.effects:update(dt, self.enemies)
  self.enemies:remove_dead()
  self:spawn_pending_fissions()

  if self.game.state ~= "playing" then
    self.enemies:clear()
    self.projectiles:clear()
    self.effects:clear()
  end
end

function Arena:draw_crosshair(mouse_x, mouse_y)
  if not mouse_x then return end
  love.graphics.push("all")
  local color = self.colors.foreground
  love.graphics.setColor(color[1], color[2], color[3], 0.9)
  love.graphics.setLineWidth(1)
  local half, corner = 6, 3
  love.graphics.line(mouse_x - half, mouse_y - half,
    mouse_x - half + corner, mouse_y - half)
  love.graphics.line(mouse_x - half, mouse_y - half,
    mouse_x - half, mouse_y - half + corner)
  love.graphics.line(mouse_x + half, mouse_y - half,
    mouse_x + half - corner, mouse_y - half)
  love.graphics.line(mouse_x + half, mouse_y - half,
    mouse_x + half, mouse_y - half + corner)
  love.graphics.line(mouse_x - half, mouse_y + half,
    mouse_x - half + corner, mouse_y + half)
  love.graphics.line(mouse_x - half, mouse_y + half,
    mouse_x - half, mouse_y + half - corner)
  love.graphics.line(mouse_x + half, mouse_y + half,
    mouse_x + half - corner, mouse_y + half)
  love.graphics.line(mouse_x + half, mouse_y + half,
    mouse_x + half, mouse_y + half - corner)
  love.graphics.pop()
end

function Arena:draw(mouse_x, mouse_y)
  self:draw_crosshair(mouse_x, mouse_y)
  self.projectiles:draw()
  self.enemies:draw()
  self.player:draw()
  self.effects:draw()
end

function Arena:mousepressed(x, y)
  self.player:try_attack(x, y, self.projectiles, self.effects)
end
