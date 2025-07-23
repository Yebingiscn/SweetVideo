import { FileFolder } from '../../interfaces/FileFolderInterface'
import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../utils/AttributeModifierUtil'
import { VideoListController } from '../VideoItemComponent/VideoItemComponent'

@Reusable
@Component
export struct FileFolderListComponent {
  @Prop folder: FileFolder
  @Link videoListController: VideoListController

  aboutToReuse(params: Record<string, Object>): void {
    this.folder = params.item as FileFolder;
  }

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row() {
        SymbolGlyph(this.videoListController.folder.name === this.folder?.name ?
        $r('sys.symbol.doc_plaintext_and_folder') : $r('sys.symbol.folder'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
        Text(this.folder.name)
          .fontSize(15)
          .margin({ left: 10, right: 12 })
      }
    }
    .align(Alignment.Start)
    .padding({ left: 15, right: 15 })
    .attributeModifier(new ButtonFancyModifier('100%', 60))
    .animation({ duration: 300, curve: Curve.Ease })
  }
}