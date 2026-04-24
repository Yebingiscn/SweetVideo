import { PathUtils } from '../../utils/PathUtils'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { fileUri } from '@kit.CoreFileKit'
import { ImageFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { VideoListController } from './VideoItemComponent'
import { VideoInfoBuilder } from './VideoInfoBuilder'
import { Setting } from '../../utils/ObservedUtil'
import { CoverLayoutMode } from '../../common/enum/DisplayMode'

@ReusableV2
@ComponentV2
export default struct VideoListItem {
  @Param @Require item: VideoMetadata
  @Consumer() videoListController: VideoListController = new VideoListController()
  @Local choose: boolean = false
  @Param delMultipleList: VideoMetadata[] = []

  // 组件复用时的生命周期回调
  aboutToReuse(): void {
    // 组件复用时，重置选择状态
    this.choose = this.delMultipleList.some(item => item.date === this.item.date)
  }

  @Monitor('delMultipleList')
  checkChoose() {
    this.choose = this.delMultipleList.some(item => item.date === this.item.date)
  }

  build() {
    Row() {
      Image(fileUri.getUriFromPath(PathUtils.coverPath + this.item.date))
        .attributeModifier(new ImageFancyModifier(16, Setting.coverLayout === CoverLayoutMode.VERTICAL_PLATE ? 75 : 100,
          Setting.coverLayout === CoverLayoutMode.VERTICAL_PLATE ? 100 : 75))
      Column() {
        Row() {
          Text(VideoInfoUtil.getVideoTitle(this.item))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .maxLines(2)
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

