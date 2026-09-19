-- 商店卡片及每次升级的增量。
return {
  price_growth = 1.5,
  hit_power_per_level = 1,
  fire_interval_reduction = 0.01,
  min_attack_interval = 0.04,
  gold_bonus_per_level = 0.15,
  critical_chance_per_level = 0.05,
  critical_multiplier = 2,
  luck_chance_per_level = 0.03,
  luck_chain_range = 70,
  luck_area_duration = 2,
  luck_area_size = 56,
  luck_frost_slow = 0.55,
  cards = {
    {key = "gold_gain", label = "GOLD +15%", base_price = 8, max = 8},
    {key = "critical", label = "CRIT +5%", base_price = 12, max = 8},
    {key = "luck", label = "LUCK +3%", base_price = 15, max = 8},
    {key = "hit_power", label = "HIT POWER +1", base_price = 10, max = 10},
    {key = "bounce", label = "BOUNCE +1", base_price = 15, max = 5},
    {key = "fire_rate", label = "FIRE RATE", base_price = 12, max = 6},
    {key = "auto_attack", label = "AUTO-FIRE", base_price = 30, max = 1},
  },
}
