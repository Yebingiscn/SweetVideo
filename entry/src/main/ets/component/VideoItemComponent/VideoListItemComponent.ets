import { PathUtils } from '../../utils/PathUtils'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { ImageFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { VideoListController } from '../../controller/VideoListController'
import { VideoInfoBuilder } from './VideoInfoBuilder'
import { Setting } from '../../utils/ObservedUtil'
import { CoverLayoutMode } from '../../common/enum/DisplayMode'

@ComponentV2
export default struct VideoListItem {
  @Param @Require item: VideoMetadata
  @Consumer() videoListController: VideoListController = new VideoListController()
  @Local choose: boolean = false
  @Param delMultipleList: VideoMetadata[] = []
  @Param coverRefreshDate: string = ''
  @Param coverRefreshToken: number = 0
  @Param coverTransition: boolean = false
  @Local coverSrc: string = ''

  aboutToAppear(): void {
    this.coverSrc = PathUtils.coverUri(this.item.date)
  }

  @Monitor('item')
  onItemChange() {
    this.coverSrc = PathUtils.coverUri(this.item.date)
  }

  // 封面文件被覆盖后文件名不变，先清空再重设地址，强制 Image 重新读取文件
  @Monitor('coverRefreshToken')
  onCoverRefreshTokenChange() {
    if (this.coverRefreshDate !== this.item.date) {
      return
    }
    this.coverSrc = ''
    setTimeout(() => {
      this.coverSrc = PathUtils.coverUri(this.item.date)
    }, 100)
  }

  @Monitor('delMultipleList')
  checkChoose() {
    this.choose = this.delMultipleList.some(item => item.date === this.item.date)
  }

  build() {
    Row() {
      Image(this.coverSrc)
        .attributeModifier(new ImageFancyModifier(12,
          Setting.coverLayout === CoverLayoutMode.VERTICAL_PLATE ? 85 : 110,
          Setting.coverLayout === CoverLayoutMode.VERTICAL_PLATE ? 110 : 110))
        .id(`video_cover_${this.item.date}`)
        .geometryTransition(this.coverTransition ? `home-video-cover:${this.item.date}` : '')
      Column() {
        Row() {
          Text(VideoInfoUtil.getVideoTitle(this.item?.title))
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

        VideoInfoBuilder({ item: this.item })
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16 })
      .layoutWeight(1)
    }
    .borderRadius(12)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('auto')
    .backdropBlur(Setting.listItemBackgroundBlur ? 150 : 0)
  }
}

