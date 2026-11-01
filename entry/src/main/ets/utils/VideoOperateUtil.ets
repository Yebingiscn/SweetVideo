import BluRayDirectory from './BluRayDirectory'
import ImageFileUtil from './ImageFileUtil'
import ImageStorage from './ImageStorage'
import { window } from '@kit.ArkUI'
import { audio } from '@kit.AudioKit'
import { BusinessError, settings, SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import { media } from '@kit.MediaKit'
import { NativeAVPlayer } from '../controller/engine/NativeAVPlayer'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { AudioTrack, SubtitleTrack } from '../interfaces/AudioTrackInterface'
import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { PathUtils } from './PathUtils'
import ToolsUtil from './ToolsUtil'
import { PlayerEngine } from '../common/NavigationCommon'
import { Setting } from './ObservedUtil'
import { fileIo } from '@kit.CoreFileKit'
import { SweetRepeatMode, normalizeRepeatMode } from '../common/enum/SweetRepeatMode'
import { BackgroundColorMode } from '../common/enum/BackgroundColorMode'
import { CoverLayoutMode, ListDisplayMode } from '../common/enum/DisplayMode'
import { MpvDecodingMethod, MpvGpuApi } from '../controller/MpvController/MpvTypes'
import preferences from '@ohos.data.preferences'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { image } from '@kit.ImageKit'
import VideoInfoUtil from './VideoInfoUtil'
import { salmonLogger } from 'salmonlogger'
import { SCALE_FACTORS, SUPPORT_AUDIO_FORMAT } from '../common/Constants'
import { VideoStartTimeMode } from '../common/enum/VideoStartTimeMode'
import { LanguageConfig } from '../common/LanguageConfig'
import Preferences from '../database/Preferences'
import PreferencesUtil from '../database/PreferencesUtil'
import { XAnimation } from './AnimationUtil'
import PermissionUtil from './PermissionUtil'
import lazy SubtitleUtil from './SubtitleUtil'
import { WindowUtil } from './WindowUtil'
import { SubtitlePreferredLanguage } from '../common/enum/SubtitleLanguage'
import SubtitleLanguageUtil from './SubtitleLanguageUtil'
import { VIDEO_HDR_TYPE } from '../common/enum/HDR_TYPE'
import MediaLibraryService from './MediaLibraryService'
import lazy FFmpegThumbnailUtil from './FFmpegThumbnailUtil'
import { SurfaceScreenshotCandidate, SurfaceScreenshotCapture, SurfaceScreenshotRequest } from './SurfaceScreenshotCapture'

const TAG = 'VideoOperateUtil'

// 视频操作类
export default class VideoOperateUtil {
  public static maxVolume: number = 0
  public static minVolume: number = 0
  public static windowStage: window.WindowStage | undefined = undefined
  public static backgroundSettingsInitialized: boolean = false
  private static mainWin: window.Window | undefined = undefined
  private static captureRequestSequence: number = 0
  private static activeCaptureRequestId: number = 0
  private static captureQueue: Promise<void> = Promise.resolve()
  private static captureQueueDepth: number = 0

  // 设置亮度
  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
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

  static async getAudioTracks(avPlayer: NativeAVPlayer): Promise<AudioTrack[]> {
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
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.get_audio_tracks_failed').id))
      return []
    }
  }

  static async getInnerSubtitles(avPlayer: NativeAVPlayer | undefined | null): Promise<SubtitleTrack[]> {
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

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
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
    VideoOperateUtil.backgroundSettingsInitialized = false
    PermissionUtil.reqPermissionsFromUser(PermissionUtil.permissions, context)
    const settingDefaults: Record<string, preferences.ValueType> = {
      'backgroundDropBlur': 0,
      'backgroundColorMode': BackgroundColorMode.AUTO,
      'allowBackgroundPlay': true,
      'autoListenVideo': true,
      'allowConcurrentPlay': false,
      'allowPlayBackExist': false,
      'fastForwardSeconds': '15',
      'smartGestureEnabled': false,
      'knockShareEnabled': false,
      'gripPostureEnabled': true,
      'recentPlay': true,
      'showToast': true,
      'defaultPlayerEngine': '系统播放器',
      'shortVideoMode': false,
      'subtitleSize': '22',
      'subtitlePosition': 90,
      'subtitlePreferredLanguage': SubtitlePreferredLanguage.SIMPLIFIED_CHINESE,
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
      'randomCover': false,
      'coverLayoutMode': CoverLayoutMode.VERTICAL_PLATE,
      'superResolutionState': false,
      'mpvShaderMode': 0,
      'autoActivePip': false,
      'autoResumeOnReturn': false,
      'mpv_decoding_method': MpvDecodingMethod.HARDWARE_SURFACE,
      'mpv_gpu_api': MpvGpuApi.OPENGL,
      'mpv_sdr_to_hdr': false,
      'mpv_auto_deinterlace': false,
      'mpv_audio_passthrough': false,
      'mpv_usb_exclusive': false,
      'mpv_usb_dop': false,
      'mpv_usb_dsd_mode': -1,
      'mpv_usb_device': '',
      'mpv_usb_volume_mode': 0,
      'enableBackgroundDarkImage': false,
      'enableAiPrivacyAntiPeep': false,
      'defaultBrightness': 0,
      'defaultDensityEnabled': true,
      'maxListLine': 5,
      'listItemBackgroundBlur': false,
      'seekSensitivity': 0
    }
    const keys = Object.keys(settingDefaults)
    const defaults = Object.values(settingDefaults)
    const values = PreferencesUtil.batchGetPreferencesValue(context, 'sweet_video', keys, defaults)
    const valueMap: Record<string, preferences.ValueType> = {}
    keys.forEach((key, i) => {
      valueMap[key] = values[i]
    })
    Setting.backgroundDropBlur = valueMap['backgroundDropBlur'] as number
    Setting.backgroundColorMode = valueMap['backgroundColorMode'] as BackgroundColorMode
    Setting.allowBackgroundPlay = valueMap['allowBackgroundPlay'] as boolean
    Setting.autoListenVideo = valueMap['autoListenVideo'] as boolean
    Setting.allowConcurrentPlay = valueMap['allowConcurrentPlay'] as boolean
    Setting.allowPlayBackExist = valueMap['allowPlayBackExist'] as boolean
    Setting.fastForwardSeconds = valueMap['fastForwardSeconds'] as string
    Setting.smartGestureEnabled = valueMap['smartGestureEnabled'] as boolean
    Setting.knockShareEnabled = valueMap['knockShareEnabled'] as boolean
    Setting.gripPostureEnabled = valueMap['gripPostureEnabled'] as boolean
    Setting.recentPlay = valueMap['recentPlay'] as boolean
    Setting.showToast = valueMap['showToast'] as boolean
    Setting.defaultPlayerEngine = valueMap['defaultPlayerEngine'] as string
    Setting.shortVideoMode = valueMap['shortVideoMode'] as boolean
    Setting.subtitleSize = valueMap['subtitleSize'] as string
    Setting.subtitlePosition = valueMap['subtitlePosition'] as number
    Setting.subtitlePreferredLanguage = SubtitleLanguageUtil.normalizeLanguage(
      valueMap['subtitlePreferredLanguage'] as number)
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
    Setting.randomCover = valueMap['randomCover'] as boolean
    Setting.coverLayout = valueMap['coverLayoutMode'] as CoverLayoutMode
    Setting.superResolutionState = valueMap['superResolutionState'] as boolean
    Setting.mpvShaderMode = valueMap['mpvShaderMode'] as number
    Setting.autoActivePip = valueMap['autoActivePip'] as boolean
    Setting.autoResumeOnReturn = valueMap['autoResumeOnReturn'] as boolean
    Setting.mpvDecodingMethod = valueMap['mpv_decoding_method'] as MpvDecodingMethod
    Setting.mpvGpuApi = valueMap['mpv_gpu_api'] as MpvGpuApi
    Setting.mpvSdrToHdr = valueMap['mpv_sdr_to_hdr'] as boolean
    Setting.mpvAutoDeinterlace = valueMap['mpv_auto_deinterlace'] as boolean
    Setting.mpvAudioPassthrough = valueMap['mpv_audio_passthrough'] as boolean
    Setting.mpvUsbExclusive = valueMap['mpv_usb_exclusive'] as boolean
    const dsdMode = valueMap['mpv_usb_dsd_mode'] as number
    Setting.mpvUsbDsdMode = dsdMode === -1 ? (valueMap['mpv_usb_dop'] === true ? 1 : 0) :
      (dsdMode === 1 || dsdMode === 2 ? dsdMode : 0)
    Setting.mpvUsbDevice = valueMap['mpv_usb_device'] as string
    const usbVolumeMode = valueMap['mpv_usb_volume_mode'] as number
    Setting.mpvUsbVolumeMode = Number.isInteger(usbVolumeMode) && usbVolumeMode >= 0 && usbVolumeMode <= 3 ? usbVolumeMode : 0
    Setting.enableBackgroundDarkImage = valueMap['enableBackgroundDarkImage'] as boolean
    Setting.enableAiPrivacyAntiPeep = valueMap['enableAiPrivacyAntiPeep'] as boolean
    Setting.defaultBrightness = valueMap['defaultBrightness'] as number
    Setting.defaultDensityEnabled = valueMap['defaultDensityEnabled'] as boolean
    Setting.maxListLine = valueMap['maxListLine'] as number
    Setting.listItemBackgroundBlur = valueMap['listItemBackgroundBlur'] as boolean
    Setting.seekSensitivity = valueMap['seekSensitivity'] as number
    VideoOperateUtil.syncBackgroundColorMode(context)
    VideoOperateUtil.backgroundSettingsInitialized = true
    void ImageFileUtil.refreshBackground().catch((error: Error) => {
      salmonLogger.addLog(TAG, `初始化壁纸失败: ${error.message}`, true)
    })
  }

  static syncBackgroundColorMode(context: Context, colorMode?: number): boolean {
    let effectiveMode = colorMode
    if (effectiveMode === undefined) {
      try {
        effectiveMode = context.resourceManager.getConfigurationSync().colorMode
      } catch (error) {
        salmonLogger.addLog(TAG, `读取应用颜色模式失败: ${error}`, true)
        return false
      }
    }
    if (effectiveMode !== ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT &&
      effectiveMode !== ConfigurationConstant.ColorMode.COLOR_MODE_DARK) return false
    if (AppStorage.get('currentColorMode') === effectiveMode) return false
    AppStorage.setOrCreate('currentColorMode', effectiveMode)
    return true
  }

  // 封装获取屏幕亮度的方法
  static async getScreenBrightness(): Promise<number> {
    if (canIUse('SystemCapability.Applications.Settings.Core')) {
      try {
        const brightnessTask: Promise<string> = settings.getValue(
          PathUtils.appContext!,
          settings.display.SCREEN_BRIGHTNESS_STATUS,
          settings.domainName.DEVICE_SHARED
        )
        const value = await brightnessTask
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
    const res = LanguageConfig.languageResources[lowerCode]
    return res !== undefined ? ToolsUtil.getStringResource(res.id) : code
  }

  static isLandscapeVideo(width: number, height: number, screenExtend?: string): boolean {
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 1 || height <= 1) {
      return false
    }
    // 固定比例按用户选择判断；拉伸、适配和等比缩放仍按视频自身方向判断。
    const ratio = screenExtend ? VideoInfoUtil.ASPECT_RATIO_MAP.get(screenExtend) : undefined
    return ratio !== undefined ? ratio > 1 : width > height
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
      const percent = Number(text.slice('自定义比例:'.length))
      if (!Number.isFinite(percent) || percent < 50 || percent > 150) return null
      scale = percent / 100
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

  static getVideoStartPlayTimeMode(nowPlaying: VideoMetadata, showToast: boolean = true): number {
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
        if (showToast) {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.skipped_intro').id))
        }
        return VideoStartTimeMode.SEEK_TO_START_TIME
      }
    }
    // 条件2：若有有效播放记录（且未接近结尾），则跳转到上次播放位置
    if (last_play !== 0 && last_play < time * 0.95 && Setting.jumpToHistoryTimeStatus) {
      if (showToast) {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.jumped_to_last_position').id))
      }
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
          if (showToast) {
            ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.skipped_unified_intro').id))
          }
          return VideoStartTimeMode.SEEK_TO_INTRO_TIME
        }
      }
    }
    return -1
  }

  static getTimePixel(screenWidth: number, videoTime: number) {
    const baseTimePerPixel = videoTime > 600000 ? 600000 / screenWidth : videoTime / screenWidth
    const sensitivityFactor = Setting.seekSensitivity === 2 ? 0.1 : Setting.seekSensitivity === 1 ? 0.5 : 1.0
    return baseTimePerPixel * sensitivityFactor
  }

  static nextCaptureRequestId(): number {
    return ++VideoOperateUtil.captureRequestSequence
  }

  static saveCaptureScreenToAlbum(uri: string, positionMs: number,
    isCurrent: () => boolean = () => true,
    requestId: number = VideoOperateUtil.nextCaptureRequestId(),
    surfaceRequest?: SurfaceScreenshotRequest): Promise<void> {
    const requestedAt = Date.now()
    // Freeze the click-time image now, not after an earlier save dialog closes.
    const surfaceCandidate = surfaceRequest ? SurfaceScreenshotCapture.prepare(surfaceRequest) : undefined
    const ahead = VideoOperateUtil.captureQueueDepth++
    salmonLogger.addLog(TAG, `[Screenshot#${requestId}] request: positionMs=${positionMs}, ` +
      `network=${ToolsUtil.isNetworkUrl(uri)}, queuedAhead=${ahead}`, false)
    if (ahead > 0) {
      salmonLogger.addLog(TAG, `[Screenshot#${requestId}] queued: activeRequest=${VideoOperateUtil.activeCaptureRequestId}`, false)
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.screenshot_queued').id))
    }
    // Keep fallback decoding and the system save dialog serial. A bounded
    // pre-captured Surface image can wait here without holding decoder buffers.
    const task = VideoOperateUtil.captureQueue.then(async (): Promise<void> => {
      try {
        if (!isCurrent()) {
          salmonLogger.addLog(TAG, `[Screenshot#${requestId}] ignored: reason=stale_before_start`, false)
          return
        }
        VideoOperateUtil.activeCaptureRequestId = requestId
        salmonLogger.addLog(TAG, `[Screenshot#${requestId}] dequeued: waitMs=${Date.now() - requestedAt}, ` +
          `positionMs=${positionMs}`, false)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.screenshot_processing').id))
        await VideoOperateUtil.performCaptureScreenToAlbum(uri, positionMs, isCurrent, requestId,
          surfaceCandidate, surfaceRequest?.hdrType ?? 0)
      } catch (error) {
        const err = error as BusinessError
        salmonLogger.addLog(TAG, `[Screenshot#${requestId}] queue task failed: ` +
          `code=${Number.isFinite(err?.code) ? err.code : 0}`, true)
        if (isCurrent()) ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.screenshot_failed').id))
      } finally {
        await surfaceCandidate?.dispose()
        VideoOperateUtil.captureQueueDepth--
        try {
          if (VideoOperateUtil.captureQueueDepth === 0) {
            await FFmpegThumbnailUtil.releaseScreenshotSession()
          }
        } finally {
          VideoOperateUtil.activeCaptureRequestId = 0
        }
      }
    })
    // A failed/cancelled job cannot poison subsequent queued requests.
    VideoOperateUtil.captureQueue = task.catch((): void => {})
    return VideoOperateUtil.captureQueue
  }

  private static async performCaptureScreenToAlbum(uri: string, positionMs: number,
    isCurrent: () => boolean, requestId: number,
    surfaceCandidate?: SurfaceScreenshotCandidate, surfaceHdrType: number = 0): Promise<void> {
    const startedAt = Date.now()
    let stage = 'extract'
    let stageStartedAt = startedAt
    let outcome = 'failed'
    const beginStage = (nextStage: string): void => {
      stage = nextStage
      stageStartedAt = Date.now()
      salmonLogger.addLog(TAG, `[Screenshot#${requestId}] stage=${stage} event=begin`, false)
    }
    const endStage = (): void => {
      salmonLogger.addLog(TAG, `[Screenshot#${requestId}] stage=${stage} event=end ` +
        `elapsedMs=${Date.now() - stageStartedAt}`, false)
    }
    let pixelMap: image.PixelMap | undefined = undefined
    let packer: image.ImagePacker | undefined = undefined
    let encodedSource: image.ImageSource | undefined = undefined
    let tempFile: fileIo.File | undefined = undefined
    let sourceFile: fileIo.File | undefined = undefined
    let targetFile: fileIo.File | undefined = undefined
    let tempPath: string = ''
    let extension: string = ''
    try {
      // A Surface image can be valid yet unsupported by the encoder. Retry the
      // complete preparation once with FFmpeg before opening any save dialog.
      for (let attempt = 0; attempt < 2; attempt++) {
        let usingSurface = false
        try {
          beginStage('extract')
          if (attempt === 0) pixelMap = await surfaceCandidate?.take()
          usingSurface = pixelMap !== undefined
          let frameMs: number | undefined = undefined
          let sourceHdrType = surfaceHdrType
          if (!pixelMap) {
            const frame = await FFmpegThumbnailUtil.extractScreenshot(uri, positionMs, requestId)
            pixelMap = frame.pixelMap
            frameMs = Math.round(frame.frameTimeUs / 1000)
            sourceHdrType = frame.hdrType
            if (!frame.success || !pixelMap) {
              salmonLogger.addLog(TAG, `[Screenshot#${requestId}] extraction failed: ` +
                `success=${frame.success}, hasPixelMap=${pixelMap !== undefined}`, true)
              throw new Error('FFmpeg screenshot extraction failed')
            }
          }
          endStage()
          if (!isCurrent()) {
            outcome = 'stale_after_extract'
            salmonLogger.addLog(TAG, `[Screenshot#${requestId}] ignored: reason=${outcome}`, false)
            return
          }
          beginStage('inspect_frame')
          const captureInfo = pixelMap.getImageInfoSync()
          const isHdr = captureInfo.isHdr
          salmonLogger.addLog(TAG, `[Screenshot#${requestId}] capture: source=${usingSurface ? 'surface' : 'ffmpeg'}, ` +
            `requestedMs=${positionMs}, frameMs=${frameMs ?? 'unknown'}, sourceHdrType=${sourceHdrType}, ` +
            `isHdr=${isHdr}, pixelFormat=${captureInfo.pixelFormat}, ` +
            `size=${captureInfo.size.width}x${captureInfo.size.height}`, false)
          endStage()
          extension = isHdr ? 'jpg' : 'png'
          const packOpts: image.PackingOption = {
            format: isHdr ? 'image/jpeg' : 'image/png',
            quality: 100,
            desiredDynamicRange: isHdr ? image.PackingDynamicRange.AUTO : image.PackingDynamicRange.SDR
          }
          beginStage('encode')
          packer = image.createImagePacker()
          tempPath = PathUtils.tempPath + `/screenshot_${requestId}_${Date.now()}.${extension}`
          tempFile = fileIo.openSync(tempPath,
            fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC)
          await packer.packToFile(pixelMap, tempFile.fd, packOpts)
          endStage()
          beginStage('release_encoded_resources')
          ImageStorage.closeFileSafely(tempFile, '截图临时文件')
          tempFile = undefined
          await ImageStorage.releaseImageSafely(packer, '截图编码器')
          packer = undefined
          await ImageStorage.releaseImageSafely(pixelMap, '截图像素图')
          pixelMap = undefined
          await surfaceCandidate?.dispose()
          endStage()

          // 回读文件头确认编码结果，不能把请求 AUTO 当成 HDR 已保留。
          beginStage('verify_encoded')
          let encodedHdrVerified = false
          try {
            encodedSource = image.createImageSource(tempPath)
            const encodedInfo = encodedSource.getImageInfoSync()
            encodedHdrVerified = encodedInfo.isHdr
            salmonLogger.addLog(TAG, `[Screenshot#${requestId}] encoded: sourceHdr=${isHdr}, isHdr=${encodedInfo.isHdr}, ` +
              `format=${encodedInfo.mimeType}`, isHdr && !encodedInfo.isHdr)
          } catch (error) {
            const err = error as BusinessError
            salmonLogger.addLog(TAG, `[Screenshot#${requestId}] encoded info failed: ` +
              `code=${Number.isFinite(err?.code) ? err.code : 0}`, true)
          } finally {
            await ImageStorage.releaseImageSafely(encodedSource, '截图编码结果')
            encodedSource = undefined
          }
          endStage()
          if (usingSurface && isHdr && !encodedHdrVerified) {
            throw new Error('Surface HDR encoding verification failed')
          }
          break
        } catch (error) {
          const err = error as BusinessError
          salmonLogger.addLog(TAG, `[Screenshot#${requestId}] preparation failed: source=${usingSurface ? 'surface' : 'ffmpeg'}, ` +
            `stage=${stage}, code=${Number.isFinite(err?.code) ? err.code : 0}`, true)
          if (!usingSurface || !isCurrent() || attempt !== 0) throw new Error('Screenshot preparation failed')
          salmonLogger.addLog(TAG, `[Screenshot#${requestId}] surface fallback: reason=prepare_failed, stage=${stage}`, false)
          ImageStorage.closeFileSafely(tempFile, '截图临时文件')
          tempFile = undefined
          await ImageStorage.releaseImageSafely(packer, '截图编码器')
          packer = undefined
          await ImageStorage.releaseImageSafely(pixelMap, '截图像素图')
          pixelMap = undefined
          await ImageStorage.releaseImageSafely(encodedSource, '截图编码结果')
          encodedSource = undefined
          await surfaceCandidate?.dispose()
          VideoOperateUtil.removeScreenshotTempFile(tempPath, requestId)
          tempPath = ''
        }
      }

      if (!isCurrent()) {
        outcome = 'stale_before_dialog'
        salmonLogger.addLog(TAG, `[Screenshot#${requestId}] ignored: reason=${outcome}`, false)
        return
      }
      beginStage('save_dialog')
      const srcUri = PathUtils.pathToUri(tempPath)
      const helper = photoAccessHelper.getPhotoAccessHelper(PathUtils.appContext)
      const dstUris = await helper.showAssetsCreationDialog(
        [srcUri],
        [{ photoType: photoAccessHelper.PhotoType.IMAGE, fileNameExtension: extension }]
      )
      endStage()
      if (!dstUris.length) {
        outcome = 'dialog_cancelled'
        salmonLogger.addLog(TAG, `[Screenshot#${requestId}] cancelled: reason=save_dialog`, false)
        return
      }
      // 原样复制编码文件，保留 JPEG 中的 HDR 信息。
      beginStage('copy_to_album')
      sourceFile = fileIo.openSync(srcUri, fileIo.OpenMode.READ_ONLY)
      targetFile = fileIo.openSync(dstUris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
      fileIo.copyFileSync(sourceFile.fd, targetFile.fd)
      ImageStorage.closeFileSafely(targetFile, '截图相册文件')
      targetFile = undefined
      ImageStorage.closeFileSafely(sourceFile, '截图源文件')
      sourceFile = undefined
      endStage()
      outcome = 'saved'
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.save_success').id))
    } catch (error) {
      const err = error as BusinessError
      salmonLogger.addLog(TAG, `[Screenshot#${requestId}] failed: stage=${stage}, ` +
        `stageElapsedMs=${Date.now() - stageStartedAt}, totalElapsedMs=${Date.now() - startedAt}, ` +
        `code=${Number.isFinite(err?.code) ? err.code : 0}`, true)
      if (isCurrent()) ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.screenshot_failed').id))
    } finally {
      beginStage('cleanup')
      ImageStorage.closeFileSafely(targetFile, '截图相册文件')
      ImageStorage.closeFileSafely(sourceFile, '截图源文件')
      ImageStorage.closeFileSafely(tempFile, '截图临时文件')
      await ImageStorage.releaseImageSafely(packer, '截图编码器')
      await ImageStorage.releaseImageSafely(pixelMap, '截图像素图')
      await ImageStorage.releaseImageSafely(encodedSource, '截图编码结果')
      VideoOperateUtil.removeScreenshotTempFile(tempPath, requestId)
      endStage()
      salmonLogger.addLog(TAG, `[Screenshot#${requestId}] finished: outcome=${outcome}, ` +
        `totalElapsedMs=${Date.now() - startedAt}`, false)
    }
  }

  private static removeScreenshotTempFile(tempPath: string, requestId: number): void {
    if (tempPath) {
      try {
        if (fileIo.accessSync(tempPath)) {
          fileIo.unlinkSync(tempPath)
        }
      } catch (error) {
        const err = error as BusinessError
        salmonLogger.addLog(TAG, `[Screenshot#${requestId}] temp cleanup failed: ` +
          `code=${Number.isFinite(err?.code) ? err.code : 0}`, true)
      }
    }
  }

  static getRepeatMode(repeatMode: SweetRepeatMode): SweetRepeatMode {
    switch (normalizeRepeatMode(repeatMode)) {
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
    if (BluRayDirectory.isEntry(metadata.uri) || VideoInfoUtil.isMxf(metadata)) {
      return PlayerEngine.MPV_PLAYER
    }
    const defaultPlayer = Preferences.getDefaultPlayerEngine(PathUtils.appContext!)
    const titleLower = metadata.title?.toLowerCase() ?? ''
    const formatLower = metadata.format?.toLowerCase() ?? ''
    const isDolbyAudio = VideoOperateUtil.containsDolbyAudioCodec(titleLower) ||
      VideoOperateUtil.containsDolbyAudioCodec(formatLower) || titleLower.includes('atmos')
    const hasVideoTrack = VideoInfoUtil.hasVideoTrack(metadata)
    if (hasVideoTrack && isDolbyAudio) {
      return PlayerEngine.MPV_PLAYER
    }
    if (hasVideoTrack && metadata.hdr_type === VIDEO_HDR_TYPE.DOLBY_VISION) {
      salmonLogger.addLog(TAG, '检测到杜比视界，强制使用MPV播放器', false)
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

  static getManualNavigationRepeatMode(repeatMode: SweetRepeatMode): SweetRepeatMode {
    // 单曲循环只影响自动播完；手动切集也不能被旧 ONCE 状态拦住。
    const effectiveMode = normalizeRepeatMode(repeatMode)
    return effectiveMode === SweetRepeatMode.SINGLE ? SweetRepeatMode.LIST : effectiveMode
  }

  static computeAdjacentVideo(
    videoMetaDataList: VideoMetadata[],
    nowPlaying: VideoMetadata | undefined,
    repeatMode: SweetRepeatMode,
    direction: 'previous' | 'next'
  ): VideoMetadata | undefined {
    const effectiveMode = normalizeRepeatMode(repeatMode)
    const total = videoMetaDataList.length
    const currentId = nowPlaying?.date || ''
    const currentIndex = currentId ? videoMetaDataList.findIndex(v => v.date === currentId) : -1
    const modeName = effectiveMode === SweetRepeatMode.SEQUENCE ? 'sequence' :
      effectiveMode === SweetRepeatMode.SINGLE ? 'single' :
        effectiveMode === SweetRepeatMode.RANDOM ? 'random' : 'list'
    let nextItem: VideoMetadata | undefined = undefined
    let wrapped = false
    let reason = total === 0 ? 'empty-list' : 'unsupported-mode'
    if (total > 0) {
      // Keep the existing first-item anchor when the current item is absent,
      // but make that recovery visible instead of silently looking like EOF wrap.
      const anchorIndex = currentIndex >= 0 ? currentIndex : 0
      const item = videoMetaDataList[anchorIndex]
      switch (effectiveMode) {
        case SweetRepeatMode.RANDOM:
          const availableVideos = videoMetaDataList.filter(v => v.date !== item.date)
          nextItem = availableVideos.length > 0
            ? availableVideos[Math.floor(Math.random() * availableVideos.length)]
            : item
          reason = 'random'
          break
        case SweetRepeatMode.SEQUENCE:
          nextItem = MediaLibraryService.getAdjacentItem(videoMetaDataList, item.date, direction, false)
          reason = nextItem ? 'adjacent' : 'list-boundary'
          break
        case SweetRepeatMode.SINGLE:
          nextItem = currentIndex >= 0 ? videoMetaDataList[currentIndex] : undefined
          reason = 'repeat-current'
          break
        case SweetRepeatMode.LIST:
          nextItem = MediaLibraryService.getAdjacentItem(videoMetaDataList, item.date, direction, true)
          wrapped = direction === 'next' ? anchorIndex === total - 1 : anchorIndex === 0
          reason = wrapped ? (direction === 'next' ? 'wrap-to-start' : 'wrap-to-end') : 'adjacent'
          break
      }
      if (currentIndex < 0) {
        reason = 'current-not-found'
      }
    }
    const nextIndex = nextItem ? videoMetaDataList.indexOf(nextItem) : -1
    // One record per selection, shared by automatic EOF, buttons and both
    // player engines. Indexes are zero-based; no URL or per-frame logging.
    salmonLogger.addLog('PlaybackQueue',
      `select direction=${direction} mode=${modeName} currentIndex=${currentIndex} nextIndex=${nextIndex} ` +
        `total=${total} currentId=${currentId || 'none'} nextId=${nextItem?.date || 'none'} ` +
        `wrapped=${wrapped} reason=${reason}`, total > 0 && currentIndex < 0)
    return nextItem
  }

  static getAdjacentSubtitleOffset(playTime: number, currentOffset: number,
    direction: 'prev' | 'next'): number | undefined {
    const targetOffset = SubtitleUtil.getAdjacentSubtitleOffset(playTime, currentOffset, direction)
    if (targetOffset == undefined) {
      ToolsUtil.showToast(direction === 'prev' ? ToolsUtil.getStringResource($r('app.string.no_prev_subtitle').id) : ToolsUtil.getStringResource($r('app.string.no_next_subtitle').id))
      return undefined
    }
    if (Math.abs(targetOffset) > 50000) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.subtitle_offset_out_of_range').id))
      return undefined
    }
    return Math.round(targetOffset)
  }

  private static containsDolbyAudioCodec(value: string): boolean {
    return value.includes('truehd') || value.includes('mlp') ||
      value.includes('eac3') || value.includes('e-ac-3') || value.includes('ec-3') ||
      value.includes('ddp') || value.includes('dolby') ||
      value.includes('ac3') || value.includes('ac-3')
  }

  private static async getTracksByType<T>(avPlayer: NativeAVPlayer, trackType: media.MediaType,
    mapper: (desc: media.MediaDescription) => T, errorLabel: string): Promise<T[]> {
    return new Promise((resolve, reject) => {
      avPlayer.getTrackDescription((error: BusinessError | undefined, arrList: Array<media.MediaDescription>) => {
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
}
