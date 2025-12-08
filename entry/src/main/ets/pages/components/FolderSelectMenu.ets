import { MenuFancyModifier } from "../../common/AttributeModifierConfig"
import ToolsUtil from "../../utils/ToolsUtil"
import { SymbolGlyphModifier } from "@kit.ArkUI"

export interface IMenuItem {
  icon: Resource
  content: ResourceStr
  onAction?: () => void
}

@Component
export struct FolderSelectMenu {
  @Prop menus: IMenuItem[]

  build() {
    Menu() {
      ForEach(this.menus, (item: IMenuItem, index) => {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier(item.icon),
          content: item.content
        }).onClick(item.onAction)
      })
    }.attributeModifier(new MenuFancyModifier()).onAppear(() => {
      ToolsUtil.startVibration()
    })
  }
}