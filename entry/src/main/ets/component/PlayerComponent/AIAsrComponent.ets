import { AICaptionController, AICaptionOptions } from '@kit.SpeechKit';
import { AVPlayerController } from '../../controller/AVPlayerController';
import { MpvController } from '../../controller/MpvController/MpvController';

@Component
export struct AISubtitleComponent {
  @Link isAIAsrShown: boolean
  @Link showControl: boolean
  @Consume('player') player: AVPlayerController | MpvController
  private captionOption?: AICaptionOptions
  private controller: AICaptionController = new AICaptionController()

  aboutToAppear(): void {
    if (!this.captionOption) {
      this.captionOption = {
        initialOpacity: 0.5,
        onPrepared: () => {
          console.error('test AI字幕组件准备就绪')
        },
        onError: (error: BusinessError) => {
          console.error(`test AI字幕组件错误。错误码: ${error.code}, 消息: ${error.message}`)
        }
      }
    }
  }

  build() {
    if (this.isAIAsrShown) {
      if (canIUse('SystemCapability.AI.AICaption')) {
        Column() {
          AICaptionComponent({
            isShown: this.isAIAsrShown,
            controller: this.controller,
            options: this.captionOption
          })
            .width('100%')
            .height(80)
        }
        .justifyContent(FlexAlign.End)
        .width('75%')
        .height(80)
        .offset({
          x: 0,
          y: this.showControl ? this.player.screenHeight / 2 - 150 :
            this.player.screenHeight / 2 - 40
        })
      }
    }
  }
}
