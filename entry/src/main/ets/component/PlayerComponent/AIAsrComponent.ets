import { AICaptionComponent, AICaptionController, AICaptionOptions } from '@kit.SpeechKit';
import { salmonLogger } from 'salmonlogger';
import { AVPlayerController } from '../../controller/AVPlayerController';
import { MpvController } from '../../controller/MpvController/MpvController';

const TAG = 'AIAsrComponent'

@Component
export struct AISubtitleComponent {
  @Link isAIAsrShown: boolean
  @Consume('player') player: AVPlayerController | MpvController
  private captionOption?: AICaptionOptions
  private controller: AICaptionController = new AICaptionController()

  aboutToAppear(): void {
    if (!this.captionOption) {
      this.captionOption = {
        initialOpacity: 0.5,
        onPrepared: () => {
          salmonLogger.addLog(TAG, 'test AI字幕组件准备就绪', true)
        },
        onError: (error: BusinessError) => {
          salmonLogger.addLog(TAG, `test AI字幕组件错误。错误码: ${error.code}, 消息: ${error.message}`, true)
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
          y: this.player.showControl ? this.player.screenHeight / 2 - 150 :
            this.player.screenHeight / 2 - 40
        })
      }
    }
  }
}
