import { SymbolGlyphModifier } from '@kit.ArkUI'

@Component
export struct VideoSettingComponent {
  @Link circlePlay: boolean
  @State repeatMode: string = '列表循环'
  onMirrorClick = () => {
  }

  build() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r("sys.symbol.trapezoid_and_line_vertical")),
        content: '屏幕镜像'
      }).onClick(() => {
        this.onMirrorClick()
      })
      MenuItem({
        symbolStartIcon: this.circlePlay ? new SymbolGlyphModifier($r('sys.symbol.repeat_1')) :
          new SymbolGlyphModifier($r('sys.symbol.order_play')),
        content: this.repeatMode
      })
        .onClick(() => {
          this.circlePlay = !this.circlePlay
          this.circlePlay ? this.repeatMode = '单曲循环' : this.repeatMode = '列表循环'
        })
    }.onAppear(() => {
      this.circlePlay ? this.repeatMode = '单曲循环' : this.repeatMode = '列表循环'
    })
  }
}