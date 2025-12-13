import { UIUtils } from '@kit.ArkUI';
import { BackgroundColorMode } from '../common/enum/BackgroundColorMode';

class BackgroundUtil {
  public backgroundImageSrc: string = ''
  public backgroundDropBlur: number = 0
  public backgroundColorMode: BackgroundColorMode = BackgroundColorMode.AUTO
}

export default UIUtils.makeObserved(new BackgroundUtil());