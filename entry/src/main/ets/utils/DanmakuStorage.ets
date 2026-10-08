import { fileIo as fs } from '@kit.CoreFileKit'
import { PathUtils } from './PathUtils'
import ToolsUtil from './ToolsUtil.ets'

export class DanmakuStorage {
  static get directory(): string {
    return `${PathUtils.sandboxPath}/danmaku`
  }

  static path(media: string): string {
    if (!PathUtils.sandboxPath || !media || media.length > 200) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.danmaku_invalid_video_id').id))
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
