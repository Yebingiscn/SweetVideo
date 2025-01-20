import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class WindowUtil {
  private static instance: WindowUtil;
  private windowStage?: window.WindowStage;

  public static getInstance() {
    if (!WindowUtil.instance) {
      WindowUtil.instance = new WindowUtil();
    }
    return WindowUtil.instance;
  }

  public setWindowStage(windowStage: window.WindowStage): void {

    this.windowStage = windowStage;
    this.windowStage.getMainWindow((err, windowClass: window.Window) => {
      if (err.code) {
        hilog.error(777, 'testFlag', `Failed to obtain the main window. Code:${err.code}, message:${err.message}`);
        return;
      }
      const properties = windowClass.getWindowProperties();
      let area: window.AvoidArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      let naviBarArea: window.AvoidArea =
        windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      AppStorage.setOrCreate('deviceWidth', properties.windowRect.width);
      AppStorage.setOrCreate('deviceHeight', properties.windowRect.height);
      AppStorage.setOrCreate('statusBarHeight', px2vp(area.topRect.height));
      AppStorage.setOrCreate('navBarHeight', px2vp(naviBarArea.bottomRect.height));
    });
  }
}