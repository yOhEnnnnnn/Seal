-- Demo 星座技能树；同一分支由上至下解锁。
return {
  hit_power_per_level = 1,
  ball_speed_bonus_per_level = 0.10,
  momentum_decay_delay = 2,
  momentum_decay_per_second = 1,
  momentum_damage_step = 5,
  momentum_speed_per_point = 0.01,
  momentum_speed_bonus_max = 0.6,
  blast_radius_per_level = 4,
  blast_damage_per_level = 1,
  blast_momentum_step_reduction_per_level = 0.5,
  shockwave_enemy_charge_per_level = 2,
  shockwave_boss_charge_per_level = 1,
  shockwave_radius_per_level = 8,
  shockwave_damage_per_level = 1,
  branches = {
    {
      key = "starshot", label = "STARSHOT",
      nodes = {
        {key = "hit_power", label = "IMPACT", max = 3},
        {key = "ball_count", label = "AMMO", max = 3},
        {key = "ball_speed", label = "VELOCITY", max = 3},
      },
    },
    {
      key = "nova", label = "NOVA",
      nodes = {
        {key = "blast_radius", label = "RADIUS", max = 3},
        {key = "blast_damage", label = "POWER", max = 3},
        {key = "blast_momentum", label = "MOMENTUM", max = 3},
      },
    },
    {
      key = "pulse", label = "PULSE",
      nodes = {
        {key = "shockwave_charge", label = "CHARGE", max = 3},
        {key = "shockwave_radius", label = "RANGE", max = 3},
        {key = "shockwave_damage", label = "FORCE", max = 3},
      },
    },
  },
}
