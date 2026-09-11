import nativePlayer, { NativePlayerEvent, NativePlayerResult } from 'libmpvnative.so'
import { media } from '@kit.MediaKit'
import { audio } from '@kit.AudioKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { salmonLogger } from 'salmonlogger'
import { AudioEffectConfig } from '../../interfaces/AudioEffectInterface'

type StateCallback = (state: string) => void
type NumberCallback = (value: number) => void
type EmptyCallback = () => void
type ErrorCallback = (error: BusinessError) => void
type BooleanCallback = (enabled: boolean) => void
type SubtitleCallback = (subtitle: media.SubtitleInfo) => void
type InterruptCallback = (event: audio.InterruptEvent) => void
type DeviceCallback = (event: audio.AudioStreamDeviceChangeInfo) => void
type BufferCallback = (event: NativeBufferingInfo) => void
type PlayerCallback = StateCallback | NumberCallback | EmptyCallback | ErrorCallback | BooleanCallback |
  SubtitleCallback | InterruptCallback | DeviceCallback | BufferCallback

export interface NativeBufferingInfo {
  type: number
  value: number
}

interface NativePlayerOptions {
  surfaceId?: string
  mode?: number
  url?: string
  headers?: Record<string, string>
  generation?: number
  fd?: number
  position?: number
  rate?: number
  index?: number
  volume?: number
  gain?: number
  type?: number
  muted?: boolean
  enabled?: boolean
  width?: number
  height?: number
  preferredBufferDurationForPlaying?: number
  showFirstFrameOnPrepare?: boolean
  enableSuperResolution?: boolean
  preferredHdr?: boolean
  effect?: string
  effectVersion?: number
  soundField?: number
  environment?: number
  beautifier?: number
  spaceMode?: number
  spaceX?: number
  spaceY?: number
  spaceZ?: number
  spaceTime?: number
  spaceDirection?: number
  spaceRadius?: number
  spaceAngle?: number
  pureGender?: number
  pureType?: number
  purePitch?: number
  generalType?: number
  tempo?: number
  pitch?: number
  separation?: number
  eq0?: number
  eq1?: number
  eq2?: number
  eq3?: number
  eq4?: number
  eq5?: number
  eq6?: number
  eq7?: number
  eq8?: number
  eq9?: number
}

// This facade is the only system-player implementation. media is used for public enums/data types,
// never for media.createAVPlayer(), and no cast pretends this object is an ArkTS AVPlayer.
export class NativeAVPlayer {
  state: string = 'idle'
  duration: number = 0
  currentTime: number = 0
  width: number = 0
  height: number = 0
  pcmSupported: boolean = false
  private id: number = 0
  private generation: number = 0
  private closed: boolean = false
  private tail: Promise<void> = Promise.resolve()
  private releaseTask: Promise<void> | undefined = undefined
  private listeners: Map<string, PlayerCallback> = new Map()
  private metrics: Array<(info: Array<media.AVMetricsEvent>) => void> = []
  private desiredEffect: AudioEffectConfig = new AudioEffectConfig()
  private effectVersion: number = 0
  private activeEffectVersion: number = 0

  private constructor() {
    const result = nativePlayer.avPlayerCreate((event: NativePlayerEvent) => this.receive(event))
    this.id = result.id
    this.pcmSupported = result.pcmSupported === 1
  }

  static async create(): Promise<NativeAVPlayer> {
    return new NativeAVPlayer()
  }

  private send(operation: string, options: NativePlayerOptions = {}): Promise<NativePlayerResult> {
    if (this.closed && operation !== 'release') {
      return Promise.reject(new Error('播放器已释放'))
    }
    const task = this.tail.then(() => nativePlayer.avPlayerCommand(this.id, operation, options))
    // Publish a rejection-safe tail so one failed option does not poison release or later commands.
    this.tail = task.then(() => {}, () => {})
    return task
  }

  private fire(operation: string, options: NativePlayerOptions): void {
    this.send(operation, options).catch((error: BusinessError) => this.reportError(error))
  }

  set surfaceId(value: string) {
    if (value.length > 0) this.fire('surface', { surfaceId: value })
  }

  set audioInterruptMode(value: audio.InterruptMode) {
    this.fire('interrupt', { mode: value })
  }

  async setUrlSource(url: string, headers?: Record<string, string>): Promise<void> {
    this.generation++
    const options: NativePlayerOptions = { url: url, generation: this.generation, headers: headers }
    await this.send('source', options)
  }

