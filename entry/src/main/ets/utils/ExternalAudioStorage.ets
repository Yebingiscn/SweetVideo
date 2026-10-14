import { fileIo as fs } from '@kit.CoreFileKit'
import { PathUtils } from './PathUtils'

export class ExternalAudioStorage {
  private static sequence: number = 0
  private static epochs: Map<string, number> = new Map()
  static readonly pending: Set<string> = new Set()
  static get directory(): string { return `${PathUtils.sandboxPath}/external_audio` }

  static create(media: string, extension: string): string {
    if (!media || media.length > 200 || !/^(mp3|aac|m4a|flac|wav)$/.test(extension)) {
      throw new Error('无效的外挂音频文件')
    }
    return `${encodeURIComponent(media)}~${Date.now()}-${++ExternalAudioStorage.sequence}.${extension}`
  }

  static owner(file: string): string {
    const match = /^(.*)~\d+-\d+\.(mp3|aac|m4a|flac|wav)(?:\.\d+-\d+\.tmp)?$/.exec(file)
    if (!match) return ''
    try {
      const media = decodeURIComponent(match[1])
      return media && media.length <= 200 && encodeURIComponent(media) === match[1] ? media : ''
    } catch (_) { return '' }
  }

  static path(file: string): string {
    if (!ExternalAudioStorage.owner(file)) throw new Error('无效的外挂音频路径')
    return `${ExternalAudioStorage.directory}/${file}`
  }

  static epoch(media: string): number { return ExternalAudioStorage.epochs.get(media) ?? 0 }
  static async removeFile(file: string): Promise<void> {
    const path = ExternalAudioStorage.path(file)
    try {
      await fs.unlink(path)
    } catch (error) {
      if (error.code !== 13900002) {
        throw new Error(`删除外挂音频文件失败: ${error.code}`)
      }
    }
  }

  static async remove(media: string): Promise<void> {
    ExternalAudioStorage.epochs.set(media, ExternalAudioStorage.epoch(media) + 1)
    let files: string[]
    try {
      files = await fs.listFile(ExternalAudioStorage.directory)
    } catch (error) {
      if (error.code === 13900002) { return }
      throw new Error(`读取外挂音频目录失败: ${error.code}`)
    }
    for (const file of files) {
      if (ExternalAudioStorage.owner(file) === media) await ExternalAudioStorage.removeFile(file)
    }
  }
}
