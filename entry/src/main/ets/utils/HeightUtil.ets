import { UIUtils } from '@kit.ArkUI';

class HeightUtil {
  public topSafeHeight: number = 0
  public bottomSafeHeight: number = 0
}

export default UIUtils.makeObserved(new HeightUtil());