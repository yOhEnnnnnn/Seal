-- 六类基础反馈音；paths 中的多个文件会随并发声部轮换。
return {
  master_volume = 0.9,
  events = {
    attack = {
      path = "assets/sounds/attack.ogg",
      volume = 0.20,
      voices = 4,
      pitch_variation = 0.05,
    },
    enemy_hit = {
      path = "assets/sounds/enemy_hit.ogg",
      volume = 0.35,
      voices = 5,
      pitch_variation = 0.05,
    },
    enemy_death = {
      paths = {
        "assets/sounds/enemy_death_1.ogg",
        "assets/sounds/enemy_death_2.ogg",
      },
      volume = 0.50,
      voices = 4,
      pitch_variation = 0.10,
    },
    wall_hit = {
      path = "assets/sounds/wall_hit.ogg",
      volume = 0.20,
      voices = 4,
      pitch_variation = 0.10,
    },
    player_hit = {
      paths = {
        "assets/sounds/player_hit_1.ogg",
        "assets/sounds/player_hit_2.ogg",
      },
      volume = 0.50,
      voices = 4,
      pitch_variation = 0.05,
    },
    purchase = {
      paths = {
        "assets/sounds/purchase_1.ogg",
        "assets/sounds/purchase_2.ogg",
        "assets/sounds/purchase_3.ogg",
      },
      volume = 0.50,
      voices = 6,
      pitch_variation = 0.05,
    },
  },
}
