import { Context } from '@kit.AbilityKit'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import Preferences from '../database/Preferences'
import { salmonLogger } from 'salmonlogger'

// 只收集本次导入的新条目；提交时合并最新媒体库，不保存旧的全库快照。
export default class MediaImportBatch {
  private pending: Map<string, VideoMetadata[]> = new Map()
  private uris: Set<string> = new Set()
  private count: number = 0
  private timer: number | undefined = undefined
  private failure: Error | undefined = undefined
  private static active: Set<MediaImportBatch> = new Set()

  private context: Context
  private onDuplicates: (count: number) => void

  constructor(context: Context, onDuplicates: (count: number) => void = () => {}) {
    this.context = context
    this.onDuplicates = onDuplicates
    MediaImportBatch.active.add(this)
  }

  hasUri(uri: string): boolean {
    return this.uris.has(uri)
  }

  add(folderDate: string, video: VideoMetadata): void {
    if (this.failure) throw this.failure
    if (!this.pending.has(folderDate)) this.pending.set(folderDate, [])
    this.pending.get(folderDate)!.push(video)
    this.uris.add(video.uri)
    this.count++
    if (this.count >= 16) {
      this.flush()
    } else if (this.timer === undefined) {
      this.timer = setTimeout(() => {
        this.timer = undefined
        try {
          this.flush()
        } catch (_error) {
          salmonLogger.addLog('MediaImportBatch', '导入批次保存失败，停止接收新条目', true)
        }
      }, 500)
    }
  }

  flush(): void {
    if (this.timer !== undefined) {
      clearTimeout(this.timer)
      this.timer = undefined
    }
    if (this.failure) throw this.failure
    if (this.count === 0) return
    try {
      const imported = Preferences.appendImportedVideos(this.context, this.pending)
      if (imported < this.count) this.onDuplicates(this.count - imported)
      this.pending.clear()
      this.uris.clear()
      this.count = 0
    } catch (_error) {
      this.failure = new Error('Import batch could not be saved')
      throw this.failure
    }
  }

  close(): void {
    try {
      this.flush()
    } finally {
      MediaImportBatch.active.delete(this)
    }
  }

  static flushActive(): void {
    for (const batch of MediaImportBatch.active) {
      try {
        batch.flush()
      } catch (_error) {
        salmonLogger.addLog('MediaImportBatch', '保存未完成的导入批次失败', true)
      }
    }
  }
}
