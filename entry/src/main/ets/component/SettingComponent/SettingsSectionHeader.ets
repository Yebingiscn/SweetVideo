@Builder
export function SettingsSectionHeaderBuilder(title: ResourceStr, description?: ResourceStr) {
  Column({ space: 3 }) {
    Text(title)
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('sys.color.font_primary'))

    if (description !== undefined) {
      Text(description)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
    }
  }
  .alignItems(HorizontalAlign.Start)
  .width('100%')
  .padding({
    left: 6,
    right: 6,
    top: 14,
    bottom: 6
  })
}
