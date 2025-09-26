import { FileFolder } from '../../interfaces/FileFolderInterface'
import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../utils/AttributeModifierUtil'
import { VideoListController } from '../VideoItemComponent/VideoItemComponent'

@Reusable
@Component
export struct FileFolderListComponent {
  @Prop folder: FileFolder
  @Link videoListController: VideoListController

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row() {
        SymbolGlyph(this.videoListController.folder.name === this.folder?.name ?
          $r('sys.symbol.doc_plaintext_and_folder') : $r('sys.symbol.folder'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
        Column() {
          Text(this.folder?.name)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .fontSize(this.videoListController.folder.name === this.folder?.name ? 18 : 15)
            .textAlign(TextAlign.Start)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
          if (this.videoListController.folder.name === this.folder?.name) {
            Text(this.videoListController.folder.video_list.length === 0 ? `空空如也~` :
              `共 ${this.videoListController.folder.video_list.length} 部视频`)
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
}