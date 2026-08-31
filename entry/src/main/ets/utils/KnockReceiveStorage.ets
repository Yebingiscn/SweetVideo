import { Environment, fileIo, fileShare, fileUri, picker } from '@kit.CoreFileKit'
import { SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import { salmonLogger } from 'salmonlogger'
import { PathUtils } from './PathUtils'
import ToolsUtil from './ToolsUtil'

const TAG = 'KnockReceiveStorage'

/** 碰一碰使用空沙箱目录中转，只有隐私文件才长期保存在沙箱。 */
export default class KnockReceiveStorage {
  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  static async getDownloadDirectory(): Promise<string> {
    if (!canIUse('SystemCapability.FileManagement.File.Environment.FolderObtain')) {
      throw new Error('当前设备不支持获取公共下载目录')
    }
    // dataReceive 只在 PC/2in1 注册；使用系统返回的下载目录，不硬编码用户路径。
    const downloadRoot = Environment.getUserDownloadDir().replace(/\/+$/, '')
    if (!downloadRoot.startsWith('/') || downloadRoot === '') {
      throw new Error('系统未返回有效的下载目录')
    }
    const directory = `${downloadRoot}/流心播放器`
    const policy: fileShare.PolicyInfo = {
      uri: fileUri.getUriFromPath(directory),
      operationMode: fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE
    }
    const supportsAuthorization = canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization')
    if (supportsAuthorization) {
      const persisted = await fileShare.checkPersistentPermission([policy])
      if (persisted[0]) {
        await fileShare.activatePermission([policy])
      }
    }
    try {
      await fileIo.mkdir(directory, true)
      await fileIo.access(directory, fileIo.AccessModeType.WRITE)
    } catch (error) {
      const code = (error as BusinessError).code
      if ((code !== 13900012 && code !== 13900001) ||
        !canIUse('SystemCapability.FileManagement.UserFileService.FolderSelection')) {
        throw new Error(`下载目录不可用: ${code}`)
      }
      ToolsUtil.showToast('请授权 Download 目录或其中的“流心播放器”文件夹，用于保存碰一碰文件')
      const selected = await new picker.DocumentViewPicker(PathUtils.appContext!).select({
        selectMode: picker.DocumentSelectMode.FOLDER,
        maxSelectNumber: 1,
        defaultFilePathUri: fileUri.getUriFromPath(downloadRoot)
      })
      if (selected.length !== 1) {
        throw new Error('未授权碰一碰下载目录')
      }
      const selectedPath = new fileUri.FileUri(selected[0]).path.replace(/\/+$/, '')
      if (selectedPath !== downloadRoot && selectedPath !== directory) {
        throw new Error('请选择 Download 或 Download/流心播放器，未更改接收位置')
      }
      await fileIo.mkdir(directory, true)
      await fileIo.access(directory, fileIo.AccessModeType.WRITE)
    }
    if (supportsAuthorization) {
      try {
        // 即使用户选择了下载根目录，也只持久化本应用子目录的权限。
        await fileShare.persistPermission([policy])
      } catch (error) {
        salmonLogger.addLog(TAG, `下载目录授权持久化失败，下次可能需要重新选择: ${error}`, true)
      }
    }
    return directory
  }

  private static getSourcePath(uri: string, receivePath: string): string {
    const path = new fileUri.FileUri(uri).path
    const relativePath = path.substring(receivePath.length + 1)
    if (!path.startsWith(`${receivePath}/`) || relativePath.length === 0 ||
      relativePath.split('/').some((part: string) => part === '..' || part === '.')) {
      throw new Error('接收文件不在本次中转目录内')
    }
    return path
  }

  static async saveToDownloads(uri: string, receivePath: string, directory: string): Promise<string> {
    const sourcePath = KnockReceiveStorage.getSourcePath(uri, receivePath)
    const sourceStat = await fileIo.lstat(sourcePath)
    if (!sourceStat.isFile()) {
      throw new Error('接收内容不是普通文件')
    }
    const name = sourcePath.substring(sourcePath.lastIndexOf('/') + 1)
    const dot = name.lastIndexOf('.')
    const stem = dot > 0 ? name.substring(0, dot) : name
    const suffix = dot > 0 ? name.substring(dot) : ''
    // 独占的临时目录防止并发覆盖；最终移动使用不覆盖模式处理同名竞争。
    const temporaryDirectory = await fileIo.mkdtemp(`${directory}/.knock-XXXXXX`)
    const temporaryPath = `${temporaryDirectory}/received`
    try {
      await fileIo.copyFile(sourcePath, temporaryPath)
      if ((await fileIo.stat(temporaryPath)).size !== sourceStat.size) {
        throw new Error('转存文件大小校验失败')
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
          throw new Error(`移动转存文件失败: ${(error as BusinessError).code}, ${(error as BusinessError).message}`)
        }
        // 先生成有效 URI，再删除中转文件；转存后的条目始终引用公共文件。
        const destinationUri = fileUri.getUriFromPath(destination)
        await KnockReceiveStorage.removeReceivedSource(uri, receivePath)
        return destinationUri
      }
      throw new Error('下载目录中的同名文件过多')
    } finally {
      // 此目录只属于本次复制，不触碰目录外已有文件；失败时源文件仍在沙箱。
      try {
        await fileIo.rmdir(temporaryDirectory)
      } catch (error) {
        salmonLogger.addLog(TAG, `清理转存临时目录失败: ${error}`, true)
      }
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
}
