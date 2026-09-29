import { fileIo as fs } from '@kit.CoreFileKit'
import { PathUtils } from './PathUtils'

export class DanmakuStorage {
  static get directory(): string {
    return `${PathUtils.sandboxPath}/danmaku`
  }

  static path(media: string): string {
    if (!PathUtils.sandboxPath || !media || media.length > 200) {
      throw new Error('无效的视频标识')
    }
    return `${DanmakuStorage.directory}/${encodeURIComponent(media)}.xml`
  }

  // Called by the same video-resource cleanup path as external subtitles.
  static remove(media: string): void {
    const path = DanmakuStorage.path(media)
    if (fs.accessSync(path)) {
      fs.unlinkSync(path)
    }
  }
}
