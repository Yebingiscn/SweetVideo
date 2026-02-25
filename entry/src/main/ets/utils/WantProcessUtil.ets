import { hilog } from '@kit.PerformanceAnalysisKit'
import { media } from '@kit.MediaKit'
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import VideoUtil from './VideoInfoUtil'
import VideoInfoUtil from './VideoInfoUtil'
import { common, Context, OpenLinkOptions, Want } from '@kit.AbilityKit'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import Preferences from '../database/Preferences'
import { systemShare } from '@kit.ShareKit'
import NavigationAddress, { PlayerParams } from '../common/NavigationCommon'
import ToolsUtil from './ToolsUtil'

// 处理拉起应用传来的视频链接
export default class WantProcess {
  public static hasNewWant = false
  private static isSystemShare: boolean = false
  private static receiveWant: Want | undefined = undefined
  private static receiveWantUri: string = ''

  public static set wantUri(value: string) {
    WantProcess.receiveWantUri = value
  }

  public static set want(value: Want | undefined) {
    WantProcess.receiveWant = value
  }

  static async getSystemShareWant(want: Want) {
    try {
      if (canIUse("SystemCapability.Collaboration.SystemShare")) {
        const data = await systemShare.getSharedData(want)
        const records = data.getRecords()
        for (const record of records) {
          if (record.uri) {
            WantProcess.receiveWantUri = record.uri
            WantProcess.isSystemShare = true
            WantProcess.hasNewWant = true
            break
          }
        }
      } else {
        ToolsUtil.showToast('系统不支持该功能')
      }
    } catch (error) {
      const businessError = error as BusinessError
      console.error(`Failed: Code ${businessError.code}, ${businessError.message}`)
    }
  }

  static async checkWant(context: Context, pathStack: NavPathStack) {
    if (!WantProcess.receiveWant) {
      return
    }
    if (WantProcess.receiveWant.uri) {
      WantProcess.receiveWantUri = WantProcess.receiveWant.uri
      WantProcess.hasNewWant = true
    } else {
      await WantProcess.getSystemShareWant(WantProcess.receiveWant)
      if (!WantProcess.receiveWantUri) {
        return
      }
    }
    if (WantProcess.receiveWantUri != '') {
      WantProcess.clearWantState()
      WantProcess.hasWant(context, pathStack)
    }
  }

  // 处理拉起链接
  static async hasWant(context: Context, pathStack: NavPathStack) {
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      try {
        let avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor()
        let file = fs.openSync(WantProcess.receiveWantUri)
        avMetadataExtractor.fdSrc = file
        avMetadataExtractor.fetchMetadata(async (_error: BusinessError, metadata: media.AVMetadata) => {
          let targetVideo: VideoMetadata = {
            uri: WantProcess.receiveWantUri,
            title: decodeURI(WantProcess.receiveWantUri.split('/')[WantProcess.receiveWantUri.split('/').length-1]),
            date: systemDateTime.getTime(false).toString(),
            size: VideoUtil.getVideoWidthAndHeight(metadata),
            time: parseInt(metadata.duration || '0'),
            last_play: 0,
            format: VideoInfoUtil.getVideoFormat(WantProcess.receiveWantUri),
            video_size: await VideoUtil.getVideoSize(WantProcess.receiveWantUri, true) as string,
            hdr_type: metadata.hdrType ? media.HdrType.AV_HDR_TYPE_VIVID : media.HdrType.AV_HDR_TYPE_NONE,
            start_time: 0,
            end_time: 0,
            external_subtitle_format: '',
            pointA: 0,
            pointB: 0
          }
          // 获取默认播放器
          let url = WantProcess.getPlayer(context, targetVideo)
          const playerParams = new PlayerParams(targetVideo, [targetVideo], undefined)
          WantProcess.receiveWantUri = ''
          pathStack.pushPathByName(url, playerParams, true)
        })
      } catch (error) {
        console.error('want process error:' + error)
      }
    }
  }

  static getPlayer(context: Context, metadata: VideoMetadata) {
    const defaultPlayer = Preferences.getDefaultPlayerEngine(context)
    // 系统分享（有长宽情况下）和 HDR VIVID 视频强制使用系统播放器
    if ((defaultPlayer === VideoInfoUtil.playerEngineList[0] || WantProcess.isSystemShare ||
      metadata.hdr_type === media.HdrType.AV_HDR_TYPE_VIVID || metadata.format.toLowerCase() === 'mov') &&
      metadata.size[0] !== 0) {
      return NavigationAddress.AV_PLAYER
    } else if (defaultPlayer === VideoInfoUtil.playerEngineList[1]) {
      return NavigationAddress.MPV_PLAYER
    }
    // 兜底播放器
    return NavigationAddress.AV_PLAYER
  }

  // 跳转外部网页
  static linkToWeb(context: common.UIAbilityContext, link: string) {
    let openLinkOptions: OpenLinkOptions = {
      appLinkingOnly: false,
    }
    try {
      context.openLink(link, openLinkOptions)
    } catch (paramError) {
      hilog.error(777, 'testFlag', 'paramError' + paramError)
    }
  }

  private static clearWantState() {
    WantProcess.hasNewWant = false
    WantProcess.receiveWant = undefined
  }
}
