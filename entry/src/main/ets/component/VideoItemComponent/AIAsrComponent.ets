import { AICaptionComponent, AICaptionController, AICaptionOptions } from '@kit.SpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'AI_CAPTION'

class Logger {
  static info(...msg: string[]) {
    hilog.info(0x0000, TAG, msg.join())
  }

  static error(...msg: string[]) {
    hilog.error(0x0000, TAG, msg.join())
  }
}

@Component
export struct AIAsr {
  @Prop isShown: boolean = false;
  private captionOption?: AICaptionOptions;
  private controller: AICaptionController = new AICaptionController();

  aboutToAppear(): void {
    this.captionOption = {
      initialOpacity: 0.5,
      onPrepared: () => {
        Logger.info('AI字幕组件准备就绪')
      },
      onError: (error: BusinessError) => {
        Logger.error(`AI字幕组件错误。错误码: ${error.code}, 消息: ${error.message}`)
      }
    }
  }

  build() {
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
