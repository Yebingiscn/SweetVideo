import promptAction from '@ohos.promptAction';

class Tools {
  showToast(text: string) {
    promptAction.showToast({
      message: text,
      duration: 2000,
      backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THICK,
    });
  }
}

const ToolsUtil = new Tools()

export default ToolsUtil