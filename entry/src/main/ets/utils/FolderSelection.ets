import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'

export interface FolderDeletionPlan {
  dates: Set<string>
  videos: VideoMetadata[]
  videoCount: number
}

export default class FolderSelection {
  static selectable(folders: FileFolder[]): FileFolder[] {
    return folders.filter(folder => folder.name !== '首页')
  }

  static deletionPlan(folders: FileFolder[], selected: string[]): FolderDeletionPlan {
    const allowed = new Set(FolderSelection.selectable(folders).map(folder => folder.date))
    const children = new Map<string, string[]>()
    for (const folder of folders) {
      if (folder.parent_date) {
        if (!children.has(folder.parent_date)) { children.set(folder.parent_date, []) }
        children.get(folder.parent_date)!.push(folder.date)
      }
    }
    const dates = new Set<string>()
    const pending = selected.filter(date => allowed.has(date))
    while (pending.length > 0) {
      const date = pending.pop()!
      if (dates.has(date) || !allowed.has(date)) { continue }
      dates.add(date)
      pending.push(...(children.get(date) ?? []))
    }
    const videos = new Map<string, VideoMetadata>()
    const retainedVideos = new Set<string>()
    for (const folder of folders) {
      for (const video of folder.video_list ?? []) {
        if (!video.date) { continue }
        if (dates.has(folder.date)) { videos.set(video.date, video) }
        else { retainedVideos.add(video.date) }
      }
    }
    // 仍被其他文件夹引用的媒体保留封面、字幕和播放记录。
    return { dates, videoCount: videos.size,
      videos: Array.from(videos.values()).filter(video => !retainedVideos.has(video.date)) }
  }
}
