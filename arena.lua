Arena = Object:extend()

function Arena:init(game)
  self.game = game
  self.colors = game.colors
  self.spawn_interval = EnemyConfig.spawn_interval
  self.spawn_timer = EnemyConfig.opening_spawn_interval
  self.next_spawn_side = 1
  self.max_enemies = EnemyConfig.max_enemies
  self.player = Player{
    x = aw / 2,
    y = ah / 2,
    camera = game.camera,
    audio = game.audio,
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

function Arena:get_enemy_growth()
  local difficulty = self.game.difficulty_level
  local late_levels = math.max(
    difficulty - EnemyConfig.late_growth_start_level, 0)
  local player_damage_bonus = 0
  if late_levels > 0 then
    player_damage_bonus = math.floor(math.max(
      self.player.base_projectile_hit_power -
        Data.player.projectile_hit_power, 0) *
      EnemyConfig.player_damage_hits_ratio)
  end
  return {
    hits_bonus = math.floor(
      difficulty / EnemyConfig.difficulty_levels_per_hit) + math.floor(
        late_levels * EnemyConfig.late_hits_per_level) + player_damage_bonus,
    speed_multiplier = 1 + math.min(
      difficulty * EnemyConfig.difficulty_speed_per_level,
      EnemyConfig.difficulty_speed_max_bonus),
    contact_damage_bonus = math.min(
      difficulty * EnemyConfig.difficulty_contact_damage_per_level,
      EnemyConfig.difficulty_contact_damage_max_bonus),
    score_bonus = math.floor(
      difficulty / EnemyConfig.difficulty_score_levels_per_point),
    pressure_speed_bonus = math.min(
      late_levels * EnemyConfig.pressure_speed_per_level,
      EnemyConfig.pressure_speed_max_bonus),
  }
end

function Arena:get_base_enemy_hits()
  local progress = math.min(
    self.game.elapsed_time / EnemyConfig.opening_duration, 1)
  return EnemyConfig.opening_max_hits + math.floor(
    progress * (EnemyConfig.max_hits - EnemyConfig.opening_max_hits))
end

function Arena:add_enemy(x, y, overrides)
  if #self.enemies >= self.max_enemies then return end
  overrides = overrides or {}
  local growth = self:get_enemy_growth()
  local traits = self.game.enemy_traits
  local armor = traits.armor
  local haste = traits.haste
  local fission = traits.fission
  return self.enemies:add(Enemy{
    x = x,
    y = y,
    max_hits = overrides.max_hits or self:get_base_enemy_hits() +
      growth.hits_bonus + math.min(
        armor * EnemyConfig.armor_hits_per_level,
        EnemyConfig.armor_max_hits_bonus),
    hits_remaining = overrides.hits_remaining,
    v = overrides.v or EnemyConfig.move_speed * growth.speed_multiplier *
      (1 + math.min(haste * EnemyConfig.haste_per_level,
        EnemyConfig.haste_max_bonus)),
    contact_damage = overrides.contact_damage or EnemyConfig.contact_damage +
      growth.contact_damage_bonus,
    pressure_speed_bonus = overrides.pressure_speed_bonus or
      growth.pressure_speed_bonus,
    base_score = overrides.base_score or growth.score_bonus +
      EnemyConfig.base_score + haste * EnemyConfig.haste_score +
      armor * EnemyConfig.armor_score + fission * EnemyConfig.fission_score,
    fission = overrides.fission == nil and fission > 0 or overrides.fission,
    color = self.colors.enemy,
    hit_color = self.colors.foreground,
    effects = self.effects,
    audio = self.game.audio,
  })
end

function Arena:spawn_boss(level)
  level = level or 1
  local side = love.math.random(1, 4)
  local margin = math.max(
    EnemyConfig.spawn_margin, EnemyConfig.boss_size / 2 + 1)
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

  local boss_growth = level - 1
  return self.enemies:add(Enemy{
    x = x,
    y = y,
    width = EnemyConfig.boss_size,
    height = EnemyConfig.boss_size,
    max_hits = EnemyConfig.boss_hits +
      boss_growth * EnemyConfig.boss_hits_per_level +
      boss_growth * boss_growth * EnemyConfig.boss_hits_quadratic,
    v = EnemyConfig.move_speed * EnemyConfig.boss_speed_multiplier *
      (1 + math.min(boss_growth * EnemyConfig.boss_speed_per_level,
        EnemyConfig.boss_speed_max_bonus)),
    contact_damage = math.min(
      EnemyConfig.boss_contact_damage +
        boss_growth * EnemyConfig.boss_contact_damage_per_level,
      EnemyConfig.boss_contact_damage_max),
    base_score = EnemyConfig.boss_score +
      (level - 1) * EnemyConfig.boss_score_per_level,
    is_boss = true,
    color = self.colors.enemy,
    hit_color = self.colors.gold,
    effects = self.effects,
    audio = self.game.audio,
  })
end

function Arena:has_boss()
  for _, enemy in ipairs(self.enemies) do
    if enemy.is_boss and not enemy.dead then return true end
  end
  return false
end

function Arena:spawn_pending_boss()
  local level = self.game.pending_boss_level
  if not level then return end
  self.game.pending_boss_level = nil
  self:spawn_boss(level)
end

function Arena:on_enemy_removed(enemy)
  if enemy.reached_center or enemy.removed_without_reward then return end
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
    local child_hits = math.max(1,
      math.ceil(parent.max_hits * EnemyConfig.fission_hits_ratio))
    for direction = -1, 1, 2 do
      self:add_enemy(
        math.max(margin, math.min(aw - margin,
          parent.x + direction * EnemyConfig.fission_offset_x)),
        math.max(margin, math.min(ah - margin,
          parent.y + direction * EnemyConfig.fission_offset_y)), {
          max_hits = child_hits,
          hits_remaining = child_hits,
          v = parent.v,
          contact_damage = parent.contact_damage,
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

  local spawn_batch = math.min(EnemyConfig.max_spawn_batch,
    1 + math.floor(self.game.difficulty_level /
      EnemyConfig.spawn_batch_levels))
  for _ = 1, spawn_batch do
    if #self.enemies >= self.max_enemies then break end
    self:spawn_enemy(self.next_spawn_side)
    self.next_spawn_side = self.next_spawn_side % 4 + 1
  end
  local opening_progress = math.min(
    self.game.elapsed_time / EnemyConfig.opening_duration, 1)
  local base_interval = EnemyConfig.opening_spawn_interval +
    (self.spawn_interval - EnemyConfig.opening_spawn_interval) *
      opening_progress
  self.spawn_timer = math.max(EnemyConfig.min_spawn_interval,
    base_interval * (1 - self.game.difficulty_level *
      EnemyConfig.difficulty_spawn_reduction_per_level))
end

function Arena:update(dt, aim_x, aim_y)
  if self.game.state ~= "playing" then return end
  self.player:update(dt)
  self:update_enemy_spawning(dt)

  self.enemies:update(dt, self.player, self.enemies)
  if self.player.dead then self.game:fail() end
  self.projectiles:update(dt, self.enemies)
  self.effects:update(dt, self.enemies)
  self.enemies:remove_dead()
  self:spawn_pending_boss()
  self:spawn_pending_fissions()

end

function Arena:start_death_wave()
  self.death_wave_radius = 0
end

function Arena:update_death_wave(dt)
  self.death_wave_radius = self.death_wave_radius +
    Data.rules.death_wave_speed * dt
  local player = self.player
  for _, enemy in ipairs(self.enemies) do
    local dx, dy = enemy.x - player.x, enemy.y - player.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if not enemy.death_wave_hit and distance <= self.death_wave_radius then
      enemy:hit_by_death_wave(dx, dy, distance)
    end
    enemy:update_death_wave(dt)
  end
end

function Arena:revive()
  local player = self.player
  player.dead = false
  player.hp = player.max_hp
  player.hit_time = 0
  player.invincibility_time = Data.rules.revive_invincibility

  local radius_squared = Data.rules.revive_clear_radius ^ 2
  for _, enemy in ipairs(self.enemies) do
    local dx, dy = enemy.x - player.x, enemy.y - player.y
    if dx * dx + dy * dy <= radius_squared then
      enemy.removed_without_reward = true
      enemy:die()
    end
  end
  self.enemies:remove_dead()
  self.effects:add(RevivePulse{x = player.x, y = player.y})
end

function Arena:draw_crosshair(mouse_x, mouse_y)
  if not mouse_x then return end
  love.graphics.push("all")
  local color = self:get_aimed_enemy(mouse_x, mouse_y) and
    self.colors.gold or self.colors.foreground
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

function Arena:get_aimed_enemy(x, y)
  for _, enemy in ipairs(self.enemies) do
    if not enemy.dead then
      local dx, dy = x - enemy.x, y - enemy.y
      local cosine, sine = math.cos(enemy.r), math.sin(enemy.r)
      local local_x = dx * cosine + dy * sine
      local local_y = -dx * sine + dy * cosine
      if math.abs(local_x) <= enemy.width / 2 and
        math.abs(local_y) <= enemy.height / 2 then
        return enemy
      end
    end
  end
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
