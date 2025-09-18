import { AudioTrack } from '../../interfaces/AudioTrackInterface'
import { ImageFancyModifier } from '../../utils/AttributeModifierUtil'
import { AudioTrackSource } from '../../utils/DataUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

@Component
export struct AudioTrackComponent {
  @State audioTrackDataSource: AudioTrackSource = new AudioTrackSource([])
  @Prop audioTrack: AudioTrack[]
  @Prop audioTrackSelected: number
  onSelect = (_index: number) => {
  }

  aboutToAppear(): void {
    this.audioTrackDataSource = new AudioTrackSource(this.audioTrack)
  }

  build() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      if (this.audioTrack.length === 0) {
        Row() {
          Text('实验性音轨解码')
            .fontSize(18)
            .height(40)
            .flexGrow(1)
            .flexShrink(1)
            .fontColor($r('app.color.main_color'))
            .margin({ left: 5 })
          Image($r('app.media.ffmpeg'))
            .attributeModifier(new ImageFancyModifier(10, 30, 30))
            .width(95)
        }
      }
      if (VideoOperateUtil.validateAudioTracks(this.audioTrack)) {
        LazyForEach(this.audioTrackDataSource, (item: AudioTrack, index: number) => {
          Row() { // 音轨
            Text(`${item.index} : ${item.name}(${VideoOperateUtil.getLanguageName(item.language)})`)
              .fontSize(18)
              .height(40)
              .flexGrow(1)
              .flexShrink(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(this.audioTrackSelected === index ? $r('app.color.main_color') : $r('app.color.text_color'))
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
        }, (item: AudioTrack) => item.name + item.index)
      }
    }.width(235)
  }
}