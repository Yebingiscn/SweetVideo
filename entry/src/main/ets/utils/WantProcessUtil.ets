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
class WantProcess {
  public hasNewWant = false //是否接收到拉起
  // 隐私协议链接
  public PRIVACY_LINK: string =
    "https://github.com/Yebingiscn/SweetVideo/wiki/%E6%B5%81%E5%BF%83%E6%92%AD%E6%94%BE%E5%99%A8%E7%9A%84%E4%BD%BF%E7%94%A8%E6%9D%A1%E6%AC%BE%E4%B8%8E%E9%9A%90%E7%A7%81%E5%A3%B0%E6%98%8E"
  private isSystemShare: boolean = false // 是否系统分享
  private _wantUri: string = ''; //接收到的uri

  public set wantUri(value: string) {
    this._wantUri = value;
  }

  private _want: Want | undefined = undefined;

  public set want(value: Want | undefined) {
    this._want = value;
  }

  async getSystemShareWant(want: Want) {
    try {
      if (canIUse("SystemCapability.Collaboration.SystemShare")) {
        const data = await systemShare.getSharedData(want);
        const records = data.getRecords();
        for (const record of records) {
          if (record.uri) {
            this._wantUri = record.uri;
            this.isSystemShare = true;
            this.hasNewWant = true;
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

  async checkWant(context: Context, pathStack: NavPathStack) {
    if (!this._want) {
      return
    }
    if (this._want.uri) {
      this._wantUri = this._want.uri
      this.hasNewWant = true
    } else {
      await this.getSystemShareWant(this._want)
      if (!this._wantUri) {
        return
      }
    }
    if (this._wantUri != '') {
      this.clearWantState()
      this.hasWant(context, pathStack)
    }
  }

  // 处理拉起链接
  async hasWant(context: Context, pathStack: NavPathStack) {
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      try {
        let avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor()
        let file = fs.openSync(this._wantUri);
        avMetadataExtractor.fdSrc = file
        avMetadataExtractor.fetchMetadata(async (_error: BusinessError, metadata: media.AVMetadata) => {
          let targetVideo: VideoMetadata = {
            uri: this._wantUri,
            title: decodeURI(this._wantUri.split('/')[this._wantUri.split('/').length-1]),
            date: systemDateTime.getTime(false).toString(),
            size: VideoUtil.getVideoWidthAndHeight(metadata),
            time: parseInt(metadata.duration || '0'),
            last_play: 0,
            format: VideoInfoUtil.getVideoFormat(this._wantUri),
            video_size: await VideoUtil.getVideoSize(this._wantUri, true) as string,
            hdr_type: metadata.hdrType ? media.HdrType.AV_HDR_TYPE_VIVID : media.HdrType.AV_HDR_TYPE_NONE,
            start_time: 0,
            end_time: 0,
            external_subtitle_format: ''
          }
          // 获取默认播放器
          let url = this.getPlayer(context, targetVideo)
          const playerParams = new PlayerParams(targetVideo, [targetVideo], undefined)
          this._wantUri = ''
          pathStack.pushPathByName(url, playerParams, true)
        })
      } catch (error) {
        console.error('want process error:' + error)
      }
    }
  }

  getPlayer(context: Context, metadata: VideoMetadata) {
    const defaultPlayer = Preferences.getDefaultPlayer(context);
    // 系统分享（有长宽情况下）和 HDR VIVID 视频强制使用系统播放器
    if ((defaultPlayer === '系统播放器' || this.isSystemShare ||
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
  linkToWeb(context: common.UIAbilityContext, link: string) {
    let openLinkOptions: OpenLinkOptions = {
      appLinkingOnly: false,
    };
    try {
      context.openLink(link, openLinkOptions)
    } catch (paramError) {
      hilog.error(777, 'testFlag', 'paramError' + paramError)
    }
  }

  private clearWantState() {
    this.hasNewWant = false;
    this._want = undefined;
  }
}

export default new WantProcess()