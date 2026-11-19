import { PathUtils } from '../../utils/PathUtils'
import ImageStorage from '../../utils/ImageStorage'
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
  private coverDate: string = ''
  private coverLoadFailed: boolean = false
  private coverActive: boolean = false
  private coverReloadTimer: number | undefined = undefined

  aboutToAppear(): void {
    this.coverActive = true
    this.onItemChange()
    this.coverSrc = PathUtils.coverUri(this.item.date)
  }

  aboutToDisappear(): void {
    this.coverActive = false
    this.clearCoverReloadTimer()
  }

  @Monitor('item')
  onItemChange(): void {
    if (this.coverDate === this.item.date) {
      return
    }
    this.clearCoverReloadTimer()
    this.coverDate = this.item.date
    this.coverLoadFailed = false
    this.coverSrc = PathUtils.coverUri(this.item.date)
  }

  @Monitor('videoListController.videoDataSource.revision')
  onCoverDataRevisionChange(): void {
    if (!this.coverActive || !this.coverLoadFailed || this.coverDate !== this.item.date ||
      this.coverReloadTimer !== undefined) {
      return
    }
    // 重复导入可能补回原文件名的封面，只重试已经加载失败且现已存在的图片。
    if (ImageStorage.getExistingImageUri(PathUtils.coverPath + this.item.date)) {
      this.reloadCover()
    }
  }

  @Monitor('coverRefreshToken')
  onCoverRefreshTokenChange(): void {
    if (this.coverRefreshDate === this.item.date) {
      this.reloadCover()
    }
  }

  // 文件名未变，先清空再重设地址；列表复用或退出后不能写回旧封面。
  private reloadCover(): void {
    if (!this.coverActive) {
      return
    }
    this.clearCoverReloadTimer()
    const date = this.item.date
    this.coverSrc = ''
    this.coverReloadTimer = setTimeout(() => {
      this.coverReloadTimer = undefined
      if (this.coverActive && this.item.date === date && this.coverDate === date) {
        this.coverSrc = PathUtils.coverUri(date)
      }
    }, 100)
  }

  private clearCoverReloadTimer(): void {
    if (this.coverReloadTimer !== undefined) {
      clearTimeout(this.coverReloadTimer)
      this.coverReloadTimer = undefined
    }
  }

  private onCoverLoadError(): void {
    if (this.coverSrc.length > 0) {
      this.coverLoadFailed = true
    }
  }

  private onCoverLoadComplete(): void {
    if (this.coverSrc.length > 0) {
      this.coverLoadFailed = false
    }
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
        .onError(() => this.onCoverLoadError())
        .onComplete(() => this.onCoverLoadComplete())
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
            Stack({ alignContent: Alignment.Center }) {
              SymbolGlyph(this.choose ? $r('sys.symbol.checkmark') : $r('sys.symbol.circle'))
                .attributeModifier(new SymbolGlyphFancyModifier(this.choose ? 18 : 28, '', ''))
                .fontColor([this.choose ? Color.White : $r('app.color.text_color')])
            }
              .width(28)
              .height(28)
              .backgroundColor(this.choose ? $r('app.color.main_color') : Color.Transparent)
              .borderRadius(14)
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

