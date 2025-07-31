import { hilog } from '@kit.PerformanceAnalysisKit';
import { media } from '@kit.MediaKit';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import VideoUtil from './VideoInfoUtil';
import VideoInfoUtil from './VideoInfoUtil';
import { common, Context, OpenLinkOptions, Want } from '@kit.AbilityKit';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { PlayerParams } from '../common/PlayerParams';
import Preferences from '../database/Preferences';
import { systemShare } from '@kit.ShareKit';

// 处理拉起应用传来的视频链接
class WantProcess {
  public hasNewWant = false //是否接收到拉起
  public want: Want | undefined = undefined
  public wantUri: string = '' //接收到的uri
  public isSystemShare: boolean = false // 是否系统分享
  public GITHUB_HOME_LINK: string = "https://github.com/Yebingiscn/SweetVideo" // 项目主页
  // 隐私协议链接
  public PRIVACY_LINK: string =
    "https://github.com/Yebingiscn/SweetVideo/wiki/%E6%B5%81%E5%BF%83%E8%A7%86%E9%A2%91%E7%9A%84%E4%BD%BF%E7%94%A8%E6%9D%A1%E6%AC%BE%E4%B8%8E%E9%9A%90%E7%A7%81%E5%A3%B0%E6%98%8E"

  async getSystemShareWant(want: Want) {
    try {
      const data = await systemShare.getSharedData(want);
      const records = data.getRecords();
      for (const record of records) {
        if (record.uri) {
          this.wantUri = record.uri;
          this.isSystemShare = true;
          this.hasNewWant = true;
          break;
        }
      }
    } catch (error) {
      const businessError = error as BusinessError;
      console.error(`Failed: Code ${businessError.code}, ${businessError.message}`);
    }
  }

  async checkWant(context: Context, pathStack: NavPathStack) {
    if (!this.want) {
      return
    }
    if (this.want.uri) {
      this.wantUri = this.want.uri
      this.hasNewWant = true
    } else {
      await this.getSystemShareWant(this.want)
      if (!this.wantUri) {
        return
      }
    }
    if (this.wantUri != '') {
      this.clearWantState()
      this.hasWant(context, pathStack)
    }
  }

  // 处理拉起链接
  async hasWant(context: Context, pathStack: NavPathStack) {
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      let avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor()
      let file = fs.openSync(this.wantUri);
      avMetadataExtractor.fdSrc = file
      avMetadataExtractor.fetchMetadata(async (_error: BusinessError, metadata: media.AVMetadata) => {
        let targetVideo: VideoMetadata = {
          uri: this.wantUri,
          title: decodeURI(this.wantUri.split('/')[this.wantUri.split('/').length-1]),
          date: systemDateTime.getTime(false).toString(),
          size: VideoUtil.getVideoWidthAndHeight(metadata),
          time: parseInt(metadata.duration || '0'),
          last_play: 0,
          format: VideoInfoUtil.getVideoFormat(this.wantUri),
          video_size: await VideoUtil.getVideoSize(this.wantUri, true) as string,
          hdr_type: metadata.hdrType ? media.HdrType.AV_HDR_TYPE_VIVID : media.HdrType.AV_HDR_TYPE_NONE,
          start_time: 0,
          end_time: 0
        }
        // 获取默认播放器
        let url = this.getPlayer(context, targetVideo)
        const playerParams = new PlayerParams(targetVideo as VideoMetadata, [], undefined)
        this.wantUri = ''
        pathStack.pushPathByName(url, playerParams, true)
      })
    }
  }

  getPlayer(context: Context, metadata: VideoMetadata) {
    const defaultPlayer = Preferences.getDefaultPlayer(context);
    // 系统分享（有长宽情况下）和 HDR VIVID 视频强制使用系统播放器
    if ((defaultPlayer === '系统播放器' || this.isSystemShare ||
      metadata.hdr_type === media.HdrType.AV_HDR_TYPE_VIVID) && metadata.size[0] !== 0) {
      return 'Player';
    } else if (defaultPlayer === '红薯播放器') {
      return 'RedPlayer';
    } else if (defaultPlayer === 'FFMpeg播放器') {
      return 'FFMpegPlayer';
    }
    // 默认使用FFMpeg播放器
    return 'FFMpegPlayer';
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
    this.want = undefined;
  }
}

export default new WantProcess()