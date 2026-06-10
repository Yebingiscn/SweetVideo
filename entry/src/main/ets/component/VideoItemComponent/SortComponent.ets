import { MenuFancyModifier } from '../../common/AttributeModifierConfig'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { SortField } from '../../common/enum/SortField'
import ToolsUtil from '../../utils/ToolsUtil'

@ComponentV2
export struct SortComponent {
  @Param currentSortField: SortField | '' = ''
  @Param currentSortAsc: boolean = true
  private sortByNameText: string = '按名称排序'
  private sortByDatetimeText: string = '按导入时间排序'
  private sortByTimeText: string = '按时长排序'
  @Event onSortByName: () => void = () => {
  }
  @Event onSortByTime: () => void = () => {
  }
  @Event onSortByDatetime: () => void = () => {
  }

  aboutToAppear(): void {
    this.sortByNameText = ToolsUtil.getStringResource($r('app.string.sort_by_name').id)
    this.sortByDatetimeText = ToolsUtil.getStringResource($r('app.string.sort_by_datetime').id)
    this.sortByTimeText = ToolsUtil.getStringResource($r('app.string.sort_by_time').id)
  }

  build() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat')),
        content: this.sortByNameText + this.getSortIndicator(SortField.NAME)
      })
        .onClick(() => {
          this.onSortByName()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.calendar')),
        content: this.sortByDatetimeText + this.getSortIndicator(SortField.DATETIME)
      })
        .onClick(() => {
          this.onSortByDatetime()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: this.sortByTimeText + this.getSortIndicator(SortField.TIME)
      })
        .onClick(() => {
          this.onSortByTime()
        })
    }.attributeModifier(new MenuFancyModifier())
  }

  private getSortIndicator(field: SortField): string {
    if (this.currentSortField === field) {
      return this.currentSortAsc ? ' ↑' : ' ↓'
    }
    return ''
  }
}
