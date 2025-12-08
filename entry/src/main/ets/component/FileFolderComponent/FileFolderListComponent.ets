import { FileFolder } from '../../interfaces/FileFolderInterface'
import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import { VideoListController } from '../VideoItemComponent/VideoItemComponent'

class FileFolderListBuilderValue {
  folder: FileFolder | undefined = undefined
  videoListController: VideoListController | undefined = undefined
}

@Builder
export function FileFolderListBuilder(fileFolderListBuilderValue: FileFolderListBuilderValue) {
  Button({ type: ButtonType.Normal, stateEffect: true }) {
    Row() {
      SymbolGlyph(fileFolderListBuilderValue.videoListController?.folder.name ===
        fileFolderListBuilderValue.folder?.name ?
        $r('sys.symbol.doc_plaintext_and_folder') : $r('sys.symbol.folder'))
        .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
        .fontColor(fileFolderListBuilderValue.videoListController?.folder.name ===
          fileFolderListBuilderValue.folder?.name ?
          [$r('app.color.main_color'), $r('app.color.text_color')] : [$r('app.color.text_color')])
      Column() {
        Text(fileFolderListBuilderValue.folder?.name)
          .width('100%')
          .fontColor(fileFolderListBuilderValue.videoListController?.folder.name ===
            fileFolderListBuilderValue.folder?.name ?
            $r('app.color.main_color') : $r('app.color.text_color'))
          .fontSize(fileFolderListBuilderValue.videoListController?.folder.name ===
            fileFolderListBuilderValue.folder?.name ? 18 : 15)
          .fontWeight(fileFolderListBuilderValue.videoListController?.folder.name ===
            fileFolderListBuilderValue.folder?.name ? FontWeight.Bold :
            FontWeight.Medium)
          .textAlign(TextAlign.Start)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
        if (fileFolderListBuilderValue.videoListController?.folder?.name === fileFolderListBuilderValue.folder?.name) {
          Text(fileFolderListBuilderValue.videoListController?.folder?.video_list.length === 0 ? `空空如也~` :
            `共 ${fileFolderListBuilderValue.videoListController?.folder?.video_list.length} 部视频`)
            .fontColor($r('app.color.main_color'))
            .fontSize(12)
            .textAlign(TextAlign.Start)
            .width('100%')
            .textOverflow({ overflow: TextOverflow.MARQUEE })
        }
      }
      .margin({ left: 5 })
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
  .align(Alignment.Start)
  .padding({ left: 15, right: 15 })
  .attributeModifier(new ButtonFancyModifier('100%', 60))
  .animation({ duration: 300, curve: Curve.Ease })
}