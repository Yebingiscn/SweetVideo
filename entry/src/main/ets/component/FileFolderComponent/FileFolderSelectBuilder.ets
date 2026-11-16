import { MenuFancyModifier } from '../../common/AttributeModifierConfig'
import { IMenuItem } from '../../interfaces/IMenuItemInterface'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import BluRayDirectory from '../../utils/BluRayDirectory'
import ToolsUtil from '../../utils/ToolsUtil'

@Builder
export function FolderSelectMenuBuilder(menus: IMenuItem[]) {
  Menu() {
    Repeat<IMenuItem>(menus)
      .each((repeatItem: RepeatItem<IMenuItem>) => {
        MenuItem({
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
      content: ToolsUtil.getStringResource($r('app.string.play_bluray').id) + ' · ' + item.title,
      onAction: () => onPlayDisc(item, folder.video_list)
    }))
  items.push({
    content: $r('app.string.multiple_choice'),
    onAction: onSelect
  }, {
    content: $r('app.string.menu_intro_outro'),
    onAction: () => actions.run(FolderMenuAction.INTRO_OUTRO, folder)
  })
  if (folder.name !== '首页') {
    items.push({
      content: $r('app.string.delete'),
      onAction: () => actions.run(FolderMenuAction.DELETE, folder)
    }, {
      content: $r('app.string.edit'),
      shortcut: 'F2',
      onAction: () => actions.run(FolderMenuAction.EDIT, folder)
    }, {
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
      content: $r('app.string.cancel'),
      onAction: onCancel
    }])
  } else {
    FolderSelectMenuBuilder(folderMenuItems(folder, actions, onSelect, onPlayDisc))
  }
}
