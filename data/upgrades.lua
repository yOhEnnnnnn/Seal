-- 商店卡片及每次升级的增量。
return {
  price_growth = 1.5,
  hit_power_per_level = 1,
  ball_speed_bonus_per_level = 0.10,
  momentum_gain_per_level = 0.25,
  momentum_decay_delay = 2,
  momentum_decay_per_second = 1,
  momentum_damage_step = 5,
  momentum_speed_per_point = 0.01,
  momentum_speed_bonus_max = 0.6,
  focus_radius_per_level = 4,
  cards = {
    {key = "ball_count", label = "BALL +1", base_price = 20, max = 4},
    {key = "ball_speed", label = "SPEED +10%", base_price = 14, max = 7},
    {key = "hit_power", label = "POWER +1", base_price = 10, max = 10},
    {key = "momentum", label = "MOMENTUM +25%", base_price = 18, max = 6},
    {key = "focus", label = "FOCUS +4", base_price = 16, max = 8},
  },
}
