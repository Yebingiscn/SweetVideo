import { MenuFancyModifier } from '../../common/AttributeModifierConfig'
import { IMenuItem } from '../../interfaces/IMenuItemInterface'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import BluRayDirectory from '../../utils/BluRayDirectory'
import ToolsUtil from '../../utils/ToolsUtil'
import { SymbolGlyphModifier } from '@kit.ArkUI'

@Builder
export function FolderSelectMenuBuilder(menus: IMenuItem[]) {
  Menu() {
    Repeat<IMenuItem>(menus)
      .each((repeatItem: RepeatItem<IMenuItem>) => {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier(repeatItem.item.icon),
          content: repeatItem.item.content,
          labelInfo: repeatItem.item.shortcut
        }).onClick(repeatItem.item.onAction)
      })
      .key((item: IMenuItem) => item.key ?? (item.content as string))
  }.attributeModifier(new MenuFancyModifier()).onAppear(() => {
    ToolsUtil.startVibration()
  })
}

export enum FolderMenuAction {
  EDIT,
  MOVE,
  INTRO_OUTRO,
  DELETE
}

@ObservedV2
export class FolderMenuActions {
  @Trace deleting: boolean = false
  run: (action: FolderMenuAction, folder: FileFolder) => void = () => {}
  playDisc: (item: VideoMetadata, list: VideoMetadata[]) => Promise<void> = async () => {}
  confirmDelete: (dates: string[], onDeleted: () => void) => void = () => {}
}

function folderMenuItems(folder: FileFolder, actions: FolderMenuActions, onSelect: () => void,
  onPlayDisc: (item: VideoMetadata, list: VideoMetadata[]) => Promise<void>): IMenuItem[] {
  const items = folder.video_list.filter(video => BluRayDirectory.isEntry(video.uri))
    .map((item: VideoMetadata): IMenuItem => ({
      key: 'bluray:' + item.date,
      icon: $r('sys.symbol.play'),
      content: ToolsUtil.getStringResource($r('app.string.play_bluray').id) + ' · ' + item.title,
      onAction: () => onPlayDisc(item, folder.video_list)
    }))
  items.push({
    icon: $r('sys.symbol.checkmark_square'),
    content: $r('app.string.multiple_choice'),
    onAction: onSelect
  }, {
    icon: $r('sys.symbol.time_lapse'),
    content: $r('app.string.menu_intro_outro'),
    onAction: () => actions.run(FolderMenuAction.INTRO_OUTRO, folder)
  })
  if (folder.name !== '首页') {
    items.push({
      icon: $r('sys.symbol.trash_fill'),
      content: $r('app.string.delete'),
      onAction: () => actions.run(FolderMenuAction.DELETE, folder)
    }, {
      icon: $r('sys.symbol.rename'),
      content: $r('app.string.edit'),
      shortcut: 'F2',
      onAction: () => actions.run(FolderMenuAction.EDIT, folder)
    }, {
      icon: $r('sys.symbol.arrow_right_folder_circle'),
      content: $r('app.string.move_folder'),
      onAction: () => actions.run(FolderMenuAction.MOVE, folder)
    })
  }
  return items
}

@Builder
export function FolderContextMenu(folder: FileFolder, actions: FolderMenuActions, selecting: boolean,
  onSelect: () => void, onCancel: () => void,
  onPlayDisc: (item: VideoMetadata, list: VideoMetadata[]) => Promise<void>) {
  if (selecting) {
    FolderSelectMenuBuilder([{
      icon: $r('sys.symbol.xmark'),
      content: $r('app.string.cancel'),
      onAction: onCancel
    }])
  } else {
    FolderSelectMenuBuilder(folderMenuItems(folder, actions, onSelect, onPlayDisc))
  }
}
