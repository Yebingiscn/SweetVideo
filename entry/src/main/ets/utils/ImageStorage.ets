import { fileIo as fs } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { JSON } from '@kit.ArkTS'
import { salmonLogger } from 'salmonlogger'
import { PathUtils } from './PathUtils'

const TAG = 'ImageStorage'

export interface SavePixelMapOptions {
  releasePixelMap?: boolean
  deleteOnFail?: boolean
  format?: string
}

// 图片原文件复制、PixelMap 编码及通用资源清理，不负责主题或封面业务选择。
export default class ImageStorage {
  static copyImageFile(sourceFileUri: string, filePath: string): boolean {
    if (!sourceFileUri || !filePath) {
      return false
    }
    let sourceFile: fs.File | undefined = undefined
    let targetFile: fs.File | undefined = undefined
    try {
      sourceFile = fs.openSync(sourceFileUri, fs.OpenMode.READ_ONLY)
      targetFile = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      fs.copyFileSync(sourceFile.fd, targetFile.fd)
      return true
    } catch (error) {
      salmonLogger.addLog(TAG, `Failed to copy image: ${error}`, true)
      return false
    } finally {
      ImageStorage.closeFileSafely(sourceFile, '图片源文件')
      ImageStorage.closeFileSafely(targetFile, '图片目标文件')
    }
  }

  static async savePixelMapToFile(basePath: string, fileName: string, pixelMap: image.PixelMap,
    options?: SavePixelMapOptions): Promise<string> {
    const filePath = basePath + fileName
    let packer: image.ImagePacker | undefined = undefined
    let file: fs.File | undefined = undefined
    try {
      packer = image.createImagePacker()
      file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      await packer.packToFile(pixelMap, file.fd, { format: options?.format ?? 'image/webp', quality: 85 })
      return filePath
    } catch (err) {
      salmonLogger.addLog(TAG, `Failed to save pixelMap to ${filePath}: ${JSON.stringify(err)} :${err.message}`, true)
      if (options?.deleteOnFail) {
        try {
          fs.accessSync(filePath) && fs.unlinkSync(filePath)
        } catch {
        }
      }
      return ''
    } finally {
      ImageStorage.closeFileSafely(file, '图片编码文件')
      await ImageStorage.releaseImageSafely(packer, '图片编码器')
      if (options?.releasePixelMap) {
        await ImageStorage.releaseImageSafely(pixelMap, '编码图片')
      }
    }
  }

  static getExistingImageUri(filePath: string): string {
    try {
      return fs.accessSync(filePath) ? PathUtils.pathToUri(filePath) : ''
    } catch (error) {
      salmonLogger.addLog(TAG, `Failed to access image: ${filePath} ${error}`, true)
      return ''
    }
  }

  static async releaseImageSafely(resource: image.PixelMap | image.ImageSource | image.ImagePacker | undefined,
    scene: string): Promise<void> {
    if (!resource) {
      return
    }
    try {
      await resource.release()
    } catch (error) {
      salmonLogger.addLog(TAG, `${scene}释放失败: ${error}`, true)
    }
  }

  static closeFileSafely(file: fs.File | null | undefined, scene: string): void {
    if (!file) {
      return
    }
    try {
      fs.closeSync(file.fd)
    } catch (error) {
      salmonLogger.addLog(TAG, `${scene}关闭文件失败: ${error}`, true)
    }
  }
}