  async setFdSource(fd: number): Promise<void> {
    this.generation++
    await this.send('source', { fd: fd, generation: this.generation })
  }

  async prepare(): Promise<void> { await this.send('prepare') }
  async play(): Promise<void> { await this.send('play') }
  async pause(): Promise<void> { await this.send('pause') }
  async reset(): Promise<void> {
    this.generation++
    const result = await this.send('reset', { generation: this.generation })
    this.pcmSupported = result.pcmSupported === 1
    this.state = 'idle'
    this.duration = 0
    this.currentTime = 0
    this.width = 0
    this.height = 0
  }

  release(): Promise<void> {
    if (this.releaseTask) return this.releaseTask
    this.closed = true
    this.generation++
    this.listeners.clear()
    this.metrics = []
    this.releaseTask = this.send('release').then(() => { this.state = 'released' })
    return this.releaseTask
  }

  seek(position: number, mode: media.SeekMode = media.SeekMode.SEEK_CLOSEST): void {
    this.fire('seek', { position: Math.max(0, Math.round(position)), mode: mode })
  }
  async setPlaybackRate(rate: number): Promise<void> { await this.send('rate', { rate: rate }) }
  async selectTrack(index: number): Promise<void> { await this.send('selectTrack', { index: index }) }
  async deselectTrack(index: number): Promise<void> { await this.send('deselectTrack', { index: index }) }
  async setVolume(volume: number): Promise<void> { await this.send('volume', { volume: volume }) }
  async setLoudnessGain(gain: number): Promise<void> { await this.send('loudness', { gain: gain }) }
  async setMediaMuted(type: media.MediaType, muted: boolean): Promise<void> {
    await this.send('muted', { type: type, muted: muted })
  }
  async setSuperResolution(enabled: boolean): Promise<void> {
    await this.send('superResolution', { enabled: enabled })
  }
  async setVideoWindowSize(width: number, height: number): Promise<void> {
    await this.send('windowSize', { width: width, height: height })
  }
  async setPlaybackStrategy(strategy: media.PlaybackStrategy): Promise<void> {
    const options: NativePlayerOptions = {}
    if (strategy.preferredBufferDurationForPlaying !== undefined)
      options.preferredBufferDurationForPlaying = strategy.preferredBufferDurationForPlaying
    if (strategy.showFirstFrameOnPrepare !== undefined) options.showFirstFrameOnPrepare = strategy.showFirstFrameOnPrepare
    if (strategy.enableSuperResolution !== undefined) options.enableSuperResolution = strategy.enableSuperResolution
    if (strategy.preferredHdr !== undefined) options.preferredHdr = strategy.preferredHdr
    await this.send('strategy', options)
  }

  getTrackDescription(callback: (error: BusinessError | undefined, tracks: Array<media.MediaDescription>) => void): void {
    this.send('tracks').then((result: NativePlayerResult) => {
      const tracks: media.MediaDescription[] = result.tracks.map((track): media.MediaDescription => {
        const description: media.MediaDescription = {
          'track_index': track.track_index, 'track_type': track.track_type,
          'channel_count': track.channel_count, 'sample_rate': track.sample_rate,
          'codec_mime': track.codec_mime, 'language': track.language, 'track_name': track.track_name
        }
        return description
      })
      callback(undefined, tracks)
    }).catch((error: BusinessError) => callback(error, []))
  }

  async applyAudioEffect(config: AudioEffectConfig): Promise<void> {
    const version = ++this.effectVersion
    const next = AudioEffectConfig.copy(config)
    const options = this.effectOptions(next)
    options.effectVersion = version
    salmonLogger.addLog('NativeAVPlayer', `应用音效 ${next.effect}，版本 ${version}`)
    try {
      await this.send('effect', options)
    } catch (error) {
      salmonLogger.addLog('NativeAVPlayer', `音效 ${next.effect} 版本 ${version} 失败：${(error as Error).message}`, true)
      throw error as Error
    }
    // Native commands complete in order. If a later edit fails, this remains the actual active choice.
    this.activeEffectVersion = version
    this.desiredEffect = next
    salmonLogger.addLog('NativeAVPlayer', `音效 ${next.effect} 版本 ${version} 已应用`)
  }

  restoreAudioEffect(config: AudioEffectConfig): void {
    // Used only when creating a replacement native instance; its PCM format is not known yet.
    this.effectVersion++
    this.desiredEffect = AudioEffectConfig.copy(config)
  }

