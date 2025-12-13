import { UIUtils } from '@kit.ArkUI';
import { BackgroundColorMode } from '../common/enum/BackgroundColorMode';

class BackgroundUtil {
  public backgroundImageSrc: string = ''
  public backgroundDropBlur: number = 0
  public backgroundColorMode: BackgroundColorMode = BackgroundColorMode.AUTO
}

class SafeHeightUtil {
  public topSafeHeight: number = 0
  public bottomSafeHeight: number = 0
}

export const SafeHeight = UIUtils.makeObserved(new SafeHeightUtil());

export const Background = UIUtils.makeObserved(new BackgroundUtil());