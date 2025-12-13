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

class PrivacyBackgroundUtil {
  public isPrivacyBackground: boolean = false
}

class PcUtil {
  public pcMode: boolean = false
}

export const SafeHeight = UIUtils.makeObserved(new SafeHeightUtil());

export const Background = UIUtils.makeObserved(new BackgroundUtil());

export const Privacy = UIUtils.makeObserved(new PrivacyBackgroundUtil());

export const Pc = UIUtils.makeObserved(new PcUtil());
