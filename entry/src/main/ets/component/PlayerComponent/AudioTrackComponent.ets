import { AudioTrack } from '../../interfaces/AudioTrackInterface'
import { ImageFancyModifier } from '../../utils/AttributeModifierUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

@Component
export struct AudioTrackComponent {
  @Prop audio_track: AudioTrack[]
  @Prop audio_track_select: number
  onSelect = (index: number) => {
    console.log('select: ' + index)
  }

  build() {
    if (VideoOperateUtil.audioTrackErrorExecute(this.audio_track)) {
      Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
        ForEach(this.audio_track, (item: AudioTrack, index: number) => {
          Row() { // 音轨
            Text(`${item.index} : ${item.name}(${VideoOperateUtil.getLanguageName(item.language)})`)
              .fontSize(18)
              .height(40)
              .flexGrow(1)
              .flexShrink(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(this.audio_track_select === index ? $r('app.color.main_color') : $r('app.color.text_color'))
              .margin({ left: 5 })
            if (item.mime.split('/')[1] === 'av3a') {
              Image($r('app.media.audio_vivid_icon'))
                .attributeModifier(new ImageFancyModifier(10, 85, 30))
                .width(95)
            }
          }
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .width('100%')
          .onClick(() => {
            this.onSelect(index)
          })
        })
      }.width(235)
    }
  }
}