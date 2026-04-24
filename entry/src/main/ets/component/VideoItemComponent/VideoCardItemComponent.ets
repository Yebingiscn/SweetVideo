import { ImageFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import { ListDisplayMode } from '../../common/enum/DisplayMode'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { VideoInfoBuilder } from './VideoInfoBuilder'
import { VideoListController } from './VideoItemComponent'
import { fileUri } from '@kit.CoreFileKit'

@ReusableV2
@ComponentV2
export default struct VideoCardItem {
  @Param @Require item: VideoMetadata
  @Consumer() videoListController: VideoListController = new VideoListController()
  @Local choose: boolean = false
  @Param @Once delMultipleList: VideoMetadata[] = []

  // 组件复用时的生命周期回调
  aboutToReuse(): void {
    // 组件复用时，重置选择状态
    this.choose = this.delMultipleList.some(item => item.date === this.item.date)
  }

  checkChoose() {
    this.choose = this.delMultipleList.some(item => item.date === this.item.date)
  }

  build() {
    Column() {
      Image(fileUri.getUriFromPath(PathUtils.coverPath + this.item.date))
        .attributeModifier(new ImageFancyModifier(16, '', ''))
        .width('100%')
        .height('auto')
        .constraintSize({
          maxHeight: Setting.listDisplayMode === ListDisplayMode.GRID_DISPLAY ? 100 : 300,
          minHeight: Setting.listDisplayMode === ListDisplayMode.GRID_DISPLAY ? 100 : undefined
        })
        .objectFit(ImageFit.Auto)
      Row() {
        Text(VideoInfoUtil.getVideoTitle(this.item))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .maxLines(Setting.listDisplayMode === ListDisplayMode.GRID_DISPLAY ? 1 : 5)
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