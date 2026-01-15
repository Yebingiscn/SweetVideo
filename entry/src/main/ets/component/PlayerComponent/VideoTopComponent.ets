import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import { SubtitleMode } from '../../common/enum/SubtitleMode'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

@Component
export struct VideoTopComponent {
  @State videoTitle: string = ''
  @Link subTitleVisibility: Visibility
  @Link isAIAsrShown: boolean
  @Prop subtitleSelected: SubtitleMode
  @Link screenExtendSelectedText: string | undefined
  @Link screenWidth: number
  @Link screenHeight: number
  @BuilderParam audioTrackMenuBuilder: () => void
  @BuilderParam subtitlePanelComponent: () => void
  @Link lockRotation: boolean
  @Link playAreaHeight: number
  @Link playAreaWidth: number
  onLockRotationClick = async () => {
  }
  onExitVideoClick = () => {
  }

  build() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .attributeModifier(new SymbolGlyphFancyModifier(40, '', ''))
        .fontColor(['#f0f0f0'])
        .onClick(() => {
          this.onExitVideoClick()
        })
        .padding({ right: 5 })
      Row() {
        Text(this.videoTitle.slice(0, this.videoTitle?.lastIndexOf('.')))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .fontColor($r('sys.color.white'))
          .layoutWeight(1) // 关键布局属性
        Row({ space: 12 }) {
          SymbolGlyph(this.subTitleVisibility === Visibility.Visible ?
            $r('sys.symbol.textformat_size_square_fill') : $r('sys.symbol.textformat_size_square'))
            .attributeModifier(new SymbolGlyphFancyModifier(30, '', ''))
            .fontColor(['#f0f0f0'])
            .bindMenu(this.subtitlePanelComponent, { backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN })
          if (this.screenWidth > this.screenHeight) {
            SymbolGlyph($r('sys.symbol.opticaldisc'))
              .attributeModifier(new SymbolGlyphFancyModifier(30, '', ''))
              .fontColor(['#f0f0f0'])
              .bindMenu(this.audioTrackMenuBuilder,
                { backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN })
          }
          if (this.screenWidth > this.screenHeight) {
            Select(VideoInfoUtil.screenExtendList)
              .font({ size: 18, weight: FontWeight.Medium })
              .value(this.screenExtendSelectedText)
              .selected(VideoInfoUtil.screenExtendMap.indexOf(this.screenExtendSelectedText!))
              .fontColor($r('sys.color.white'))
              .onSelect((_index: number, text?: string | undefined) => {
                this.screenExtendSelectedText = text
                this.screenExtend(text!)
              })
              .menuBackgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
          }
        }.alignItems(VerticalAlign.Center)
      }.height('100%').layoutWeight(1)

      Button({ type: ButtonType.Circle, stateEffect: true }) { // 旋转锁定
        SymbolGlyph(this.lockRotation ? $r('sys.symbol.lock_fill') : $r('sys.symbol.rotate_left'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
      }
      .attributeModifier(new ButtonFancyModifier(35, 40))
      .backgroundColor('#50000000')
      .onClick(async () => {
        await this.onLockRotationClick()
      })
    }
    .padding({ left: 8, right: 8 })
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  private screenExtend(text: string) {
    if (VideoOperateUtil.aspectRatioMap.has(text)) {
      const play_area_size = VideoOperateUtil.setVideoAspectRatio(
        VideoOperateUtil.aspectRatioMap.get(text)!,
        VideoInfoUtil.play_area_width,
        VideoInfoUtil.play_area_height
      )
      this.playAreaWidth = play_area_size[0]
      this.playAreaHeight = play_area_size[1]
      return
    }
    switch (text) {
      case VideoInfoUtil.screenExtendMap[0]:
        this.playAreaHeight = VideoInfoUtil.play_area_height
        this.playAreaWidth = VideoInfoUtil.play_area_width
        break
      case VideoInfoUtil.screenExtendMap[1]:
        this.playAreaHeight = this.screenHeight
        this.playAreaWidth = this.screenWidth
        break
      case VideoInfoUtil.screenExtendMap[2]: // 适应宽度
        this.playAreaWidth = this.screenWidth
        this.playAreaHeight = (VideoInfoUtil.play_area_height / VideoInfoUtil.play_area_width) * this.screenWidth
        break
      case VideoInfoUtil.screenExtendMap[3]: // 适应高度
        this.playAreaHeight = this.screenHeight
        this.playAreaWidth = (VideoInfoUtil.play_area_width / VideoInfoUtil.play_area_height) * this.screenHeight
        break
      default:
        const scale = text ? VideoInfoUtil.scale_factors.get(text) : undefined
        if (scale) {
          this.playAreaHeight = scale * VideoInfoUtil.play_area_height
          this.playAreaWidth = scale * VideoInfoUtil.play_area_width
        }
        break
    }
  }
}