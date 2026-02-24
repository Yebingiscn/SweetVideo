import { AICaptionComponent, AICaptionController, AICaptionOptions } from '@kit.SpeechKit'
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit'

@Component
export struct AISubtitleComponent {
  @Link isAIAsrShown: boolean
  @Link showControl: boolean
  @Prop screenWidth: number
  @Prop screenHeight: number

  build() {
    AIAsr({
      isShown: this.isAIAsrShown
    })
      .visibility(this.showControl ? Visibility.None : Visibility.Visible)
      .width('80%').height(80)
      .offset({
        x: 0,
        y: this.screenWidth > this.screenHeight ? this.screenHeight / 2 - 40 :
          this.screenHeight / 2 - 100
      })
  }
}

@Component
export struct AIAsr {
  @Link isShown: boolean
  private captionOption: AICaptionOptions = {
    initialOpacity: 0.5,
    onPrepared: () => {
      console.log('AI字幕组件准备就绪')
    },
    onError: (error: BusinessError) => {
      console.error(`AI字幕组件错误。错误码: ${error.code}, 消息: ${error.message}`)
    }
  }
  // 使用@State管理控制器状态
  @State private controller: AICaptionController | null = null

  // 组件初始化
  aboutToAppear(): void {
    // 检查API可用性
    if (this.isAICaptionSupported()) {
      this.controller = new AICaptionController()
    }
  }

  // 组件销毁
  aboutToDisappear(): void {
    // 安全释放资源
    try {
      this.controller = null
    } catch (error) {
      console.error('AI字幕组件释放失败:', error)
    }
  }

  build() {
    // 仅在支持时渲染组件
    if (this.isAICaptionSupported() && this.controller) {
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

  // 检查AI字幕支持
  private isAICaptionSupported(): boolean {
    return deviceInfo.sdkApiVersion >= 18 &&
    canIUse('SystemCapability.AI.AICaption')
  }
}