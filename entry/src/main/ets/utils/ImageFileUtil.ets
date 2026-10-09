import ImageStorage from './ImageStorage'
import { ConfigurationConstant } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { effectKit } from '@kit.ArkGraphics2D'
import { salmonLogger } from 'salmonlogger'
import ToolsUtil from './ToolsUtil'
import { Setting } from './ObservedUtil'
import { PathUtils } from './PathUtils'

const TAG = 'ImageFileUtil'

// 组合封面处理、主题背景选择与模糊缓存业务；文件操作直接使用 ImageStorage。
export default class ImageFileUtil {
  // 手动封面兼顾卡片和长按预览，保持比例并且不放大小图。
  private static readonly PICKED_COVER_MAX_EDGE: number = 960
  private static coverSaveSequence: number = 0

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
    return ImageStorage.getExistingImageUri(PathUtils.photoPath + ImageFileUtil.getCurrentBackgroundImageName())
  }

  static getExistingBlurImageUri(): string {
    const imageName = ImageFileUtil.getCurrentBackgroundImageName()
    return ImageStorage.getExistingImageUri(PathUtils.photoPath + imageName + '_blur')
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
      const blurUri = ImageStorage.getExistingImageUri(blurPath)
      if (blurUri) {
        Setting.backgroundBlurImageSrc = ''
        Setting.backgroundBlurImageSrc = blurUri
        return blurUri
      }
    }
    Setting.backgroundBlurImageSrc = ''
    const blurUri = await ImageFileUtil.generateBlurredBackground(imageName, blurRadius)
    Setting.backgroundBlurImageSrc = blurUri
    return blurUri
  }

  static getCurrentBackgroundImageName(): string {
    try {
      const currentColorMode = AppStorage.get('currentColorMode') as number
      if (currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK && Setting.enableBackgroundDarkImage &&
        ImageStorage.getExistingImageUri(PathUtils.photoPath + 'BackgroundDarkImage')) {
        return 'BackgroundDarkImage'
      }
    } catch (error) {
      salmonLogger.addLog(TAG, `Failed to select background image: ${error}`, true)
    }
    return 'BackgroundImage'
  }

  static async savePickedCover(sourceFileUri: string, date: string): Promise<boolean> {
    if (!sourceFileUri || !date) {
      return false
    }
    const filePath = PathUtils.coverPath + date
    const temporaryName = `${date}.${Date.now()}-${++ImageFileUtil.coverSaveSequence}.pending`
    const temporaryPath = PathUtils.coverPath + temporaryName
    let sourceFile: fs.File | undefined = undefined
    let imageSource: image.ImageSource | undefined = undefined
    let pixelMap: image.PixelMap | undefined = undefined
    try {
      sourceFile = await fs.open(sourceFileUri, fs.OpenMode.READ_ONLY)
      let useEncodedCover = false
      try {
        imageSource = image.createImageSource(sourceFile.fd)
        // 按帧数判断动图，不能仅根据文件后缀判断 GIF 或动态 WebP。
        const frameCount = await imageSource.getFrameCount()
        if (frameCount === 1) {
          const info = await imageSource.getImageInfo()
          const maxEdge = Math.max(info.size.width, info.size.height)
          if (maxEdge > 0 && !(info.mimeType === 'image/webp' &&
            maxEdge <= ImageFileUtil.PICKED_COVER_MAX_EDGE)) {
            const scale = Math.min(1, ImageFileUtil.PICKED_COVER_MAX_EDGE / maxEdge)
            pixelMap = await imageSource.createPixelMapUsingAllocator({
              desiredSize: {
                width: Math.max(1, Math.round(info.size.width * scale)),
                height: Math.max(1, Math.round(info.size.height * scale))
              },
              desiredPixelFormat: image.PixelMapFormat.RGBA_8888
            }, image.AllocatorType.AUTO)
            const savedPath = await ImageStorage.savePixelMapToFile(PathUtils.coverPath, temporaryName, pixelMap,
              { deleteOnFail: true })
            useEncodedCover = savedPath.length > 0
          }
        }
      } catch (error) {
        // 探测、解码或编码失败时保留原文件，也避免把未知动图误当成静态图。
        salmonLogger.addLog(TAG, `Cover optimization skipped: ${error}`)
      }
      if (!useEncodedCover) {
        const targetFile = await fs.open(temporaryPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
        try {
          await fs.copyFile(sourceFile.fd, targetFile.fd)
        } finally {
          ImageStorage.closeFileSafely(targetFile, '封面临时文件')
        }
      }
      // 成功后再替换旧封面，复制或转码失败不破坏已有文件。
      fs.renameSync(temporaryPath, filePath)
      return true
    } catch (error) {
      salmonLogger.addLog(TAG, `Failed to save picked cover: ${error}`, true)
      return false
    } finally {
      await ImageStorage.releaseImageSafely(pixelMap, '封面解码图片')
      await ImageStorage.releaseImageSafely(imageSource, '封面图片源')
      ImageStorage.closeFileSafely(sourceFile, '封面源文件')
      try {
        if (fs.accessSync(temporaryPath)) {
          fs.unlinkSync(temporaryPath)
        }
      } catch (error) {
        salmonLogger.addLog(TAG, `Failed to remove cover temporary file: ${error}`, true)
      }
    }
  }

  static async generateBlurredBackground(imageName: string, blurRadius: number): Promise<string> {
    if (blurRadius <= 0) {
      return ''
    }
    const sourcePath = PathUtils.photoPath + imageName
    const blurFileName = imageName + '_blur'
    let sourceFile: fs.File | undefined = undefined
    let imageSource: image.ImageSource | undefined = undefined
    let pixelMap: image.PixelMap | undefined = undefined
    let blurredPixelMap: image.PixelMap | undefined = undefined
    try {
      sourceFile = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY)
      imageSource = image.createImageSource(sourceFile.fd)
      pixelMap = await imageSource.createPixelMap()
      const effect = effectKit.createEffect(pixelMap)
      blurredPixelMap = await effect.blur(blurRadius).getEffectPixelMap()
      if (!blurredPixelMap) {
        return ''
      }
      const savedPath = await ImageStorage.savePixelMapToFile(PathUtils.photoPath!, blurFileName, blurredPixelMap, {
        deleteOnFail: true, format: 'image/jpeg'
      })
      return savedPath ? PathUtils.pathToUri(savedPath) : ''
    } catch (error) {
      salmonLogger.addLog(TAG, `Failed to generate blurred background: ${error}`, true)
      return ''
    } finally {
      await ImageStorage.releaseImageSafely(blurredPixelMap, '模糊图片')
      if (pixelMap !== blurredPixelMap) {
        await ImageStorage.releaseImageSafely(pixelMap, '背景原图')
      }
      await ImageStorage.releaseImageSafely(imageSource, '背景图片源')
      ImageStorage.closeFileSafely(sourceFile, '背景源文件')
    }
  }
}
