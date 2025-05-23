import { hilog } from '@kit.PerformanceAnalysisKit';
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import VideoUtil from './VideoInfoUtil';
import { common, OpenLinkOptions } from '@kit.AbilityKit';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { PlayerParams } from '../common/PlayerParams';
import Preferences from '../database/Preferences';

// 处理拉起应用传来的视频链接
class WantProcess {
  public has_new_want = false //是否接收到拉起
  public want_uri: string = '' //接收到的uri
  public isSystemShare: boolean = false // 是否系统分享
  public GITHUB_HOME_LINK: string = "https://github.com/Yebingiscn/SweetVideo" // 项目主页
  public isNewWant = true
  // 隐私协议链接
  public PRIVACY_LINK: string =
    "https://github.com/Yebingiscn/SweetVideo/wiki/%E6%B5%81%E5%BF%83%E8%A7%86%E9%A2%91%E7%9A%84%E4%BD%BF%E7%94%A8%E6%9D%A1%E6%AC%BE%E4%B8%8E%E9%9A%90%E7%A7%81%E5%A3%B0%E6%98%8E"

  checkWant(context: Context, pathStack: NavPathStack) {
    if (this.want_uri != '') {
      this.isNewWant = false
      this.has_new_want = false
      this.hasWant(context, pathStack)
    }
  }

  // 处理拉起链接
  async hasWant(context: Context, pathStack: NavPathStack) {
    let avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor()
    let file = fs.openSync(this.want_uri);
    avMetadataExtractor.fdSrc = file
    const format = this.want_uri.split('.')[this.want_uri.split('.').length-1]
    avMetadataExtractor.fetchMetadata(async (_error: BusinessError, metadata: media.AVMetadata) => {
      let tmp: VideoMetadata = {
        uri: this.want_uri,
        title: this.want_uri.split('/')[this.want_uri.split('/').length-1],
        date: '',
        size: VideoUtil.getVideoWidthAndHeight(metadata),
        time: parseInt(metadata.duration || '0'),
        last_play: 0,
        format: format,
        video_size: await VideoUtil.getVideoSize(this.want_uri),
        hdr_type: metadata.hdrType ? media.HdrType.AV_HDR_TYPE_VIVID : media.HdrType.AV_HDR_TYPE_NONE,
      }
      // 获取默认播放器
      const defaultPlayer = Preferences.getDefaultPlayer(context)
      let url = ''
      // 如果是系统分享（一般都是从图库分享，图库的视频如果使用了高效视频格式或者是 HDR VIVID 需要使用系统播放器才能播
      if (defaultPlayer === '系统播放器' || this.isSystemShare || tmp.hdr_type === media.HdrType.AV_HDR_TYPE_VIVID) {
        url = 'Player'
      } else if (defaultPlayer === '红薯播放器') {
        url = 'RedPlayer'
      } else {
        url = 'FFMpegPlayer'
      }
      const playerParams = new PlayerParams(tmp as VideoMetadata, [], undefined)
      this.want_uri = ''
      pathStack.pushPathByName(url, playerParams, true)
    })
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
}

export default new WantProcess()