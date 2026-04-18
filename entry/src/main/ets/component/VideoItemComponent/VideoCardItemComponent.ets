import { PathUtils } from '../../utils/PathUtils'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { fileUri } from '@kit.CoreFileKit'
import { ImageFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { VideoListController } from './VideoItemComponent'
import { VideoInfoBuilder } from './VideoInfoBuilder'
import { ListDisplayMode } from '../../common/enum/DisplayMode'
import { Setting } from '../../utils/ObservedUtil'
import { coverEventBus, CoverUpdateEvent } from '../../utils/CoverEventUtil'

@Reusable
@Component
export default struct VideoCardItem {
  @Prop @Watch('onItemChange') item: VideoMetadata
  @Consume videoListController: VideoListController
  @State choose: boolean = false
  @State coverUri: string = ''
  @Watch('checkChoose') @Link delMultipleList: VideoMetadata[]
  private unsubscribeCoverEvent: (() => void) | null = null

  checkChoose() {
    this.choose = this.delMultipleList.some(item => item.date === this.item.date)
  }

  onItemChange() {
    this.coverUri = fileUri.getUriFromPath(PathUtils.coverPath + this.item.date)
  }

  aboutToAppear() {
    this.coverUri = fileUri.getUriFromPath(PathUtils.coverPath + this.item.date)
    this.unsubscribeCoverEvent = coverEventBus.on('coverReady', (event: CoverUpdateEvent) => {
      if (event.date === this.item.date) {
        this.coverUri = fileUri.getUriFromPath(PathUtils.coverPath + this.item.date) + '?t=' + Date.now()
      }
    })
  }

  aboutToDisappear() {
    this.unsubscribeCoverEvent?.()
    this.unsubscribeCoverEvent = null
  }

  build() {
    Column() {
      Image(this.coverUri)
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
