import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import VideoUtil, { VideoMetadata } from './VideoUtil';

class WantProcess {
  public want_uri: string = ''

  async hasWant() {
    let avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor()
    let file = fs.openSync(this.want_uri);
    avMetadataExtractor.fdSrc = file
    avMetadataExtractor.fetchMetadata(async (_error: BusinessError, metadata: media.AVMetadata) => {
      let tmp: VideoMetadata = {
        uri: this.want_uri,
        title: this.want_uri.split('/')[this.want_uri.split('/').length-1],
        date: '',
        size: [parseInt((metadata.videoOrientation == '90' || metadata.videoOrientation == '270' ?
        metadata.videoHeight : metadata.videoWidth) || '0'),
          parseInt((metadata.videoOrientation == '90' || metadata.videoOrientation == '270' ? metadata.videoWidth :
          metadata.videoHeight) || '0')],
        time: parseInt(metadata.duration || '0'),
        last_play: 0,
        format: this.want_uri.split('.')[this.want_uri.split('.').length-1],
        video_size: await VideoUtil.getVideoSize(this.want_uri),
        hdr_type: metadata.hdrType ? media.HdrType.AV_HDR_TYPE_VIVID : media.HdrType.AV_HDR_TYPE_NONE,
      }
      router.pushUrl({
        url: 'pages/Player',
        params: {
          metadata: JSON.stringify(tmp)
        }
      }, router.RouterMode.Standard, (err) => {
        hilog.info(0xFF00, "testTag", String(err));
      });
    })
  }
}

const wantProcess = new WantProcess()

export default wantProcess as WantProcess