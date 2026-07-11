import { MpvAudioChannelMode } from '../../controller/MpvController/MpvTypes'
import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'

class ChannelOption {
  mode: number = 0
  label: string = ''

  constructor(mode: number, label: string) {
    this.mode = mode
    this.label = label
  }
}

@ComponentV2
export struct AudioChannelComponent {
  private static readonly CHANNEL_OPTIONS: ChannelOption[] = [
    new ChannelOption(MpvAudioChannelMode.STEREO, '立体声'),
    new ChannelOption(MpvAudioChannelMode.LEFT_ONLY, '仅左'),
    new ChannelOption(MpvAudioChannelMode.RIGHT_ONLY, '仅右')
  ]
  @Consumer('player') player: PlayerControllerInterface =
    PlayerControllerFactory.createAVPlayerController() as PlayerControllerInterface
  @Event onSelect: (_mode: number) => void = () => {
  }

  build() {
    Row() {
      Repeat<ChannelOption>(AudioChannelComponent.CHANNEL_OPTIONS)
        .each((repeatItem: RepeatItem<ChannelOption>) => {
          Text(repeatItem.item.label)
            .fontSize(14)
            .height(32)
            .padding({ left: 8, right: 8 })
            .maxLines(1)
            .fontColor(this.player.audioChannelMode === repeatItem.item.mode ? $r('sys.color.white') :
              $r('app.color.text_color'))
            .backgroundColor(
              this.player.audioChannelMode === repeatItem.item.mode ? $r('app.color.main_color') : Color.Transparent)
            .borderRadius(16)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
            .onClick(() => {
              this.onSelect(repeatItem.item.mode)
            })
        })
        .key((item: ChannelOption) => item.label)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
    .alignItems(VerticalAlign.Center)
  }
}
