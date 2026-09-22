Arena = Object:extend()

function Arena:init(game)
  self.game = game
  self.colors = game.colors
  self.spawn_interval = EnemyConfig.spawn_interval
  self.spawn_timer = EnemyConfig.opening_spawn_interval
  self.spawn_wave_index = 0
  self.max_enemies = EnemyConfig.max_enemies
  self.player = Player{
    x = aw / 2,
    y = ah / 2,
    camera = game.camera,
    audio = game.audio,
    upgrades = game.upgrades,
  }
  self.shockwave_charge = 0
  self.shockwave_charging = false
  self.shockwave_charge_time = 0
  self.player.on_projectile_bounce = function(kind, enemy)
    if kind == "enemy" then
      local charge_level = game.upgrades.shockwave_charge or 0
      local charge = enemy and enemy.is_boss and
        Data.player.shockwave_boss_charge + charge_level *
          Data.upgrades.shockwave_boss_charge_per_level or
        Data.player.shockwave_enemy_charge + charge_level *
          Data.upgrades.shockwave_enemy_charge_per_level
      self:add_shockwave_charge(charge)
    end
  end
  self.projectiles = Group()
  self.effects = Group()
  self.enemies = Group{on_remove = function(enemy)
    self:on_enemy_removed(enemy)
  end}
  self.pending_fissions = {}
end

function Arena:start()
  self:spawn_enemy_wave()
end

function Arena:get_spawn_slot_count()
  return math.max(1, math.floor(EnemyConfig.spawn_angular_slots or 1))
end

function Arena:wave_has_enemy(slot)
  local gap_period = math.floor(EnemyConfig.spawn_gap_period or 0)
  if gap_period <= 1 then return true end
  return (slot + self.spawn_wave_index * 3) %
    gap_period ~= 0
end

function Arena:get_spawn_position(slot)
  local outside = EnemyConfig.spawn_outside_margin
  local step = math.pi * 2 / self:get_spawn_slot_count()
  local phase = self.spawn_wave_index % 2 * step / 2
  local angle = slot * step + phase + math.sin(
    slot * 0.73 + self.spawn_wave_index * 1.7) *
      EnemyConfig.spawn_angle_jitter
  local cosine, sine = math.cos(angle), math.sin(angle)
  local horizontal = (aw / 2 + outside) /
    math.max(math.abs(cosine), 0.0001)
  local vertical = (ah / 2 + outside) /
    math.max(math.abs(sine), 0.0001)
  local radius = math.min(horizontal, vertical)
  return self.player.x + cosine * radius,
    self.player.y + sine * radius, angle, radius
end

function Arena:spawn_enemy(slot, formation_duration)
  if #self.enemies >= self.max_enemies then return end

  local x, y, angle, radius = self:get_spawn_position(slot)
  return self:add_enemy(x, y, {
    formation_angle = angle,
    formation_radius = radius,
    formation_start_radius = radius,
    formation_target_radius = EnemyConfig.spawn_circle_radius,
    formation_duration = formation_duration,
    formation_time = 0,
  })
end

function Arena:spawn_enemy_wave()
  local radius_sum, count = 0, 0
  for slot = 0, self:get_spawn_slot_count() - 1 do
    if self:wave_has_enemy(slot) then
      local _, _, _, radius = self:get_spawn_position(slot)
      radius_sum = radius_sum + radius
      count = count + 1
    end
  end
  if count == 0 then return 0 end
  local formation_duration = math.max(
    (radius_sum / count - EnemyConfig.spawn_circle_radius) /
      self:get_enemy_speed(), 0.01)
  local spawned = 0
  for slot = 0, self:get_spawn_slot_count() - 1 do
    if self:wave_has_enemy(slot) then
      local enemy = self:spawn_enemy(slot, formation_duration)
      if enemy then spawned = spawned + 1 end
    end
  end
  self.spawn_wave_index = self.spawn_wave_index + 1
  return spawned
end

