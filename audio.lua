Audio = Object:extend()

local pitch_pattern = {-1, 0.35, 1, -0.35, 0}

local function create_tone(settings)
  local sample_rate = settings.sample_rate or 22050
  local duration = settings.duration or 0.09
  local sample_count = math.floor(sample_rate * duration)
  local sound = love.sound.newSoundData(sample_count, sample_rate, 16, 1)

  for index = 0, sample_count - 1 do
    local time = index / sample_rate
    local envelope = (1 - time / duration) ^ 2
    local wave = math.sin(time * math.pi * 2 * (settings.frequency or 240))
    sound:setSample(index, wave * envelope * (settings.gain or 0.22))
  end

  return sound
end

function Audio:init(config)
  self.config = config or Data.audio
  self.events = {}
  for name, settings in pairs(self.config.events) do
    self.events[name] = self:create_event(settings)
  end
end

function Audio:create_event(settings)
  local event = {voices = {}, next_voice = 1, next_pitch = 1, play_count = 0}
  local paths = settings.paths or {settings.path}
  local tone = settings.tone and create_tone(settings.tone)
  for index = 1, settings.voices or 1 do
    local source
    if tone then
      source = love.audio.newSource(tone, "static")
    else
      local path = paths[(index - 1) % #paths + 1]
      source = love.audio.newSource(path, "static")
    end
    source:setVolume((settings.volume or 1) * self.config.master_volume)
    event.voices[#event.voices + 1] = source
  end
  event.pitch_variation = settings.pitch_variation or 0
  return event
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
