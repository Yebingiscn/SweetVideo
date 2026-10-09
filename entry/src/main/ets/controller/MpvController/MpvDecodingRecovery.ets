import { PlayerControllerInterface } from '../PlayerControllerFactory'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { MpvDecodingMethod } from './MpvTypes'
import { MpvPlayerState } from './MpvPlayerState'
import {
  getDolbyVisionProfile as mpvGetDolbyVisionProfile,
  getHardwareDecoder as mpvGetHardwareDecoder,
  getVideoHeight as mpvGetVideoHeight,
  getVideoWidth as mpvGetVideoWidth
} from 'libmpvnative.so'
import { salmonLogger } from 'salmonlogger'
import { VideoStartTimeMode } from '../../common/enum/VideoStartTimeMode'
import { Setting } from '../../utils/ObservedUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { MpvPlayerEngineAdapter } from '../engine/MpvPlayerEngineAdapter'

const TAG = 'MpvDecodingRecovery'
const LOCAL_DECODING_MODE_TIMEOUT_MS = 500
const NETWORK_DECODING_MODE_INACTIVITY_TIMEOUT_MS = 15000

export interface MpvDecodingPolicy {
  activeAutoDeinterlace: boolean
  activeHwdecMode: MpvDecodingMethod
  initialStartHandledByLoad: boolean
  resumeAfterBuffering: boolean
}

export type DecodingModeSwitch = (targetMode: 'buffer_hw' | 'buffer_sw', message: string,
  time?: number, playing?: boolean, media?: VideoMetadata) => void

class DecodingModeVerification {
  targetMode: 'buffer_hw' | 'buffer_sw'
  savedTime: number
  savedPlaying: boolean
  savedVideo: VideoMetadata
  modeName: string
  token: number
  isNetworkStream: boolean
  lastNetworkSpeed: number = 0
  lastBufferPercent: number = -1
  lastCacheDuration: number = -1
  lastBuffering: boolean = false

  constructor(targetMode: 'buffer_hw' | 'buffer_sw', savedTime: number, savedPlaying: boolean,
    savedVideo: VideoMetadata, modeName: string, token: number) {
    this.targetMode = targetMode
    this.savedTime = savedTime
    this.savedPlaying = savedPlaying
    this.savedVideo = savedVideo
    this.modeName = modeName
    this.token = token
    this.isNetworkStream = ToolsUtil.isNetworkUrl(savedVideo.uri)
  }
}

export class MpvDecodingRecovery {
  private decodingModeVerifyTimer: number = 0
  private decodingModeVerifyToken: number = 0
  private pendingDecodingModeVerification: DecodingModeVerification | undefined = undefined
  private state: PlayerControllerInterface
  private engine: MpvPlayerEngineAdapter
  private getPolicy: () => MpvDecodingPolicy
  private getState: () => MpvPlayerState
  private transitionTo: (state: MpvPlayerState) => void
  private switchDecodingMode: DecodingModeSwitch

  constructor(state: PlayerControllerInterface, engine: MpvPlayerEngineAdapter,
    getPolicy: () => MpvDecodingPolicy, getState: () => MpvPlayerState,
    transitionTo: (state: MpvPlayerState) => void, switchDecodingMode: DecodingModeSwitch) {
    this.state = state
    this.engine = engine
    this.getPolicy = getPolicy
    this.getState = getState
    this.transitionTo = transitionTo
    this.switchDecodingMode = switchDecodingMode
  }

  private isInState(state: MpvPlayerState): boolean { return this.getState() === state }

  startDecodingModeVerification(targetMode: 'buffer_hw' | 'buffer_sw', savedTime: number,
    savedPlaying: boolean, savedVideo: VideoMetadata, modeName: string): void {
    const verification = new DecodingModeVerification(targetMode, savedTime, savedPlaying, savedVideo, modeName,
      this.decodingModeVerifyToken)
    this.pendingDecodingModeVerification = verification
    this.scheduleDecodingModeInactivityTimeout(verification)
    this.completeDecodingModeVerificationOnVideoSize()
  }

  completeDecodingModeVerificationOnVideoSize(): void {
    const verification = this.pendingDecodingModeVerification
    if (!verification || verification.token !== this.decodingModeVerifyToken ||
      mpvGetVideoWidth(this.engine.handle) <= 0 || mpvGetVideoHeight(this.engine.handle) <= 0) {
      return
    }
    this.finishDecodingModeVerification(verification)
  }

