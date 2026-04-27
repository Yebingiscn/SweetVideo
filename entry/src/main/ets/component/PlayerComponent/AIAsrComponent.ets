import { AICaptionComponent, AICaptionController, AICaptionOptions } from '@kit.SpeechKit';
import { salmonLogger } from 'salmonlogger';

const TAG = 'AIAsrComponent'

@Component
export struct AISubtitleComponent {
  @Prop isAIAsrShown: boolean
  @Prop showControl: boolean = false
  @Prop screenHeight: number = 0
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
          // TODO: AICaptionComponent 内部使用 @Link，V2 组件暂无法直接调用。
          // 等待 HarmonyOS SDK 更新支持后恢复以下代码：
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
          y: this.showControl ? this.screenHeight / 2 - 150 :
            this.screenHeight / 2 - 40
        })
      }
    }
  }
}
