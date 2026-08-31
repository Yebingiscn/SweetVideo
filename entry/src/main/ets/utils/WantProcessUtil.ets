import VideoInfoUtil from './VideoInfoUtil'
import FFmpegThumbnailUtil from './FFmpegThumbnailUtil'
import { bundleManager, common, OpenLinkOptions, Want } from '@kit.AbilityKit'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { salmonLogger } from 'salmonlogger'
import { VideoSource } from '../common/enum/VideoSource'
import { PathUtils } from './PathUtils'
import SelectFileUtil from './SelectFileUtil'
import ToolsUtil from './ToolsUtil'
import { WindowUtil } from './WindowUtil'
import { systemDateTime } from '@kit.BasicServicesKit'
import { fileUri } from '@kit.CoreFileKit'
import { systemShare } from '@kit.ShareKit'

const TAG = 'WantProcessUtil'

export default class WantProcess {
  public static hasNewWant = false
  private static receiveWant: Want | undefined = undefined
  private static receiveWantUri: string = ''
  private static isContinue: boolean = false
  private static continueData: VideoMetadata | undefined = undefined
  private static continueTime: number = 0
  private static continueSkipHistory: boolean = false

  public static set wantUri(value: string) {
    WantProcess.receiveWantUri = value
  }

  public static set want(value: Want | undefined) {
    WantProcess.receiveWant = value
  }

  static async getSystemShareWant(want: Want): Promise<void> {
    if (canIUse("SystemCapability.Collaboration.SystemShare")) {
      try {
        const data = await systemShare.getSharedData(want)
        const records = data.getRecords()
        for (const record of records) {
          if (record.uri) {
            WantProcess.receiveWantUri = record.uri
            WantProcess.hasNewWant = true
            break
          }
        }
      } catch (error) {
        const businessError = error as BusinessError
        salmonLogger.addLog(TAG, `Failed: Code ${businessError.code}, ${businessError.message}`, true)
      }
    } else {
      ToolsUtil.showToast('系统不支持该功能')
      salmonLogger.addLog(TAG, '系统不支持处理 system share', true)
    }
  }

  static async checkWant(pathStack: NavPathStack): Promise<void> {
    if (WantProcess.isContinue) {
      await WantProcess.checkContinue(pathStack)
      return
    }
    // 检查快捷方式参数（如 testKey: "RecentPlay"）
    if (WantProcess.receiveWant?.parameters?.testKey) {
      const shortCutKey = WantProcess.receiveWant.parameters.testKey as string
      if (shortCutKey === 'RecentPlay') {
        pathStack.pushPathByName('RecentPlay', null)
        WantProcess.clearWantState()
        return
      }
    }
    if (!WantProcess.receiveWant) {
      return
    }
    if (WantProcess.receiveWant.uri) {
      WantProcess.receiveWantUri = WantProcess.receiveWant.uri
      WantProcess.hasNewWant = true
    } else if (WantProcess.receiveWant.action === 'ohos.want.action.sendData') {
      await WantProcess.getSystemShareWant(WantProcess.receiveWant)
    }
    if (WantProcess.receiveWantUri != '') {
      await WantProcess.hasWant(pathStack)
    }
  }

  static restoreContinueData(want: Want) {
    if (!want.parameters) {
      salmonLogger.addLog(TAG, 'missing parameters in restoreContinueData', true)
      return
    }
    WantProcess.continueTime = want.parameters.continueTime as number
    WantProcess.continueData = want.parameters.data as VideoMetadata
    WantProcess.continueSkipHistory = want.parameters.skipHistory as boolean ?? false
    WantProcess.isContinue = true
  }

  static async checkContinue(pathStack: NavPathStack): Promise<void> {
    if (!WantProcess.isContinue) {
      return
    }
    WantProcess.isContinue = false
    const data = WantProcess.continueData
    if (data) {
      if (WantProcess.continueTime !== undefined && WantProcess.continueTime > 0) {
        data.last_play = WantProcess.continueTime
      }
      await ToolsUtil.routerWhere(pathStack, data, [data], WantProcess.continueSkipHistory)
    }
    WantProcess.continueData = undefined
    WantProcess.continueTime = 0
    WantProcess.continueSkipHistory = false
  }

