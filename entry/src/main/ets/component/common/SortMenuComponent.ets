import { MenuFancyModifier } from '../../common/AttributeModifierConfig'
import { SortField } from '../../common/enum/SortField'
import ToolsUtil from '../../utils/ToolsUtil'

export interface SortMenuItem {
  field: SortField
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
          content: ToolsUtil.getStringResource(ri.item.textResource.id) + this.getSortIndicator(ri.item.field)
        })
          .contentFontColor(this.currentSortField === ri.item.field ? $r('sys.color.white') :
            $r('app.color.text_color'))
          .backgroundColor(this.currentSortField === ri.item.field ? $r('app.color.main_color') : Color.Transparent)
          .height(40)
          .margin({ top: 2, bottom: 2 })
          .borderRadius(16)
          .onClick(() => {
            ri.item.onAction()
          })
      }).key((item: SortMenuItem) => item.field)
      if (this.currentSortField === this.pinyinSortField) {
        MenuItem({
          content: this.pinyinSortText
        })
          .contentFontColor(this.pinyinSort ? $r('sys.color.white') : $r('app.color.text_color'))
          .backgroundColor(this.pinyinSort ? $r('app.color.main_color') : Color.Transparent)
          .height(40)
          .margin({ top: 2, bottom: 2 })
          .borderRadius(16)
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