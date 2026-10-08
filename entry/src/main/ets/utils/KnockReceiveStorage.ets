import { fileIo, fileUri } from '@kit.CoreFileKit'
import { salmonLogger } from 'salmonlogger'
import VideoInfoUtil from './VideoInfoUtil'
import ToolsUtil from './ToolsUtil.ets'

const TAG = 'KnockReceiveStorage'

/** 碰一碰使用空沙箱目录中转，只有隐私文件才长期保存在沙箱。 */
export default class KnockReceiveStorage {
  static async saveToDownloads(uri: string, receivePath: string, directory: string): Promise<string> {
    try {
      const sourcePath = KnockReceiveStorage.getSourcePath(uri, receivePath)
      const sourceStat = await fileIo.lstat(sourcePath)
      if (!sourceStat.isFile()) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.knock_content_not_file').id))
      }
      const name = sourcePath.substring(sourcePath.lastIndexOf('/') + 1)
      const parts = VideoInfoUtil.splitFileName(name)
      const stem = parts.stem
      const suffix = parts.ext
      // 独占的临时目录防止并发覆盖；最终移动使用不覆盖模式处理同名竞争。
      const temporaryDirectory = await fileIo.mkdtemp(`${directory}/.knock-XXXXXX`)
      const temporaryPath = `${temporaryDirectory}/received`
      try {
        await fileIo.copyFile(sourcePath, temporaryPath)
        if ((await fileIo.stat(temporaryPath)).size !== sourceStat.size) {
          throw new Error(ToolsUtil.getStringResource($r('app.string.knock_size_check_failed').id))
        }
        for (let index = 0; index < 10000; index++) {
          const candidateName = index === 0 ? name : `${stem} (${index})${suffix}`
          const destination = `${directory}/${candidateName}`
          try {
            await fileIo.moveFile(temporaryPath, destination, 1)
          } catch (error) {
            if ((error as BusinessError).code === 13900015) {
              continue
            }
            throw new Error(ToolsUtil.getStringResourceArgs2($r('app.string.knock_move_failed_detail').id, (error as BusinessError).code, (error as BusinessError).message))
          }
          // 先生成有效 URI，再删除中转文件；转存后的条目始终引用公共文件。
          const destinationUri = fileUri.getUriFromPath(destination)
          await KnockReceiveStorage.removeReceivedSource(uri, receivePath)
          return destinationUri
        }
        throw new Error(ToolsUtil.getStringResource($r('app.string.knock_too_many_duplicates').id))
      } finally {
        // 此目录只属于本次复制，不触碰目录外已有文件；失败时源文件仍在沙箱。
        try {
          await fileIo.rmdir(temporaryDirectory)
        } catch (error) {
          salmonLogger.addLog(TAG, `清理转存临时目录失败: ${error}`, true)
        }
      }
    } catch (error) {
      throw new Error(ToolsUtil.getStringResourceArgs($r('app.string.knock_save_failed').id, String(error)))
    }
  }

  static async removeReceivedSource(uri: string, receivePath: string): Promise<void> {
    try {
      await fileIo.unlink(KnockReceiveStorage.getSourcePath(uri, receivePath))
    } catch (error) {
      salmonLogger.addLog(TAG, `清理已转存的接收副本失败: ${error}`, true)
    }
  }

  static async removeEmptyReceiveDirectory(receivePath: string): Promise<void> {
    try {
      // 不递归清理有内容的接收目录，失败或尚未导入的文件必须保留。
      if ((await fileIo.listFile(receivePath)).length === 0) {
        await fileIo.rmdir(receivePath)
      }
    } catch (error) {
      salmonLogger.addLog(TAG, `清理空接收目录失败: ${error}`, true)
    }
  }

  private static getSourcePath(uri: string, receivePath: string): string {
    const path = new fileUri.FileUri(uri).path
    const relativePath = path.substring(receivePath.length + 1)
    if (!path.startsWith(`${receivePath}/`) || relativePath.length === 0 ||
      relativePath.split('/').some((part: string) => part === '..' || part === '.')) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.knock_file_outside_temp').id))
    }
    return path
  }
}
