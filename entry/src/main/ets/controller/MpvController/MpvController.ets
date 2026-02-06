import { PlayerControllerInterface } from '../PlayerControllerFactory';
import * as mpv from 'libmpvnative.so';
import { Setting } from '../../utils/ObservedUtil';
import { VideoStartTimeMode } from '../../common/enum/VideoStartTimeMode';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import { SubtitleMode } from '../../common/enum/SubtitleMode';
import { PathUtils } from '../../utils/PathUtils';
import VideoOperateUtil from '../../utils/VideoOperateUtil';
import { MpvAudioTrack, MpvSubtitleTrack } from './MpvTypes';
import { avSession as avSessionManager } from '@kit.AVSessionKit';
import { audio } from '@kit.AudioKit';

@Observed
export class MpvController implements PlayerControllerInterface {
  @Track mpvHandle: number | null = null
  surfaceId: string | null = null
  playTimeUpdateTag: number | null = null
  @Track playTime: number = 0
  @Track playing: boolean = false
  @Track nowPlaying: VideoMetadata | undefined = undefined
  @Track videoMetaDataList: VideoMetadata[] = []
  @Track speed: number = 1.0
  @Track volume: number = 0
  @Track volumeActually: number = 0
  @Track audioTrack: MpvAudioTrack[] = []
  @Track subtitleTrack: MpvSubtitleTrack[] = []
  @Track screenBrightness: number = 0
  @Track onSwipingVoice: boolean = false
  @Track subtitleSelected: SubtitleMode = SubtitleMode.INNER_SUBTITLE
  avSession: avSessionManager.AVSession | undefined = undefined
  audioVolumeManager: audio.AudioVolumeManager | null = null

  create(): void {
    if (this.mpvHandle) {
      console.error('[MpvPlayer] MPV already created, skipping')
      return
    }
    console.error('[MpvPlayer] Creating mpv instance')
    try {
      this.mpvHandle = mpv.create()
      console.error('[MpvPlayer] Create returned:', this.mpvHandle, 'type:', typeof this.mpvHandle)
      if (!this.mpvHandle) {
        console.error('[MpvPlayer] Failed to create mpv instance - handle is null/undefined')
      } else {
        console.error('[MpvPlayer] MPV instance created:', this.mpvHandle)
        //  this.applyUserAgent()
      }
    } catch {
      console.error('[MpvPlayer] Exception during create')
    }
  }

  init(url: string, startPosition?: number): void {
    // 传递起始位置给 native（参考 mpv-android）
    if (startPosition !== undefined && startPosition > 0) {
      mpv.loadVideo(this.mpvHandle, url, startPosition)
    } else {
      mpv.loadVideo(this.mpvHandle, url)
    }
    this.playTimeUpdateTag = setInterval(() => {
      this.playTime = mpv.getCurrentPosition(this.mpvHandle)
    }, 1000);
    this.playing = true
    console.error('[MpvPlayer] load video success')
    setTimeout(() => {
      this.getAudioTrackList()
      this.getSubtitleTrackList()
      this.videoStartPlayTime(VideoOperateUtil.getVideoStartPlayTimeMode(this.nowPlaying!))
    }, 1000)

  }

  backForward(): void {
    if (!this.mpvHandle) {
      return
    }
    mpv.seek(this.mpvHandle, (this.playTime - Number(Setting.fastForwardSeconds) * 1000) / 1000, true)
  }

  fastForward(): void {
    if (!this.mpvHandle) {
      return
    }
    mpv.seek(this.mpvHandle, (this.playTime + Number(Setting.fastForwardSeconds) * 1000) / 1000, true)
  }

  prepare(): void {
    this.create()
  }

  play(): void {
    if (!this.mpvHandle) {
      return
    }
    this.playing = true
    mpv.play(this.mpvHandle)
  }

  pause(): void {
    if (!this.mpvHandle) {
      return
    }
    this.playing = false
    mpv.pause(this.mpvHandle)
  }

  reset(): void {
    throw new Error("Method not implemented.");
  }

  release(): void {
    if (!this.mpvHandle) {
      return
    }
    mpv.destroy(this.mpvHandle)
    clearInterval(this.playTimeUpdateTag)
  }

  seekTime(seekTime: number): void {
    if (!this.mpvHandle) {
      return
    }
    mpv.seek(this.mpvHandle, seekTime / 1000, true)
  }

  getPlayAreaWidth(): number {
    return mpv.getVideoWidth(this.mpvHandle)
  }

  getPlayAreaHeight(): number {
    return mpv.getVideoHeight(this.mpvHandle)
  }

  togglePlayback(): void {
    this.playing ? this.pause() : this.play()
  }

  updatePlaybackSpeed(speed: number) {
    mpv.setSpeed(this.mpvHandle, speed)
    this.speed = speed
  }

  getDuration(): number {
    const totalTime = mpv.getDuration(this.mpvHandle)
    if (this.nowPlaying?.time === 0) {
      this.nowPlaying.time = totalTime
      VideoOperateUtil.saveVideoTotalTime(PathUtils.appContext!, this.nowPlaying)
    }
    return totalTime
  }

  videoStartPlayTime(seekMode: number): void {
    switch (seekMode) {
      case VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME:
        this.seekTime(this.nowPlaying?.last_play || 0)
        break
      case VideoStartTimeMode.SEEK_TO_START_TIME:
        this.seekTime(this.nowPlaying?.start_time || 0)
        break
      case VideoStartTimeMode.SEEK_TO_INTRO_TIME:
        this.seekTime(this.playTime + Number(Setting.skipIntroTime) * 1000)
        break
      default:
        return
    }
  }

  getAudioTrackList() {
    this.audioTrack = mpv.getAudioTracks(this.mpvHandle) as MpvAudioTrack[];
  }

  selectAudioTrack(trackId: number): void {
    mpv.selectAudio(this.mpvHandle, trackId)
  }

  getSubtitleTrackList() {
    this.subtitleTrack = mpv.getSubtitleTracks(this.mpvHandle) as MpvSubtitleTrack[]
  }

  selectSubtitleTrack(trackId: number): void {
    mpv.selectSubtitle(this.mpvHandle, trackId)
  }
}