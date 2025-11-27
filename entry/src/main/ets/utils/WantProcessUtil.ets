import { hilog } from '@kit.PerformanceAnalysisKit';
import { media } from '@kit.MediaKit';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import VideoUtil from './VideoInfoUtil';
import VideoInfoUtil from './VideoInfoUtil';
import { common, Context, OpenLinkOptions, Want } from '@kit.AbilityKit';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import Preferences from '../database/Preferences';
import { systemShare } from '@kit.ShareKit';
import NavigationAddress, { PlayerParams } from '../common/NavigationCommon';
import ToolsUtil from './ToolsUtil';

// 处理拉起应用传来的视频链接
export default class WantProcess {
  public static hasNewWant = false
  //是否接收到拉起
  // 隐私协议链接
  public static PRIVACY_LINK: string =
    "https://github.com/Yebingiscn/SweetVideo/wiki/%E6%B5%81%E5%BF%83%E6%92%AD%E6%94%BE%E5%99%A8%E7%9A%84%E4%BD%BF%E7%94%A8%E6%9D%A1%E6%AC%BE%E4%B8%8E%E9%9A%90%E7%A7%81%E5%A3%B0%E6%98%8E"
  private static isSystemShare: boolean = false
  // 是否系统分享
  private static _wantUri: string = '';

  //接收到的uri

  public static set wantUri(value: string) {
    WantProcess._wantUri = value;
  }

  private static _want: Want | undefined = undefined;

  public static set want(value: Want | undefined) {
    WantProcess._want = value;
  }

  static async getSystemShareWant(want: Want) {
    try {
      if (canIUse("SystemCapability.Collaboration.SystemShare")) {
        const data = await systemShare.getSharedData(want);
        const records = data.getRecords();
        for (const record of records) {
          if (record.uri) {
            WantProcess._wantUri = record.uri;
            WantProcess.isSystemShare = true;
            WantProcess.hasNewWant = true;
            break;
          }
        }
      } else {
        ToolsUtil.showToast('系统不支持该功能')
      }
    } catch (error) {
      const businessError = error as BusinessError;
      console.error(`Failed: Code ${businessError.code}, ${businessError.message}`);
    }
  }

  static async checkWant(context: Context, pathStack: NavPathStack) {
    if (!WantProcess._want) {
      return
    }
    if (WantProcess._want.uri) {
      WantProcess._wantUri = WantProcess._want.uri
      WantProcess.hasNewWant = true
    } else {
      await WantProcess.getSystemShareWant(WantProcess._want)
      if (!WantProcess._wantUri) {
        return
      }
    }
    if (WantProcess._wantUri != '') {
      WantProcess.clearWantState()
      WantProcess.hasWant(context, pathStack)
    }
  }

  // 处理拉起链接
  static async hasWant(context: Context, pathStack: NavPathStack) {
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      try {
        let avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor()
        let file = fs.openSync(WantProcess._wantUri);
        avMetadataExtractor.fdSrc = file
        avMetadataExtractor.fetchMetadata(async (_error: BusinessError, metadata: media.AVMetadata) => {
          let targetVideo: VideoMetadata = {
            uri: WantProcess._wantUri,
            title: decodeURI(WantProcess._wantUri.split('/')[WantProcess._wantUri.split('/').length-1]),
            date: systemDateTime.getTime(false).toString(),
            size: VideoUtil.getVideoWidthAndHeight(metadata),
            time: parseInt(metadata.duration || '0'),
            last_play: 0,
            format: VideoInfoUtil.getVideoFormat(WantProcess._wantUri),
            video_size: await VideoUtil.getVideoSize(WantProcess._wantUri, true) as string,
            hdr_type: metadata.hdrType ? media.HdrType.AV_HDR_TYPE_VIVID : media.HdrType.AV_HDR_TYPE_NONE,
            start_time: 0,
            end_time: 0,
            external_subtitle_format: ''
          }
          // 获取默认播放器
          let url = WantProcess.getPlayer(context, targetVideo)
          const playerParams = new PlayerParams(targetVideo, [targetVideo], undefined)
          WantProcess._wantUri = ''
          pathStack.pushPathByName(url, playerParams, true)
        })
      } catch (error) {
        console.error('want process error:' + error)
      }
    }
  }

  static getPlayer(context: Context, metadata: VideoMetadata) {
    const defaultPlayer = Preferences.getDefaultPlayer(context);
    // 系统分享（有长宽情况下）和 HDR VIVID 视频强制使用系统播放器
    if ((defaultPlayer === '系统播放器' || WantProcess.isSystemShare ||
      metadata.hdr_type === media.HdrType.AV_HDR_TYPE_VIVID || metadata.format.toLowerCase() === 'mov') &&
      metadata.size[0] !== 0) {
      return NavigationAddress.AV_PLAYER;
    } else if (defaultPlayer === '红薯播放器') {
      return NavigationAddress.RED_PLAYER;
    } else if (defaultPlayer === 'FFMpeg播放器') {
      return NavigationAddress.FFMPEG_PLAYER;
    }
    // 默认使用FFMpeg播放器
    return NavigationAddress.FFMPEG_PLAYER;
  }

  // 跳转外部网页
  static linkToWeb(context: common.UIAbilityContext, link: string) {
    let openLinkOptions: OpenLinkOptions = {
      appLinkingOnly: false,
    };
    try {
      context.openLink(link, openLinkOptions)
    } catch (paramError) {
      hilog.error(777, 'testFlag', 'paramError' + paramError)
    }
  }

  private static clearWantState() {
    WantProcess.hasNewWant = false;
    WantProcess._want = undefined;
  }
}
