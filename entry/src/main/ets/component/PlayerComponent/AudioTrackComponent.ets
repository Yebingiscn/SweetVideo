import { AudioTrack } from '../../interfaces/AudioTrackInterface'
import { ImageFancyModifier } from '../../common/AttributeModifierConfig'
import { AudioTrackSource } from '../../utils/DataUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { MpvAudioTrack } from '../../controller/MpvController/MpvTypes'

// 定义联合类型
type TrackType = AudioTrack | MpvAudioTrack

@Component
export struct AudioTrackComponent {
  @State audioTrackDataSource: AudioTrackSource = new AudioTrackSource([])
  @Prop audioTrack: TrackType[]
  @Link audioTrackSelected: number
  onSelect = (_index: number) => {
  }

  aboutToAppear(): void {
    this.audioTrackDataSource = new AudioTrackSource(this.audioTrack)
  }

  // 检查是否是 AudioTrack
  isAudioTrack(item: TrackType): boolean {
    const track = item as AudioTrack
    return track.index !== undefined && track.language !== undefined
  }

  // 检查是否是 MpvAudioTrack
  isMpvAudioTrack(item: TrackType): boolean {
    const track = item as MpvAudioTrack
    return track.id !== undefined && track.lang !== undefined
  }

  // 获取轨道索引
  getTrackIndex(item: TrackType): number {
    if (this.isAudioTrack(item)) {
      return (item as AudioTrack).index
    } else if (this.isMpvAudioTrack(item)) {
      return (item as MpvAudioTrack).id
    }
    return 0
  }

  // 获取轨道名称
  getTrackName(item: TrackType): string {
    if (this.isAudioTrack(item)) {
      return (item as AudioTrack).name
    } else if (this.isMpvAudioTrack(item)) {
      return (item as MpvAudioTrack).title
    }
    return ''
  }

  // 获取轨道语言
  getTrackLanguage(item: TrackType): string {
    if (this.isAudioTrack(item)) {
      return (item as AudioTrack).language
    } else if (this.isMpvAudioTrack(item)) {
      return (item as MpvAudioTrack).lang
    }
    return ''
  }

  // 获取轨道语言名称
  getLanguageName(item: TrackType): string {
    const language = this.getTrackLanguage(item)
    return VideoOperateUtil.getLanguageName(language)
  }

  // 检查是否显示 AV3A 图标
  shouldShowAv3aIcon(item: TrackType): boolean {
    if (this.isAudioTrack(item)) {
      const track = item as AudioTrack
      return track?.mime?.split('/')[1] === 'av3a'
    }
    return false
  }

  // 获取唯一键
  getKey(item: TrackType): string {
    if (this.isAudioTrack(item)) {
      const track = item as AudioTrack
      return track.name + track.index
    } else if (this.isMpvAudioTrack(item)) {
      const track = item as MpvAudioTrack
      return track.title + track.id
    }
    return ''
  }

  build() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      LazyForEach(this.audioTrackDataSource, (item: TrackType, index: number) => {
        Row() { // 音轨
          Text(`${this.getTrackIndex(item)} : ${this.getTrackName(item)}(${this.getLanguageName(item)})`)
            .fontSize(18)
            .height(40)
            .flexGrow(1)
            .flexShrink(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(this.audioTrackSelected === index ? $r('sys.color.white') :
              $r('app.color.text_color'))
            .margin({ left: 5 })
          if (this.shouldShowAv3aIcon(item)) {
            Image($r('app.media.audio_vivid_icon'))
              .attributeModifier(new ImageFancyModifier(8, 85, 30))
              .width(95)
          }
        }
        .backgroundColor(this.audioTrackSelected === index ? $r('app.color.main_color') : '')
        .borderRadius(16)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .width('100%')
        .onClick(() => {
          this.onSelect(index)
        })
      }, (item: TrackType) => this.getKey(item))
    }.width(235)
  }
}