  private restoreDesiredEffect(): void {
    const version = this.effectVersion
    const generation = this.generation
    const task = this.tail.then(async () => {
      // A PCM event may be queued behind a user edit, reset or release. Recheck on execution,
      // not just on event receipt, or an old effect could turn itself back on after "off".
      if (this.closed || version !== this.effectVersion || generation !== this.generation ||
        this.desiredEffect.effect === 'off') return
      const options = this.effectOptions(this.desiredEffect)
      options.effectVersion = version
      await nativePlayer.avPlayerCommand(this.id, 'effect', options)
      this.activeEffectVersion = version
    })
    this.tail = task.then(() => {}, () => {})
    task.catch((error: BusinessError) => {
      if (!this.closed && version === this.effectVersion && generation === this.generation) this.effectFailed(error)
    })
  }

  private effectOptions(c: AudioEffectConfig): NativePlayerOptions {
    const eqNames: string[] = ['custom', 'default', 'ballads', 'chinese-style', 'classical', 'dance', 'jazz', 'pop', 'r-and-b', 'rock']
    const eqPresets: number[][] = [
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      [3, 5, 2, -4, 1, 2, -3, 1, 4, 5], [0, 0, 2, 0, 0, 4, 4, 2, 2, 5],
      [2, 3, 2, 1, 0, 0, -5, -5, -5, -6], [4, 3, 2, -3, 0, 0, 5, 4, 2, 0],
      [2, 0, 2, 3, 6, 5, -1, 3, 4, 4], [5, 2, 1, -1, -5, -5, -2, 1, 2, 4],
      [1, 4, 5, 3, -2, -2, 2, 3, 5, 5], [6, 4, 4, 2, 0, 1, 3, 3, 5, 4]
    ]
    const gains = c.eqPreset === 'custom' ? c.eqGains : eqPresets[Math.max(0, eqNames.indexOf(c.eqPreset))]
    const options: NativePlayerOptions = {
      effect: c.effect,
      soundField: ['front-facing', 'grand', 'near', 'wide'].indexOf(c.soundField) + 1,
      environment: ['broadcast', 'earpiece', 'underwater', 'gramophone'].indexOf(c.environment) + 1,
      beautifier: ['clear', 'theatre', 'cd', 'studio'].indexOf(c.beautifier) + 1,
      spaceMode: ['position', 'rotation', 'extension'].indexOf(c.spaceMode),
      spaceX: c.spaceX, spaceY: c.spaceY, spaceZ: c.spaceZ, spaceTime: c.spaceTime,
      spaceDirection: c.spaceDirection === 'clockwise' ? 1 : 0,
      spaceRadius: c.spaceRadius, spaceAngle: c.spaceAngle,
      pureGender: ['female', 'male'].indexOf(c.pureGender) + 1,
      pureType: ['cartoon', 'cute', 'female', 'male', 'monster', 'robots', 'seasoned'].indexOf(c.pureType) + 1,
      purePitch: c.purePitch,
      generalType: ['cute', 'cyberpunk', 'female', 'male', 'mix', 'monster', 'seasoned', 'synth', 'trill', 'war'].indexOf(c.generalType) + 1,
      tempo: c.tempo, pitch: c.pitch, separation: ['vocals', 'accompaniment', 'mix'].indexOf(c.separationOutput),
      eq0: gains[0] ?? 0, eq1: gains[1] ?? 0, eq2: gains[2] ?? 0, eq3: gains[3] ?? 0,
      eq4: gains[4] ?? 0, eq5: gains[5] ?? 0, eq6: gains[6] ?? 0, eq7: gains[7] ?? 0,
      eq8: gains[8] ?? 0, eq9: gains[9] ?? 0
    }
    return options
  }

  on(type: 'stateChange', callback: StateCallback): void
  on(type: 'timeUpdate' | 'seekDone' | 'playbackRateDone', callback: NumberCallback): void
  on(type: 'startRenderFrame', callback: EmptyCallback): void
  on(type: 'error' | 'effectError', callback: ErrorCallback): void
  on(type: 'superResolutionChanged', callback: BooleanCallback): void
  on(type: 'subtitleUpdate', callback: SubtitleCallback): void
  on(type: 'audioInterrupt', callback: InterruptCallback): void
  on(type: 'audioOutputDeviceChangeWithInfo', callback: DeviceCallback): void
  on(type: 'bufferingUpdate', callback: BufferCallback): void
  on(type: string, callback: PlayerCallback): void { this.listeners.set(type, callback) }
  off(type: string): void { this.listeners.delete(type) }
  onMetricsEvent(callback: (info: Array<media.AVMetricsEvent>) => void): void {
    if (this.metrics.indexOf(callback) < 0) this.metrics.push(callback)
  }
  offMetricsEvent(callback?: (info: Array<media.AVMetricsEvent>) => void): void {
    this.metrics = callback ? this.metrics.filter((item) => item !== callback) : []
  }

