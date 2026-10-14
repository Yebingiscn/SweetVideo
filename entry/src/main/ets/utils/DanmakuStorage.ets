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
  static async remove(media: string): Promise<void> {
    const path = DanmakuStorage.path(media)
    try {
      await fs.unlink(path)
    } catch (error) {
      if (error.code !== 13900002) {
        throw new Error(`删除弹幕文件失败: ${error.code}`)
      }
    }
  }
}
