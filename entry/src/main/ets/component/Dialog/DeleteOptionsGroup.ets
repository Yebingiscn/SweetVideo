import { DeleteType } from '../../common/enum/DeleteType'
import { DANGER_COLOR, DANGER_COLOR_ALPHA_15, WARNING_COLOR, WARNING_COLOR_ALPHA_15 } from '../../common/Constants'

@ComponentV2
export struct DeleteOptionsGroup {
  @Param deleteOption: 'soft' | 'hard' | 'recent' = 'soft'
  @Param permanentDeleteVisibility: boolean = false
  @Param moveToRecentVisibility: boolean = false
  @Event onOptionChange: (_option: 'soft' | 'hard' | 'recent') => void = () => {
  }
  @Event onConfirm: (_deleteType: DeleteType) => void = () => {
  }
  @Event onCancel: () => void = () => {
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Radio({ value: 'soft', group: 'deleteOptionsGroup' })
          .radioStyle({
            checkedBackgroundColor: $r('app.color.main_color')
          })
          .checked(this.deleteOption === 'soft')
          .onChange((checked: boolean) => {
            if (checked) {
              this.onOptionChange('soft')
            }
          })
          .width(20)
          .height(20)
        Column() {
          Text('仅从列表移除')
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .fontWeight(FontWeight.Medium)
          Text('文件保留在设备中，仅从应用列表移除')
            .fontSize(12)
            .fontColor($r('app.color.text_color'))
            .opacity(0.6)
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 8 })
      }
      .width('100%')
      .onClick(() => this.onOptionChange('soft'))

      if (this.permanentDeleteVisibility) {
        Row() {
          Radio({ value: 'hard', group: 'deleteOptionsGroup' })
            .radioStyle({
              checkedBackgroundColor: DANGER_COLOR
            })
            .checked(this.deleteOption === 'hard')
            .onChange((checked: boolean) => {
              if (checked) {
                this.onOptionChange('hard')
              }
            })
            .width(20)
            .height(20)
          Column() {
            Text('彻底删除文件')
              .fontSize(15)
              .fontColor(this.deleteOption === 'hard' ? DANGER_COLOR : $r('app.color.text_color'))
              .fontWeight(FontWeight.Medium)
            Text('文件将从设备中永久删除，不可恢复')
              .fontSize(12)
              .fontColor(DANGER_COLOR)
              .opacity(0.8)
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 8 })
        }
        .width('100%')
        .onClick(() => this.onOptionChange('hard'))
      }

      if (this.moveToRecentVisibility) {
        Row() {
          Radio({ value: 'recent', group: 'deleteOptionsGroup' })
            .radioStyle({
              checkedBackgroundColor: WARNING_COLOR
            })
            .checked(this.deleteOption === 'recent')
            .onChange((checked: boolean) => {
              if (checked) {
                this.onOptionChange('recent')
              }
            })
            .width(20)
            .height(20)
          Column() {
            Text('移至最近删除')
              .fontSize(15)
              .fontColor(this.deleteOption === 'recent' ? WARNING_COLOR : $r('app.color.text_color'))
              .fontWeight(FontWeight.Medium)
            Text('文件可在30天内从系统最近删除中恢复')
              .fontSize(12)
              .fontColor(WARNING_COLOR)
              .opacity(0.8)
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 8 })
        }
        .width('100%')
        .onClick(() => this.onOptionChange('recent'))
      }

      Row({ space: 20 }) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.xmark')).fontSize(16).fontColor([$r('app.color.text_color')])
            Text($r('app.string.cancel'))
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
              .fontWeight(FontWeight.Medium)
          }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .backgroundColor($r('sys.color.button_background_color_transparent'))
        .borderRadius(12)
        .height(36)
        .onClick(() => this.onCancel())

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.trash_fill'))
              .fontSize(16)
              .fontColor(this.getActionColor())
            Text($r('app.string.sure'))
              .fontSize(15)
              .fontColor(this.getActionTextColor())
              .fontWeight(FontWeight.Medium)
          }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .backgroundColor(this.getActionBgColor())
        .borderRadius(12)
        .height(36)
        .onClick(() => {
          let deleteType = DeleteType.SOFT
          if (this.deleteOption === 'hard') {
            deleteType = DeleteType.HARD
          } else if (this.deleteOption === 'recent') {
            deleteType = DeleteType.RECENT
          }
          this.onConfirm(deleteType)
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ bottom: 5 })
    }
    .width('100%')
    .padding({ left: 8, right: 8 })
  }

  private getActionTextColor(): ResourceColor {
    if (this.deleteOption === 'hard') {
      return DANGER_COLOR
    }
    if (this.deleteOption === 'recent') {
      return WARNING_COLOR
    }
    return $r('app.color.text_color')
  }

  private getActionColor(): ResourceColor[] {
    if (this.deleteOption === 'hard') {
      return [DANGER_COLOR]
    }
    if (this.deleteOption === 'recent') {
      return [WARNING_COLOR]
    }
    return [$r('app.color.text_color')]
  }

  private getActionBgColor(): ResourceColor {
    if (this.deleteOption === 'hard') {
      return DANGER_COLOR_ALPHA_15
    }
    if (this.deleteOption === 'recent') {
      return WARNING_COLOR_ALPHA_15
    }
    return $r('sys.color.button_background_color_transparent')
  }
}
