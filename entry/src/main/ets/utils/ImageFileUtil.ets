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
  private static backgroundRefreshVersion: number = 0
  private static blurRequestVersion: number = 0
  private static blurTaskKey: string = ''
  private static blurTask: Promise<string> | undefined = undefined
  private static backgroundVersions: Map<string, number> = new Map()
  private static invalidBlurImages: Set<string> = new Set()
  private static imagesToReload: Set<string> = new Set()

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
    if (imageName !== 'avatar') {
      ImageFileUtil.invalidateBackgroundCache(imageName, true)
    }
  }

  static invalidateBackgroundCache(imageName: 'BackgroundImage' | 'BackgroundDarkImage',
    imageChanged: boolean = false): void {
    ImageFileUtil.backgroundVersions.set(imageName, (ImageFileUtil.backgroundVersions.get(imageName) ?? 0) + 1)
    ImageFileUtil.invalidBlurImages.add(imageName)
    if (imageChanged) ImageFileUtil.imagesToReload.add(imageName)
    try {
      const blurPath = PathUtils.photoPath + imageName + '_blur'
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

  static async refreshBackground(forceRegenerate: boolean = false): Promise<string> {
    const refreshVersion = ++ImageFileUtil.backgroundRefreshVersion
    const imageName = ImageFileUtil.getCurrentBackgroundImageName()
    const imageUri = ImageFileUtil.getImageUri()
    if (ImageFileUtil.imagesToReload.has(imageName)) {
      ImageFileUtil.imagesToReload.delete(imageName)
      if (imageUri && Setting.backgroundImageSrc === imageUri) {
        // Reload changed bytes at the same URI only when replacing the visible image.
        Setting.backgroundImageSrc = ''
        Setting.backgroundBlurImageSrc = ''
        await new Promise<void>((resolve) => setTimeout(resolve, 100))
        if (refreshVersion !== ImageFileUtil.backgroundRefreshVersion ||
          imageName !== ImageFileUtil.getCurrentBackgroundImageName()) return ''
      }
    }
    Setting.backgroundImageSrc = imageUri
    return ImageFileUtil.updateBlurBackground(imageUri ? Setting.backgroundDropBlur : 0, forceRegenerate)
  }

  static async updateBlurBackground(blurRadius: number, forceRegenerate: boolean = false): Promise<string> {
    const imageName = ImageFileUtil.getCurrentBackgroundImageName()
    if (forceRegenerate) ImageFileUtil.invalidateBackgroundCache(imageName)
    const sourceVersion = ImageFileUtil.backgroundVersions.get(imageName) ?? 0
    const taskKey = `${imageName}:${sourceVersion}:${blurRadius}`
    if (!forceRegenerate && ImageFileUtil.blurTask && ImageFileUtil.blurTaskKey === taskKey) {
      return ImageFileUtil.blurTask
    }
    const requestVersion = ++ImageFileUtil.blurRequestVersion
    ImageFileUtil.blurTask = undefined
    ImageFileUtil.blurTaskKey = taskKey
    if (!Number.isFinite(blurRadius) || blurRadius <= 0 || !ImageFileUtil.getImageUri()) {
      Setting.backgroundBlurImageSrc = ''
      return ''
    }
    const blurFileName = imageName + '_blur'
    const blurPath = PathUtils.photoPath + blurFileName
    if (!forceRegenerate && !ImageFileUtil.invalidBlurImages.has(imageName)) {
      const blurUri = ImageStorage.getExistingImageUri(blurPath)
      if (blurUri) {
        Setting.backgroundBlurImageSrc = blurUri
        return blurUri
      }
    }
    Setting.backgroundBlurImageSrc = ''
    const task = ImageFileUtil.generateBlurredBackground(imageName, blurRadius, requestVersion, sourceVersion)
      .then((blurUri: string): string => {
        if (!ImageFileUtil.isBlurRequestCurrent(imageName, blurRadius, requestVersion, sourceVersion)) return ''
        Setting.backgroundBlurImageSrc = blurUri
        return blurUri
      })
    ImageFileUtil.blurTask = task
    try {
      return await task
    } finally {
      if (requestVersion === ImageFileUtil.blurRequestVersion) {
        ImageFileUtil.blurTask = undefined
        ImageFileUtil.blurTaskKey = ''
      }
    }
  }

  private static isBlurRequestCurrent(imageName: string, blurRadius: number, requestVersion: number,
    sourceVersion: number): boolean {
    return requestVersion === ImageFileUtil.blurRequestVersion &&
      sourceVersion === (ImageFileUtil.backgroundVersions.get(imageName) ?? 0) &&
      imageName === ImageFileUtil.getCurrentBackgroundImageName() &&
      blurRadius === Setting.backgroundDropBlur
  }

  static getCurrentBackgroundImageName(): 'BackgroundImage' | 'BackgroundDarkImage' {
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
              desiredPixelFormat: info.isHdr ? image.PixelMapFormat.RGBA_1010102 : image.PixelMapFormat.RGBA_8888,
              desiredDynamicRange: image.DecodingDynamicRange.AUTO
            }, info.isHdr ? image.AllocatorType.DMA : image.AllocatorType.AUTO)
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

  private static async generateBlurredBackground(imageName: string, blurRadius: number, requestVersion: number,
    sourceVersion: number): Promise<string> {
    const sourcePath = PathUtils.photoPath + imageName
    const blurFileName = imageName + '_blur'
    const temporaryName = `${blurFileName}.${Date.now()}-${requestVersion}.pending`
    const temporaryPath = PathUtils.photoPath + temporaryName
    let sourceFile: fs.File | undefined = undefined
    let imageSource: image.ImageSource | undefined = undefined
    let pixelMap: image.PixelMap | undefined = undefined
    let blurredPixelMap: image.PixelMap | undefined = undefined
    try {
      sourceFile = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY)
      imageSource = image.createImageSource(sourceFile.fd)
      pixelMap = await imageSource.createPixelMap()
      if (!ImageFileUtil.isBlurRequestCurrent(imageName, blurRadius, requestVersion, sourceVersion)) return ''
      const effect = effectKit.createEffect(pixelMap)
      blurredPixelMap = await effect.blur(blurRadius).getEffectPixelMap()
      if (!blurredPixelMap ||
        !ImageFileUtil.isBlurRequestCurrent(imageName, blurRadius, requestVersion, sourceVersion)) {
        return ''
      }
      const savedPath = await ImageStorage.savePixelMapToFile(PathUtils.photoPath!, temporaryName, blurredPixelMap, {
        deleteOnFail: true, format: 'image/jpeg'
      })
      if (!savedPath ||
        !ImageFileUtil.isBlurRequestCurrent(imageName, blurRadius, requestVersion, sourceVersion)) return ''
      const blurPath = PathUtils.photoPath + blurFileName
      fs.renameSync(savedPath, blurPath)
      ImageFileUtil.invalidBlurImages.delete(imageName)
      return PathUtils.pathToUri(blurPath)
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
      try {
        if (fs.accessSync(temporaryPath)) fs.unlinkSync(temporaryPath)
      } catch (error) {
        salmonLogger.addLog(TAG, `Failed to remove blur temporary file: ${error}`, true)
      }
    }
  }
}
