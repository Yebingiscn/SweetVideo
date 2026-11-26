import { LengthMetrics } from '@kit.ArkUI'
import { DanmakuSession } from '../../utils/DanmakuSession'
import { Setting } from '../../utils/ObservedUtil'
import { ButtonFancyModifier } from '../../common/AttributeModifierConfig'

@ComponentV2
export struct DanmakuMenuComponent {
  @Param session: DanmakuSession = new DanmakuSession()
  @Event onImport: () => void = () => {
  }
  @Event onOffset: () => void = () => {
  }

  build() {
    Menu() {
      MenuItem({ content: $r('app.string.show_danmaku') })
        .enabled(this.session.items.length > 0)
        .contentFontColor(this.session.enabled && this.session.items.length > 0 ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .onClick(() => {
          this.session.enabled = !this.session.enabled
        })
        .height(40)
        .backgroundColor(this.session.enabled && this.session.items.length > 0 ? $r('app.color.main_color') :
          Color.Transparent)
        .borderRadius(16)
        .width('100%')
      MenuItem({ content: this.session.loading ? $r('app.string.importing') : $r('app.string.import_local_danmaku') })
        .danmakuItemStyle()
        .enabled(!this.session.loading)
        .onClick(() => this.onImport())
      if (this.session.items.length > 0) {
        MenuItem({ content: `${this.session.items.length} 条 · ${this.session.name}` })
          .enabled(false)
        MenuItem({ content: $r('app.string.display_area'), builder: this.DanmakuAreaMenu }).danmakuItemStyle()
        MenuItem({ content: $r('app.string.danmaku_time_offset', this.session.offsetMs) })
          .danmakuItemStyle()
          .onClick(() => this.onOffset())
      }
      MenuItemGroup({
        header: this.DanmakuSizeSlider,
        footer: this.DanmakuOpacitySlider
      })
    }
    .width(270)
    .height('auto')
    .menuItemGroupDivider({ strokeWidth: LengthMetrics.vp(0), color: Color.Transparent })
    .subMenuExpandingMode(SubMenuExpandingMode.STACK_EXPAND)
  }

  @Builder
  DanmakuSizeSlider() {
    Row() {
      Text(`大小 ${Math.round(this.session.fontSize)}号`)
        .fontSize(14)
        .fontColor($r('app.color.text_color'))
        .width(68)
      Slider({
        value: this.session.fontSize,
        min: 14,
        max: 48,
        step: 1,
        style: SliderStyle.InSet
      })
        .onChange((value: number) => {
          this.session.fontSize = value
        })
        .selectedColor($r('app.color.main_color'))
        .enableHapticFeedback(true)
        .layoutWeight(1)
        .trackBorderRadius(16)
        .trackThickness(20)
        .selectedBorderRadius(16)
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.undo'))
          .fontSize(16)
          .fontColor([$r('app.color.text_color')])
      }
      .attributeModifier(new ButtonFancyModifier(28, 28))
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.session.fontSize = Math.max(14, Math.min(48, Number(Setting.subtitleSize) || 22))
      })
    }
    .padding({
      left: 8,
      right: 8,
      top: 4,
      bottom: 4
    })
    .width('100%')
  }

  @Builder
  DanmakuOpacitySlider() {
    Row() {
      Text(`透明 ${Math.round(this.session.opacity * 100)}%`)
        .fontSize(14)
        .fontColor($r('app.color.text_color'))
        .width(68)
      Slider({
        value: this.session.opacity * 100,
        min: 10,
        max: 100,
        step: 1,
        style: SliderStyle.InSet
      })
        .onChange((value: number) => {
          this.session.opacity = value / 100
        })
        .selectedColor($r('app.color.main_color'))
        .enableHapticFeedback(true)
        .layoutWeight(1)
        .trackBorderRadius(16)
        .trackThickness(20)
        .selectedBorderRadius(16)
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.undo'))
          .fontSize(16)
          .fontColor([$r('app.color.text_color')])
      }
      .attributeModifier(new ButtonFancyModifier(28, 28))
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.session.opacity = 0.8
      })
    }
    .padding({
      left: 8,
      right: 8,
      top: 4,
      bottom: 4
    })
    .width('100%')
  }

  @Builder
  DanmakuAreaMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.area_fullscreen') })
        .danmakuItemStyle()
        .contentFontColor(this.session.area === 1 ? $r('sys.color.white') : $r('app.color.text_color'))
        .backgroundColor(this.session.area === 1 ? $r('app.color.main_color') : Color.Transparent)
        .onClick(() => {
          this.session.area = 1
        })
      MenuItem({ content: $r('app.string.area_top_quarter') })
        .danmakuItemStyle()
        .contentFontColor(this.session.area === 0.25 ? $r('sys.color.white') : $r('app.color.text_color'))
        .backgroundColor(this.session.area === 0.25 ? $r('app.color.main_color') : Color.Transparent)
        .onClick(() => {
          this.session.area = 0.25
        })
      MenuItem({ content: $r('app.string.area_top_half') })
        .danmakuItemStyle()
        .contentFontColor(this.session.area === 0.5 ? $r('sys.color.white') : $r('app.color.text_color'))
        .backgroundColor(this.session.area === 0.5 ? $r('app.color.main_color') : Color.Transparent)
        .onClick(() => {
          this.session.area = 0.5
        })
      MenuItem({ content: $r('app.string.area_top_three_quarter') })
        .danmakuItemStyle()
        .contentFontColor(this.session.area === 0.75 ? $r('sys.color.white') : $r('app.color.text_color'))
        .backgroundColor(this.session.area === 0.75 ? $r('app.color.main_color') : Color.Transparent)
        .onClick(() => {
          this.session.area = 0.75
        })
    }
  }
}

@Extend(MenuItem)
function danmakuItemStyle() {
  .height(40)
  .borderRadius(16)
  .width('100%')
  .contentFontColor($r('app.color.text_color'))
}