function Arena:get_enemy_growth()
  local difficulty = self.game.difficulty_level
  local late_levels = math.max(
    difficulty - EnemyConfig.late_growth_start_level, 0)
  local upgrades = self.game.upgrades
  local direct_damage_bonus = math.max(
    self.player.base_projectile_hit_power -
      Data.player.projectile_hit_power, 0)
  local blast_damage_bonus = (upgrades.blast_damage or 0) *
    Data.upgrades.blast_damage_per_level
  local player_power_bonus = math.floor(
    math.max(direct_damage_bonus, blast_damage_bonus) *
      EnemyConfig.player_damage_hits_ratio +
    (upgrades.ball_count or 0) * EnemyConfig.player_ball_hits_ratio)
  return {
    hits_bonus = math.floor(
      difficulty / EnemyConfig.difficulty_levels_per_hit) + math.floor(
        late_levels * EnemyConfig.late_hits_per_level) + player_power_bonus,
    player_power_bonus = player_power_bonus,
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

function Arena:get_enemy_speed(growth, haste)
  growth = growth or self:get_enemy_growth()
  haste = haste or self.game.enemy_traits.haste
  return EnemyConfig.move_speed * growth.speed_multiplier *
    (1 + math.min(haste * EnemyConfig.haste_per_level,
      EnemyConfig.haste_max_bonus))
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
    v = overrides.v or self:get_enemy_speed(growth, haste),
    contact_damage = overrides.contact_damage or EnemyConfig.contact_damage +
      growth.contact_damage_bonus,
    pressure_speed_bonus = overrides.pressure_speed_bonus or
      growth.pressure_speed_bonus,
    base_score = overrides.base_score or growth.score_bonus +
      EnemyConfig.base_score + haste * EnemyConfig.haste_score +
      armor * EnemyConfig.armor_score + fission * EnemyConfig.fission_score,
    fission = overrides.fission == nil and fission > 0 or overrides.fission,
    formation_angle = overrides.formation_angle,
    formation_radius = overrides.formation_radius,
    formation_start_radius = overrides.formation_start_radius,
    formation_target_radius = overrides.formation_target_radius,
    formation_duration = overrides.formation_duration,
    formation_time = overrides.formation_time,
    color = self.colors.enemy,
    hit_color = self.colors.foreground,
    effects = self.effects,
    audio = self.game.audio,
  })
end

