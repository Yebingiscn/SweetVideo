import { window } from '@kit.ArkUI'
import { audio } from '@kit.AudioKit'
import { BusinessError, settings } from '@kit.BasicServicesKit'
import { media } from '@kit.MediaKit'
import { SaveOptions, VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { AudioTrack, SubtitleTrack } from '../interfaces/AudioTrackInterface'
import { common } from '@kit.AbilityKit'
import { PathUtils } from './PathUtils'
import ToolsUtil from './ToolsUtil'
import { PlayerEngine } from '../common/NavigationCommon'
import { Setting } from './ObservedUtil'
import { fileIo } from '@kit.CoreFileKit'
import { SweetRepeatMode } from '../common/enum/SweetRepeatMode'
import { BackgroundColorMode } from '../common/enum/BackgroundColorMode'
import { CoverLayoutMode, ListDisplayMode } from '../common/enum/DisplayMode'
import { MpvDecodingMethod } from '../controller/MpvController/MpvTypes'
import preferences from '@ohos.data.preferences'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { image } from '@kit.ImageKit'
import VideoInfoUtil from './VideoInfoUtil'
import { salmonLogger } from 'salmonlogger'
import { FrameSize } from '../interfaces/FrameSizeInterface'
import { Subtitle3DMode } from '../common/enum/SubtitleMode'
import { DeleteType } from '../common/enum/DeleteType'
import { SCALE_FACTORS, SUPPORT_AUDIO_FORMAT } from '../common/Constants'
import { VideoSource } from '../common/enum/VideoSource'
import { VideoStartTimeMode } from '../common/enum/VideoStartTimeMode'
import { LanguageConfig } from '../common/LanguageConfig'
import Preferences from '../database/Preferences'
import PreferencesUtil from '../database/PreferencesUtil'
import { XAnimation } from './AnimationUtil'
import DataSyncUtil from './DataSyncUtil'
import PermissionUtil from './PermissionUtil'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import RecentPlayUtil from './RecentPlayUtil'
import SelectFileUtil from './SelectFileUtil'
import SubtitleUtil from './SubtitleUtil'
import { WindowUtil } from './WindowUtil'
import { fileManagerService } from '@kit.FileManagerServiceKit'

const TAG = 'VideoOperateUtil'

// 视频操作类
export default class VideoOperateUtil {
  public static maxVolume: number = 0
  public static minVolume: number = 0
  public static initPinchDistance: number = 0
  public static initPinchWidth: number = 0
  public static initPinchHeight: number = 0
  public static initScaleFactor: number = 1
  public static clearSubtitleTimer: number | null = null
  public static screenBrightnessTmp: number = 0
  public static lastSpeed: number = 1
  public static lastPlayTime: number = 0
  public static lastVolume: number = 0
  public static windowStage: window.WindowStage | undefined = undefined
  public static longPressStartX: number = 0
  public static panStartX: number = 0
  public static panStartY: number = 0
  public static autoHideTimeout: boolean = false
  public static leftSideSwipe: boolean = true
  public static avImageGenerator: media.AVImageGenerator | undefined = undefined
  public static nowPlayingFile: fileIo.File | undefined = undefined
  public static updatePix: boolean = true
  private static avImageGeneratorLifecycleTask: Promise<void> = Promise.resolve()
  private static mainWin: window.Window | undefined = undefined

  // 设置亮度
  static setBrightness(screenBrightness: number) {
    if (!VideoOperateUtil.windowStage) {
      return
    }
    try {
      if (!VideoOperateUtil.mainWin) {
        VideoOperateUtil.mainWin = VideoOperateUtil.windowStage.getMainWindowSync()
      }
      VideoOperateUtil.mainWin.setWindowBrightness(screenBrightness, (err) => {
        if (err && err.code !== 0) {
          salmonLogger.addLog(TAG, `Failed to obtain the main window. Cause code: ${err.code}, message: ${err.message}`,
            true)
        }
      })
    } catch (exception) {
      salmonLogger.addLog(TAG, `Failed to obtain the main window.`, true)
    }
  }

  // 获取系统音量
  static getVolume(): Map<string, number> {
    let volume_list: Map<string, number> = new Map()
    try {
      const volumeManager = audio.getAudioManager().getVolumeManager()
      const volume: number = volumeManager.getVolumeByStream(audio.StreamUsage.STREAM_USAGE_MOVIE)
      volume_list.set('volume', volume)
      const maxVolume: number = volumeManager.getMaxVolumeByStream(audio.StreamUsage.STREAM_USAGE_MOVIE)
      volume_list.set('max_volume', maxVolume)
      VideoOperateUtil.maxVolume = maxVolume
      const minVolume: number = volumeManager.getMinVolumeByStream(audio.StreamUsage.STREAM_USAGE_MOVIE)
      volume_list.set('min_volume', minVolume)
      VideoOperateUtil.minVolume = minVolume
    } catch (error) {
      salmonLogger.addLog(TAG, `Failed to get volume: ${error}`, true)
    }
    return volume_list
  }

  // 计算手指移动距离
  static calcFingerDistance(f1: FingerInfo, f2: FingerInfo): number {
    // 检查坐标是否存在
    if (
      typeof f1?.localX != 'number' ||
        typeof f1?.localY != 'number' ||
        typeof f2?.localX != 'number' ||
        typeof f2?.localY != 'number'
    ) {
      return -1
    }
    const dx = f2.localX - f1.localX
    const dy = f2.localY - f1.localY
    return Math.sqrt(dx * dx + dy * dy)
  }

  static async getAudioTracks(avPlayer: media.AVPlayer): Promise<AudioTrack[]> {
    try {
      return await VideoOperateUtil.getTracksByType<AudioTrack>(avPlayer, media.MediaType.MEDIA_TYPE_AUD,
        (desc): AudioTrack => ({
          index: desc[media.MediaDescriptionKey.MD_KEY_TRACK_INDEX] as number,
          language: desc[media.MediaDescriptionKey.MD_KEY_LANGUAGE] as string,
          name: desc[media.MediaDescriptionKey.MD_KEY_TRACK_NAME] as string,
          mime: desc[media.MediaDescriptionKey.MD_KEY_CODEC_MIME] as string,
          channelCount: desc[media.MediaDescriptionKey.MD_KEY_AUD_CHANNEL_COUNT] as number,
        }), 'audioTracks')
    } catch (error) {
      salmonLogger.addLog(TAG, `获取 audioTracks 失败: ${error}`, true)
      ToolsUtil.showToast('获取音轨失败')
      return []
    }
  }

  static async getInnerSubtitles(avPlayer: media.AVPlayer | undefined | null): Promise<SubtitleTrack[]> {
    if (!avPlayer) {
      return []
    }
    try {
      return await VideoOperateUtil.getTracksByType<SubtitleTrack>(avPlayer, media.MediaType.MEDIA_TYPE_SUBTITLE,
        (desc): SubtitleTrack => ({
          id: desc[media.MediaDescriptionKey.MD_KEY_TRACK_INDEX] as number,
          lang: desc[media.MediaDescriptionKey.MD_KEY_LANGUAGE] as string,
          title: desc[media.MediaDescriptionKey.MD_KEY_TRACK_NAME] as string
        }), 'subtitleTracks')
    } catch (error) {
      salmonLogger.addLog(TAG, "获取 subtitleTracks 失败: " + error, true)
      return []
    }
  }

  // 保存视频播放进度
  static saveVideoProperty(context: Context, nowPlaying: VideoMetadata, options: SaveOptions) {
    SelectFileUtil.saveData(context, nowPlaying!, options)
  }

  static saveVideoTime(play_time: number, nowPlaying: VideoMetadata, context: Context) {
    VideoOperateUtil.saveVideoProperty(context, nowPlaying, { playTime: play_time })
    if (Setting.recentPlay && !PrivacySpaceUtil.getPrivacyMode() &&
      !SelectFileUtil.isPathFromSource(nowPlaying.uri, VideoSource.PRIVACY_SPACE)) {
      const result = Preferences.findVideoByDate(context, nowPlaying.date)
      RecentPlayUtil.addPlayback(context, result[0] ?? nowPlaying!)
    }
  }

  static saveVideoPlayTimeIfNeed(playTime: number, nowPlaying: VideoMetadata | undefined,
    skipHistory: boolean, context: Context): void {
    salmonLogger.addLog(TAG, `保存视频播放时间开始${playTime}, ${nowPlaying?.date}`, false)
    if (!nowPlaying || playTime <= 0 || skipHistory) {
      return
    }
    VideoOperateUtil.saveVideoTime(playTime, nowPlaying, context)
    salmonLogger.addLog(TAG, `保存视频播放时间完成`, false)
  }

  static saveVideoStartTime(startTime: number, nowPlaying: VideoMetadata, context: Context) {
    VideoOperateUtil.saveVideoProperty(context, nowPlaying, { startTime: startTime })
  }

  static saveVideoEndTime(endTime: number, nowPlaying: VideoMetadata, context: Context) {
    VideoOperateUtil.saveVideoProperty(context, nowPlaying, { endTime: endTime })
  }

  static saveVideoWeightAndHeight(context: Context, nowPlaying: VideoMetadata) {
    VideoOperateUtil.saveVideoProperty(context, nowPlaying, { size: nowPlaying.size })
  }

  static saveVideoTotalTime(context: Context, nowPlaying: VideoMetadata) {
    VideoOperateUtil.saveVideoProperty(context, nowPlaying, { totalTime: nowPlaying.time })
  }

  static saveVideoPointA(context: Context, nowPlaying: VideoMetadata, pointA?: number) {
    VideoOperateUtil.saveVideoProperty(context, nowPlaying, { pointA: pointA })
  }

  static saveVideoPointB(context: Context, nowPlaying: VideoMetadata, pointB?: number) {
    VideoOperateUtil.saveVideoProperty(context, nowPlaying, { pointB: pointB })
  }

  static saveVideoHdrType(context: Context, nowPlaying: VideoMetadata, hdrType: number) {
    VideoOperateUtil.saveVideoProperty(context, nowPlaying, { hdrType: hdrType })
  }

  static saveVideoAudioType(context: Context, nowPlaying: VideoMetadata, audioType: number) {
    VideoOperateUtil.saveVideoProperty(context, nowPlaying, { audioType: audioType })
  }

  static saveLastPlayVideoIndex(list: VideoMetadata[], date: string | undefined) {
    if (!date) {
      return
    }
    const targetIndex = list.findIndex(i => i.date === date)
    if (targetIndex === DataSyncUtil.lastPlayVideoIndex) {
      DataSyncUtil.lastPlayVideoIndex = -1
    } else {
      DataSyncUtil.lastPlayVideoIndex = targetIndex
    }
  }

  static async getFrameTimePreprocess(uri: string) {
    if (!Setting.showFrameImgStatus) {
      return
    }
    const previousTask = VideoOperateUtil.avImageGeneratorLifecycleTask
    const task = previousTask.catch(() => {
    }).then(async () => {
      await VideoOperateUtil.releaseAVImageGeneratorNow()
      if (!Setting.showFrameImgStatus) {
        return
      }
      let generator: media.AVImageGenerator | undefined
      let file: fileIo.File | undefined
      try {
        generator = await media.createAVImageGenerator()
        file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY)
        const avFileDescriptor: media.AVFileDescriptor = { fd: file.fd }
        generator.fdSrc = avFileDescriptor
        VideoOperateUtil.avImageGenerator = generator
        VideoOperateUtil.nowPlayingFile = file
        VideoOperateUtil.updatePix = true
      } catch (error) {
        salmonLogger.addLog(TAG, 'getFrameTimePreprocess error' + error, true)
        try {
          await generator?.release()
        } catch (_error) {
        }
        if (file) {
          try {
            fileIo.closeSync(file)
          } catch (_error) {
          }
        }
      }
    })
    VideoOperateUtil.avImageGeneratorLifecycleTask = task
    await task
  }

  static async releaseAVImageGenerator(): Promise<void> {
    const previousTask = VideoOperateUtil.avImageGeneratorLifecycleTask
    const task = previousTask.catch(() => {
    }).then(async () => {
      await VideoOperateUtil.releaseAVImageGeneratorNow()
    })
    VideoOperateUtil.avImageGeneratorLifecycleTask = task
    await task
  }

  static async fetchFrameByTime(time: number, videoSize?: number[]) {
    if (Setting.showFrameImgStatus) {
      try {
        await VideoOperateUtil.avImageGeneratorLifecycleTask
        let size: FrameSize
        if (!videoSize) {
          return undefined
        }
        // 这里需要排除掉音频文件
        if (videoSize[0] === 0 || videoSize[1] === 0 || videoSize[0] === videoSize[1]) {
          return undefined
        }
        if (videoSize.length >= 2) {
          size = VideoOperateUtil.calculateFrameSize(videoSize[0], videoSize[1])
        } else {
          size = { width: 100, height: 100 }
        }
        return await VideoOperateUtil.avImageGenerator?.fetchFrameByTime(time * 1000,
          media.AVImageQueryOptions.AV_IMAGE_QUERY_CLOSEST, size)
      } catch (e) {
        salmonLogger.addLog(TAG, 'fetchFrameByTime error', e)
        return undefined
      }
    }
    return undefined
  }

  static async fullScreenOrRotateScreen(screenWidth: number, screenHeight: number,
    windowClass: Promise<window.Window | undefined>) {
    const orientation =
      await WindowUtil.fullScreenOperate(screenHeight, screenWidth, windowClass)
    if (orientation) {
      XAnimation.runWithAnimation(async () => {
        (await windowClass)?.setPreferredOrientation(orientation)?.catch(() => {
          salmonLogger.addLog(TAG, 'setPreferredOrientation error', true)
        })
      })
    }
  }

  static changeVolume(currentVolume: number, step: number) {
    const newVolume = currentVolume + step
    // 确保音量在有效范围内
    return Math.min(Math.max(newVolume, VideoOperateUtil.minVolume), VideoOperateUtil.maxVolume)
  }

  // 启动时初始化已保存的设置项
  static initSetting(context: common.UIAbilityContext) {
    PermissionUtil.reqPermissionsFromUser(PermissionUtil.permissions, context)
    Setting.backgroundImageSrc = SelectFileUtil.getImageUri()
    const settingDefaults: Record<string, preferences.ValueType> = {
      'backgroundDropBlur': 0,
      'backgroundColorMode': BackgroundColorMode.AUTO,
      'allowBackgroundPlay': true,
      'allowConcurrentPlay': false,
      'allowPlayBackExist': false,
      'fastForwardSeconds': '15',
      'recentPlay': true,
      'showToast': true,
      'defaultPlayerEngine': '系统播放器',
      'subtitleSize': '22',
      'subtitlePosition': 90,
      'subtitleColor': '#F0F0F0',
      'subtitleBold': false,
      'subtitleItalic': false,
      'subtitleBorderSize': 1,
      'subtitleBorderColor': '#000000',
      'subtitleShadowEnabled': true,
      'subtitleShadowSize': 6,
      'subtitleShadowColor': '#000000',
      'subtitleBackgroundOpacity': 0,
      'allowDoubleFastForward': true,
      'skipIntroTime': '0',
      'skipOutroTime': '0',
      'listDisplayMode': ListDisplayMode.LIST_DISPLAY,
      'smartRotation': true,
      'longPressSpeed': 3,
      'showSettingPageEntry': true,
      'allowGestureEntry': true,
      'showFrameTime': true,
      'jumpToHistoryTime': true,
      'coverLayoutMode': CoverLayoutMode.VERTICAL_PLATE,
      'superResolutionState': false,
      'mpvShaderMode': 0,
      'autoActivePip': false,
      'autoResumeOnReturn': false,
      'mpv_decoding_method': MpvDecodingMethod.HARDWARE_SURFACE,
      'enableBackgroundDarkImage': false,
      'enableAiPrivacyAntiPeep': false,
      'defaultBrightness': 0,
      'defaultDensityEnabled': true,
      'maxListLine': 5,
      'listItemBackgroundBlur': false
    }
    const keys = Object.keys(settingDefaults)
    const defaults = Object.values(settingDefaults)
    const values = PreferencesUtil.batchGetPreferencesValue(context, 'sweet_video', keys, defaults)
    const valueMap: Record<string, preferences.ValueType> = {}
    keys.forEach((key, i) => {
      valueMap[key] = values[i]
    })
    Setting.backgroundDropBlur = valueMap['backgroundDropBlur'] as number
    if (Setting.backgroundDropBlur > 0 && Setting.backgroundImageSrc.length > 0) {
      Setting.backgroundBlurImageSrc = SelectFileUtil.getExistingBlurImageUri()
    }
    Setting.backgroundColorMode = valueMap['backgroundColorMode'] as BackgroundColorMode
    Setting.allowBackgroundPlay = valueMap['allowBackgroundPlay'] as boolean
    Setting.allowConcurrentPlay = valueMap['allowConcurrentPlay'] as boolean
    Setting.allowPlayBackExist = valueMap['allowPlayBackExist'] as boolean
    Setting.fastForwardSeconds = valueMap['fastForwardSeconds'] as string
    Setting.recentPlay = valueMap['recentPlay'] as boolean
    Setting.showToast = valueMap['showToast'] as boolean
    Setting.defaultPlayerEngine = valueMap['defaultPlayerEngine'] as string
    Setting.subtitleSize = valueMap['subtitleSize'] as string
    Setting.subtitlePosition = valueMap['subtitlePosition'] as number
    Setting.subtitleColor = valueMap['subtitleColor'] as string
    Setting.subtitleBold = valueMap['subtitleBold'] as boolean
    Setting.subtitleItalic = valueMap['subtitleItalic'] as boolean
    Setting.subtitleBorderSize = valueMap['subtitleBorderSize'] as number
    Setting.subtitleBorderColor = valueMap['subtitleBorderColor'] as string
    Setting.subtitleShadowEnabled = valueMap['subtitleShadowEnabled'] as boolean
    Setting.subtitleShadowSize = valueMap['subtitleShadowSize'] as number
    Setting.subtitleShadowColor = valueMap['subtitleShadowColor'] as string
    Setting.subtitleBackgroundOpacity = valueMap['subtitleBackgroundOpacity'] as number
    Setting.allowDoubleFastForward = valueMap['allowDoubleFastForward'] as boolean
    Setting.skipIntroTime = valueMap['skipIntroTime'] as string
    Setting.skipOutroTime = valueMap['skipOutroTime'] as string
    Setting.listDisplayMode = valueMap['listDisplayMode'] as ListDisplayMode
    Setting.smartRotation = valueMap['smartRotation'] as boolean
    Setting.longPressSpeed = valueMap['longPressSpeed'] as number
    Setting.showSettingPageEntry = valueMap['showSettingPageEntry'] as boolean
    Setting.allowGestureEntry = valueMap['allowGestureEntry'] as boolean
    Setting.showFrameImgStatus = valueMap['showFrameTime'] as boolean
    Setting.jumpToHistoryTimeStatus = valueMap['jumpToHistoryTime'] as boolean
    Setting.coverLayout = valueMap['coverLayoutMode'] as CoverLayoutMode
    Setting.superResolutionState = valueMap['superResolutionState'] as boolean
    Setting.mpvShaderMode = valueMap['mpvShaderMode'] as number
    Setting.autoActivePip = valueMap['autoActivePip'] as boolean
    Setting.autoResumeOnReturn = valueMap['autoResumeOnReturn'] as boolean
    Setting.mpvDecodingMethod = valueMap['mpv_decoding_method'] as MpvDecodingMethod
    Setting.enableBackgroundDarkImage = valueMap['enableBackgroundDarkImage'] as boolean
    Setting.enableAiPrivacyAntiPeep = valueMap['enableAiPrivacyAntiPeep'] as boolean
    Setting.defaultBrightness = valueMap['defaultBrightness'] as number
    Setting.defaultDensityEnabled = valueMap['defaultDensityEnabled'] as boolean
    Setting.maxListLine = valueMap['maxListLine'] as number
    Setting.listItemBackgroundBlur = valueMap['listItemBackgroundBlur'] as boolean
  }

  // 封装获取屏幕亮度的方法
  static async getScreenBrightness(): Promise<number> {
    if (canIUse('SystemCapability.Applications.Settings.Core')) {
      try {
        const value = await settings.getValue(
          PathUtils.appContext!,
          settings.display.SCREEN_BRIGHTNESS_STATUS,
          settings.domainName.DEVICE_SHARED
        )
        return Number(value) / 255
      } catch (error) {
        return 0
      }
    }
    return 0
  }

  static getLanguageName(code: string): string {
    if (!code) {
      return code
    }
    const lowerCode = code.toLowerCase()
    return LanguageConfig.languageMap[lowerCode] || code
  }

  static calcScreenExtendSize(text: string | undefined, screenWidth: number, screenHeight: number): number[] | null {
    if (!text || text === '原始比例') {
      return null
    }
    if (VideoInfoUtil.ASPECT_RATIO_MAP.has(text)) {
      return VideoOperateUtil.setVideoAspectRatio(
        VideoInfoUtil.ASPECT_RATIO_MAP.get(text)!,
        VideoInfoUtil.playAreaWidth, VideoInfoUtil.playAreaHeight)
    }
    if (text === '拉伸全屏') {
      return [screenWidth, screenHeight]
    }
    if (text === '按宽度全屏') {
      return [screenWidth, (VideoInfoUtil.playAreaHeight / VideoInfoUtil.playAreaWidth) * screenWidth]
    }
    if (text === '按高度全屏') {
      return [(VideoInfoUtil.playAreaWidth / VideoInfoUtil.playAreaHeight) * screenHeight, screenHeight]
    }
    let scale: number | undefined
    if (text.startsWith('自定义比例:')) {
      scale = parseInt(text.split(':')[1]) / 100
    } else {
      scale = SCALE_FACTORS.get(text)
    }
    if (scale !== undefined) {
      return [scale * VideoInfoUtil.playAreaWidth, scale * VideoInfoUtil.playAreaHeight]
    }
    return null
  }

  static setVideoAspectRatio(targetRatio: number, containerWidth: number, containerHeight: number) {
    let finalWidth = 0
    let finalHeight = 0
    const containerRatio = containerWidth / containerHeight
    if (containerRatio > targetRatio) {
      // 容器比目标“更宽” → 固定高度，按比例缩小宽度
      finalHeight = containerHeight
      finalWidth = containerHeight * targetRatio // 宽度 = 高度 × 目标比例
    } else {
      // 容器比目标“更高” → 固定宽度，按比例缩小高度
      finalWidth = containerWidth
      finalHeight = containerWidth / targetRatio // 高度 = 宽度 ÷ 目标比例
    }
    return [finalWidth, finalHeight]
  }

  static getVideoStartPlayTimeMode(nowPlaying: VideoMetadata): number {
    // 先判断 nowPlaying 是否有效
    if (!nowPlaying) {
      return -1
    }
    const start_time = nowPlaying.start_time
    const end_time = nowPlaying.end_time
    const last_play = nowPlaying.last_play ?? 0
    const time = nowPlaying.time ?? 0
    const title = nowPlaying.title
    const isAlmostComplete = time > 0 && last_play >= time * 0.95
    // 已观看完成的视频再次打开时显式跳到开头，避免播放器沿用末尾位置后立即触发 completed。
    if (isAlmostComplete && (start_time == null || start_time <= 0)) {
      return VideoStartTimeMode.SEEK_TO_BEGINNING
    }
    // 条件1：若设置了片头时间（start_time > 0），且片头<=总时长 且 片头<片尾（片头+片尾<=总时长）
    if (start_time != null && start_time > 0 && (time <= 0 || start_time <= time)
      && (end_time == null || end_time <= 0 || end_time > start_time)) {
      const isBeforeStart = last_play < start_time
      const isBeyondEnd = end_time != null && end_time > 0 && last_play >= end_time
      if (isBeforeStart || isAlmostComplete || isBeyondEnd) {
        ToolsUtil.showToast('已跳过片头')
        return VideoStartTimeMode.SEEK_TO_START_TIME
      }
    }
    // 条件2：若有有效播放记录（且未接近结尾），则跳转到上次播放位置
    if (last_play !== 0 && last_play < time * 0.95 && Setting.jumpToHistoryTimeStatus) {
      ToolsUtil.showToast('已跳到上次播放时间')
      return VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME
    }
    // 条件3：若无播放记录，但全局设置了统一片头跳过时间（仅适用于视频）
    const skipIntroSeconds = Number(Setting.skipIntroTime)
    if (skipIntroSeconds > 0) {
      const skipIntroMs = skipIntroSeconds * 1000
      const skipOutroMs = Number(Setting.skipOutroTime) * 1000
      if (skipIntroMs < time && skipIntroMs + skipOutroMs <= time && title != null) {
        const parts = title.split('.')
        const fileExt = parts.length > 0 ? parts[parts.length - 1].toLowerCase() : ''
        if (fileExt !== '' && !SUPPORT_AUDIO_FORMAT.includes(fileExt)) {
          ToolsUtil.showToast('已跳过统一的片头时间')
          return VideoStartTimeMode.SEEK_TO_INTRO_TIME
        }
      }
    }
    return -1
  }

  static calNewBrightness(deltaYScale: number) {
    const newBrightness = VideoOperateUtil.screenBrightnessTmp - deltaYScale
    return Math.min(Math.max(newBrightness, 0), 1)
  }

  static getTimePixel(screenWidth: number, videoTime: number) {
    return videoTime > 600000 ? 600000 / screenWidth : videoTime / screenWidth
  }

  static saveCaptureScreenToAlbum(surfaceID: string) {
    try {
      // 1. 截屏 → 沙箱临时文件
      const pixelMap = image.createPixelMapFromSurfaceSync(surfaceID)
      const packOpts: image.PackingOption = { format: 'image/png', quality: 100 }
      const imagePackerApi = image.createImagePacker()
      const tempPath = PathUtils.tempPath + '/screenshot.png'
      const tempFile = fileIo.openSync(tempPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
      let srcUri: string
      imagePackerApi.packToFile(pixelMap, tempFile.fd, packOpts)
        .then(() => imagePackerApi.release())
        .then(async () => {
          fileIo.closeSync(tempFile)
          // 2. 用系统对话框保存到相册
          srcUri = PathUtils.pathToUri(tempPath)
          const helper = photoAccessHelper.getPhotoAccessHelper(PathUtils.appContext)
          return await helper.showAssetsCreationDialog(
            [srcUri],
            [{ photoType: photoAccessHelper.PhotoType.IMAGE, fileNameExtension: 'png' }]
          )
        })
        .then(dstUris => {
          // 3. 拷贝到用户选择的相册位置
          if (dstUris.length) {
            const src = fileIo.openSync(srcUri, fileIo.OpenMode.READ_ONLY)
            const dst = fileIo.openSync(dstUris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
            fileIo.copyFileSync(src.fd, dst.fd)
            fileIo.closeSync(src)
            fileIo.closeSync(dst)
            ToolsUtil.showToast('保存成功')
          }
        })
        ?.catch((err: BusinessError) => {
          salmonLogger.addLog(TAG, `packToFile failed: ${err.code}, ${err.message}`, true)
        })
    } catch (e) {
      salmonLogger.addLog(TAG, `captureScreen failed: ${e.code}, ${e.message}`, true)
    }
  }

  static getRepeatMode(repeatMode: SweetRepeatMode): SweetRepeatMode {
    switch (repeatMode) {
      case SweetRepeatMode.LIST:
        return SweetRepeatMode.SINGLE
      case SweetRepeatMode.SINGLE:
        return SweetRepeatMode.RANDOM
      case SweetRepeatMode.RANDOM:
        return SweetRepeatMode.SEQUENCE
      case SweetRepeatMode.SEQUENCE:
        return SweetRepeatMode.LIST
      default:
        return SweetRepeatMode.LIST
    }
  }

  static resolvePlayerType(metadata: VideoMetadata, reverse: boolean = false) {
    const defaultPlayer = Preferences.getDefaultPlayerEngine(PathUtils.appContext!)
    const isAv3a = metadata.title?.toLowerCase().includes('av3a') || metadata.format?.toLowerCase().includes('av3a')
    const titleLower = metadata.title?.toLowerCase() ?? ''
    const formatLower = metadata.format?.toLowerCase() ?? ''
    const isDolbyAudio = titleLower.includes('eac3') || titleLower.includes('ddp') ||
      titleLower.includes('atmos') || titleLower.includes('truehd') ||
      formatLower.includes('eac3') || formatLower.includes('ddp')
    const hasSize = VideoInfoUtil.videoWidthAndHeightFormat(String(metadata.size)) !== '0 x 0'
    if (isAv3a && hasSize) {
      return PlayerEngine.AV_PLAYER
    }
    if (!hasSize) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.video_error').id))
      return PlayerEngine.MPV_PLAYER
    }
    if (isDolbyAudio) {
      return PlayerEngine.MPV_PLAYER
    }
    const isFirstPlayer = defaultPlayer === VideoInfoUtil.playerEngineList[0]
    return (reverse ? !isFirstPlayer : isFirstPlayer) ? PlayerEngine.AV_PLAYER : PlayerEngine.MPV_PLAYER
  }

  static getPlayerName(defaultAddress: string, reverse: boolean = false) {
    const isFirstPlayer = defaultAddress === VideoInfoUtil.playerEngineList[0];
    return (reverse ? !isFirstPlayer : isFirstPlayer)
      ? $r('app.string.AV_PLAYER')
      : $r('app.string.MPV_Player');
  }

  static computeNextVideo(
    videoMetaDataList: VideoMetadata[],
    nowPlaying: VideoMetadata | undefined,
    repeatMode: SweetRepeatMode
  ): VideoMetadata | undefined {
    if (videoMetaDataList.length === 0) {
      return undefined
    }
    let item = SelectFileUtil.getItem(videoMetaDataList, nowPlaying?.date || '') as VideoMetadata
    if (!item) {
      item = videoMetaDataList[0]
    }
    switch (repeatMode) {
      case SweetRepeatMode.RANDOM:
        const availableVideos = videoMetaDataList.filter(v => v.date !== item.date)
        return availableVideos.length > 0
          ? availableVideos[Math.floor(Math.random() * availableVideos.length)]
          : item
      case SweetRepeatMode.ONCE:
        return undefined
      case SweetRepeatMode.SEQUENCE:
        if (SelectFileUtil.isLastItem(videoMetaDataList, item.date)) {
          return undefined
        }
        return SelectFileUtil.getNextItem(videoMetaDataList, item.date)
      case SweetRepeatMode.SINGLE:
        return videoMetaDataList.find(v => v.date === nowPlaying?.date)!
      case SweetRepeatMode.LIST:
        return SelectFileUtil.getNextItem(videoMetaDataList, item.date)
      default:
        return undefined
    }
  }

  static saveSubtitlePreference(
    nowPlaying: VideoMetadata | undefined,
    subtitleSelected: number,
    subtitleTrackSelected: number,
    subtitleVisibility: Visibility,
    isAIAsrShown: boolean,
    subtitle3DMode: Subtitle3DMode
  ): void {
    const appContext = PathUtils.appContext
    if (!nowPlaying || !appContext) {
      return
    }

    const subtitleMode = SubtitleUtil.normalizeSubtitleMode(subtitleSelected)
    const subtitleVisible = subtitleVisibility === Visibility.Visible
    const subtitleAIAsrShown = isAIAsrShown
    const subtitle3DModeValue = SubtitleUtil.normalizeSubtitle3DMode(subtitle3DMode)
    const subtitleOffsetMillis = Math.max(-50000, Math.min(50000, Math.round(SubtitleUtil.offsetMillis)))
    const subtitleTrackId = subtitleTrackSelected
    const hasPreferenceChanged =
      nowPlaying.subtitle_mode !== subtitleMode ||
        nowPlaying.subtitle_visible !== subtitleVisible ||
        nowPlaying.subtitle_ai_asr_shown !== subtitleAIAsrShown ||
        nowPlaying.subtitle_3d_mode !== subtitle3DModeValue ||
        nowPlaying.subtitle_offset_millis !== subtitleOffsetMillis ||
        nowPlaying.subtitle_track_id !== subtitleTrackId

    if (!hasPreferenceChanged) {
      return
    }

    nowPlaying.subtitle_mode = subtitleMode
    nowPlaying.subtitle_visible = subtitleVisible
    nowPlaying.subtitle_ai_asr_shown = subtitleAIAsrShown
    nowPlaying.subtitle_3d_mode = subtitle3DModeValue
    nowPlaying.subtitle_offset_millis = subtitleOffsetMillis
    nowPlaying.subtitle_track_id = subtitleTrackId

    SelectFileUtil.saveData(appContext, nowPlaying, {
      subtitleMode,
      subtitleVisible,
      subtitleAIAsrShown,
      subtitle3DMode: subtitle3DModeValue,
      subtitleOffsetMillis,
      subtitleTrackId
    })
  }

  static saveAudioTrackPreference(
    nowPlaying: VideoMetadata | undefined,
    audioTrackSelected: number,
    audioTrackCount: number
  ): void {
    const appContext = PathUtils.appContext
    if (!nowPlaying || !appContext) {
      return
    }
    if (audioTrackCount <= 1) {
      return
    }
    if (audioTrackSelected === 0) {
      if (nowPlaying.audio_track_id !== undefined) {
        nowPlaying.audio_track_id = undefined
        SelectFileUtil.saveData(appContext, nowPlaying, { audioTrackId: null })
      }
      return
    }
    const audioTrackId = audioTrackSelected
    if (nowPlaying.audio_track_id === audioTrackId) {
      return
    }
    nowPlaying.audio_track_id = audioTrackId
    SelectFileUtil.saveData(appContext, nowPlaying, { audioTrackId })
  }

  static getAdjacentSubtitleOffset(playTime: number, currentOffset: number,
    direction: 'prev' | 'next'): number | undefined {
    const targetOffset = SubtitleUtil.getAdjacentSubtitleOffset(playTime, currentOffset, direction)
    if (targetOffset == undefined) {
      ToolsUtil.showToast(direction === 'prev' ? '没有上一条字幕' : '没有下一条字幕')
      return undefined
    }
    if (Math.abs(targetOffset) > 50000) {
      ToolsUtil.showToast('目标字幕超出偏移范围：-50000 到 50000')
      return undefined
    }
    return Math.round(targetOffset)
  }

  static async deleteVideoFiles(items: VideoMetadata[], deleteType: DeleteType): Promise<void> {
    for (const item of items) {
      if (!item.date) {
        continue
      }
      RecentPlayUtil.delData(PathUtils.appContext!, item.uri)
      await SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, item.date)
      await SelectFileUtil.deleteCover(item.date)
      if (deleteType === DeleteType.HARD) {
        try {
          await fileIo.unlink(item.uri)
          salmonLogger.addLog('BatchDelete', 'remove file succeed: ' + item.uri)
        } catch (err) {
          salmonLogger.addLog('BatchDelete', 'remove file failed: ' + (err as Error).message, true)
        }
      } else if (deleteType === DeleteType.RECENT) {
        try {
          if (canIUse('SystemCapability.FileManagement.FileManagerService.Core')) {
            await fileManagerService.deleteToTrash(PathUtils.pathToUri(item.uri))
          }
        } catch (error) {
          salmonLogger.addLog('BatchDelete', 'move to trash failed: ' + (error as Error).message, true)
        }
      }
    }
  }

  private static async releaseAVImageGeneratorNow(): Promise<void> {
    const generator = VideoOperateUtil.avImageGenerator
    const file = VideoOperateUtil.nowPlayingFile
    VideoOperateUtil.avImageGenerator = undefined
    VideoOperateUtil.nowPlayingFile = undefined
    VideoOperateUtil.updatePix = false
    if (generator) {
      try {
        await generator.release()
      } catch (error) {
        salmonLogger.addLog(TAG, `releaseAVImageGenerator error: ${error}`, true)
      }
    }
    if (file) {
      try {
        fileIo.closeSync(file)
      } catch (_error) {
      }
    }
  }

  private static async getTracksByType<T>(avPlayer: media.AVPlayer, trackType: media.MediaType,
    mapper: (desc: media.MediaDescription) => T, errorLabel: string): Promise<T[]> {
    return new Promise((resolve, reject) => {
      avPlayer.getTrackDescription((error: BusinessError, arrList: Array<media.MediaDescription>) => {
        if (error || !arrList || arrList.length === 0) {
          salmonLogger.addLog(TAG, `Failed to get TrackDescription, error: ${error}`, true)
          return reject(error || new Error(`No ${errorLabel} available`))
        }
        const tracks: T[] = arrList
          .filter(desc => desc[media.MediaDescriptionKey.MD_KEY_TRACK_TYPE] === trackType)
          .map(mapper)
        resolve(tracks)
      })
    })
  }

  private static calculateFrameSize(videoWidth: number, videoHeight: number): FrameSize {
    const size = VideoInfoUtil.calculateAspectRatioSize(videoWidth, videoHeight, 200)
    const result: FrameSize = { width: size.width, height: size.height }
    return result
  }
}
