import { common } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import { formBindingData, formProvider } from '@kit.FormKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import ToolsUtil from '../utils/ToolsUtil'
import VideoInfoUtil from '../utils/VideoInfoUtil'
import { VideoFormItem } from './VideoFormItem'

export const VIDEO_FORM_NAME = 'ContinueWatching'

export const VIDEO_FORM_ABILITY = 'VideoFormAbility'

export class VideoFormSnapshot {
  items: VideoFormItem[] = []
  // Read compatibility with the original single-item snapshot.
  mediaId?: string
  title?: string
}

export class VideoFormBinding {
  data: formBindingData.FormBindingData
  private files: fileIo.File[] = []

  constructor(context: common.Context, dimension: number) {
    const snapshot = VideoFormData.read(context)
    const images: Record<string, number> = {}
    let imageBytes = 0
    for (const item of snapshot.items) {
      item.cover = ''
      try {
        if (!/^\d+$/.test(item.mediaId)) {
          continue
        }
        const path = `${context.filesDir}/${item.mediaId}`
        const size = fileIo.statSync(path).size
        // Reuse an existing thumbnail only; never decode media in the extension.
        if (size > 0 && imageBytes + size <= 2 * 1024 * 1024) {
          const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
          this.files.push(file)
          imageBytes += size
          item.cover = `cover_${item.mediaId}_${Date.now()}`
          images[item.cover] = file.fd
        }
      } catch (_) {
        // Missing thumbnails use the bundled application image.
      }
    }
    this.data = formBindingData.createFormBindingData({
      dimension: dimension,
      items: snapshot.items,
      formImages: images
    })
  }

  close(): void {
    for (const file of this.files) {
      try {
        fileIo.closeSync(file)
      } catch (_) {
        hilog.warn(0, 'VideoForm', 'Unable to close card thumbnail')
      }
    }
    this.files = []
  }
}

export class VideoFormData {
  private static timer: number = -1
  private static publishing: boolean = false
  private static dirty: boolean = false

  static isPublicMedia(video: VideoMetadata): boolean {
    return !!video.uri && !video.uri.includes('/data/storage/el2')
  }

  static read(context: common.Context): VideoFormSnapshot {
    try {
      const stored = JSON.parse(fileIo.readTextSync(`${context.filesDir}/video_form.json`)) as VideoFormSnapshot
      const snapshot = new VideoFormSnapshot()
      if (Array.isArray(stored.items)) {
        snapshot.items = stored.items.slice(0, 3)
      } else if (stored.mediaId) {
        const item = new VideoFormItem()
        item.mediaId = stored.mediaId
        item.title = VideoInfoUtil.getVideoTitle(ToolsUtil.fileNameFromUri(stored.title ?? ''))
        snapshot.items = [item]
      }
      return snapshot
    } catch (_) {
      return new VideoFormSnapshot()
    }
  }

  static save(context: common.Context, videos: VideoMetadata[], forceRefresh: boolean = false): void {
    if (!canIUse('SystemCapability.Ability.Form')) {
      return
    }
    const snapshot = new VideoFormSnapshot()
    const seen = new Set<string>()
    for (const video of videos) {
      if (!VideoFormData.isPublicMedia(video) || seen.has(video.uri)) {
        continue
      }
      seen.add(video.uri)
      const item = new VideoFormItem()
      item.mediaId = video.date
      item.title = VideoInfoUtil.getVideoTitle(ToolsUtil.fileNameFromUri(video.title))
      snapshot.items.push(item)
      if (snapshot.items.length === 3) {
        break
      }
    }
    try {
      const value = JSON.stringify(snapshot)
      if (JSON.stringify(VideoFormData.read(context)) === value && !forceRefresh) {
        return
      }
      const path = `${context.filesDir}/video_form.json`
      const file = fileIo.openSync(`${path}.tmp`, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE |
        fileIo.OpenMode.TRUNC)
      try {
        fileIo.writeSync(file.fd, value)
      } finally {
        fileIo.closeSync(file)
      }
      // Readers in the extension see either the old or the complete new snapshot.
      fileIo.renameSync(`${path}.tmp`, path)
      VideoFormData.dirty = true
      if (VideoFormData.timer === -1) {
        VideoFormData.timer = setTimeout(() => {
          VideoFormData.timer = -1
          VideoFormData.publish(context)
        }, 500)
      }
    } catch (_) {
      hilog.warn(0, 'VideoForm', 'Unable to save card snapshot')
    }
  }

  static async update(context: common.Context, formId: string, dimension?: number): Promise<void> {
    // The system supplies dimensions to the provider, not to the card's LocalStorage.
    let binding: VideoFormBinding | undefined = undefined
    try {
      const currentDimension = dimension ?? (await formProvider.getPublishedRunningFormInfoById(formId)).dimension
      binding = new VideoFormBinding(context, currentDimension)
      await formProvider.updateForm(formId, binding.data)
    } catch (_) {
      hilog.warn(0, 'VideoForm', 'Unable to update card')
    } finally {
      binding?.close()
    }
  }

  private static async publish(context: common.Context): Promise<void> {
    if (VideoFormData.publishing) {
      return
    }
    VideoFormData.publishing = true
    try {
      while (VideoFormData.dirty) {
        VideoFormData.dirty = false
        const forms = await formProvider.getPublishedRunningFormInfos()
        for (const form of forms) {
          if (form.formName === VIDEO_FORM_NAME) {
            try {
              await VideoFormData.update(context, form.formId, form.dimension)
            } catch (_) {
              hilog.warn(0, 'VideoForm', 'Unable to update a desktop card')
            }
          }
        }
      }
    } catch (_) {
      hilog.warn(0, 'VideoForm', 'Unable to query desktop cards')
    } finally {
      VideoFormData.publishing = false
    }
  }
}
