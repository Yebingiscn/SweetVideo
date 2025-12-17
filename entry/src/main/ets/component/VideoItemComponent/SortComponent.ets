import { MenuFancyModifier } from '../../common/AttributeModifierConfig'
import { SymbolGlyphModifier } from '@kit.ArkUI'

@Component
export struct SortComponent {
  onSortByName = () => {
  }
  onSortByTime = () => {
  }
  onSortByDatetime = () => {
  }

  build() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat')),
        content: $r('app.string.sort_by_name')
      })
        .onClick(() => {
          this.onSortByName()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.calendar')),
        content: $r('app.string.sort_by_datetime')
      })
        .onClick(() => {
          this.onSortByDatetime()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: $r('app.string.sort_by_time')
      })
        .onClick(() => {
          this.onSortByTime()
        })
    }.attributeModifier(new MenuFancyModifier())
  }
}