import { MpvPlaybackEffects } from './MpvPlaybackEffects'
import { ExternalAudioStorage } from '../../utils/ExternalAudioStorage'
import { LocalSidecarFile } from '../../utils/LocalSidecarFile'
import { picker } from '@kit.CoreFileKit'
import { loadExternalAudio, removeExternalAudio, setExternalAudioDelay } from 'libmpvnative.so'
import { UsbAudioSession } from '../../utils/UsbAudioSession'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { MpvAudioChannelMode, MpvAudioTrack } from './MpvTypes'
import { SweetRepeatMode } from '../../common/enum/SweetRepeatMode'
import {
  command as mpvCommand,
  getAudioTracks as mpvGetAudioTracks,
  getCurrentAudioTrack as mpvGetCurrentAudioTrack,
  selectAudio as mpvSelectAudio,
  setAudioChannel as mpvSetAudioChannel,
  setLoudnessGain as mpvSetLoudnessGain
} from 'libmpvnative.so'
import { salmonLogger } from 'salmonlogger'
import AVSessionUtil from '../../utils/AVSessionUtil'
import { Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { fileIo } from '@kit.CoreFileKit'
import { MpvPlayerEngineAdapter } from '../engine/MpvPlayerEngineAdapter'
import { AudioEffectConfig } from '../../interfaces/AudioEffectInterface'
import { AudioControllerInterface } from '../PlayerControllerFactory'
import MediaLibraryService from '../../utils/MediaLibraryService'

const TAG = 'MpvAudioController'

interface MpvCommandResult {
  success: boolean
  code: number
  error?: string
}

interface MpvAudioState {
  nowPlaying: VideoMetadata | undefined
  audioTrack: MpvAudioTrack[]
  audioTrackSelected: number
  externalAudioImporting: boolean
  externalAudioOffsetMs: number
  usbExclusiveActive: boolean
  audioChannelMode: MpvAudioChannelMode
  volumeLoudnessGain: number
  audioEffectConfig: AudioEffectConfig
  audioCoverUri: string
  playing: boolean
  playTime: number
  repeatMode: SweetRepeatMode
  speed: number
}

export class MpvAudioController implements AudioControllerInterface {
  private externalAudioQueue: Promise<void> = Promise.resolve()
  private externalAudioTrackId: number = -1
  private externalAudioGeneration: number = -1
  private usbDsdMode: number = 0
  private usbDevice: string = ''
  readonly usbSession: UsbAudioSession = new UsbAudioSession()
  private activeAudioPassthrough: boolean = false
  private state: MpvAudioState
  private engine: MpvPlayerEngineAdapter
  private getGeneration: () => number
  private getRequestGeneration: () => number

  constructor(state: MpvAudioState, engine: MpvPlayerEngineAdapter, getGeneration: () => number,
    getRequestGeneration: () => number) {
    this.state = state
    this.engine = engine
    this.getGeneration = getGeneration
    this.getRequestGeneration = getRequestGeneration
  }

  updatePreferences(destroyCore: () => void): void {
    if (this.state.usbExclusiveActive !== Setting.mpvUsbExclusive || this.usbDsdMode !== Setting.mpvUsbDsdMode ||
      this.usbDevice !== Setting.mpvUsbDevice) {
      if (this.engine.handle) { destroyCore() }
      this.usbSession.close()
      UsbAudioSession.volumeControl = undefined
    }
    this.state.usbExclusiveActive = Setting.mpvUsbExclusive
    this.usbDsdMode = Setting.mpvUsbDsdMode
    this.usbDevice = Setting.mpvUsbDevice
    this.activeAudioPassthrough = Setting.mpvAudioPassthrough
  }

  releaseOutput(): void {
    // 主控制器销毁 AO 后再关闭描述符，避免原生回调访问已关闭设备。
    this.usbSession.close()
    UsbAudioSession.volumeControl = undefined
    this.state.usbExclusiveActive = false
    this.activeAudioPassthrough = false
  }

  resetMedia(): void {
    this.externalAudioTrackId = -1
    this.externalAudioGeneration = -1
    this.state.externalAudioOffsetMs = 0
    setExternalAudioDelay(0)
  }

  async getAudioTrackList(): Promise<void> {
    const generation = this.getGeneration()
    const tracks = mpvGetAudioTracks(this.engine.handle) as MpvAudioTrack[]
    if (!tracks || tracks.length === 0) {
      setTimeout(() => {
        if (generation !== this.getGeneration() || !this.engine.isMediaLoaded()) return
        const retryTracks = mpvGetAudioTracks(this.engine.handle) as MpvAudioTrack[]
        if (retryTracks && retryTracks.length > 0) {
          this.state.audioTrack = retryTracks
          this.restoreAudioTrackPreference()
          salmonLogger.addLog(TAG, `重试获取音轨成功，共 ${retryTracks.length} 条音轨`, false)
        } else {
          this.state.audioTrack = retryTracks || []
          salmonLogger.addLog(TAG, "重试获取音轨仍然失败，可能文件没有音轨", false)
        }
      }, 1000)
    } else {
      this.state.audioTrack = tracks
      this.restoreAudioTrackPreference()
      salmonLogger.addLog(TAG, `获取音轨成功，共 ${tracks.length} 条音轨`, false)
    }
  }

  selectAudioTrack(trackId: number): void {
    mpvSelectAudio(this.engine.handle, trackId)
    setExternalAudioDelay(this.externalAudioGeneration === this.getGeneration() &&
      trackId === this.externalAudioTrackId ? this.state.externalAudioOffsetMs / 1000 : 0)
    this.resetAudioChannelMode()
    AVSessionUtil.updatePlaybackSessionState(this.state.playing, this.state.playTime, this.state.repeatMode, this.state.speed)
  }

  selectAudioTrackByIndex(index: number): void {
    if (index >= 0 && index < this.state.audioTrack.length) {
      this.selectAudioTrack(this.state.audioTrack[index].id)
      if (this.state.nowPlaying?.external_audio_file) {
        const selected = this.externalAudioGeneration === this.getGeneration() &&
          this.state.audioTrack[index].id === this.externalAudioTrackId
        try {
          MediaLibraryService.saveData(PathUtils.appContext!, this.state.nowPlaying, { externalAudioSelected: selected })
          this.state.nowPlaying.external_audio_selected = selected
        } catch (_error) { ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.audio_external_save_failed').id)) }
      }
    }
  }

  getAudioTrackCount(): number {
    return this.state.audioTrack.length
  }

  restoreAudioTrackPreference(): void {
    if (this.state.nowPlaying?.external_audio_selected) {
      if (this.externalAudioGeneration === this.getGeneration()) {
        const index = this.state.audioTrack.findIndex((track: MpvAudioTrack) => track.id === this.externalAudioTrackId)
        if (index >= 0) { this.selectAudioTrack(this.externalAudioTrackId); this.state.audioTrackSelected = index }
      }
      return
    }
    if (!this.state.nowPlaying || this.state.audioTrack.length <= 1) {
      return
    }
    const audioTrackId = this.state.nowPlaying.audio_track_id
    if (audioTrackId !== undefined && audioTrackId > 0 && audioTrackId < this.state.audioTrack.length &&
      !this.state.audioTrack[audioTrackId].external) {
      this.selectAudioTrack(this.state.audioTrack[audioTrackId].id)
      this.state.audioTrackSelected = audioTrackId
    }
  }

  private queueExternalAudio(task: () => Promise<void>): Promise<void> {
    const result = this.externalAudioQueue.then(task)
    this.externalAudioQueue = result.catch(() => { })
    return result
  }

  async importExternalAudio(): Promise<void> {
    if (this.state.externalAudioImporting || !this.state.nowPlaying?.date || !this.engine.isMediaLoaded()) return
    const media = this.state.nowPlaying
    const generation = this.getGeneration()
    const request = this.engine.getLoadRequestId()
    const epoch = ExternalAudioStorage.epoch(media.date!)
    const cancelled = (): boolean => generation !== this.getGeneration() || this.state.nowPlaying !== media ||
      !this.engine.isMediaLoaded() || ExternalAudioStorage.epoch(media.date!) !== epoch
    this.state.externalAudioImporting = true
    let candidate = ''
    let committed = false
    try {
      const options = new picker.DocumentSelectOptions()
      options.maxSelectNumber = 1
      options.fileSuffixFilters = ToolsUtil.localizeSuffixFilter(['音频|.mp3,.aac,.m4a,.flac,.wav'], $r('app.string.audio_external_filter'))
      const uris = await new picker.DocumentViewPicker(PathUtils.appContext!).select(options)
      if (!uris.length || cancelled()) return
      const name = decodeURIComponent(uris[0].split('/').pop() || '')
      candidate = ExternalAudioStorage.create(media.date!, name.split('.').pop()?.toLowerCase() || '')
      ExternalAudioStorage.pending.add(candidate)
      await LocalSidecarFile.copy(uris[0], ExternalAudioStorage.path(candidate), cancelled)
      await this.queueExternalAudio(async (): Promise<void> => {
        if (cancelled()) return
        const id = await loadExternalAudio(ExternalAudioStorage.path(candidate), name, request)
        if (cancelled()) {
          await removeExternalAudio(ExternalAudioStorage.path(candidate), request)
          return
        }
        if (id < 0) throw new Error('audio load failed')
        const oldFile = media.external_audio_file
        try {
          MediaLibraryService.saveData(PathUtils.appContext!, media, {
            externalAudioFile: candidate,
            externalAudioName: name, externalAudioSelected: true, externalAudioOffsetMs: 0
          })
        } catch (error) {
          await removeExternalAudio(ExternalAudioStorage.path(candidate), request)
          throw new Error('audio association save failed')
        }
        media.external_audio_file = candidate
        media.external_audio_name = name
        media.external_audio_selected = true
        media.external_audio_offset_ms = 0
        committed = true
        this.externalAudioTrackId = id
        this.externalAudioGeneration = generation
        this.state.externalAudioOffsetMs = 0
        this.state.audioTrack = mpvGetAudioTracks(this.engine.handle) as MpvAudioTrack[]
        this.selectAudioTrack(id)
        this.state.audioTrackSelected = this.state.audioTrack.findIndex((track: MpvAudioTrack) => track.id === id)
        if (oldFile && oldFile !== candidate) {
          await removeExternalAudio(ExternalAudioStorage.path(oldFile), request)
          ExternalAudioStorage.removeFile(oldFile)
        }
        if (!cancelled()) this.state.audioTrack = mpvGetAudioTracks(this.engine.handle) as MpvAudioTrack[]
      })
    } catch (_error) {
      if (!cancelled() && !committed) ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.audio_external_failed').id))
      salmonLogger.addLog(TAG, '外挂音频导入失败', true)
    } finally {
      if (candidate) {
        ExternalAudioStorage.pending.delete(candidate)
        if (!committed) {
          try { ExternalAudioStorage.removeFile(candidate) } catch (_error) { }
        }
      }
      this.state.externalAudioImporting = false
    }
  }

  async restoreExternalAudio(generation: number): Promise<void> {
    const media = this.state.nowPlaying
    const file = media?.external_audio_file
    if (!file) return
    const request = this.engine.getLoadRequestId()
    const epoch = ExternalAudioStorage.epoch(media!.date!)
    await this.queueExternalAudio(async (): Promise<void> => {
      const current = (): boolean => generation === this.getGeneration() && this.state.nowPlaying === media &&
        this.engine.isMediaLoaded() && media!.external_audio_file === file &&
        epoch === ExternalAudioStorage.epoch(media!.date!)
      if (!current()) return
      try {
        const path = ExternalAudioStorage.path(file)
        if (!fileIo.accessSync(path)) return
        const id = await loadExternalAudio(path, media!.external_audio_name || ToolsUtil.getStringResource($r('app.string.audio_external_title').id), request)
        if (!current()) { await removeExternalAudio(path, request); return }
        if (id < 0) { ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.audio_external_load_failed').id)); return }
        this.externalAudioTrackId = id
        this.externalAudioGeneration = generation
        this.state.externalAudioOffsetMs = media!.external_audio_offset_ms || 0
        this.state.audioTrack = mpvGetAudioTracks(this.engine.handle) as MpvAudioTrack[]
        this.restoreAudioTrackPreference()
      } catch (_error) { salmonLogger.addLog(TAG, '恢复外挂音频失败', true) }
    })
  }

  setExternalAudioOffset(value: number, persist: boolean = true): void {
    if (!this.state.nowPlaying?.external_audio_file || !Number.isFinite(value)) return
    const offset = Math.max(-5000, Math.min(5000, Math.round(value / 100) * 100))
    this.state.externalAudioOffsetMs = offset
    if (this.externalAudioGeneration === this.getGeneration() &&
      this.state.audioTrack[this.state.audioTrackSelected]?.id === this.externalAudioTrackId) setExternalAudioDelay(offset / 1000)
    if (persist) {
      try {
        MediaLibraryService.saveData(PathUtils.appContext!, this.state.nowPlaying, { externalAudioOffsetMs: offset })
        this.state.nowPlaying.external_audio_offset_ms = offset
      } catch (_error) { ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.audio_external_save_failed').id)) }
    }
  }

  setLoudnessGain(loudnessGain: number) {
    if (this.state.usbExclusiveActive) { ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.adjust_usb_volume').id)); return }
    this.state.volumeLoudnessGain = loudnessGain
    if (this.engine.handle) {
      mpvSetLoudnessGain(this.engine.handle, loudnessGain)
    }
  }

  setAudioChannelMode(mode: MpvAudioChannelMode) {
    if (this.state.usbExclusiveActive) { ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.usb_no_channel_processing').id)); return }
    this.state.audioChannelMode = mode
    if (this.engine.handle) {
      mpvSetAudioChannel(this.engine.handle, mode)
    }
  }

  resetAudioChannelMode() {
    this.state.audioChannelMode = MpvAudioChannelMode.STEREO
    if (this.state.usbExclusiveActive) return
    if (this.engine.handle) {
      mpvSetAudioChannel(this.engine.handle, MpvAudioChannelMode.STEREO)
    }
  }

  applyAudioEffect(config: AudioEffectConfig): boolean {
    if (this.state.usbExclusiveActive) {
      if (config.effect !== 'off') {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.usb_no_audio_effect').id)); return false
      }
      this.state.audioEffectConfig = AudioEffectConfig.copy(config)
      return true
    }
    if (config.effect !== 'off' && this.isAudioVividTrack()) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.audio_vivid_no_effect').id))
    }
    if (!this.engine.handle || !this.engine.isAlive()) {
      return false
    }

    // Disable compressed output before installing PCM effects. If effect setup
    // fails, remaining on PCM is preferable to processing compressed samples.
    if (!this.applyAudioPassthrough(this.state.speed, config.effect === 'off' ? this.state.audioEffectConfig.effect : config.effect)) {
      return false
    }

    if (!MpvPlaybackEffects.applyAudioEffect(this.engine.handle, config)) {
      return false
    }

    this.state.audioEffectConfig = AudioEffectConfig.copy(config)
    this.applyAudioPassthrough(this.state.speed, config.effect)
    salmonLogger.addLog(TAG, `已应用 AudioSuite 声音效果: ${config.effect}`, false)
    return true
  }

  private isAudioVividTrack(): boolean {
    if (!this.engine.handle || !this.engine.isAlive()) return false
    const selected = mpvGetCurrentAudioTrack(this.engine.handle)
    const tracks = mpvGetAudioTracks(this.engine.handle) as MpvAudioTrack[]
    return tracks?.some((track: MpvAudioTrack) =>
      track.id === selected && track.codec?.toLowerCase() === 'av3a') ?? false
  }

  applyAudioCoverMode(): void {
    if (!this.engine.handle) {
      throw new Error('MPV core is not created')
    }
    const coverUri = VideoInfoUtil.getCachedAudioCoverUri(this.state.nowPlaying)
    const result = mpvCommand(this.engine.handle,
      ['set', 'options/audio-display', coverUri ? 'no' : 'embedded-first']) as MpvCommandResult
    if (!result?.success) {
      salmonLogger.addLog(TAG, `设置音频封面显示模式失败: ${result?.error ?? result?.code ?? 'unknown'}`, true)
    }
    this.state.audioCoverUri = coverUri
    if (coverUri) {
      salmonLogger.addLog(TAG, '音频使用本地缩略图封面，已关闭 MPV 内嵌封面渲染', false)
    }
  }

  async prepareUsbOutput(requestGeneration: number): Promise<void> {
    if (!this.state.usbExclusiveActive) return
    if (this.usbDsdMode > 0 && !this.usbDevice) throw new Error(ToolsUtil.getStringResource($r('app.string.dsd_needs_dac').id))
    const probe = mpvCommand(this.engine.handle, ['set', 'options/usb-exclusive-dsd-mode', this.usbDsdMode === 2 ? 'native' : this.usbDsdMode === 1 ? 'dop' : 'no']) as MpvCommandResult
    if (!probe?.success) throw new Error(ToolsUtil.getStringResource($r('app.string.mpv_usb_dsd_unsupported').id))
    const stopped = mpvCommand(this.engine.handle, ['stop']) as MpvCommandResult
    if (!stopped?.success) throw new Error(ToolsUtil.getStringResource($r('app.string.stop_previous_audio_output_failed').id))
    this.usbSession.close()
    const fd = await this.usbSession.open(this.usbDevice)
    if (requestGeneration !== this.getRequestGeneration()) return
    this.configureUsbOutput(fd)
  }

  configureUsbOutput(fd: number): void {
    if (!this.state.usbExclusiveActive) return
    if (fd < 0) throw new Error(ToolsUtil.getStringResource($r('app.string.usb_device_closed').id))
    const stopResult = mpvCommand(this.engine.handle, ['stop']) as MpvCommandResult
    if (!stopResult?.success) throw new Error(ToolsUtil.getStringResource($r('app.string.stop_previous_audio_output_failed').id))
    const settings: string[][] = [
      ['usb-exclusive-dop', 'no'],
      ['usb-exclusive-dsd-mode', this.usbDsdMode === 2 ? 'native' : this.usbDsdMode === 1 ? 'dop' : 'no'],
      ['usb-exclusive-fd', fd.toString()], ['ao', 'usb-exclusive'], ['audio-spdif', this.usbDsdMode === 2 ? 'native-dsd' : 'dop'],
      ['speed', '1'], ['pitch', '1'], ['audio-pitch-correction', 'no'], ['audio-samplerate', '0'],
      ['audio-channels', 'auto'], ['af', ''], ['replaygain', 'no'],
      ['volume', '100'], ['mute', 'no'], ['audio-normalize-downmix', 'no'],
      ['video-sync', 'audio'], ['gapless-audio', 'no']
    ]
    for (const item of settings) {
      const result = mpvCommand(this.engine.handle, ['set', 'options/' + item[0], item[1]]) as MpvCommandResult
      if (!result?.success) throw new Error(ToolsUtil.getStringResourceArgs($r('app.string.usb_output_setup_failed').id, item[0]))
    }
    this.state.speed = 1
    this.state.volumeLoudnessGain = 0
    this.state.audioEffectConfig = new AudioEffectConfig()
    UsbAudioSession.volumeControl = (delta: number): boolean => this.changeUsbVolume(delta)
  }

  changeUsbVolume(delta: number): boolean {
    if (!this.state.usbExclusiveActive || !this.engine.handle) return false
    const result = mpvCommand(this.engine.handle, ['add', 'ao-volume', delta.toString()]) as MpvCommandResult
    if (!result?.success) ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.usb_no_hardware_volume').id))
    return result?.success === true
  }

  applyAudioPassthrough(speed: number, effect: string): boolean {
    if (!this.engine.handle || !this.engine.isAlive()) return false
    if (this.state.usbExclusiveActive) return true
    let enabled = this.activeAudioPassthrough && speed === 1 && effect === 'off'
    if (enabled) {
      // Older bundled cores do not have the dedicated compressed AO. Never
      // enable audio-spdif unless the backend's explicit opt-in is accepted.
      const probe = mpvCommand(this.engine.handle,
        ['set', 'options/ohaudio-eac3-enabled', 'yes']) as MpvCommandResult
      if (!probe?.success) {
        enabled = false
        salmonLogger.addLog(TAG, '当前 MPV 内核未提供 E-AC3 直通后端，使用普通音频输出', false)
      }
    }
    const result = mpvCommand(this.engine.handle,
      ['set', 'options/audio-spdif', enabled ? 'eac3' : '']) as MpvCommandResult
    if (!result?.success) {
      salmonLogger.addLog(TAG, '设置音频直通失败，错误码：' + result?.code, true)
    }
    return result?.success === true
  }
}