  handleDecodingModeNetworkState(speed: number, bufferPercent: number, cacheDuration: number,
    buffering: boolean): void {
    this.completeDecodingModeVerificationOnVideoSize()
    const verification = this.pendingDecodingModeVerification
    if (!verification || !verification.isNetworkStream || verification.token !== this.decodingModeVerifyToken) {
      return
    }
    const hasProgress = speed > 0 || bufferPercent > verification.lastBufferPercent ||
      cacheDuration > verification.lastCacheDuration || buffering !== verification.lastBuffering
    verification.lastNetworkSpeed = speed
    verification.lastBufferPercent = bufferPercent
    verification.lastCacheDuration = cacheDuration
    verification.lastBuffering = buffering
    if (hasProgress) {
      this.scheduleDecodingModeInactivityTimeout(verification)
    }
  }

  private scheduleDecodingModeInactivityTimeout(verification: DecodingModeVerification): void {
    if (this.decodingModeVerifyTimer) {
      clearTimeout(this.decodingModeVerifyTimer)
    }
    const timeout = verification.isNetworkStream ? NETWORK_DECODING_MODE_INACTIVITY_TIMEOUT_MS :
      LOCAL_DECODING_MODE_TIMEOUT_MS
    this.decodingModeVerifyTimer = setTimeout(() => {
      this.decodingModeVerifyTimer = 0
      this.handleDecodingModeInactivityTimeout(verification.token)
    }, timeout)
  }

  private handleDecodingModeInactivityTimeout(verificationToken: number): void {
    const verification = this.pendingDecodingModeVerification
    if (!verification || verification.token !== verificationToken ||
      verificationToken !== this.decodingModeVerifyToken ||
      this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
      return
    }
    if (mpvGetVideoWidth(this.engine.handle) > 0 && mpvGetVideoHeight(this.engine.handle) > 0) {
      this.finishDecodingModeVerification(verification)
      return
    }
    const isAudioFile = !VideoInfoUtil.hasVideoTrack(verification.savedVideo)
    if (isAudioFile) {
      salmonLogger.addLog(TAG,
        `[MpvController] ${verification.modeName} mode: audio file has no video size, treating as success`)
      this.finishDecodingModeVerification(verification)
      return
    }
    if (verification.isNetworkStream) {
      if (verification.targetMode === 'buffer_hw') {
        salmonLogger.addLog(TAG,
          `[MpvController] ${verification.modeName} network stream made no progress; ` +
          'falling back to software decoding without reporting playback failure', true)
        this.switchDecodingMode('buffer_sw', 'Buffer硬件解码串流加载无进展', verification.savedTime,
          verification.savedPlaying, verification.savedVideo)
        return
      }
      salmonLogger.addLog(TAG,
        `[MpvController] ${verification.modeName} network stream made no progress; ` +
        'keeping software playback active and deferring final failure detection to MPV', false)
      this.cancelDecodingModeVerification()
      if (!this.engine.isMediaLoaded()) {
        this.state.initialPlaying = verification.savedPlaying
        this.transitionTo(MpvPlayerState.LOADING)
        return
      }
      if (verification.savedPlaying) {
        this.state.play()
      } else {
        this.state.pause()
      }
      return
    }
    if (verification.targetMode === 'buffer_hw') {
      this.switchDecodingMode('buffer_sw', 'Buffer硬件解码播放失败', verification.savedTime,
        verification.savedPlaying, verification.savedVideo)
    } else {
      this.cancelDecodingModeVerification()
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.playback_failed_try_other').id))
      this.transitionTo(MpvPlayerState.ERROR)
    }
  }