  // 处理拉起链接
  static async hasWant(pathStack: NavPathStack): Promise<void> {
    try {
      const uri = WantProcess.receiveWantUri
      const probeResult = await FFmpegThumbnailUtil.probeUri(uri)
      if (!probeResult.success || !probeResult.probe) {
        throw new Error(probeResult.error || 'FFmpeg media probing failed')
      }
      const probe = probeResult.probe
      const fileName = ToolsUtil.safeDecodeURI(uri.split('/')[uri.split('/').length - 1])
      const targetVideo: VideoMetadata = {
        uri: uri,
        title: VideoInfoUtil.resolveImportedTitle(fileName, probe),
        date: systemDateTime.getTime(false).toString(),
        size: VideoInfoUtil.getPlayableResolution(probe),
        cover_size: [probe.coverWidth, probe.coverHeight],
        has_video_track: VideoInfoUtil.probeHasVideoTrack(probe),
        time: Math.round(probe.durationMs),
        last_play: 0,
        format: VideoInfoUtil.getVideoFormat(uri),
        video_size: await VideoInfoUtil.getVideoSize(uri, true) as string,
        frame_rate: Math.round(probe.frameRate),
        hdr_type: probe.hdrType,
        audio_type: probe.audioType,
        start_time: 0,
        end_time: 0,
        external_subtitle_format: '',
        pointA: 0,
        pointB: 0,
      }
      WantProcess.clearWantState()
      WantProcess.receiveWantUri = ''
      await ToolsUtil.routerWhere(pathStack, targetVideo, [targetVideo], false, true)
    } catch (error) {
      salmonLogger.addLog(TAG, 'want process error:' + error, true)
      WantProcess.clearWantState()
      WantProcess.receiveWantUri = ''
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.video_error').id))
    }
  }


  // 跳转外部网页
  static linkToWeb(context: common.UIAbilityContext, link: string) {
    let openLinkOptions: OpenLinkOptions = {
      appLinkingOnly: false,
    }
    try {
      context.openLink(link, openLinkOptions)
    } catch (paramError) {
      salmonLogger.addLog(TAG, 'linkToWeb error:' + paramError, true)
    }
  }

  static async linkToVideoSource(uri: string | undefined): Promise<void> {
    if (!uri) {
      ToolsUtil.showToast('文件地址异常')
      salmonLogger.addLog(TAG, "file address failed", false)
      return
    }
    if (SelectFileUtil.isPathFromSource(uri, VideoSource.PHOTO_SELECT_OPTION)) {
      await WantProcess.linkToGallery(uri)
      return
    }
    if (SelectFileUtil.isPathFromSource(uri, VideoSource.DOCUMENT_SELECT_OPTION) ||
      SelectFileUtil.isPathFromSource(uri, VideoSource.EXTERNAL_DEVICE)) {
      WantProcess.linkToFileManager(uri)
      return
    }
    if (SelectFileUtil.isPathFromSource(uri, VideoSource.SWEET_VIDEO_DOWNLOAD_FILE)) {
      WantProcess.linkToFileManager(uri)
      return
    }
    ToolsUtil.showToast('不支持打开文件位置')
  }

  static async linkToGallery(uri: string): Promise<void> {
    try {
      let context = WindowUtil.windowClass?.getUIContext().getHostContext() as common.UIAbilityContext;
      let bundleInfo: bundleManager.BundleInfo =
        await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      let wantInfo: Want = {
        bundleName: 'com.huawei.hmos.photos',
        abilityName: 'com.huawei.hmos.photos.MainAbility',
        uri: uri,
        parameters: {
          pushParams: bundleInfo.name // app的bundleName也就是包名
        }
      }
      context.startAbility(wantInfo).then(() => {
        salmonLogger.addLog(TAG, "open gallery success", false)
      }).catch(() => {
        salmonLogger.addLog(TAG, "open gallery failed", true)
      })
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      salmonLogger.addLog(TAG, "open gallery failed: " + err, true)
    }
  }

  static linkToFileManager(uri: string) {
    try {
      let context: common.UIAbilityContext =
        WindowUtil.windowClass?.getUIContext().getHostContext() as common.UIAbilityContext
      let link: string = 'filemanager://openDirectory'
      let openLinkOptions: OpenLinkOptions = {
        parameters: {
          'fileUri': new fileUri.FileUri(uri).toString()
        }
      }
      context.openLink(link, openLinkOptions)
        .then(() => {
          salmonLogger.addLog(TAG, "open file manager success", false)
        }).catch((err: BusinessError) => {
        salmonLogger.addLog(TAG, "open file manager failed: " + err, true)
      })
    } catch (error) {
      salmonLogger.addLog(TAG, "open file manager failed: " + error, true)
    }
  }

  static linkToAppGallery(appName: string) {
    const want: Want = {
      action: 'ohos.want.action.appdetail',
      // bundleName为需要拉起写评论页的应用包名，action隐式指定为write-review，表示进入详情页后，下一步将拉起写评论页。
      uri: `store://appgallery.huawei.com/app/detail?id=${appName}&action=write-review`
    }
    PathUtils.appContext!.startAbility(want)
      .then(() => {
        salmonLogger.addLog(TAG, '成功打开应用市场评论页', false)
      })
      ?.catch((error: BusinessError) => {
        ToolsUtil.showToast('打开应用市场失败，原因是：' + error)
        salmonLogger.addLog(TAG, '打开应用市场评论页失败，原因是：' + error, true)
      })
  }

  private static clearWantState() {
    WantProcess.hasNewWant = false
    WantProcess.receiveWant = undefined
  }
}
