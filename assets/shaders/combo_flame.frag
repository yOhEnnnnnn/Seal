extern number time;
extern number intensity;

float hash(vec2 point) {
  return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 vcolor, Image texture, vec2 uv, vec2 screen) {
  float flame = 0.0;
  for (int index = 0; index < 8; index++) {
    float step = float(index) / 7.0;
    float wave_a = sin(uv.x * 42.0 + time * 7.0 + step * 4.0);
    float wave_b = hash(vec2(floor(uv.x * 32.0), floor(time * 12.0 + step * 9.0)));
    float bend = (wave_a * 0.006 + (wave_b - 0.5) * 0.018) * intensity;
    float alpha = Texel(texture,
      vec2(uv.x + bend, uv.y + step * 0.34 * intensity)).a;
    flame = max(flame, alpha * (1.0 - step * 0.78));
  }

  float core = Texel(texture, uv).a;
  float heat = clamp((0.72 - uv.y) * 2.2, 0.0, 1.0);
  vec3 outer = vec3(0.84, 0.04, 0.14);
  vec3 inner = vec3(1.0, 0.72, 0.08);
  vec3 flame_color = mix(outer, inner, heat);
  flame_color = mix(flame_color, vec3(1.0), core * intensity);
  return vec4(flame_color, flame * intensity * 0.95);
}
