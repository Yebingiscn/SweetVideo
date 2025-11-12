import { AICaptionComponent, AICaptionController, AICaptionOptions } from '@kit.SpeechKit';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';

@Component
export struct AIAsr {
  @State isShown: boolean = false;
  private captionOption?: AICaptionOptions;
  private controller: AICaptionController = new AICaptionController();

  aboutToAppear(): void {
    this.captionOption = {
      initialOpacity: 0.5,
      onPrepared: () => {
        console.info('AI字幕组件准备就绪')
      },
      onError: (error: BusinessError) => {
        console.error(`AI字幕组件错误。错误码: ${error.code}, 消息: ${error.message}`)
      }
    }
  }

  build() {
    if (deviceInfo.sdkApiVersion >= 18) {
      if (canIUse('SystemCapability.AI.AICaption')) {
        Column() {
          AICaptionComponent({
            isShown: this.isShown,
            controller: this.controller,
            options: this.captionOption
          })
            .width('100%')
            .height(80)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
      }
    }
  }
}
