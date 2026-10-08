import { ConfigurationConstant } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { effectKit } from '@kit.ArkGraphics2D'
import { JSON } from '@kit.ArkTS'
import { salmonLogger } from 'salmonlogger'
import ToolsUtil from './ToolsUtil'
import { Setting } from './ObservedUtil'
import { PathUtils } from './PathUtils'

const TAG = 'SelectFileUtil'

export interface SavePixelMapOptions {
  releasePixelMap?: boolean
  deleteOnFail?: boolean
  format?: string
}

// 背景、模糊图和封面共用同一套图片文件处理与资源释放逻辑。
export default class ImageFileUtil {
  static async deletePhoto(imageName: 'BackgroundImage' | 'BackgroundDarkImage' | 'avatar'): Promise<void> {
    try {
      const res = await fs.access(PathUtils.photoPath! + imageName)
      if (res) {
        await new Promise<void>((resolve, reject) => {
          fs.unlink(PathUtils.photoPath! + imageName, (unlinkErr) => {
            if (unlinkErr) {
              ToolsUtil.showToast(ToolsUtil.getStringResourceArgs($r('app.string.delete_failed_reason').id, unlinkErr.message))
              reject(unlinkErr)
            } else {
              ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.delete_success').id))
              resolve()
            }
          })
        })
      } else {
        salmonLogger.addLog(TAG, "照片不存在", true)
      }
    } catch (err) {
      salmonLogger.addLog(TAG, "access failed with error message: " + err.message + ", error code: " + err.code, true)
    }
    try {
      const blurPath = PathUtils.photoPath! + imageName + '_blur'
      if (fs.accessSync(blurPath)) {
        fs.unlinkSync(blurPath)
      }
    } catch (e) {
      salmonLogger.addLog(TAG, `Failed to delete blur image: ${e}`, true)
    }
  }

  static getImageUri(): string {
    const currentColorMode = AppStorage.get('currentColorMode') as number
    const basePhotoPath = PathUtils.photoPath!
    const getSafeUri = (fileName: string): string => {
      const fullPath = `${basePhotoPath}${fileName}`
      try {
        if (fs.accessSync(fullPath)) {
          return PathUtils.pathToUri(fullPath)
        }
      } catch (e) {
        salmonLogger.addLog(TAG, `Failed to access image: ${fullPath} ` + e)
      }
      return ''
    }
    try {
      // 1. 处理亮色模式
      if (currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
        return getSafeUri('BackgroundImage')
      }
      // 2. 处理暗色模式
      if (currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
        // 检查深浅色图片切换开关，仅在开关开启时使用深色背景
        if (Setting.enableBackgroundDarkImage) {
          const darkUri = getSafeUri('BackgroundDarkImage')
          if (darkUri) {
            return darkUri
          }
        }
        // 开关关闭或深色背景不存在，降级返回浅色背景
        return getSafeUri('BackgroundImage')
      }
      // 3. 其他未定义的模式，默认返回空或根据需求返回亮色图
      return ''
    } catch (error) {
      // 捕获顶层意外错误（如 AppStorage 读取失败等）
      salmonLogger.addLog(TAG, 'Unexpected error in getImageUri' + error, true)
      return ''
    }
  }

  static getExistingBlurImageUri(): string {
    const imageName = ImageFileUtil.getCurrentBackgroundImageName()
    const blurPath = PathUtils.photoPath + imageName + '_blur'
    try {
      if (fs.accessSync(blurPath)) {
        return PathUtils.pathToUri(blurPath)
      }
    } catch (e) {
      salmonLogger.addLog(TAG, `Failed to access blur image: ${blurPath} ` + e, true)
    }
    return ''
  }

  static async updateBlurBackground(blurRadius: number, forceRegenerate: boolean = false): Promise<string> {
    if (blurRadius <= 0) {
      Setting.backgroundBlurImageSrc = ''
      return ''
    }
    const imageName = ImageFileUtil.getCurrentBackgroundImageName()
    const blurFileName = imageName + '_blur'
    const blurPath = PathUtils.photoPath + blurFileName
    if (!forceRegenerate) {
      try {
        if (fs.accessSync(blurPath)) {
          const blurUri = PathUtils.pathToUri(blurPath)
          Setting.backgroundBlurImageSrc = ''
          Setting.backgroundBlurImageSrc = blurUri
          return blurUri
        }
      } catch (e) {
        salmonLogger.addLog(TAG, `Failed to access blur image: ${blurPath} ` + e, true)
      }
    }
    Setting.backgroundBlurImageSrc = ''
    const blurUri = await ImageFileUtil.generateBlurredBackground(imageName, blurRadius)
    Setting.backgroundBlurImageSrc = blurUri
    return blurUri
  }

