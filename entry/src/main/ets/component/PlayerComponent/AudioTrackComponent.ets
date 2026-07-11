import { AudioTrack } from '../../interfaces/AudioTrackInterface'
import { AudioTrackSource } from '../../utils/DataUtil'
import { MpvAudioTrack } from '../../controller/MpvController/MpvTypes'
import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import { MpvController } from '../../controller/MpvController/MpvController'
import { ButtonFancyModifier } from '../../common/AttributeModifierConfig'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { AudioChannelComponent } from './AudioChannelComponent'

// 定义联合类型
type TrackType = AudioTrack | MpvAudioTrack

@ComponentV2
export struct AudioTrackComponent {
  private static readonly CHANNEL_MAP: Record<number, string> = {
    1: 'Mono',
    2: '2.0',
    3: '2.1',
    4: '3.1',
    5: '4.0',
    6: '5.1',
    7: '6.1',
    8: '7.1',
    10: '5.1.4',
    12: '7.1.4'
  }
  @Local audioTrackDataSource: AudioTrackSource = new AudioTrackSource([])
  @Consumer('player') player: PlayerControllerInterface =
    PlayerControllerFactory.createAVPlayerController() as PlayerControllerInterface
  @Event onSelect: (_index: number) => void = () => {
  }

  isCurrentTrackStereo(): boolean {
    if (this.player instanceof MpvController) {
      const selectedIdx = this.player.audioTrackSelected
      if (selectedIdx >= 0 && selectedIdx < this.player.audioTrack.length) {
        return this.player.audioTrack[selectedIdx].channels === 2
      }
    }
    return false
  }

  aboutToAppear(): void {
    this.audioTrackDataSource = new AudioTrackSource(this.player.audioTrack)
  }

  // 检查是否是 AudioTrack
  isAudioTrack(item: TrackType): boolean {
    const track = item as AudioTrack
    return track.index != undefined && track.language != undefined
  }

  // 检查是否是 MpvAudioTrack
  isMpvAudioTrack(item: TrackType): boolean {
    const track = item as MpvAudioTrack
    return track.id != undefined && track.lang != undefined
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

  getFormattedTrackName(item: TrackType): string {
    const langName = this.getLanguageName(item)
    if (this.isMpvAudioTrack(item)) {
      const track = item as MpvAudioTrack
      const parts: string[] = []
      if (track.title) {
        parts.push(track.title)
      }
      if (track.channels) {
        parts.push(AudioTrackComponent.CHANNEL_MAP[track.channels] ?? `${track.channels}ch`)
      }
      if (langName) {
        parts.push(langName)
      }
      return parts.length > 0 ? parts.join(' · ') : `Track ${track.id}`
    }
    if (this.isAudioTrack(item)) {
      const track = item as AudioTrack
      const parts: string[] = []
      if (track.name) {
        parts.push(track.name)
      }
      if (track.channelCount) {
        parts.push(AudioTrackComponent.CHANNEL_MAP[track.channelCount] ?? `${track.channelCount}ch`)
      }
      if (langName) {
        parts.push(langName)
      }
      return parts.length > 0 ? parts.join(' · ') : `Track ${track.index}`
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
    Column() {
      Repeat<TrackType>(this.audioTrackDataSource.data)
        .each((repeatItem: RepeatItem<TrackType>) => {
          Row() {
            Text(`${this.getTrackIndex(repeatItem.item)} : ${this.getFormattedTrackName(repeatItem.item)}`)
              .fontSize(18)
              .height(40)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.MARQUEE })
              .fontColor(this.player.audioTrackSelected === repeatItem.index ? $r('sys.color.white') :
                $r('app.color.text_color'))

            if (this.shouldShowAv3aIcon(repeatItem.item)) {
              Row() {
                SymbolGlyph($r('sys.symbol.hdr'))
                  .fontSize(14)
                  .fontColor([$r('sys.color.white')])

                Text('AUDIO Vivid')
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.white'))  // 文字固定黑色，确保高对比
                  .margin({ left: 2 }) // 图标与文字间距
              }
              .padding({
                left: 5,
                right: 5,
                top: 2,
                bottom: 2
              })
              .linearGradient({
                direction: GradientDirection.Right, // 渐变方向
                repeating: false,
                colors: [['#ef2f4e', 0.0], ['#d53b61', 0.3], ['#954e89', 0.5], ['#4766bd', 0.7],
                  ['#1677dc', 0.9]]
              })
              .borderRadius(8)
              .alignItems(VerticalAlign.Center)
              .width('auto')
              .height(22)
            }
          }
          .padding({
            left: 8,
            right: 8,
            top: 4,
            bottom: 4
          })
          .width('100%')
          .backgroundColor(
            this.player.audioTrackSelected === repeatItem.index ? $r('app.color.main_color') : Color.Transparent)
          .borderRadius(16)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .onClick(() => {
            this.onSelect(repeatItem.index ?? 0)
          })
        })
        .key((item: TrackType, _index: number) => this.getKey(item))
      if (this.isCurrentTrackStereo()) {
        AudioChannelComponent({
          onSelect: (mode: number) => {
            if (this.player instanceof MpvController) {
              this.player.setAudioChannelMode(mode)
            }
          }
        }).padding({ top: 8 })
      }
      Row() {
        Text('响度')
          .fontSize(16)
          .fontColor($r('app.color.text_color'))
          .width(35)
        Slider({
          value: this.player.volumeLoudnessGain,
          min: -90,
          max: 24,
          step: 1,
          style: SliderStyle.NONE
        })
          .onChange((value) => {
            this.player.setLoudnessGain(value)
          })
          .selectedColor($r('app.color.main_color'))
          .enableHapticFeedback(true)
          .layoutWeight(1)
          .trackBorderRadius(16)
          .selectedColor($r('app.color.main_color'))
          .enableHapticFeedback(true)
          .trackThickness(20)
          .selectedBorderRadius(16)
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.undo'))
            .fontSize(16)
            .fontColor([$r('app.color.text_color')])
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .attributeModifier(new ButtonFancyModifier(28, 28))
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.player.setLoudnessGain(0)
        })
      }
      .padding({
        left: 8,
        right: 8,
        top: 4,
        bottom: 4
      })
      .width('100%')
    }
    .width(235)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}