  private reportError(error: BusinessError): void {
    const callback = this.listeners.get('error') as ErrorCallback | undefined
    callback?.(error)
    salmonLogger.addLog('NativeAVPlayer', `${error.code}: ${error.message}`, true)
  }

  private receive(event: NativePlayerEvent): void {
    if (this.closed || event.generation !== this.generation) return
    try {
      const callback = this.listeners.get(event.type)
      switch (event.type) {
        case 'stateChange':
          this.state = event.state ?? this.state
          if (event.duration !== undefined) this.duration = event.duration
          if (event.width !== undefined) this.width = event.width
          if (event.height !== undefined) this.height = event.height
          if (callback) (callback as StateCallback)(this.state)
          break
        case 'timeUpdate':
        case 'seekDone':
          this.currentTime = event.value ?? 0
          if (callback) (callback as NumberCallback)(this.currentTime)
          break
        case 'playbackRateDone':
          if (callback) (callback as NumberCallback)(event.value ?? 1)
          break
        case 'durationUpdate': this.duration = event.value ?? 0; break
        case 'videoSizeChange': this.width = event.width ?? 0; this.height = event.height ?? 0; break
        case 'startRenderFrame': if (callback) (callback as EmptyCallback)(); break
        case 'superResolutionChanged': if (callback) (callback as BooleanCallback)(event.value === 1); break
        case 'subtitleUpdate':
          if (callback) (callback as SubtitleCallback)({ text: event.text, duration: event.duration, startTime: event.startTime })
          break
        case 'audioInterrupt':
          if (callback) (callback as InterruptCallback)({
            eventType: event.eventType ?? 0, forceType: event.forceType ?? 0, hintType: event.hintType ?? 0
          })
          break
        case 'audioDeviceChange':
          const deviceCallback = this.listeners.get('audioOutputDeviceChangeWithInfo') as DeviceCallback | undefined
          deviceCallback?.({ devices: [], changeReason: event.value ?? 0 })
          break
        case 'bufferingUpdate':
          if (callback) (callback as BufferCallback)({ type: event.bufferType ?? 0, value: event.value ?? 0 })
          if (event.bufferType === 1) {
            const metric: media.AVMetricsEvent = {
              event: media.AVMetricsEventType.AV_METRICS_EVENT_STALLING,
              timeStamp: Date.now(), playbackPosition: this.currentTime, details: { buffering: true }
            }
            this.metrics.forEach((listener) => listener([metric]))
          }
          break
        case 'pcmFormat':
          if (this.desiredEffect.effect !== 'off') {
            this.restoreDesiredEffect()
          }
          break
        case 'effectError':
          this.handleEffectError(event)
          break
        case 'error': this.reportError(this.eventError(event)); break
      }
    } catch (error) { salmonLogger.addLog('NativeAVPlayer', `事件处理失败：${error}`, true) }
  }

  private eventError(event: NativePlayerEvent): BusinessError {
    const error = new Error(event.message ?? '系统播放器错误') as BusinessError
    error.code = event.code ?? -1
    return error
  }
  private handleEffectError(event: NativePlayerEvent): void {
    // Let an in-flight replacement settle before deciding which graph this error belongs to.
    this.tail.then(() => {
      if (!this.closed && event.generation === this.generation &&
        (event.effectVersion === undefined || event.effectVersion === this.activeEffectVersion)) {
        this.effectFailed(this.eventError(event))
      }
    }).catch((error: Error) => salmonLogger.addLog('NativeAVPlayer', error.message, true))
  }
  private effectFailed(error: BusinessError): void {
    this.desiredEffect = new AudioEffectConfig()
    this.effectVersion++
    const callback = this.listeners.get('effectError') as ErrorCallback | undefined
    callback?.(error)
    salmonLogger.addLog('NativeAVPlayer', `音效关闭：${error.message}`, true)
  }
}
