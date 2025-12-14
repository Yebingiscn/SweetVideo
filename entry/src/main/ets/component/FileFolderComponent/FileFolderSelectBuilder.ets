import { MenuFancyModifier } from '../../common/AttributeModifierConfig';
import { IMenuItem } from '../../interfaces/IMenuItemInterface';
import ToolsUtil from '../../utils/ToolsUtil';
import { SymbolGlyphModifier } from '@kit.ArkUI';

@Builder
export function FolderSelectMenuBuilder(menus: IMenuItem[]) {
  Menu() {
    ForEach(menus, (item: IMenuItem, _index: number) => {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier(item.icon),
        content: item.content
      }).onClick(item.onAction)
    })
  }.attributeModifier(new MenuFancyModifier()).onAppear(() => {
    ToolsUtil.startVibration()
  })
}