function Arena:spawn_boss(level)
  if #self.enemies >= self.max_enemies then return end
  level = level or 1
  local side = love.math.random(1, 4)
  local outside = math.max(
    EnemyConfig.spawn_outside_margin, EnemyConfig.boss_size / 2 + 4)
  local corner = EnemyConfig.spawn_corner_margin
  local x, y
  if side == 1 then
    x, y = -outside, love.math.random(corner, ah - corner)
  elseif side == 2 then
    x, y = aw + outside, love.math.random(corner, ah - corner)
  elseif side == 3 then
    x, y = love.math.random(corner, aw - corner), -outside
  else
    x, y = love.math.random(corner, aw - corner), ah + outside
  end

  local boss_growth = level - 1
  return self.enemies:add(Enemy{
    x = x,
    y = y,
    width = EnemyConfig.boss_size,
    height = EnemyConfig.boss_size,
    max_hits = EnemyConfig.boss_hits +
      boss_growth * EnemyConfig.boss_hits_per_level +
      boss_growth * boss_growth * EnemyConfig.boss_hits_quadratic +
      self:get_enemy_growth().player_power_bonus *
        EnemyConfig.boss_player_power_multiplier,
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
    hit_color = self.colors.boss,
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
  if self:spawn_boss(level) then self.game.pending_boss_level = nil end
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

  if self:spawn_enemy_wave() > 0 then
    self.spawn_timer = self:get_spawn_interval()
  end
end

function Arena:get_spawn_interval()
  local opening_progress = math.min(
    self.game.elapsed_time / EnemyConfig.opening_duration, 1)
  local base_interval = EnemyConfig.opening_spawn_interval +
    (self.spawn_interval - EnemyConfig.opening_spawn_interval) *
      opening_progress
  local difficulty_interval = base_interval *
    (1 - self.game.difficulty_level *
      EnemyConfig.difficulty_spawn_reduction_per_level)
  local spacing_interval = EnemyConfig.spawn_spacing /
    self:get_enemy_speed()
  return math.max(EnemyConfig.min_spawn_interval,
    difficulty_interval, spacing_interval)
end

function Arena:update(dt, aim_x, aim_y)
  if self.game.state ~= "playing" then return end
  self:update_shockwave_charge(dt)
  self.player:update(dt)
  self:update_enemy_spawning(dt)

  self.enemies:update(dt, self.player, self.enemies)
  if self.player.dead then
    self.game:fail()
    self.enemies:remove_dead()
    return
  end
  local active_projectiles = #self.projectiles
  self.projectiles:update(dt, self.enemies)
  if active_projectiles > 0 and #self.projectiles == 0 then
    self.player:on_volley_ready()
  end
  self.effects:update(dt, self.enemies)
  self.enemies:remove_dead()
  self:spawn_pending_boss()
  self:spawn_pending_fissions()

end

local function smoothstep(value)
  local clamped = math.max(0, math.min(value, 1))
  return clamped * clamped * (3 - 2 * clamped)
end

function Arena:start_death_transition()
  self:cancel_shockwave_charge()
  local player = self.player
  local max_distance = math.sqrt((aw / 2) ^ 2 + (ah / 2) ^ 2)
  self.death_burst_started = false
  for _, enemy in ipairs(self.enemies) do
    local dx, dy = enemy.x - player.x, enemy.y - player.y
    local distance = math.sqrt(dx * dx + dy * dy)
    enemy.death_distance = distance
    enemy.death_angle = distance > 0 and math.atan2(dy, dx) or
      love.math.random() * math.pi * 2
    enemy.death_order = math.min(distance / max_distance, 1)
    enemy.death_phase = love.math.random() * math.pi * 2
    enemy.death_offset_x, enemy.death_offset_y = 0, 0
  end
  for _, projectile in ipairs(self.projectiles) do
    projectile.death_start_x = projectile.x
    projectile.death_start_y = projectile.y
  end
  for index = 1, 18 do
    local angle = index / 18 * math.pi * 2 + love.math.random() * 0.18
    self.effects:add(HitParticle{
      x = player.x,
      y = player.y,
      r = angle,
      speed = 75 + love.math.random() * 110,
      duration = 0.32 + love.math.random() * 0.28,
      width = 3 + love.math.random() * 4,
      color = index % 3 == 0 and self.colors.accent or
        self.colors.foreground,
    })
  end
end

function Arena:update_death_transition(progress, dt)
  local player = self.player
  local hit_stop_ratio = Data.rules.death_hit_stop /
    Data.rules.death_transition_duration
  local motion_progress = math.max(0,
    (progress - hit_stop_ratio) / (1 - hit_stop_ratio))
  local pull = smoothstep(motion_progress / Data.rules.death_pull_end)
  for _, projectile in ipairs(self.projectiles) do
    projectile.x = projectile.death_start_x +
      (player.x - projectile.death_start_x) * pull
    projectile.y = projectile.death_start_y +
      (player.y - projectile.death_start_y) * pull
  end

  if motion_progress >= Data.rules.death_pull_end and
      not self.death_burst_started then
    self.death_burst_started = true
    self.projectiles:clear()
    self.game.camera:spring_shake(5.5, 0)
    self.game.audio:play("death_burst")
    for index = 1, 24 do
      local angle = love.math.random() * math.pi * 2
      self.effects:add(HitParticle{
        x = player.x,
        y = player.y,
        r = angle,
        speed = 120 + love.math.random() * 150,
        duration = 0.22 + love.math.random() * 0.24,
        width = 4 + love.math.random() * 5,
        color = index % 4 == 0 and self.colors.accent or
          self.colors.foreground,
      })
    end
  end

  for _, enemy in ipairs(self.enemies) do
    if enemy.death_distance then
      local scale
      local sway = 0
      local wave = 0
      if motion_progress < Data.rules.death_pull_end then
        scale = 1 - pull * 0.22
      else
        wave = smoothstep((motion_progress - Data.rules.death_pull_end -
          enemy.death_order * Data.rules.death_wave_delay) /
            Data.rules.death_wave_duration)
        scale = 0.78 + (Data.rules.death_wave_scale - 0.78) * wave
        sway = math.sin(wave * math.pi) * Data.rules.death_wave_sway *
          math.sin(enemy.death_phase + wave * 5)
      end
      local cosine, sine = math.cos(enemy.death_angle),
        math.sin(enemy.death_angle)
      local target_x = player.x + cosine * enemy.death_distance * scale -
        sine * sway
      local target_y = player.y + sine * enemy.death_distance * scale +
        cosine * sway
      enemy.death_offset_x = target_x - enemy.x
      enemy.death_offset_y = target_y - enemy.y
      enemy.death_scale = motion_progress < Data.rules.death_pull_end and
        1 - pull * 0.14 or 1 + math.sin(wave * math.pi) * 0.42
      enemy.death_rotation = math.sin(enemy.death_phase) * wave * 1.1
    end
  end
  if motion_progress > 0 then self.effects:update(dt, self.enemies) end
end

function Arena:draw_crosshair(mouse_x, mouse_y)
  if not mouse_x then return end
  love.graphics.push("all")
  local color = #self.projectiles > 0 and self.colors.accent or
    (self:get_aimed_enemy(mouse_x, mouse_y) and
      self.colors.gold or self.colors.foreground)
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

function Arena:get_total_momentum()
  local momentum = 0
  for _, projectile in ipairs(self.projectiles) do
    momentum = momentum + projectile.momentum
  end
  return momentum
end

function Arena:add_shockwave_charge(amount)
  self.shockwave_charge = math.min(
    self.shockwave_charge + (amount or 1),
    Data.player.shockwave_charge_max)
  return self.shockwave_charge
end

function Arena:is_shockwave_ready()
  return self.shockwave_charge >= Data.player.shockwave_charge_max
end

function Arena:get_shockwave_power()
  return math.min(self.shockwave_charge_time /
    Data.player.shockwave_charge_duration, 1)
end

function Arena:start_shockwave_charge()
  if not self:is_shockwave_ready() or self.shockwave_charging then return false end
  self.shockwave_charging = true
  self.shockwave_charge_time = 0
  return true
end

function Arena:cancel_shockwave_charge()
  self.shockwave_charging = false
  self.shockwave_charge_time = 0
end

function Arena:update_shockwave_charge(dt)
  if not self.shockwave_charging then return end
  self.shockwave_charge_time = math.min(
    self.shockwave_charge_time + dt,
    Data.player.shockwave_charge_duration)
end

function Arena:release_shockwave()
  if not self.shockwave_charging then return false end
  return self:activate_shockwave(self:get_shockwave_power())
end

function Arena:get_shockwave_stats(power)
  power = math.max(0, math.min(power or 0, 1))
  local radius_bonus = (self.game.upgrades.shockwave_radius or 0) *
    Data.upgrades.shockwave_radius_per_level
  local damage_bonus = (self.game.upgrades.shockwave_damage or 0) *
    Data.upgrades.shockwave_damage_per_level
  local radius = Data.player.shockwave_base_radius +
    (Data.player.shockwave_max_radius - Data.player.shockwave_base_radius) *
      power + radius_bonus
  local damage = math.floor(Data.player.shockwave_base_damage +
    (Data.player.shockwave_max_damage - Data.player.shockwave_base_damage) *
      power + damage_bonus + 0.5)
  return radius, damage
end

function Arena:activate_shockwave(power)
  if not self:is_shockwave_ready() then return false end

  self.shockwave_charge = 0
  self.shockwave_charging = false
  self.shockwave_charge_time = 0
  local player = self.player
  local radius, damage = self:get_shockwave_stats(power)
  for _, enemy in ipairs(self.enemies) do
    local dx, dy = enemy.x - player.x, enemy.y - player.y
    local reach = radius + math.max(enemy.width, enemy.height) / 2
    if not enemy.dead and dx * dx + dy * dy <= reach * reach then
      enemy:hit(damage, {score_bonus = 0})
    end
  end
  self.enemies:remove_dead()
  self.effects:add(ShockwavePulse{
    x = player.x,
    y = player.y,
    radius = radius,
    power = power or 0,
  })
  if self.game.audio then self.game.audio:play("shockwave") end
  if self.game.camera then self.game.camera:spring_shake(2.2, 0) end
  return true
end

function Arena:get_blast_stats(projectile)
  local momentum = projectile and projectile.momentum or 0
  local momentum_step = math.max(2,
    Data.player.blast_momentum_per_damage -
      (self.game.upgrades.blast_momentum or 0) *
        Data.upgrades.blast_momentum_step_reduction_per_level)
  local radius = Data.player.blast_base_radius + math.sqrt(momentum) *
    Data.player.blast_radius_per_sqrt_momentum +
    self.game.upgrades.blast_radius * Data.upgrades.blast_radius_per_level
  local damage = Data.player.blast_base_damage +
    self.game.upgrades.blast_damage * Data.upgrades.blast_damage_per_level +
    math.floor(momentum / momentum_step)
  return radius, damage
end

function Arena:draw_blast_previews()
  for _, projectile in ipairs(self.projectiles) do
    local radius = self:get_blast_stats(projectile)
    graphics.circle(projectile.x, projectile.y, radius,
      graphics.color_with_alpha(
        self.colors.accent, Data.player.blast_preview_alpha), 1)
  end
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
  self:draw_blast_previews()
  self.projectiles:draw()
  self.enemies:draw()
  if not self.player.dead then self.player:draw() end
  self.effects:draw()
end

function Arena:mousepressed(x, y)
  return self.player:try_attack(x, y, self.projectiles, self.effects)
end

function Arena:detonate_volley()
  if #self.projectiles == 0 then return false end
  local total_momentum = self:get_total_momentum()
  local blasts = {}
  for _, projectile in ipairs(self.projectiles) do
    local radius, damage = self:get_blast_stats(projectile)
    blasts[#blasts + 1] = {
      x = projectile.x,
      y = projectile.y,
      radius = radius,
      damage = damage,
      score_bonus = math.floor(projectile.momentum / 4),
    }
    projectile.dead = true
  end
  self.projectiles:remove_dead()

  for _, enemy in ipairs(self.enemies) do
    local hit_damage, hit_score_bonus, hit_x, hit_y = 0, 0
    for _, blast in ipairs(blasts) do
      local dx, dy = enemy.x - blast.x, enemy.y - blast.y
      local reach = blast.radius + math.max(enemy.width, enemy.height) / 2
      if dx * dx + dy * dy <= reach * reach and
          (blast.damage > hit_damage or
            blast.damage == hit_damage and
              blast.score_bonus > hit_score_bonus) then
        hit_damage = blast.damage
        hit_score_bonus = blast.score_bonus
        hit_x, hit_y = blast.x, blast.y
      end
    end
    if not enemy.dead and hit_damage > 0 then
      enemy:hit(hit_damage, {score_bonus = hit_score_bonus})
      enemy:spawn_hit_particles(
        math.atan2(enemy.y - hit_y, enemy.x - hit_x) + math.pi,
        self.colors.accent)
    end
  end

  for _, blast in ipairs(blasts) do
    self.effects:add(DetonationBurst(blast))
  end
  if self.game.audio then self.game.audio:play("detonation") end
  if self.game.camera then self.game.camera:spring_shake(2.8, 0) end
  self.player:on_volley_ready()
  return true, total_momentum, blasts
end

function Arena:end_volley()
  if #self.projectiles == 0 then return false end
  for _, projectile in ipairs(self.projectiles) do projectile:shatter() end
  self.projectiles:remove_dead()
  self.player:on_volley_ready()
  return true
end
