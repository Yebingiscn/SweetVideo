import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import FolderHierarchy from './FolderHierarchy'

export interface PrivacyVideoFolder {
  videoDate: string
  folderDate: string
}

export interface PrivacyFolderState {
  folders: FileFolder[]
  videoFolders: PrivacyVideoFolder[]
}

export interface PrivacyFolderDeletionPlan {
  folderDates: string[]
  videoDates: string[]
}

// 文件夹只是隐私媒体的归属索引，不复制元数据，不改变沙箱文件名或普通媒体库。
export default class PrivacyFolderUtil {
  static readonly ALL = '__privacy_all__'

  static empty(): PrivacyFolderState {
    return { folders: [], videoFolders: [] }
  }

  static parse(value: string): PrivacyFolderState {
    if (value === '') return PrivacyFolderUtil.empty()
    const state = JSON.parse(value) as PrivacyFolderState
    if (!state || !Array.isArray(state.folders) || !Array.isArray(state.videoFolders)) {
      throw new Error('privacy_folder_invalid_data')
    }
    for (const folder of state.folders) {
      if (!folder || typeof folder.date !== 'string' || folder.date === '' ||
        typeof folder.name !== 'string' ||
        (folder.parent_date !== null && typeof folder.parent_date !== 'string')) {
        throw new Error('privacy_folder_invalid_data')
      }
    }
    for (const item of state.videoFolders) {
      if (!item || typeof item.videoDate !== 'string' || typeof item.folderDate !== 'string') {
        throw new Error('privacy_folder_invalid_data')
      }
    }
    return PrivacyFolderUtil.copy(state)
  }

  static copy(state: PrivacyFolderState): PrivacyFolderState {
    const counts = new Map<string, number>()
    state.folders.forEach(folder => counts.set(folder.date, (counts.get(folder.date) ?? 0) + 1))
    const folders = FolderHierarchy.repair(state.folders.map((folder): FileFolder => ({
      name: folder.name, date: folder.date, parent_date: folder.parent_date, video_list: []
    })), false)
    const valid = new Set(folders.map(folder => folder.date))
    const assignments = new Map<string, string>()
    state.videoFolders.forEach(item => {
      // 归属失效或重复目录 ID 不丢媒体，显示到根目录；未恢复的异常媒体 ID 仍保留归属。
      if (item.videoDate && valid.has(item.folderDate) && counts.get(item.folderDate) === 1) {
        assignments.set(item.videoDate, item.folderDate)
      }
    })
    const videoFolders: PrivacyVideoFolder[] = []
    assignments.forEach((folderDate, videoDate) => videoFolders.push({ videoDate, folderDate }))
    return { folders, videoFolders }
  }

  static project(state: PrivacyFolderState, videos: VideoMetadata[]): FileFolder[] {
    const folders = state.folders.map((folder): FileFolder => ({
      name: folder.name, date: folder.date, parent_date: folder.parent_date, video_list: []
    }))
    const byId = new Map<string, FileFolder>()
    folders.forEach(folder => byId.set(folder.date, folder))
    const assignments = new Map<string, string>()
    state.videoFolders.forEach(item => assignments.set(item.videoDate, item.folderDate))
    videos.forEach(video => byId.get(assignments.get(video.date) ?? '')?.video_list.push(video))
    return folders
  }

  static videosIn(state: PrivacyFolderState, videos: VideoMetadata[], date: string): VideoMetadata[] {
    if (date === PrivacyFolderUtil.ALL) return videos.slice()
    const valid = new Set(state.folders.map(folder => folder.date))
    const assignments = new Map<string, string>()
    state.videoFolders.forEach(item => {
      if (valid.has(item.folderDate)) assignments.set(item.videoDate, item.folderDate)
    })
    return videos.filter(video => (assignments.get(video.date) ?? '') === date)
  }

  private static checkParent(state: PrivacyFolderState, parentDate: string | null): void {
    if (parentDate !== null && !state.folders.some(folder => folder.date === parentDate)) {
      throw new Error('target_folder_not_found')
    }
  }

  private static checkName(state: PrivacyFolderState, name: string, parentDate: string | null,
    excluding: string = ''): string {
    const trimmed = name.trim()
    if (!trimmed || trimmed === '.' || trimmed === '..' || trimmed.length > 100 || /[\\/\u0000-\u001f]/.test(trimmed)) {
      throw new Error('privacy_folder_invalid_name')
    }
    if (state.folders.some(folder => folder.date !== excluding && folder.parent_date === parentDate &&
      folder.name === trimmed)) {
      throw new Error('same_folder_name_exists')
    }
    return trimmed
  }

  static create(state: PrivacyFolderState, name: string, parentDate: string | null): PrivacyFolderState {
    const next = PrivacyFolderUtil.copy(state)
    PrivacyFolderUtil.checkParent(next, parentDate)
    const trimmed = PrivacyFolderUtil.checkName(next, name, parentDate)
    next.folders.push({ name: trimmed, date: FolderHierarchy.createId(next.folders),
      parent_date: parentDate, video_list: [] })
    return next
  }

  static rename(state: PrivacyFolderState, date: string, name: string): PrivacyFolderState {
    const next = PrivacyFolderUtil.copy(state)
    const folder = next.folders.find(item => item.date === date)
    if (!folder) throw new Error('target_folder_not_found')
    folder.name = PrivacyFolderUtil.checkName(next, name, folder.parent_date, date)
    return next
  }

  static moveFolder(state: PrivacyFolderState, date: string, parentDate: string | null): PrivacyFolderState {
    const next = PrivacyFolderUtil.copy(state)
    const folder = next.folders.find(item => item.date === date)
    if (!folder) throw new Error('target_folder_not_found')
    PrivacyFolderUtil.checkParent(next, parentDate)
    if (parentDate !== null && FolderHierarchy.descendants(next.folders, date).has(parentDate)) {
      throw new Error('privacy_folder_cycle')
    }
    PrivacyFolderUtil.checkName(next, folder.name, parentDate, date)
    folder.parent_date = parentDate
    return next
  }

  static moveVideos(state: PrivacyFolderState, dates: string[], targetDate: string): PrivacyFolderState {
    const next = PrivacyFolderUtil.copy(state)
    PrivacyFolderUtil.checkParent(next, targetDate || null)
    const selected = new Set(dates)
    next.videoFolders = next.videoFolders.filter(item => !selected.has(item.videoDate))
    if (targetDate) {
      selected.forEach(videoDate => next.videoFolders.push({ videoDate, folderDate: targetDate }))
    }
    return next
  }

  static deletionPlan(state: PrivacyFolderState, date: string): PrivacyFolderDeletionPlan {
    if (!state.folders.some(folder => folder.date === date)) throw new Error('target_folder_not_found')
    const removed = FolderHierarchy.descendants(state.folders, date)
    // 使用全量归属，包含搜索不可见媒体和元数据丢失、仍有沙箱文件的异常项。
    const videos = new Set(state.videoFolders.filter(item => removed.has(item.folderDate)).map(item => item.videoDate))
    return { folderDates: Array.from(removed), videoDates: Array.from(videos) }
  }

  // 文件及关联记录全部清理成功后，才提交目录与归属删除；不转移任何媒体。
  static remove(state: PrivacyFolderState, date: string): PrivacyFolderState {
    const next = PrivacyFolderUtil.copy(state)
    const removed = new Set(PrivacyFolderUtil.deletionPlan(next, date).folderDates)
    next.folders = next.folders.filter(item => !removed.has(item.date))
    next.videoFolders = next.videoFolders.filter(item => !removed.has(item.folderDate))
    return next
  }
}
