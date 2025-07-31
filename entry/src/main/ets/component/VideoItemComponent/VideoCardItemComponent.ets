import { PathUtils } from '../../utils/PathUtils';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import { fileUri } from '@kit.CoreFileKit';
import { ImageFancyModifier, SymbolGlyphFancyModifier } from '../../utils/AttributeModifierUtil';
import VideoInfoUtil from '../../utils/VideoInfoUtil';
import { VideoListController } from './VideoItemComponent';
import { VideoInfoComponent } from './VideoInfoComponent';

@Reusable
@Component
export default struct VideoCardItem {
  @Prop item: VideoMetadata
  @Prop index: number
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
          topLeft: 10,
          topRight: 10,
          bottomLeft: 10,
          bottomRight: 10
        }, 60, 200))
        .width('100%').height('auto')
        .objectFit(ImageFit.Auto)
      Column() {
        Row() {
          Text(VideoInfoUtil.getVideoTitle(this.videoListController.videoDataSource.getAllData(), this.item))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
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
        .padding({ top: 5 })

        VideoInfoComponent({ item: this.item })
      }.padding({ left: 5, right: 5, bottom: 5 })
      .width('100%')
    }
    .width('100%')
    .height('auto')
  }
}