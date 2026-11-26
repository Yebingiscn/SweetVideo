import { SafeHeight } from '../../utils/ObservedUtil'

export const VIDEO_ALPHABET_INDEXER_WIDTH: number = 28

export interface VideoAlphabetIndexerParams {
  letters: string[]
  selected: number
  onSelect: (index: number) => void
  alignLeft: boolean
  topInset?: number
  offsetX?: number
  edgeMargin?: number
}

@Builder
export function VideoAlphabetIndexerBuilder($$: VideoAlphabetIndexerParams) {
  AlphabetIndexer({ arrayValue: $$.letters, selected: $$.selected })
    .onSelect((index: number) => {
      $$.onSelect(index)
    })
    .color($r('app.color.text_color'))
    .selectedColor($r('sys.color.white'))
    .popupColor($r('app.color.main_color'))
    .selectedBackgroundColor($r('app.color.main_color'))
    .popupBackground($r('app.color.start_window_background'))
    .itemSize(20)
    .width(VIDEO_ALPHABET_INDEXER_WIDTH)
    .autoCollapse(true)
    .offset({ x: $$.offsetX ?? 0 })
    .height(`calc(100% - ${($$.topInset ?? 0) + SafeHeight.bottomSafeHeight}vp)`)
    .margin({
      top: $$.topInset ?? 0,
      bottom: SafeHeight.bottomSafeHeight,
      left: $$.alignLeft ? ($$.edgeMargin ?? 2) : 0,
      right: $$.alignLeft ? 0 : ($$.edgeMargin ?? 2)
    })
}
