Arena = Object:extend()

function Arena:init(game)
  self.game = game
  self.colors = game.colors
  self.spawn_interval = math.max(0.6, 0.8 - (game.level - 1) * 0.1)
  self.spawn_timer = self.spawn_interval
  self.next_spawn_side = 1
  self.max_enemies = 80
  self.player = Player{
    x = gw / 2,
    y = gh / 2,
    inventory = game.inventory,
    camera = game.camera,
  }
  self.projectiles = Group()
  self.effects = Group()
  self.enemies = Group{on_remove = function(enemy)
    self:on_enemy_removed(enemy)
  end}
  self.pending_fissions = {}
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
    max_hp = overrides.max_hp or 10 + math.min(armor * 4, 10),
    hp = overrides.hp,
    v = overrides.v or 21 * (1 + math.min(haste * 0.1, 0.3)),
    damage = overrides.damage or 8,
    def = 0,
    base_score = overrides.base_score or
      1 + haste + armor * 2 + fission * 3,
    fission = overrides.fission == nil and fission > 0 or overrides.fission,
    color = self.colors.enemy,
    hit_color = self.colors.foreground,
    hp_bar_background = self.colors.hp_bar_background,
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
  for _, parent in ipairs(self.pending_fissions) do
    local child_hp = math.max(1, parent.max_hp / 2)
    for direction = -1, 1, 2 do
      self:add_enemy(
        math.max(9, math.min(gw - 9, parent.x + direction * 5)),
        math.max(9, math.min(gh - 9, parent.y + direction * 3)), {
          max_hp = child_hp,
          hp = child_hp,
          v = parent.v,
          damage = parent.damage,
          base_score = 1,
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
    (1 - self.game.danger_level * 0.1)
end

function Arena:update(dt)
  if self.game.state ~= "playing" then return end
  self.player:update(dt)
  self:update_enemy_spawning(dt)

  self.enemies:update(dt, self.player, self.enemies)
  if self.player.dead then self.game:fail() end
  self.projectiles:update(dt, self.enemies)
  self.effects:update(dt, self.enemies)
  -- Settle this frame's kills before checking whether ammunition ran out.
  self.enemies:remove_dead()
  self:spawn_pending_fissions()

  local active_attack = false
  for _, effect in ipairs(self.effects) do
    if effect.can_damage then active_attack = true break end
  end
  if not self.game.can_extract and self.game.inventory:get_count() == 0 and
    #self.projectiles == 0 and not active_attack then
    self.game:fail()
  end

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
