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
    volley_ready = {
      tone = {frequency = 660, duration = 0.06, gain = 0.14},
      voices = 2,
      volume = 0.55,
      pitch_variation = 0.04,
    },
    detonation = {
      tone = {frequency = 150, duration = 0.16, gain = 0.2},
      voices = 3,
      volume = 0.75,
      pitch_variation = 0.08,
    },
    shockwave = {
      tone = {frequency = 105, duration = 0.2, gain = 0.24},
      voices = 1,
      volume = 0.8,
      pitch_variation = 0,
    },
    death_snap = {
      tone = {frequency = 420, duration = 0.07, gain = 0.24},
      voices = 1,
      volume = 0.8,
      pitch_variation = 0,
    },
    death_burst = {
      tone = {frequency = 72, duration = 0.3, gain = 0.3},
      voices = 1,
      volume = 0.9,
      pitch_variation = 0,
    },
  },
}
