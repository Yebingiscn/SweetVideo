import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PathUtils } from './PathUtils';

// 用于设置窗口状态
export class WindowUtil {
  private static instance: WindowUtil;
  private static windowStage?: window.WindowStage;
  private static mainWindowClass = this.getWindow()

  public static getInstance() {
    if (!WindowUtil.instance) {
      WindowUtil.instance = new WindowUtil();
    }
    return WindowUtil.instance;
  }

  public static getWindow() {
    return window.getLastWindow(PathUtils.appContext!)?.catch(() => {
      console.error('window error')
      return undefined
    })
  }

  public static async getWindowsStatus(): Promise<window.WindowStatusType | undefined> {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      try {
        return (await WindowUtil.mainWindowClass)?.getWindowStatus()
      } catch (error) {
        console.error('window error' + error)
        return undefined
      }
    }
    return undefined
  }

  public static async enableLandscapeMultiWindow(windowClass: Promise<window.Window | undefined>) {
    if (canIUse("SystemCapability.Window.SessionManager")) {
      if (windowClass) {
        (await windowClass)?.enableLandscapeMultiWindow()?.catch(() => {
          console.error('window error')
        })
      }
    }
  }

  public static async disableLandscapeMultiWindow(windowClass: Promise<window.Window | undefined>) {
    if (canIUse("SystemCapability.Window.SessionManager")) {
      if (windowClass) {
        (await windowClass)?.disableLandscapeMultiWindow()?.catch(() => {
          console.error('window error')
        })
      }
    }
  }

  public static async fullScreenOperate() {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      switch (await WindowUtil.getWindowsStatus()) {
        case window.WindowStatusType.FLOATING:
          await WindowUtil?.maximize?.()
          return
        case window.WindowStatusType.FULL_SCREEN:
          await WindowUtil?.recover?.()
          return
      }
    }
  }

  public static async maximize(): Promise<void> {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      try {
        if ((await WindowUtil.mainWindowClass)?.getWindowStatus() === window.WindowStatusType.FLOATING) {
          (await WindowUtil.mainWindowClass)?.maximize()
            .then(() => {
              hilog.info(0x0000, 'testTag', '%{public}s', `Succeed in maximizing the window.`);
            })
          ?.catch((err: BusinessError) => {
            hilog.error(0x0000, 'testTag',
              `Failed to maximize the window. Code: ${err.code}, message: ${err.message}`,
              JSON.stringify(err) ?? '');
          });
        }
      } catch (error) {
        console.error('window error' + error)
      }
    }
  }

  public static async recover(): Promise<void> {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      try {
        if ((await WindowUtil.mainWindowClass)?.getWindowStatus() === window.WindowStatusType.FULL_SCREEN) {
          (await WindowUtil.mainWindowClass)?.recover()
            .then(() => {
              hilog.info(0x0000, 'testTag', '%{public}s', `Succeed in recovering the window.`);
            })
          ?.catch((err: BusinessError) => {
            hilog.error(0x0000, 'testTag', `Failed to recover the window. Code: ${err.code}, message: ${err.message}`,
              JSON.stringify(err) ?? '');
          });
        }
      } catch (error) {
        console.error('window error' + error)
      }
    }
  }

  public static setWindowStage(windowStage: window.WindowStage): void {
    WindowUtil.windowStage = windowStage;
    WindowUtil.windowStage.getMainWindow((err, windowClass: window.Window) => {
      if (err.code) {
        hilog.error(777, 'testFlag', `Failed to obtain the main window. Code:${err.code}, message:${err.message}`);
        return;
      }
      try {
        const properties = windowClass.getWindowProperties();
        let area: window.AvoidArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        let naviBarArea: window.AvoidArea =
          windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        AppStorage.setOrCreate('deviceWidth', properties.windowRect.width);
        AppStorage.setOrCreate('deviceHeight', properties.windowRect.height);
        AppStorage.setOrCreate('statusBarHeight', area.topRect.height);
        AppStorage.setOrCreate('navBarHeight', naviBarArea.bottomRect.height);
      } catch (error) {
        console.error('window error' + error)
      }
    });
  }
}