  static getCurrentBackgroundImageName(): string {
    const currentColorMode = AppStorage.get('currentColorMode') as number
    if (currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      return 'BackgroundImage'
    }
    if (currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      // 仅在深浅色图片切换开关开启时使用深色背景
      if (Setting.enableBackgroundDarkImage) {
        const darkPath = PathUtils.photoPath + 'BackgroundDarkImage'
        try {
          if (fs.accessSync(darkPath)) {
            return 'BackgroundDarkImage'
          }
        } catch (e) {
          salmonLogger.addLog(TAG, `Failed to access dark background image: ${darkPath} ` + e, true)
        }
      }
      return 'BackgroundImage'
    }
    return 'BackgroundImage'
  }

  static saveImageToSandBox(sourceFileUri: string, imageName: string): void {
    const filePath = PathUtils.photoPath + imageName // 定义完整文件路径
    try {
      let sourceFile = fs.openSync(sourceFileUri, fs.OpenMode.READ_ONLY)
      let targetFile = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)

      fs.copyFileSync(sourceFile.fd, targetFile.fd)

      fs.closeSync(sourceFile)
      fs.closeSync(targetFile)
    } catch (error) {
      salmonLogger.addLog(TAG, 'File operation error:' + error, true)
    }
  }

  static savePickedCover(sourceFileUri: string, date: string): boolean {
    if (!sourceFileUri || !date) {
      return false
    }
    const filePath = PathUtils.coverPath + date
    let sourceFile: fs.File | undefined = undefined
    let targetFile: fs.File | undefined = undefined
    try {
      sourceFile = fs.openSync(sourceFileUri, fs.OpenMode.READ_ONLY)
      targetFile = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      fs.copyFileSync(sourceFile.fd, targetFile.fd)
      return true
    } catch (error) {
      salmonLogger.addLog(TAG, `替换封面失败: ${error}`, true)
      return false
    } finally {
      ImageFileUtil.closeFileSafely(sourceFile, '封面源文件')
      ImageFileUtil.closeFileSafely(targetFile, '封面目标文件')
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
      if (file) {
        try {
          fs.closeSync(file)
        } catch (e) {
          salmonLogger.addLog(TAG, 'Failed to close file: ' + e, false)
        }
      }
      if (packer) {
        try {
          packer.release()
        } catch (e) {
          salmonLogger.addLog(TAG, 'Failed to release packer: ' + e, false)
        }
      }
      if (options?.releasePixelMap) {
        try {
          pixelMap.release()
        } catch (e) {
          salmonLogger.addLog(TAG, 'Failed to release pixelMap: ' + e, false)
        }
      }
    }
  }

  static async generateBlurredBackground(imageName: string, blurRadius: number): Promise<string> {
    if (blurRadius <= 0) {
      return ''
    }
    const sourcePath = PathUtils.photoPath + imageName
    const blurFileName = imageName + '_blur'
    const blurPath = PathUtils.photoPath + blurFileName
    let sourceFile: fs.File | undefined = undefined
    let imageSource: image.ImageSource | undefined = undefined
    let pixelMap: image.PixelMap | undefined = undefined
    try {
      sourceFile = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY)
      imageSource = image.createImageSource(sourceFile.fd)
      pixelMap = await imageSource.createPixelMap()
      const effect = effectKit.createEffect(pixelMap)
      const blurredPixelMap = await effect.blur(blurRadius).getEffectPixelMap()
      await ImageFileUtil.savePixelMapToFile(PathUtils.photoPath!, blurFileName, blurredPixelMap!, {
        releasePixelMap: true, format: 'image/jpeg'
      })
      return PathUtils.pathToUri(blurPath)
    } catch (error) {
      salmonLogger.addLog(TAG, `Failed to generate blurred background: ${error}`, true)
      return ''
    } finally {
      try {
        pixelMap?.release()
        imageSource?.release()
        if (sourceFile) {
          fs.closeSync(sourceFile)
        }
      } catch (e) {
        salmonLogger.addLog(TAG, `Failed to release resources in generateBlurredBackground: ${e}`, true)
      }
    }
  }

  private static closeFileSafely(file: fs.File | null | undefined, scene: string): void {
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
