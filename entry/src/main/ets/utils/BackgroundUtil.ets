import { UIUtils } from "@kit.ArkUI";

class BackgroundUtil {
  public backgroundImageSrc: string = ''
  public backgroundDropBlur: number = 0
}

export default UIUtils.makeObserved(new BackgroundUtil());