import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import VideoUtil, { VideoMetadata } from './VideoInfoUtil';
import { common, OpenLinkOptions } from '@kit.AbilityKit';
import PreferencesUtil from './PreferencesUtil';

class WantProcess {
  public want_uri: string = ''
  public isSystemShare: boolean = false
  public GITHUB_HOME_LINK: string = "https://github.com/Yebingiscn/SweetVideo"
  public PRIVACY_LINK: string =
    "https://github.com/Yebingiscn/SweetVideo/wiki/%E6%B5%81%E5%BF%83%E8%A7%86%E9%A2%91%E7%9A%84%E4%BD%BF%E7%94%A8%E6%9D%A1%E6%AC%BE%E4%B8%8E%E9%9A%90%E7%A7%81%E5%A3%B0%E6%98%8E"

  checkWant() {
    if (this.want_uri != '') {
      this.hasWant()
    }
  }

  async hasWant() {
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
      const defaultPlayer =
        await PreferencesUtil.getPreferencesValue("sweet_video", "defaultPlayer", 'FFMpeg播放器') as string
      let url = ''
      if (defaultPlayer === '系统播放器' || this.isSystemShare || tmp.hdr_type === media.HdrType.AV_HDR_TYPE_VIVID) {
        url = 'pages/Player'
      } else {
        url = 'pages/FFMpegPlayer'
      }
      router.pushUrl({
        url: url,
        params: {
          metadata: JSON.stringify(tmp),
        }
      }, router.RouterMode.Single, (err) => {
        hilog.info(0xFF00, "testTag", String(err));
      });
    })
  }

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