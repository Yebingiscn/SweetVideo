@Component
export struct ImportProgressComponent {
  @Prop processedItems: number
  @Prop totalItems: number

  build() {
    Column() {
      Progress({ value: this.processedItems, total: this.totalItems, type: ProgressType.Ring })
        .width(100)
        .height(100)
        .color($r('app.color.main_color'))
        .style({ strokeWidth: 15 })
        .margin({ bottom: 8 }) // 添加底部间距分隔文字
      Text(this.processedItems + '/' + this.totalItems)
        .fontSize(16)
        .fontColor($r('app.color.main_color'))
    }.animation({ duration: 150, curve: Curve.Sharp })
  }
}