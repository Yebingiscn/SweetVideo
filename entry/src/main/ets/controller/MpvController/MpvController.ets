import { PlayerControllerInterface } from '../PlayerControllerFactory';
import * as mpv from 'libmpvnative.so';
import { Setting } from '../../utils/ObservedUtil';
import { VideoStartTimeMode } from '../../common/enum/VideoStartTimeMode';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';

@Observed
export class MPVController implements PlayerControllerInterface {
  mpvId: number | null = null
  @Track playTime: number = 0
  @Track playing: boolean = false
  @Track nowPlaying: VideoMetadata | undefined = undefined

  create(): void {
    this.mpvId = mpv.create()
  }

  backForward(): void {
    if (!this.mpvId) {
      return
    }
    mpv.seek(this.mpvId, this.playTime - Number(Setting.fastForwardSeconds) * 1000, true)
  }

  fastForward(): void {
    if (!this.mpvId) {
      return
    }
    mpv.seek(this.mpvId, this.playTime + Number(Setting.fastForwardSeconds) * 1000, true)
  }

  prepare(): void {
    throw new Error("Method not implemented.");
  }

  play(): void {
    if (!this.mpvId) {
      return
    }
    mpv.play(this.mpvId)
  }

  pause(): void {
    if (!this.mpvId) {
      return
    }
    mpv.pause(this.mpvId)
  }

  reset(): void {
    throw new Error("Method not implemented.");
  }

  release(): void {
    if (!this.mpvId) {
      return
    }
    mpv.destroy(this.mpvId)
    mpv.destroyGL()
  }

  seekTime(seekTime: number): void {
    if (!this.mpvId) {
      return
    }
    mpv.seek(this.mpvId, seekTime, true)
  }

  togglePlayback(): void {
    this.playing ? this.pause() : this.play()
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
}