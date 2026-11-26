export class AudioEffectConfig {
  private static readonly EFFECTS: string[] = [
    'off', 'equalizer', 'noise-reduction', 'sound-field', 'audio-separation', 'voice-beautifier', 'environment',
    'audio-mixer', 'space-render', 'pure-voice-change', 'general-voice-change', 'tempo-pitch', 'hoa-space-render'
  ]

  // UI identity; effect remains the concrete effect understood by the backend.
  presetId: string = ''
  effect: string = 'off'
  eqPreset: string = 'default'
  eqGains: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  soundField: string = 'front-facing'
  environment: string = 'broadcast'
  beautifier: string = 'clear'
  spaceMode: string = 'position'
  spaceX: number = 0
  spaceY: number = 0
  spaceZ: number = 1
  spaceTime: number = 5
  spaceDirection: string = 'counterclockwise'
  spaceRadius: number = 1
  spaceAngle: number = 90
  pureGender: string = 'female'
  pureType: string = 'cartoon'
  purePitch: number = 0
  generalType: string = 'cute'
  tempo: number = 1
  pitch: number = 1
  separationOutput: string = 'vocals'
  hoaLayout: string = 'order1-acn-n3d'

  supportsSystemPlayer(): boolean {
    return this.effect !== 'audio-mixer' && this.effect !== 'hoa-space-render'
  }

  static fromStored(value: string): AudioEffectConfig {
    if (!value) {
      return new AudioEffectConfig()
    }
    try {
      const stored = JSON.parse(value) as AudioEffectConfig
      if (stored && AudioEffectConfig.EFFECTS.includes(stored.effect)) {
        return AudioEffectConfig.copy(stored)
      }
    } catch (_) {
      // A missing or invalid preference starts with the default configuration.
    }
    return new AudioEffectConfig()
  }

  static copy(source: AudioEffectConfig): AudioEffectConfig {
    const result = new AudioEffectConfig()
    result.presetId = typeof source.presetId === 'string' ? source.presetId : result.presetId
    result.effect = source.effect
    result.eqPreset = typeof source.eqPreset === 'string' ? source.eqPreset : result.eqPreset
    if (Array.isArray(source.eqGains) && source.eqGains.length === result.eqGains.length &&
      source.eqGains.every((gain: number) => Number.isFinite(gain))) {
      result.eqGains = source.eqGains.slice()
    }
    result.soundField = typeof source.soundField === 'string' ? source.soundField : result.soundField
    result.environment = typeof source.environment === 'string' ? source.environment : result.environment
    result.beautifier = typeof source.beautifier === 'string' ? source.beautifier : result.beautifier
    result.spaceMode = typeof source.spaceMode === 'string' ? source.spaceMode : result.spaceMode
    result.spaceX = Number.isFinite(source.spaceX) ? source.spaceX : result.spaceX
    result.spaceY = Number.isFinite(source.spaceY) ? source.spaceY : result.spaceY
    result.spaceZ = Number.isFinite(source.spaceZ) ? source.spaceZ : result.spaceZ
    result.spaceTime = Number.isFinite(source.spaceTime) ? source.spaceTime : result.spaceTime
    result.spaceDirection = typeof source.spaceDirection === 'string' ? source.spaceDirection : result.spaceDirection
    result.spaceRadius = Number.isFinite(source.spaceRadius) ? source.spaceRadius : result.spaceRadius
    result.spaceAngle = Number.isFinite(source.spaceAngle) ? source.spaceAngle : result.spaceAngle
    result.pureGender = typeof source.pureGender === 'string' ? source.pureGender : result.pureGender
    result.pureType = typeof source.pureType === 'string' ? source.pureType : result.pureType
    result.purePitch = Number.isFinite(source.purePitch) ? source.purePitch : result.purePitch
    result.generalType = typeof source.generalType === 'string' ? source.generalType : result.generalType
    result.tempo = Number.isFinite(source.tempo) ? source.tempo : result.tempo
    result.pitch = Number.isFinite(source.pitch) ? source.pitch : result.pitch
    result.separationOutput = typeof source.separationOutput === 'string' ? source.separationOutput :
      result.separationOutput
    result.hoaLayout = typeof source.hoaLayout === 'string' ? source.hoaLayout : result.hoaLayout
    return result
  }
}
