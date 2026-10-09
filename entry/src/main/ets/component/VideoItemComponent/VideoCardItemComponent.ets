import { ImageFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import { ListDisplayMode } from '../../common/enum/DisplayMode'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { VideoInfoBuilder } from './VideoInfoBuilder'
import { VideoListController } from '../../controller/VideoListController'

@ComponentV2
export default struct VideoCardItem {
  @Param @Require item: VideoMetadata
  @Consumer() videoListController: VideoListController = new VideoListController()
  @Local choose: boolean = false
  @Param delMultipleList: VideoMetadata[] = []
  @Param coverRefreshDate: string = ''
  @Param coverRefreshToken: number = 0
  @Param compact: boolean = false
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

  @Builder
  CoverImage() {
    Image(this.coverSrc)
      .attributeModifier(new ImageFancyModifier(Setting.backgroundImageSrc.length > 0 ? {
        topLeft: 12,
        topRight: 12,
        bottomLeft: 0,
        bottomRight: 0
      } : 12, '', ''))
      .width('100%')
      .height(this.compact ? 120 : 'auto')
      .constraintSize({
        maxHeight: this.compact ? 120 : Setting.listDisplayMode === ListDisplayMode.GRID_DISPLAY ? 100 : 300,
        minHeight: this.compact ? 120 : Setting.listDisplayMode === ListDisplayMode.GRID_DISPLAY ? 100 : undefined
      })
      .objectFit(this.compact ? ImageFit.Cover : ImageFit.Auto)
      .id(`video_cover_${this.item.date}`)
      .geometryTransition(this.coverTransition ? `home-video-cover:${this.item.date}` : '')
  }

  build() {
    Column() {
      this.CoverImage()
      Row() {
        Text(VideoInfoUtil.getVideoTitle(this.item?.title))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .maxLines(this.compact || Setting.listDisplayMode === ListDisplayMode.GRID_DISPLAY ? 1 : 5)
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

      VideoInfoBuilder({ item: this.item })
    }
    .borderRadius(12)
    .width('100%')
    .height('auto')
    .backdropBlur(Setting.listItemBackgroundBlur ? 150 : 0)
  }
}
