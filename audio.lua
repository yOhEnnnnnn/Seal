Audio = Object:extend()

local pitch_pattern = {-1, 0.35, 1, -0.35, 0}

function Audio:init(config)
  self.config = config or Data.audio
  self.events = {}
  for name, settings in pairs(self.config.events) do
    self.events[name] = self:create_event(settings)
  end
end

function Audio:create_event(settings)
  local use_path = settings.path and
    (not love.filesystem or love.filesystem.getInfo(settings.path))
  local sound_data
  if not use_path then
    assert(settings.synth, "Missing audio file and synth fallback: " ..
      tostring(settings.path))
    sound_data = self:create_sound_data(settings.synth)
  end

  local event = {voices = {}, next_voice = 1, next_pitch = 1, play_count = 0}
  for _ = 1, settings.voices or 1 do
    local source = love.audio.newSource(use_path and settings.path or sound_data,
      "static")
    source:setVolume((settings.volume or 1) * self.config.master_volume)
    event.voices[#event.voices + 1] = source
  end
  event.pitch_variation = settings.pitch_variation or 0
  return event
end

function Audio:create_sound_data(settings)
  local sample_rate = self.config.sample_rate
  local sample_count = math.max(1, math.floor(settings.duration * sample_rate))
  local sound_data = love.sound.newSoundData(sample_count, sample_rate, 16, 1)
  local phase, noise_state = 0, 1977

  for index = 0, sample_count - 1 do
    local progress = index / math.max(sample_count - 1, 1)
    local frequency = settings.start_frequency +
      (settings.end_frequency - settings.start_frequency) * progress
    phase = phase + frequency / sample_rate
    noise_state = (noise_state * 48271) % 2147483647
    local noise = noise_state / 1073741823.5 - 1
    local wave = self:get_wave_sample(settings.wave, phase)
    if settings.overtone then
      wave = wave + math.sin(phase * math.pi * 4) * settings.overtone
    end
    wave = wave * (1 - settings.noise) + noise * settings.noise
    sound_data:setSample(index,
      math.max(-1, math.min(1, wave * self:get_envelope(progress, settings))))
  end
  return sound_data
end

function Audio:get_wave_sample(wave, phase)
  phase = phase % 1
  if wave == "square" then return phase < 0.5 and 1 or -1 end
  if wave == "triangle" then return 1 - 4 * math.abs(phase - 0.5) end
  return math.sin(phase * math.pi * 2)
end

function Audio:get_envelope(progress, settings)
  local attack = math.max(settings.attack / settings.duration, 0.0001)
  local release_start = math.max(0, 1 - settings.release / settings.duration)
  if progress < attack then return progress / attack end
  if progress > release_start then
    return math.max(0, (1 - progress) / math.max(1 - release_start, 0.0001))
  end
  return 1
end

function Audio:play(name)
  local event = self.events[name]
  if not event then return false end

  local source = event.voices[event.next_voice]
  local pitch = pitch_pattern[event.next_pitch]
  source:stop()
  source:setPitch(1 + pitch * event.pitch_variation)
  source:play()

  event.next_voice = event.next_voice % #event.voices + 1
  event.next_pitch = event.next_pitch % #pitch_pattern + 1
  event.play_count = event.play_count + 1
  return true
end
