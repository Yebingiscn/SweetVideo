import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { SearchVideoEntry } from './GlobalSearchModel'
import ToolsUtil from './ToolsUtil'

interface VideoSearchSnapshot {
  video: VideoMetadata
  uri: string
  date: string
  title: string
  artist: string
  album: string
  displayKey: string
}

interface FolderSearchSnapshot {
  date: string
  name: string
  parent: string | null
  videos: VideoSearchSnapshot[]
}

interface SearchIndexRow {
  entry: SearchVideoEntry
  title: string
  artist: string
  album: string
  fileName: string
}

interface SearchDisplaySnapshot {
  key: string
  video: VideoMetadata
}

// Short, cancellable batches keep large libraries from occupying a whole UI frame.
class SearchWorkGate {
  private count: number = 0
  private started: number = Date.now()
  private isCurrent: () => boolean

  constructor(isCurrent: () => boolean) {
    this.isCurrent = isCurrent
  }

  async step(): Promise<boolean> {
    if (!this.isCurrent()) {
      return false
    }
    if (++this.count >= 128 || Date.now() - this.started >= 4) {
      await new Promise<void>((resolve) => setTimeout(resolve, 0))
      this.count = 0
      this.started = Date.now()
    }
    return this.isCurrent()
  }
}

// Page-owned, memory-only cache. Never share entries between public/private scopes.
export class GlobalSearchIndex {
  private snapshots: FolderSearchSnapshot[] = []
  private entries: SearchVideoEntry[] = []
  private rows: SearchIndexRow[] = []
  private scope: string = ''
  private initialized: boolean = false
  private displayCopies: WeakMap<VideoMetadata, SearchDisplaySnapshot> = new WeakMap()

  private displayKey(video: VideoMetadata): string {
    // Only the fields displayed by VideoListItem/VideoInfoBuilder, not a JSON
    // serialization of the full library or persisted playback settings.
    const fields: string[] = [video.uri, video.title, video.artist ?? '', video.album ?? '', video.date,
      String(video.last_play), String(video.time),
      video.size?.join(',') ?? '', video.cover_size?.join(',') ?? '', String(video.hdr_type),
      String(video.audio_type), video.format, video.video_size, String(video.frame_rate), String(video.bit_rate),
      String(video.has_video_track)]
    return JSON.stringify(fields)
  }

  private displayVideo(item: VideoSearchSnapshot): VideoMetadata {
    const previous = this.displayCopies.get(item.video)
    if (previous?.key === item.displayKey) {
      return previous.video
    }
    const video = item.video
    // Only visible metadata is copied. Playback actions still use entry.video,
    // so cached display rows cannot restore stale subtitle/audio settings.
    const copy: VideoMetadata = {
      uri: video.uri,
      title: video.title,
      artist: video.artist,
      album: video.album,
      date: video.date,
      size: video.size?.slice() ?? [],
      cover_size: video.cover_size?.slice(),
      has_video_track: video.has_video_track,
      time: video.time,
      last_play: video.last_play,
      format: video.format,
      video_size: video.video_size,
      bit_rate: video.bit_rate,
      hdr_type: video.hdr_type,
      audio_type: video.audio_type,
      frame_rate: video.frame_rate,
      start_time: video.start_time,
      end_time: video.end_time,
      external_subtitle_format: video.external_subtitle_format,
      pointA: video.pointA,
      pointB: video.pointB
    }
    this.displayCopies.set(video, { key: item.displayKey, video: copy })
    return copy
  }

  clear(): void {
    this.snapshots = []
    this.entries = []
    this.rows = []
    this.scope = ''
    this.initialized = false
    this.displayCopies = new WeakMap()
  }

