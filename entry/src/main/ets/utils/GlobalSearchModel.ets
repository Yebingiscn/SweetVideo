import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'

export interface SearchVideoEntry {
  video: VideoMetadata
  folders: string[]
}

export interface VisualSearchHit {
  imagePath: string
  similarity: number
}

export interface VisualSearchResult {
  hits: VisualSearchHit[]
  indexed: number
  skipped: number
}

export class GlobalSearchModel {
  static collect(folders: FileFolder[]): SearchVideoEntry[] {
    const byId = new Map<string, FileFolder>()
    folders.forEach(folder => byId.set(folder.date, folder))
    const entries = new Map<string, SearchVideoEntry>()
    // Read the stored flat collection, including collapsed child folders.
    for (const folder of folders) {
      const names: string[] = []
      const visited = new Set<string>()
      let current: FileFolder | undefined = folder
      while (current && !visited.has(current.date)) {
        visited.add(current.date)
        names.unshift(current.name)
        current = current.parent_date ? byId.get(current.parent_date) : undefined
      }
      const path = names.join(' / ')
      for (const video of folder.video_list) {

        const key = video.uri || video.date
        const existing = entries.get(key)
        if (existing) {
          if (!existing.folders.includes(path)) {
            existing.folders.push(path)
          }
        } else {
          entries.set(key, { video: video, folders: [path] })
        }
      }
    }
    return Array.from(entries.values())
  }
}
