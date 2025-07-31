import { PathUtils } from '../../utils/PathUtils';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import { fileUri } from '@kit.CoreFileKit';
import { ImageFancyModifier, SymbolGlyphFancyModifier } from '../../utils/AttributeModifierUtil';
import VideoInfoUtil from '../../utils/VideoInfoUtil';
import { VideoListController } from './VideoItemComponent';
import { VideoInfoComponent } from './VideoInfoComponent';

@Reusable
@Component
export default struct VideoListItem {
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
      Row() {
        Image(fileUri.getUriFromPath(PathUtils.coverPath + this.item.date))
          .attributeModifier(new ImageFancyModifier(10, 64, 96))
        Column() {
          Row() {
            Text(VideoInfoUtil.getVideoTitle(this.videoListController.videoDataSource.getAllData(), this.item))
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .wordBreak(WordBreak.BREAK_ALL)
            if (this.videoListController.multipleChooseState === Visibility.Visible) {
              SymbolGlyph(this.choose ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.circle'))
                .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                .onAppear(() => {
                  this.checkChoose()
                })
            }
          }

          VideoInfoComponent({ item: this.item })
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 15, right: 15 })
        .layoutWeight(1)
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
    }
    .height('auto')
    .justifyContent(FlexAlign.SpaceEvenly)
  }
}