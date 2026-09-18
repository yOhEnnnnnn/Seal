BulletType = {
  NORMAL = "normal",
  PIERCE = "pierce",
  BOUNCE = "bounce",
  CHAIN = "chain",
  EMBER = "ember",
  FROST = "frost",
}

Bullets = {
  order = {BulletType.NORMAL, BulletType.PIERCE, BulletType.BOUNCE,
    BulletType.CHAIN, BulletType.EMBER, BulletType.FROST},
  [BulletType.NORMAL] = {
    name = "NORMAL",
    color = {1, 1, 1, 1},
    score_operation = "add",
    score_value = 1,
    starting_amount = 30,
    shop_price = 2,
    shop_amount = 10,
    shop_limit = 5,
  },
  [BulletType.PIERCE] = {
    name = "PIERCE",
    color = {178 / 255, 232 / 255, 221 / 255, 1},
    score_operation = "add",
    score_value = 2,
    pierce = 1,
    shop_price = 5,
    shop_amount = 8,
  },
  [BulletType.BOUNCE] = {
    name = "BOUNCE",
    color = {1, 209 / 255, 102 / 255, 1},
    score_operation = "add",
    score_value = 2,
    bounces = 1,
    shop_price = 5,
    shop_amount = 7,
  },
  [BulletType.CHAIN] = {
    name = "CHAIN",
    color = {138 / 255, 59 / 255, 236 / 255, 1},
    score_operation = "add",
    score_value = 3,
    shop_price = 7,
    shop_amount = 5,
    chain_range = 80,
    on_hit = function(projectile, origin, enemies)
      local range = projectile.definition.chain_range *
        (origin.slow_time and origin.slow_time > 0 and 1.5 or 1)
      local closest, distance_squared = nil, range ^ 2
      for _, enemy in ipairs(enemies) do
        if not enemy.dead and not projectile.hit_enemies[enemy] then
          local dx, dy = enemy.x - origin.x, enemy.y - origin.y
          local distance = dx * dx + dy * dy
          if distance <= distance_squared then
            closest, distance_squared = enemy, distance
          end
        end
      end
      if not closest then return end
      projectile.hit_enemies[closest] = true
      closest:hit(projectile.damage, projectile)
      closest:spawn_hit_particles(
        math.atan2(origin.y - closest.y, origin.x - closest.x), projectile.color)
      projectile.effects:add(ChainLightning{
        x = origin.x, y = origin.y, target_x = closest.x, target_y = closest.y,
        color = projectile.color,
        effects = projectile.effects,
      })
    end,
  },
  [BulletType.EMBER] = {
    name = "EMBER",
    color = {213 / 255, 14 / 255, 61 / 255, 1},
    score_operation = "add",
    score_value = 3,
    shop_price = 12,
    shop_amount = 3,
    place = function(attack)
      attack.effects:add(BurningArea{
        x = attack.x,
        y = attack.y,
        r = love.math.random() * 2 * math.pi,
        size = 96,
        damage = attack.damage,
        source = attack,
        color = attack.color,
      })
    end,
  },
  [BulletType.FROST] = {
    name = "FROST",
    color = {0, 240 / 255, 1, 1},
    score_operation = "add",
    score_value = 2,
    shop_price = 10,
    shop_amount = 3,
    place = function(attack)
      attack.effects:add(FrostArea{
        x = attack.x,
        y = attack.y,
        radius = 60,
        damage = attack.damage,
        source = attack,
        color = attack.color,
      })
    end,
  },
}

-- Apply type defaults once; counters belong to each projectile, not the enum.
function Bullets.initialize(projectile)
  projectile.bullet = projectile.bullet or BulletType.NORMAL
  local definition = assert(Bullets[projectile.bullet], "Unknown bullet type")
  projectile.definition = definition
  projectile.color = projectile.color or definition.color
  projectile.score_operation = projectile.score_operation or definition.score_operation
  projectile.score_value = projectile.score_value or definition.score_value
  projectile.pierce = projectile.pierce or definition.pierce or 0
  projectile.bounces = projectile.bounces or definition.bounces or 0
  projectile.damage_decay = projectile.damage_decay or 1
end

function Bullets.hit(projectile, enemy, enemies)
  enemy:hit(projectile.damage, projectile)
  projectile.hit_enemies[enemy] = true
  enemy:spawn_hit_particles(projectile.r + math.pi, projectile.color)
  if projectile.definition.on_hit then
    projectile.definition.on_hit(projectile, enemy, enemies)
  end
  if projectile.pierce <= 0 then
    projectile.dead = true
  else
    projectile.pierce = projectile.pierce - 1
    projectile.damage = projectile.damage * projectile.damage_decay
  end
end

function Bullets.hit_wall(projectile, hit_x, hit_y)
  if projectile.bounces <= 0 then
    projectile:spawn_wall_impact_particles(hit_x, hit_y)
    projectile.dead = true
    return
  end
  if hit_x then projectile.vx = -projectile.vx end
  if hit_y then projectile.vy = -projectile.vy end
  projectile.r = math.atan2(projectile.vy, projectile.vx)
  projectile.bounces = projectile.bounces - 1
  if projectile.score_operation == "add" then
    projectile.score_value = projectile.score_value + 1
  end
end
