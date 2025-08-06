import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PathUtils } from './PathUtils';

// 用于设置窗口状态
export class WindowUtil {
  private static instance: WindowUtil;
  private windowStage?: window.WindowStage;
  private mainWindowClass = window.getLastWindow(PathUtils.appContext!)

  public static getInstance() {
    if (!WindowUtil.instance) {
      WindowUtil.instance = new WindowUtil();
    }
    return WindowUtil.instance;
  }

  public async getWindowsStatus(): Promise<window.WindowStatusType | undefined> {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      return (await this.mainWindowClass)?.getWindowStatus();
    }
    return undefined;
  }

  public async maximize(): Promise<void> {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      if ((await this.mainWindowClass)?.getWindowStatus() === window.WindowStatusType.FLOATING) {
        (await this.mainWindowClass)?.maximize()
          .then(() => {
            hilog.info(0x0000, 'testTag', '%{public}s', `Succeed in maximizing the window.`);
          })
          .catch((err: BusinessError) => {
            hilog.error(0x0000, 'testTag', `Failed to maximize the window. Code: ${err.code}, message: ${err.message}`,
              JSON.stringify(err) ?? '');
          });
      }
    }
  }

  public async recover(): Promise<void> {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      if ((await this.mainWindowClass)?.getWindowStatus() === window.WindowStatusType.FULL_SCREEN) {
        (await this.mainWindowClass)?.recover()
          .then(() => {
            hilog.info(0x0000, 'testTag', '%{public}s', `Succeed in recovering the window.`);
          })
          .catch((err: BusinessError) => {
            hilog.error(0x0000, 'testTag', `Failed to recover the window. Code: ${err.code}, message: ${err.message}`,
              JSON.stringify(err) ?? '');
          });
      }
    }
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