@Component
export struct ImportProgress {
  @Prop current_import: number
  @Prop import_sum: number

  build() {
    Column() {
      Progress({ value: this.current_import, total: this.import_sum, type: ProgressType.Ring })
        .width(100)
        .height(100)
        .color($r('app.color.main_color'))
        .style({ strokeWidth: 15 })
        .margin({ bottom: 8 }) // 添加底部间距分隔文字
      Text(this.current_import + '/' + this.import_sum)
        .fontSize(16)
        .fontColor($r('app.color.main_color'))
    }
  }
}