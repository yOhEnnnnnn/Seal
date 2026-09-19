-- 六类基础反馈音。path 存在时加载文件，否则按 synth 参数生成原创占位音。
return {
  sample_rate = 22050,
  master_volume = 0.9,
  events = {
    attack = {
      path = "assets/sounds/projectile_attack.wav",
      volume = 0.20,
      voices = 4,
      pitch_variation = 0.035,
    },
    enemy_hit = {
      volume = 0.16,
      voices = 5,
      pitch_variation = 0.08,
      synth = {
        wave = "triangle", duration = 0.055,
        start_frequency = 190, end_frequency = 115,
        noise = 0.55, attack = 0.002, release = 0.045,
      },
    },
    enemy_death = {
      volume = 0.22,
      voices = 4,
      pitch_variation = 0.07,
      synth = {
        wave = "square", duration = 0.14,
        start_frequency = 145, end_frequency = 48,
        noise = 0.48, attack = 0.003, release = 0.12,
      },
    },
    wall_hit = {
      volume = 0.11,
      voices = 4,
      pitch_variation = 0.06,
      synth = {
        wave = "triangle", duration = 0.045,
        start_frequency = 780, end_frequency = 310,
        noise = 0.38, attack = 0.001, release = 0.038,
      },
    },
    player_hit = {
      volume = 0.25,
      voices = 3,
      pitch_variation = 0.04,
      synth = {
        wave = "square", duration = 0.18,
        start_frequency = 105, end_frequency = 52,
        noise = 0.28, attack = 0.003, release = 0.16,
      },
    },
    purchase = {
      volume = 0.18,
      voices = 3,
      pitch_variation = 0.025,
      synth = {
        wave = "sine", duration = 0.11,
        start_frequency = 430, end_frequency = 920,
        noise = 0.04, attack = 0.003, release = 0.08,
        overtone = 0.22,
      },
    },
  },
}
