import { PathUtils } from '../../utils/PathUtils';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import { fileUri } from '@kit.CoreFileKit';
import { ImageFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig';
import VideoInfoUtil from '../../utils/VideoInfoUtil';
import { VideoListController } from './VideoItemComponent';
import { VideoInfoBuilder } from './VideoInfoBuilder';

@Reusable
@Component
export default struct VideoListItem {
  @Prop item: VideoMetadata
  @Consume videoListController: VideoListController
  @State choose: boolean = false
  @Watch('checkChoose') @Link delMultipleList: VideoMetadata[]

  checkChoose() {
    this.choose = this.delMultipleList.some(item => item.date === this.item.date)
  }

  build() {
    Row() {
      Image(fileUri.getUriFromPath(PathUtils.coverPath + this.item.date))
        .attributeModifier(new ImageFancyModifier(16, 80, 120))
      Column() {
        Row() {
          Text(VideoInfoUtil.getVideoTitle(this.item))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
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
        }.padding({ left: 5 })

        VideoInfoBuilder({ item: this.item, showProgress: true })
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 15, right: 15 })
      .layoutWeight(1)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%').height('auto')
  }
}

