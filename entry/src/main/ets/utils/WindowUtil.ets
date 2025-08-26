import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PathUtils } from './PathUtils';

// 用于设置窗口状态
export class WindowUtil {
  private static instance: WindowUtil;
  private static  windowStage?: window.WindowStage;
  private static  mainWindowClass = window.getLastWindow(PathUtils.appContext!)

  public static getInstance() {
    if (!WindowUtil.instance) {
      WindowUtil.instance = new WindowUtil();
    }
    return WindowUtil.instance;
  }

  public static  async getWindowsStatus(): Promise<window.WindowStatusType | undefined> {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      return (await WindowUtil.mainWindowClass)?.getWindowStatus();
    }
    return undefined;
  }

  public static  async enableLandscapeMultiWindow(windowClass:  Promise<window.Window>) {
    if (canIUse("SystemCapability.Window.SessionManager")) {
      (await windowClass).enableLandscapeMultiWindow()
    }
  }

  public static  async disableLandscapeMultiWindow(windowClass:  Promise<window.Window>) {
    if (canIUse("SystemCapability.Window.SessionManager")) {
      (await windowClass).disableLandscapeMultiWindow()
    }
  }

  public static  async maximize(): Promise<void> {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      if ((await WindowUtil.mainWindowClass)?.getWindowStatus() === window.WindowStatusType.FLOATING) {
        (await WindowUtil.mainWindowClass)?.maximize()
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

  public static  async recover(): Promise<void> {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      if ((await WindowUtil.mainWindowClass)?.getWindowStatus() === window.WindowStatusType.FULL_SCREEN) {
        (await WindowUtil.mainWindowClass)?.recover()
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

  public static  setWindowStage(windowStage: window.WindowStage): void {
    WindowUtil.windowStage = windowStage;
    WindowUtil.windowStage.getMainWindow((err, windowClass: window.Window) => {
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
      AppStorage.setOrCreate('statusBarHeight', area.topRect.height);
      AppStorage.setOrCreate('navBarHeight', naviBarArea.bottomRect.height);
    });
  }
}