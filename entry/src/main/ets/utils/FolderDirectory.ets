import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import FolderHierarchy from './FolderHierarchy'

export class DirectoryEntry {
  key: string
  folder: FileFolder | undefined
  video: VideoMetadata | undefined

  constructor(folder?: FileFolder, video?: VideoMetadata) {
    this.folder = folder
    this.video = video
    this.key = folder ? `folder:${folder.date}` : `video:${video!.date}`
  }
}

// 目录是现有媒体库的投影，null 表示虚拟总览，不改变“首页”或一级目录的归属。
export default class FolderDirectory {
  private children: Map<string | null, FileFolder[]> = new Map()
  private covers: Map<string, string[]> = new Map()

  constructor(folders: FileFolder[]) {
    for (const folder of folders) {
      const parent = folder.parent_date ?? null
      if (!this.children.has(parent)) { this.children.set(parent, []) }
      this.children.get(parent)!.push(folder)
    }
    // 从叶到根聚合最多四张封面，不在每个卡片构建时重复扫描整棵树。
    const ordered = FolderHierarchy.flatten(folders)
    for (let i = ordered.length - 1; i >= 0; i--) {
      const folder = ordered[i]
      const samples = folder.video_list.slice(0, 4).map(video => video.date)
      for (const child of this.childFolders(folder.date)) {
        for (const date of this.coverDates(child.date)) {
          if (samples.length < 4 && !samples.includes(date)) { samples.push(date) }
        }
        if (samples.length === 4) { break }
      }
      this.covers.set(folder.date, samples)
    }
  }

  childFolders(date: string | null): FileFolder[] {
    return this.children.get(date) ?? []
  }

  coverDates(date: string): string[] {
    return this.covers.get(date) ?? []
  }

  entries(date: string | null, videos: VideoMetadata[], query: string): DirectoryEntry[] {
    const keyword = query.trim().toLocaleLowerCase()
    const result = this.childFolders(date)
      .filter(folder => !keyword || folder.name.toLocaleLowerCase().includes(keyword))
      .map(folder => new DirectoryEntry(folder))
    if (date !== null) { result.push(...videos.map(video => new DirectoryEntry(undefined, video))) }
    return result
  }
}
