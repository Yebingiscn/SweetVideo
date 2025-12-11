import { MenuFancyModifier } from '../../common/AttributeModifierConfig';
import { IMenuItem } from '../../interfaces/IMenuItemInterface';
import ToolsUtil from '../../utils/ToolsUtil';
import { SymbolGlyphModifier } from '@kit.ArkUI';

class FolderMenus {
  menus: IMenuItem[] | undefined = undefined
}

@Builder
export function FolderSelectMenuBuilder(folderMenus: FolderMenus) {
  Menu() {
    ForEach(folderMenus?.menus, (item: IMenuItem, _index) => {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier(item.icon),
        content: item.content
      }).onClick(item.onAction)
    })
  }.attributeModifier(new MenuFancyModifier()).onAppear(() => {
    ToolsUtil.startVibration()
  })
}