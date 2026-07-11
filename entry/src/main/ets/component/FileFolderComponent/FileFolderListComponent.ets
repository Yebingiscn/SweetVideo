import { FileFolder } from '../../interfaces/FileFolderInterface'
import { VideoListController } from '../VideoItemComponent/VideoItemComponent'
import { FileFolderDataSource } from '../../utils/DataUtil'


class FileFolderListBuilderValue {
  folder: FileFolder | undefined = undefined
  videoListController: VideoListController | undefined = undefined
  fileFolderSource: FileFolderDataSource | undefined = undefined
  expandedFolderDates: Set<string> = new Set()
  onToggleExpand: ((folderDate: string) => void) | undefined = undefined
  depth: number = 0
  hasChildren: boolean = false
  isExpanded: boolean = false
}

@Builder
export function FileFolderListBuilder(fileFolderListBuilderValue: FileFolderListBuilderValue) {
  Row() {
    if (fileFolderListBuilderValue.folder && fileFolderListBuilderValue.depth > 0) {
      Row().width(fileFolderListBuilderValue.depth * 12)
    }
    if (fileFolderListBuilderValue.hasChildren) {
      SymbolGlyph(fileFolderListBuilderValue.isExpanded ?
        $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_right'))
        .fontSize(10)
        .fontColor([$r('sys.color.font_tertiary')])
        .animation({ duration: 200, curve: Curve.Ease })
        .onClick(() => {
          if (fileFolderListBuilderValue.onToggleExpand) {
            fileFolderListBuilderValue.onToggleExpand!(fileFolderListBuilderValue.folder!.date)
          }
        })
    } else {
      Row().width(10)
    }
    Row() {
      SymbolGlyph(fileFolderListBuilderValue.videoListController?.folder?.date ===
        fileFolderListBuilderValue.folder?.date ?
        $r('sys.symbol.doc_plaintext_and_folder') : $r('sys.symbol.folder'))
        .fontSize(22)
        .fontColor(fileFolderListBuilderValue.videoListController?.folder?.date ===
          fileFolderListBuilderValue.folder?.date ?
          [$r('app.color.main_color'), $r('app.color.text_color')] : [$r('sys.color.font_tertiary')])
    }
    .width(32)
    .height(32)
    .borderRadius(8)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .margin({ left: 4 })

    Column() {
      Text(fileFolderListBuilderValue.folder?.name)
        .width('100%')
        .fontColor(fileFolderListBuilderValue.videoListController?.folder?.date ===
          fileFolderListBuilderValue.folder?.date ?
          $r('app.color.main_color') : $r('app.color.text_color'))
        .fontSize(14)
        .fontWeight(fileFolderListBuilderValue.videoListController?.folder?.date ===
          fileFolderListBuilderValue.folder?.date ? FontWeight.Bold : FontWeight.Medium)
        .textAlign(TextAlign.Start)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.MARQUEE })
      if (fileFolderListBuilderValue.videoListController?.folder?.date === fileFolderListBuilderValue.folder?.date) {
        Text(fileFolderListBuilderValue.videoListController?.folder?.video_list.length === 0 ? `空空如也~` :
          `共 ${fileFolderListBuilderValue.videoListController?.folder?.video_list.length} 部视频`)
          .fontColor($r('app.color.main_color'))
          .fontSize(10)
          .textAlign(TextAlign.Start)
          .width('100%')
          .textOverflow({ overflow: TextOverflow.MARQUEE })
      }
    }
    .margin({ left: 4 })
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)

  }
  .width('100%')
  .alignItems(VerticalAlign.Center)
  .padding({ left: 8, right: 8 })
  .height(44)
  .borderRadius(10)
  .animation({ duration: 300, curve: Curve.Ease })
}