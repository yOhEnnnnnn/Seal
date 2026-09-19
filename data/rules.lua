-- 每局初始资源、连击与达标后的危险等级。
return {
  starting_coins = 8,
  combo = {
    max_multiplier = 3,
    gain = 0.1,
    duration = 1.5,
    haste_duration_bonus = 0.15,
    max_haste_duration_bonus = 0.45,
    decay_per_second = 1.5,
    pulse_duration = 0.18,
  },
  danger = {
    max_level = 5,
    seconds_per_level = 10,
    gold_bonus_per_level = 0.15,
    spawn_reduction_per_level = 0.1,
  },
}
