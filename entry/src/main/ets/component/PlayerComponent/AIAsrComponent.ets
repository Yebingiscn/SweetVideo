import { AICaptionComponent, AICaptionController, AICaptionOptions } from '@kit.SpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';

@Component
export struct AISubtitleComponent {
  @Link isAIAsrShown: boolean
  @Link showControl: boolean
  @Prop screenWidth: number
  @Prop screenHeight: number
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
    if (this.showControl) {
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
        .visibility(this.showControl ? Visibility.None : Visibility.Visible)
        .width('80%')
        .height(80)
        .offset({
          x: 0,
          y: this.screenWidth > this.screenHeight ? this.screenHeight / 2 - 40 :
            this.screenHeight / 2 - 100
        })
      }
    }
  }
}
