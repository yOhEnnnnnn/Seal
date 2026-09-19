return {
  master_volume = 0.9,
  events = {
    enemy_hit = {
      tone = {frequency = 240, duration = 0.09, gain = 0.22},
      voices = 8,
      volume = 0.65,
      pitch_variation = 0.1,
    },
    enemy_death = {
      tone = {frequency = 240, duration = 0.09, gain = 0.22},
      voices = 10,
      volume = 0.8,
      pitch_variation = 0.18,
    },
  },
}
