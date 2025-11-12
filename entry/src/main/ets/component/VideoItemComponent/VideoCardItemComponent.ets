import { PathUtils } from '../../utils/PathUtils';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import { fileUri } from '@kit.CoreFileKit';
import { ImageFancyModifier, SymbolGlyphFancyModifier } from '../../utils/AttributeModifierUtil';
import VideoInfoUtil from '../../utils/VideoInfoUtil';
import { VideoListController } from './VideoItemComponent';
import { VideoInfoBuilder } from './VideoInfoBuilder';

@Reusable
@Component
export default struct VideoCardItem {
  @Prop item: VideoMetadata
  @Consume videoListController: VideoListController
  @State choose: boolean = false
  @Watch('checkChoose') @Link delMultipleList: VideoMetadata[]

  checkChoose() {
    this.choose = this.delMultipleList.some(item => item.date === this.item.date)
  }

  build() {
    Column() {
      Image(fileUri.getUriFromPath(PathUtils.coverPath + this.item.date))
        .attributeModifier(new ImageFancyModifier({
          topLeft: 16,
          topRight: 16,
          bottomLeft: 16,
          bottomRight: 16
        }, '', ''))
        .width('100%')
        .height('auto')
        .constraintSize({ maxHeight: 200 })
        .objectFit(ImageFit.Auto)
      Row() {
        Text(VideoInfoUtil.getVideoTitle(this.item))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .maxLines(5)
          .textAlign(TextAlign.Start)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)// 占据剩余空间
          .wordBreak(WordBreak.BREAK_ALL)
        if (this.videoListController.multipleChooseState === Visibility.Visible) {
          SymbolGlyph(this.choose ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.circle'))
            .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
            .onAppear(() => {
              this.checkChoose()
            })
        }
      }
      .width('100%')
      .padding({ top: 5, left: 5 })

      VideoInfoBuilder({ item: this.item, showProgress: true })
    }
    .width('100%')
    .height('auto')
  }
}