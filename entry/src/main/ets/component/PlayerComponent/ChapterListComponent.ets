import { MpvController } from '../../controller/MpvController/MpvController'
import { AVPlayerController } from '../../controller/AVPlayerController/AVPlayerController'
import { MpvChapter } from '../../controller/MpvController/MpvTypes'
import TimeUtil from '../../utils/TimeUtil'

@ComponentV2
export struct ChapterListComponent {
  @Consumer('player') player: AVPlayerController | MpvController = new AVPlayerController()
  @Event onSelect: (_index: number) => void = () => {
  }

  build() {
    Column() {
      if (this.player instanceof MpvController && this.player.chapterList.length > 0) {
        Repeat<MpvChapter>(this.player.chapterList)
          .each((repeatItem: RepeatItem<MpvChapter>) => {
            Row() {
              Text(repeatItem.item.title)
                .fontSize(14)
                .fontColor($r('app.color.text_color'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)

              Text(TimeUtil.convertSSToHHMMSS(repeatItem.item.time))
                .fontSize(12)
                .fontColor($r('app.color.text_color'))
                .opacity(0.8)
                .margin({ left: 8 })
            }
            .width('100%')
            .height(40)
            .padding({ left: 12, right: 12 })
            .borderRadius(12)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
            .onClick(() => {
              this.onSelect(repeatItem.item.index)
            })
          })
          .key((item: MpvChapter) => item.index.toString() + item.title)
      } else {
        Text('无章节信息')
          .fontSize(14)
          .fontColor($r('app.color.text_color'))
          .opacity(0.5)
          .padding(12)
      }
    }
    .width(235)
  }
}
