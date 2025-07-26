import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../utils/AttributeModifierUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'

@Component
export struct VideoTopComponent {
  @Prop videoTitle: string
  @Link subTitleVisibility: Visibility
  @Link screenExtendSelectedText: string | undefined
  @Prop screenWidth: number
  @Prop screenHeight: number
  @BuilderParam audioTrackMenuBuilder: () => void
  @Prop lockRotation: boolean
  onLockRotationClick = async () => {
  }
  onExitVideoClick = () => {
  }
  onScreenExtendOptionSelected = (_text: string) => {
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
        Text(String(this.videoTitle).slice(0, this.videoTitle.lastIndexOf('.')))
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
            .onClick(() => {
              this.subTitleVisibility === Visibility.Visible ? this.subTitleVisibility = Visibility.None :
                this.subTitleVisibility = Visibility.Visible
            })
          if (this.screenWidth > this.screenHeight) {
            SymbolGlyph($r('sys.symbol.opticaldisc'))
              .attributeModifier(new SymbolGlyphFancyModifier(30, '', ''))
              .fontColor(['#f0f0f0'])
              .bindMenu(this.audioTrackMenuBuilder)
          }
          if (this.screenWidth > this.screenHeight) {
            Select([//屏幕扩展
              { value: '原始比例' },
              { value: '填满屏幕' },
              { value: '16:9' },
              { value: '4:3' },
              { value: '等比放大 110%' },
              { value: '等比放大 120%' },
              { value: '等比放大 130%' },
              { value: '等比放大 140%' }])
              .font({ size: 18, weight: FontWeight.Medium })
              .value(this.screenExtendSelectedText)
              .selected(VideoInfoUtil.screen_extend_map.indexOf(this.screenExtendSelectedText!))
              .fontColor($r('sys.color.white'))
              .onSelect(async (_index: number, text?: string | undefined) => {
                this.screenExtendSelectedText = text
                this.onScreenExtendOptionSelected(text!)
              })
              .menuBackgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
          }
        }.alignItems(VerticalAlign.Center)
      }.height('100%').layoutWeight(1)

      Button({ type: ButtonType.Circle, stateEffect: true }) { // 旋转锁定
        SymbolGlyph(this.lockRotation ? $r('sys.symbol.lock_fill') : $r('sys.symbol.rotate_left'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.lockRotation))
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
}