import { PathUtils } from '../../utils/PathUtils'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { fileUri } from '@kit.CoreFileKit'
import { ImageFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { VideoListController } from './VideoItemComponent'
import { VideoInfoBuilder } from './VideoInfoBuilder'
import { Setting } from '../../utils/ObservedUtil'
import { CoverLayoutMode } from '../../common/enum/DisplayMode'
import { coverEventBus, CoverUpdateEvent } from '../../utils/CoverEventUtil'

@Reusable
@Component
export default struct VideoListItem {
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
    Row() {
      Image(this.coverUri)
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