  async load(folders: FileFolder[], scope: string, isCurrent: () => boolean): Promise<SearchVideoEntry[] | undefined> {
    const gate = new SearchWorkGate(isCurrent)
    const snapshots: FolderSearchSnapshot[] = []
    let changed = !this.initialized || scope !== this.scope || folders.length !== this.snapshots.length
    for (let i = 0; i < folders.length; i++) {
      const folder = folders[i]
      const previous = this.snapshots[i]
      const snapshot: FolderSearchSnapshot = {
        date: folder.date,
        name: folder.name,
        parent: folder.parent_date ?? null,
        videos: []
      }
      if (!previous || previous.date !== snapshot.date || previous.name !== snapshot.name ||
        previous.parent !== snapshot.parent || previous.videos.length !== folder.video_list.length) {
        changed = true
      }
      for (let j = 0; j < folder.video_list.length; j++) {
        if (!await gate.step()) {
          return undefined
        }
        const video = folder.video_list[j]
        const old = previous?.videos[j]
        const item: VideoSearchSnapshot = {
          video: video,
          uri: video.uri,
          date: video.date,
          title: video.title,
          artist: video.artist ?? '',
          album: video.album ?? '',
          displayKey: this.displayKey(video)
        }
        snapshot.videos.push(item)
        // Retain newest metadata references even when only non-search fields changed.
        if (!old || old.video !== video || old.uri !== item.uri || old.date !== item.date ||
          old.title !== item.title || old.artist !== item.artist || old.album !== item.album ||
          old.displayKey !== item.displayKey) {
          changed = true
        }
      }
      snapshots.push(snapshot)
    }
    if (!isCurrent()) {
      return undefined
    }
    if (!changed) {
      return this.entries
    }

    const byId = new Map<string, FolderSearchSnapshot>()
    snapshots.forEach(folder => byId.set(folder.date, folder))
    const entries = new Map<string, SearchVideoEntry>()
    for (const folder of snapshots) {
      const names: string[] = []
      const visited = new Set<string>()
      let current: FolderSearchSnapshot | undefined = folder
      while (current && !visited.has(current.date)) {
        if (!await gate.step()) {
          return undefined
        }
        visited.add(current.date)
        names.unshift(current.name)
        current = current.parent ? byId.get(current.parent) : undefined
      }
      const path = names.join(' / ')
      for (const item of folder.videos) {
        if (!await gate.step()) {
          return undefined
        }
        const key = item.uri || item.date
        const existing = entries.get(key)
        if (existing) {
          if (!existing.folders.includes(path)) {
            existing.folders.push(path)
          }
        } else {
          // A fresh item reference also refreshes @Param children when source
          // metadata (for example last_play) was changed in-place while hidden.
          entries.set(key, { video: item.video, displayVideo: this.displayVideo(item), folders: [path] })
        }
      }
    }
    const nextEntries = Array.from(entries.values())
    const rows: SearchIndexRow[] = []
    for (const entry of nextEntries) {
      if (!await gate.step()) {
        return undefined
      }
      rows.push({
        entry: entry,
        title: entry.video.title.toLowerCase(),
        artist: entry.video.artist?.toLowerCase() ?? '',
        album: entry.video.album?.toLowerCase() ?? '',
        fileName: ToolsUtil.fileNameFromUri(entry.video.uri).toLowerCase()
      })
    }
    if (!isCurrent()) {
      return undefined
    }
    this.snapshots = snapshots
    this.entries = nextEntries
    this.rows = rows
    this.scope = scope
    this.initialized = true
    return this.entries
  }

  async search(query: string, isCurrent: () => boolean): Promise<SearchVideoEntry[] | undefined> {
    const value = query.trim().toLowerCase()
    if (!isCurrent()) {
      return undefined
    }
    if (!value) {
      return this.entries
    }
    const gate = new SearchWorkGate(isCurrent)
    const matches = new Set<string>()
    // Match exactly the existing title/artist/album/decoded-filename rules.
    for (const row of this.rows) {
      if (!await gate.step()) {
        return undefined
      }
      if (row.title.includes(value) || row.artist.includes(value) || row.album.includes(value) ||
        row.fileName.includes(value)) {
        matches.add(row.entry.video.uri)
      }
    }
    const result: SearchVideoEntry[] = []
    for (const entry of this.entries) {
      if (!await gate.step()) {
        return undefined
      }
      if (matches.has(entry.video.uri)) {
        result.push(entry)
      }
    }
    return isCurrent() ? result : undefined
  }
}
