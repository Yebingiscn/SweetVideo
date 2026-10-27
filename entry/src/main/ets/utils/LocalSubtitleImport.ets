import { Context } from '@kit.AbilityKit'
import { fileIo as fs, fileUri } from '@kit.CoreFileKit'
import { salmonLogger } from 'salmonlogger'
import Preferences from '../database/Preferences'
import { PathUtils } from './PathUtils'
import SubtitleUtil from './SubtitleUtil'
import ToolsUtil from './ToolsUtil'
import VideoInfoUtil from './VideoInfoUtil'

export interface PreparedLocalSubtitle {
  path: string
  format: string
  date?: string
}

/** Directory discovery is shared only by one import batch. */
export default class LocalSubtitleImport {
  private static sequence: number = 0
  private static readonly formats: string[] = ['srt', 'ass', 'vtt']
  private directories: Map<string, Promise<Map<string, string[]>>> = new Map()
  private attached: Map<string, PreparedLocalSubtitle> = new Map()

  private static indexDirectory(entries: string[]): Map<string, string[]> {
    const index: Map<string, string[]> = new Map()
    for (const entry of entries) {
      if (entry.includes('/') || !LocalSubtitleImport.formats.includes(VideoInfoUtil.getExtension(entry))) continue
      const stem = VideoInfoUtil.splitFileName(entry).stem.toLowerCase()
      if (!index.has(stem)) index.set(stem, [])
      index.get(stem)!.push(entry)
    }
    for (const candidates of index.values()) {
      candidates.sort((left: string, right: string): number => {
        const priority = LocalSubtitleImport.formats.indexOf(VideoInfoUtil.getExtension(left)) -
          LocalSubtitleImport.formats.indexOf(VideoInfoUtil.getExtension(right))
        return priority || (left < right ? -1 : left > right ? 1 : 0)
      })
    }
    return index
  }

  async prepare(videoUri: string, fileName: string): Promise<PreparedLocalSubtitle | undefined> {
    if (ToolsUtil.isNetworkUrl(videoUri) || videoUri.startsWith('file://media/') ||
      (!videoUri.startsWith('/') && !videoUri.startsWith('file://'))) return undefined
    const stem = VideoInfoUtil.splitFileName(fileName).stem.toLowerCase()
    if (!stem) return undefined
    try {
      const isFileUri = videoUri.startsWith('file://')
      const filePath = isFileUri ? new fileUri.FileUri(videoUri).path : videoUri
      const directory = filePath.substring(0, filePath.lastIndexOf('/')) || '/'
      const parentUri = videoUri.substring(0, videoUri.lastIndexOf('/'))
      let listing = this.directories.get(parentUri)
      if (!listing) {
        // Selecting a video does not necessarily grant access to its parent.
        listing = fs.listFile(directory)
          .then((entries: string[]): Map<string, string[]> => LocalSubtitleImport.indexDirectory(entries))
          .catch((): Map<string, string[]> => new Map())
        this.directories.set(parentUri, listing)
      }
      const entries = (await listing).get(stem) ?? []
      for (const entry of entries) {
        const sourcePath = `${directory.replace(/\/$/, '')}/${entry}`
        const sourceUri = isFileUri ? `${parentUri}/${encodeURIComponent(entry)}` : sourcePath
        const temporary = `${PathUtils.tempPath}/subtitle-import-${Date.now()}-${++LocalSubtitleImport.sequence}`
        try {
          if (!(await fs.stat(sourcePath)).isFile()) continue
          await SubtitleUtil.importSubtitleFile(sourceUri, temporary)
          return { path: temporary, format: VideoInfoUtil.getExtension(entry) }
        } catch (_) {
          salmonLogger.addLog('LocalSubtitleImport', '同名字幕读取或转换失败，继续导入视频', true)
        }
      }
    } catch (_) {
      // Album/provider URIs do not necessarily expose a filesystem directory.
    }
    return undefined
  }

  /** Only the fast rename runs inside the existing metadata lock. */
  attach(prepared: PreparedLocalSubtitle | undefined, date: string): string {
    if (!prepared) return ''
    try {
      const target = PathUtils.subtitlePath + date
      if (!fs.accessSync(PathUtils.subtitlePath)) fs.mkdirSync(PathUtils.subtitlePath, true)
      if (fs.accessSync(target)) return ''
      fs.renameSync(prepared.path, target)
      prepared.path = target
      prepared.date = date
      return prepared.format
    } catch (_) {
      salmonLogger.addLog('LocalSubtitleImport', '同名字幕保存失败，继续导入视频', true)
      return ''
    }
  }

  retain(prepared: PreparedLocalSubtitle | undefined): boolean {
    if (!prepared?.date) return false
    this.attached.set(prepared.date, prepared)
    return true
  }

  async discard(prepared: PreparedLocalSubtitle | undefined): Promise<void> {
    if (!prepared) return
    try {
      await fs.unlink(prepared.path)
    } catch (error) {
      if (error.code !== 13900002) {
        salmonLogger.addLog('LocalSubtitleImport', '清理未关联的导入字幕失败', true)
      }
    }
    if (prepared.date) this.attached.delete(prepared.date)
  }

  async finish(context: Context, privateMode: boolean): Promise<void> {
    try {
      if (this.attached.size === 0) return
      const dates = Preferences.getSavedVideoDates(context, privateMode)
      // Final batch persistence can reject a duplicate or fail to save.
      // Reconcile only the subtitles created by this batch.
      for (const prepared of Array.from(this.attached.values())) {
        if (!dates.has(prepared.date!)) await this.discard(prepared)
      }
    } catch (_) {
      // An unreadable library is not proof that a subtitle is unreferenced.
      salmonLogger.addLog('LocalSubtitleImport', '无法核对导入字幕关联，保留已保存字幕', true)
    } finally {
      this.attached.clear()
      this.directories.clear()
    }
  }
}
