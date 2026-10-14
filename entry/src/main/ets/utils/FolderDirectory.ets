import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import FolderHierarchy from './FolderHierarchy'
import MediaSortUtil from './MediaSortUtil'
import { SortField } from '../common/enum/SortField'

interface DirectoryVideoOrder {
  source: VideoMetadata[]
  count: number
  field: string
  ascending: boolean
  pinyin: boolean
  videos: VideoMetadata[]
}

interface DirectoryEntriesCache {
  videos: VideoMetadata[]
  count: number
  revision: number
  query: string
  entries: DirectoryEntry[]
}

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
  private static libraries: WeakMap<FileFolder[], FolderDirectory> = new WeakMap()
  private librarySize: number
  private folders: Map<string, FileFolder> = new Map()
  private children: Map<string | null, FileFolder[]> = new Map()
  private covers: Map<string, string[]> = new Map()
  private paths: Map<string, FileFolder[]> = new Map()
  private videoOrders: Map<string, DirectoryVideoOrder> = new Map()
  private folderEntries: Map<string, DirectoryEntry> = new Map()
  private videoEntries: WeakMap<VideoMetadata, DirectoryEntry> = new WeakMap()
  private entryLists: Map<string | null, DirectoryEntriesCache> = new Map()

  static forLibrary(folders: FileFolder[]): FolderDirectory {
    const cached = FolderDirectory.libraries.get(folders)
    if (cached && cached.librarySize === folders.length) return cached
    const index = new FolderDirectory(folders)
    FolderDirectory.libraries.set(folders, index)
    return index
  }

  constructor(folders: FileFolder[]) {
    this.librarySize = folders.length
    for (const folder of folders) {
      this.folders.set(folder.date, folder)
      this.folderEntries.set(folder.date, new DirectoryEntry(folder))
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

  folder(date: string): FileFolder | undefined {
    return this.folders.get(date)
  }

  path(date: string): FileFolder[] {
    const cached = this.paths.get(date)
    if (cached) return cached
    const chain: FileFolder[] = []
    const visited = new Set<string>()
    let folder = this.folder(date)
    while (folder && !visited.has(folder.date)) {
      visited.add(folder.date)
      chain.push(folder)
      folder = folder.parent_date ? this.folder(folder.parent_date) : undefined
    }
    chain.reverse()
    this.paths.set(date, chain)
    return chain
  }

  sortedVideos(folder: FileFolder, field: string, ascending: boolean, pinyin: boolean): VideoMetadata[] {
    const source = folder.video_list
    if (!field || source.length < 2) return source
    const cached = this.videoOrders.get(folder.date)
    if (cached && cached.source === source && cached.count === source.length && cached.field === field &&
      cached.ascending === ascending && cached.pinyin === pinyin) return cached.videos
    let videos: VideoMetadata[]
    switch (field) {
      case SortField.DATETIME:
        videos = MediaSortUtil.sortByDatetimeProcess(source, ascending)
        break
      case SortField.TIME:
        videos = MediaSortUtil.sortByTimeProcess(source, ascending)
        break
      case SortField.RECENT_PLAY:
        videos = MediaSortUtil.sortByRecentPlayProcess(source, ascending)
        break
      default:
        videos = MediaSortUtil.sortByNameProcess(source, ascending, pinyin)
    }
    this.videoOrders.set(folder.date,
      { source: source, count: source.length, field: field, ascending: ascending, pinyin: pinyin, videos: videos })
    return videos
  }

  coverDates(date: string): string[] {
    return this.covers.get(date) ?? []
  }

  entries(date: string | null, videos: VideoMetadata[], query: string, revision: number = 0): DirectoryEntry[] {
    const keyword = query.trim().toLocaleLowerCase()
    const cached = this.entryLists.get(date)
    if (cached && (date === null ||
      (cached.videos === videos && cached.count === videos.length && cached.revision === revision)) &&
      cached.query === keyword) return cached.entries
    const result = this.childFolders(date)
      .filter(folder => !keyword || folder.name.toLocaleLowerCase().includes(keyword))
      .map(folder => this.folderEntries.get(folder.date)!)
    if (date !== null) {
      for (const video of videos) {
        let entry = this.videoEntries.get(video)
        if (!entry) {
          entry = new DirectoryEntry(undefined, video)
          this.videoEntries.set(video, entry)
        }
        result.push(entry)
      }
    }
    this.entryLists.set(date, { videos: videos, count: videos.length, revision: revision, query: keyword, entries: result })
    return result
  }
}
