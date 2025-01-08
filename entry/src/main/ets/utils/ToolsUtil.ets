import promptAction from '@ohos.promptAction';

class Tools {
  showToast(text: string) {
    promptAction.showToast({
      message: text,
      duration: 2000,
      backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THICK,
    });
  }

  hasMultipleDots(input: string | undefined): boolean {
    if (input === undefined) {
      return false;
    }
    // 使用正则表达式匹配点的数量
    const dotCount = (input.match(/\./g) || []).length;
    return dotCount === 1;
  }
}

const ToolsUtil = new Tools()

export default ToolsUtil