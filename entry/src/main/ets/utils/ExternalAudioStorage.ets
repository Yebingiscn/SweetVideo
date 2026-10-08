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
  static removeFile(file: string): void {
    const path = ExternalAudioStorage.path(file)
    if (fs.accessSync(path)) fs.unlinkSync(path)
  }

  static async remove(media: string): Promise<void> {
    ExternalAudioStorage.epochs.set(media, ExternalAudioStorage.epoch(media) + 1)
    if (!fs.accessSync(ExternalAudioStorage.directory)) return
    for (const file of await fs.listFile(ExternalAudioStorage.directory)) {
      if (ExternalAudioStorage.owner(file) === media) ExternalAudioStorage.removeFile(file)
    }
  }
}
