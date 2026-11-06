import { AICaptionComponent, AICaptionController, AICaptionFontSize, AICaptionOptions } from '@kit.SpeechKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { salmonLogger } from 'salmonlogger';
import { Setting } from '../../utils/ObservedUtil';
import AICaptionSettings from '../../utils/AICaptionSettings';

const TAG = 'AIAsrComponent'

@Component
export struct AISubtitleComponent {
  @Prop isAIAsrShown: boolean
  @Prop showControl: boolean = false
  @Prop screenHeight: number = 0
  @Prop screenWidth: number = 0
  onPrepared: () => void = () => {}
  onError: () => void = () => {}
  private active: boolean = false
  private failed: boolean = false
  private captionOption?: AICaptionOptions
  private controller: AICaptionController = new AICaptionController()

  aboutToAppear(): void {
    this.active = true
    this.failed = false
    if (!this.captionOption) {
      const settings = AICaptionSettings.normalize({
        sourceLanguage: Setting.aiSubtitleSourceLanguage,
        targetLanguage: Setting.aiSubtitleTargetLanguage,
        fontSize: Setting.aiSubtitleFontSize,
        fontColor: Setting.aiSubtitleFontColor,
        backgroundOpacity: Setting.aiSubtitleBackgroundOpacity
      })
      this.captionOption = {
        initialOpacity: AICaptionSettings.getInitialOpacity(settings.backgroundOpacity, deviceInfo.deviceType),
        onPrepared: () => {
          if (!this.active || this.failed) { return }
          salmonLogger.addLog(TAG, '流心 ASREngine准备就绪', true)
          this.onPrepared()
        },
        onError: (error: BusinessError) => {
          if (!this.active || this.failed) { return }
          this.failed = true
          salmonLogger.addLog(TAG, `流心 ASREngine错误。错误码: ${error.code}, 消息: ${error.message}`, true)
          this.onError()
        }
      }
      // 这些是初始化默认值；API 23 不传新字段，重新开启 AI 字幕时读取最新设置。
      if (deviceInfo.apiAvailable(24)) {
        this.captionOption.sourceLanguage = settings.sourceLanguage
        this.captionOption.targetLanguage = settings.targetLanguage
        this.captionOption.fontSize = settings.fontSize as AICaptionFontSize
        this.captionOption.fontColor = settings.fontColor
      }
    }
  }

  aboutToDisappear(): void {
    this.active = false
  }

  build() {
    if (this.isAIAsrShown) {
      if (canIUse('SystemCapability.AI.AICaption')) {
        Column() {
          // AICaptionComponent 内部使用 @Link，V2 组件暂无法直接调用。
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
          y: this.showControl ?
            (this.screenWidth > this.screenHeight ? this.screenHeight / 2 - 180 : this.screenHeight / 2 - 220) :
            this.screenHeight / 2 - 40
        })
      }
    }
  }
}
