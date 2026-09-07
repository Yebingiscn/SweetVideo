import { ButtonFancyModifier } from '../../common/AttributeModifierConfig'
import { DIALOG_TITLE_FONT_SIZE } from '../../common/Constants'

@CustomDialog
export struct ImportSelectDialog {
  controller?: CustomDialogController
  onImportVideo?: () => void
  onImportAlbum?: () => void
  onImportMusic?: () => void

  build() {
    Column({ space: 16 }) {
      Text('导入')
        .fontSize(DIALOG_TITLE_FONT_SIZE)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })

      Column({ space: 10 }) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.resolution_video'))
              .fontSize(24)
              .fontColor([$r('app.color.text_color')])
            Text($r('app.string.import_from_videos'))
              .fontSize(16)
              .fontColor($r('app.color.text_color'))
              .layoutWeight(1)
          }.width('100%').padding({ left: 16, right: 16 })
        }
        .attributeModifier(new ButtonFancyModifier('100%', 52))
        .backgroundColor($r('sys.color.button_background_color_transparent'))
        .onClick(() => {
          this.controller?.close()
          if (this.onImportVideo) {
            this.onImportVideo()
          }
        })

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.picture_2'))
              .fontSize(24)
              .fontColor([$r('app.color.text_color')])
            Text($r('app.string.import_from_album'))
              .fontSize(16)
              .fontColor($r('app.color.text_color'))
              .layoutWeight(1)
          }.width('100%').padding({ left: 16, right: 16 })
        }
        .attributeModifier(new ButtonFancyModifier('100%', 52))
        .backgroundColor($r('sys.color.button_background_color_transparent'))
        .onClick(() => {
          this.controller?.close()
          if (this.onImportAlbum) {
            this.onImportAlbum()
          }
        })

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.music'))
              .fontSize(24)
              .fontColor([$r('app.color.text_color')])
            Text($r('app.string.import_from_music'))
              .fontSize(16)
              .fontColor($r('app.color.text_color'))
              .layoutWeight(1)
          }.width('100%').padding({ left: 16, right: 16 })
        }
        .attributeModifier(new ButtonFancyModifier('100%', 52))
        .backgroundColor($r('sys.color.button_background_color_transparent'))
        .onClick(() => {
          this.controller?.close()
          if (this.onImportMusic) {
            this.onImportMusic()
          }
        })
      }

      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Text($r('app.string.cancel'))
          .fontSize(16)
          .fontColor($r('app.color.text_color'))
          .fontWeight(FontWeight.Medium)
      }
      .attributeModifier(new ButtonFancyModifier('100%', 52))
      .backgroundColor($r('sys.color.button_background_color_transparent'))
      .onClick(() => this.controller?.close())
    }
    .padding(20)
    .width('100%')
  }
}