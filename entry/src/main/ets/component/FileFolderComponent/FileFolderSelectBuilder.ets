import { MenuFancyModifier } from '../../common/AttributeModifierConfig'
import { IMenuItem } from '../../interfaces/IMenuItemInterface'
import ToolsUtil from '../../utils/ToolsUtil'
import { SymbolGlyphModifier } from '@kit.ArkUI'

@Builder
export function FolderSelectMenuBuilder(menus: IMenuItem[]) {
  Menu() {
    Repeat<IMenuItem>(menus)
      .each((repeatItem: RepeatItem<IMenuItem>) => {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier(repeatItem.item.icon),
          content: repeatItem.item.content
        }).onClick(repeatItem.item.onAction)
      })
      .key((item: IMenuItem, _index: number) => item.content as string)
  }.attributeModifier(new MenuFancyModifier()).onAppear(() => {
    ToolsUtil.startVibration()
  })
}