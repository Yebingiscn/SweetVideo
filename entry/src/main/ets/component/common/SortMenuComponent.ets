import { MenuFancyModifier } from '../../common/AttributeModifierConfig'
import { SortField } from '../../common/enum/SortField'
import ToolsUtil from '../../utils/ToolsUtil'
import { SymbolGlyphModifier } from '@kit.ArkUI'

export interface SortMenuItem {
  field: SortField
  icon: Resource
  textResource: Resource
  onAction: () => void
}

@ComponentV2
export struct SortMenuComponent {
  @Param currentSortField: SortField | '' = ''
  @Param currentSortAsc: boolean = true
  @Param pinyinSort: boolean = true
  @Param pinyinSortField: SortField = SortField.NAME
  @Param items: SortMenuItem[] = []
  private pinyinSortText: string = '中英文混合排序'
  @Event onPinyinSortChange: (value: boolean) => void = () => {
  }

  aboutToAppear(): void {
    this.pinyinSortText = ToolsUtil.getStringResource($r('app.string.pinyin_sort').id)
  }

  build() {
    Menu() {
      Repeat(this.items).each((ri) => {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier(ri.item.icon),
          content: ToolsUtil.getStringResource(ri.item.textResource.id) + this.getSortIndicator(ri.item.field)
        })
          .onClick(() => {
            ri.item.onAction()
          })
      }).key((item: SortMenuItem) => item.field)
      if (this.currentSortField === this.pinyinSortField) {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.translate')),
          content: this.pinyinSortText + (this.pinyinSort ? ' ✓' : '')
        })
          .onClick(() => {
            this.onPinyinSortChange(!this.pinyinSort)
          })
      }
    }.attributeModifier(new MenuFancyModifier())
  }

  private getSortIndicator(field: SortField): string {
    if (this.currentSortField === field) {
      return this.currentSortAsc ? ' ↑' : ' ↓'
    }
    return ''
  }
}