interface GradientTagParams {
  symbol?: Resource
  label?: ResourceStr
  marginBottom?: number
  marginLeft?: number
  marginRight?: number
  height?: number
  paddingH?: number
}

interface SolidColorTagParams {
  symbol?: Resource
  label?: ResourceStr
  symbolSize?: number
  textColor?: Resource
  bgColor?: ResourceStr
  marginBottom?: number
  marginLeft?: number
  marginRight?: number
  height?: number
  opacity?: number
  paddingH?: number
}

@Builder
export function GradientTagBuilder($$: GradientTagParams) {
  Row() {
    SymbolGlyph($$.symbol ?? $r('sys.symbol.hdr'))
      .fontSize(14)
      .fontColor([$r('sys.color.white')])
    Text($$.label ?? '')
      .fontSize(10)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('sys.color.white'))
      .margin({ left: 2 })
  }
  .padding({ left: $$.paddingH ?? 6, right: $$.paddingH ?? 6, top: 2, bottom: 2 })
  .linearGradient({
    direction: GradientDirection.Right,
    repeating: false,
    colors: [['#ef2f4e', 0.0], ['#d53b61', 0.3], ['#954e89', 0.5], ['#4766bd', 0.7], ['#1677dc', 0.9]]
  })
  .borderRadius(8)
  .alignItems(VerticalAlign.Center)
  .height($$.height ?? 20)
  .margin({ left: $$.marginLeft ?? 0, right: $$.marginRight ?? 4, bottom: $$.marginBottom ?? 4 })
}

@Builder
export function SolidColorTagBuilder($$: SolidColorTagParams) {
  Row() {
    if ($$.symbol) {
      SymbolGlyph($$.symbol)
        .fontSize($$.symbolSize ?? 14)
        .fontColor([$$.textColor ?? $r('sys.color.white')])
    }
    Text($$.label ?? '')
      .fontSize(10)
      .fontWeight(FontWeight.Bold)
      .fontColor($$.textColor ?? $r('sys.color.white'))
      .margin({ left: $$.symbol ? 2 : 0 })
  }
  .padding({ left: $$.paddingH ?? 6, right: $$.paddingH ?? 6, top: 2, bottom: 2 })
  .backgroundColor($$.bgColor ?? $r('sys.color.black'))
  .borderRadius(8)
  .alignItems(VerticalAlign.Center)
  .justifyContent($$.symbol ? FlexAlign.Start : FlexAlign.Center)
  .height($$.height ?? 20)
  .margin({ left: $$.marginLeft ?? 0, right: $$.marginRight ?? 4, bottom: $$.marginBottom ?? 4 })
  .opacity($$.opacity ?? 1)
}