  private finishDecodingModeVerification(verification: DecodingModeVerification): void {
    if (verification.token !== this.decodingModeVerifyToken || !this.engine.isMediaLoaded()) {
      return
    }
    this.cancelDecodingModeVerification()
    if (verification.savedPlaying) {
      this.state.play()
    } else {
      this.state.pause()
    }
    const hardwareDecoder = verification.targetMode === 'buffer_hw' ? mpvGetHardwareDecoder(this.engine.handle) : 'no'
    if (verification.targetMode === 'buffer_hw' && hardwareDecoder === 'no') {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.hw_decode_fallback_sw').id))
      salmonLogger.addLog(TAG, '[MpvController] Hardware decoding unavailable, fell back to software decoding', true)
    } else if (verification.targetMode === 'buffer_hw' &&
      (!hardwareDecoder || hardwareDecoder === 'unknown')) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.switched_to_buffer_mode').id))
    } else {
      ToolsUtil.showToast(`已成功切换到${verification.modeName}模式`)
    }
    salmonLogger.addLog(TAG, `[MpvController] Mode switch completed: target=${verification.modeName}, actualDecoder=${hardwareDecoder}`)
  }

  cancelDecodingModeVerification(): void {
    if (this.decodingModeVerifyTimer) {
      clearTimeout(this.decodingModeVerifyTimer)
      this.decodingModeVerifyTimer = 0
    }
    this.pendingDecodingModeVerification = undefined
    this.decodingModeVerifyToken++
  }

  getPlaybackIntentForModeSwitch(): boolean {
    if (this.isInState(MpvPlayerState.LOADING)) {
      return this.state.initialPlaying !== false
    }
    if (this.isInState(MpvPlayerState.BUFFERING)) {
      return this.getPolicy().resumeAfterBuffering
    }
    return this.state.playing
  }

  checkDolbyVisionAndSwitch() {
    if (!this.engine.handle || this.getPolicy().activeAutoDeinterlace) {
      return
    }
    try {
      const profile = mpvGetDolbyVisionProfile(this.engine.handle)

      if (profile === 5) {
        salmonLogger.addLog(TAG, '[MpvController] Detected Dolby Vision Profile 5', false)
        if (this.getPolicy().activeHwdecMode !== MpvDecodingMethod.HARDWARE_BUFFER) {
          salmonLogger.addLog(TAG,
            `[MpvController] DV P5 requires Buffer mode, current mode=${this.getPolicy().activeHwdecMode}, switching...`,
            true)
          this.switchDecodingMode('buffer_hw', '检测到杜比视界 Profile 5，切换到Buffer模式', this.state.playTime)
        }
      }
    } catch (error) {
      salmonLogger.addLog(TAG, '[MpvController] Failed to detect Dolby Vision profile: ' + JSON.stringify(error), true)
    }
  }

  switchToBufferMode(errorMessage: string) {
    if (this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
      salmonLogger.addLog(TAG, '[MpvController] Instance released, skipping buffer mode switch', true)
      return
    }
    if (this.getPolicy().activeHwdecMode !== MpvDecodingMethod.HARDWARE_SURFACE) {
      salmonLogger.addLog(TAG, '[MpvController] Not in surface mode, skipping switch')
      return
    }

    let resumeTime = this.state.playTime
    if (resumeTime <= 0 && this.state.nowPlaying) {
      if (this.getPolicy().initialStartHandledByLoad) {
        const mode = VideoOperateUtil.getVideoStartPlayTimeMode(this.state.nowPlaying)
        if (mode === VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME) {
          const lastPlay = this.state.nowPlaying.last_play
          if (lastPlay && lastPlay > 0) {
            resumeTime = lastPlay
            salmonLogger.addLog(TAG,
              `[MpvController] playTime=0 on surface error, initial start failed, using last_play=${lastPlay}ms`, false)
          } else {
            resumeTime = 0
            salmonLogger.addLog(TAG,
              '[MpvController] playTime=0 on surface error, no last_play, resume from 0', false)
          }
        } else {
          resumeTime = 0
          salmonLogger.addLog(TAG,
            '[MpvController] playTime=0 on surface error, initial start handled but mode not SEEK_TO_LAST_PLAY_TIME, resume from 0',
            false)
        }
      } else {
        const mode = VideoOperateUtil.getVideoStartPlayTimeMode(this.state.nowPlaying)
        if (mode === VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME) {
          const lastPlay = this.state.nowPlaying.last_play
          if (lastPlay && lastPlay > 0) {
            resumeTime = lastPlay
            salmonLogger.addLog(TAG,
              `[MpvController] playTime=0 on surface error, using last_play=${lastPlay}ms as resume position`, false)
          }
        } else if (mode === VideoStartTimeMode.SEEK_TO_BEGINNING) {
          salmonLogger.addLog(TAG,
            '[MpvController] playTime=0 on surface error, video nearly complete, resume from 0', false)
          resumeTime = 0
        } else if (mode === VideoStartTimeMode.SEEK_TO_START_TIME) {
          resumeTime = Math.max(0, this.state.nowPlaying.start_time || 0)
          salmonLogger.addLog(TAG,
            `[MpvController] playTime=0 on surface error, seeking to start_time=${resumeTime}ms`, false)
        } else if (mode === VideoStartTimeMode.SEEK_TO_INTRO_TIME) {
          resumeTime = Math.max(0, Number(Setting.skipIntroTime) * 1000)
          salmonLogger.addLog(TAG,
            `[MpvController] playTime=0 on surface error, seeking to intro_time=${resumeTime}ms`, false)
        } else {
          resumeTime = 0
          salmonLogger.addLog(TAG,
            '[MpvController] playTime=0 on surface error, no specific start mode, resume from 0', false)
        }
      }
    }
    this.switchDecodingMode('buffer_hw', errorMessage, resumeTime)
  }
}
