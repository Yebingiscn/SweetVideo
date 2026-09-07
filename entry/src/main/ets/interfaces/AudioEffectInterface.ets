export class AudioEffectConfig {
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

  static copy(source: AudioEffectConfig): AudioEffectConfig {
    const result = new AudioEffectConfig()
    result.effect = source.effect
    result.eqPreset = source.eqPreset
    result.eqGains = source.eqGains.slice()
    result.soundField = source.soundField
    result.environment = source.environment
    result.beautifier = source.beautifier
    result.spaceMode = source.spaceMode
    result.spaceX = source.spaceX
    result.spaceY = source.spaceY
    result.spaceZ = source.spaceZ
    result.spaceTime = source.spaceTime
    result.spaceDirection = source.spaceDirection
    result.spaceRadius = source.spaceRadius
    result.spaceAngle = source.spaceAngle
    result.pureGender = source.pureGender
    result.pureType = source.pureType
    result.purePitch = source.purePitch
    result.generalType = source.generalType
    result.tempo = source.tempo
    result.pitch = source.pitch
    result.separationOutput = source.separationOutput
    result.hoaLayout = source.hoaLayout
    return result
  }
}
