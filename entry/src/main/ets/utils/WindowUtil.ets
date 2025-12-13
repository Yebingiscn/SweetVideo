import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError, settings } from '@kit.BasicServicesKit';
import { PathUtils } from './PathUtils';
import { Pc, SafeHeight } from './ObservedUtil';

// 用于设置窗口状态
export class WindowUtil {
  private static instance: WindowUtil;
  private static windowStage?: window.WindowStage;
  private static windowClass: window.Window | null = null
  private static isInit: boolean = false

  public static getInstance() {
    if (!WindowUtil.instance) {
      WindowUtil.instance = new WindowUtil();
    }
    return WindowUtil.instance;
  }

  public static async getWindow() {
    return await window.getLastWindow(PathUtils.appContext!)?.catch(() => {
      console.error('window error')
      return undefined
    })
  }

  public static async getWindowsStatus(): Promise<window.WindowStatusType | undefined> {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      try {
        return (await WindowUtil.getWindow())?.getWindowStatus()
      } catch (error) {
        console.error('test window error' + error)
        return undefined
      }
    }
    return undefined
  }

  public static async enableLandscapeMultiWindow(windowClass: Promise<window.Window | undefined>) {
    if (canIUse("SystemCapability.Window.SessionManager")) {
      if (windowClass) {
        (await windowClass)?.enableLandscapeMultiWindow()?.then(() => {
          AppStorage.setOrCreate('enableLandscapeMultiWindow', true)
        }).catch(() => {
          console.error('window error')
        })
      }
    }
  }

  public static async disableLandscapeMultiWindow(windowClass: Promise<window.Window | undefined>) {
    if (canIUse("SystemCapability.Window.SessionManager")) {
      if (windowClass) {
        (await windowClass)?.disableLandscapeMultiWindow()?.then(() => {
          AppStorage.setOrCreate('enableLandscapeMultiWindow', false)
        }).catch(() => {
          console.error('window error')
        })
      }
    }
  }

  public static async fullScreenOperate(screen_height: number, screen_width: number,
    windowClass: Promise<window.Window | undefined>): Promise<window.Orientation.AUTO_ROTATION_PORTRAIT | window.Orientation.AUTO_ROTATION_LANDSCAPE | undefined> {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      switch (await WindowUtil.getWindowsStatus()) {
        case window.WindowStatusType.FLOATING:
          if (Pc.pcMode) {
            await WindowUtil?.maximize?.()
            return undefined
          }
          AppStorage.get('enableLandscapeMultiWindow') ? WindowUtil.disableLandscapeMultiWindow(windowClass) :
            WindowUtil.enableLandscapeMultiWindow(windowClass)
          return undefined
        case window.WindowStatusType.FULL_SCREEN:
          if (Pc.pcMode) {
            await WindowUtil?.recover?.()
            return undefined
          }
        case window.WindowStatusType.UNDEFINED:
        default:
          return WindowUtil.getWindowOrientation(screen_height, screen_width)
      }
    }
    return undefined
  }

  public static getWindowOrientation(screen_height: number, screen_width: number) {
    return screen_height > screen_width
      ? window.Orientation.AUTO_ROTATION_LANDSCAPE
      : window.Orientation.AUTO_ROTATION_PORTRAIT;
  }

  public static async maximize(): Promise<void> {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      try {
        if ((await WindowUtil.getWindow())?.getWindowStatus() === window.WindowStatusType.FLOATING) {
          (await WindowUtil.getWindow())?.maximize()
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
        if ((await WindowUtil.getWindow())?.getWindowStatus() === window.WindowStatusType.FULL_SCREEN) {
          (await WindowUtil.getWindow())?.recover()
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

  public static async init(context: Context) {
    if (WindowUtil.isInit) {
      return
    }
    try {
      WindowUtil.windowClass = await window.getLastWindow(context)
      WindowUtil.isInit = true
      await WindowUtil.windowClass.setWindowLayoutFullScreen(true)
      if (canIUse('SystemCapability.Window.SessionManager')) {
        WindowUtil.windowClass.setWindowDecorVisible(false)
        if (canIUse('SystemCapability.Applications.Settings.Core')) {
          settings.registerKeyObserver(context, 'window_pcmode_switch_status',
            settings.domainName.USER_PROPERTY, () => WindowUtil.updatePCMode(context))
        }
      }
      WindowUtil.updatePCMode(context)
      WindowUtil.updateAvoidArea(WindowUtil.windowClass)
      const windowRect = WindowUtil.windowClass.getWindowProperties().windowRect
      WindowUtil.updateScreenSize(windowRect.width, windowRect.height)
      WindowUtil.windowClass.on('windowSizeChange', (size) => {
        WindowUtil.updateScreenSize(size.width, size.height)
        WindowUtil.updateAvoidArea(WindowUtil.windowClass!)
      })
      WindowUtil.windowClass.on('avoidAreaChange', () => {
        WindowUtil.updateAvoidArea(WindowUtil.windowClass!)
      })
      WindowUtil.windowClass.on('keyboardHeightChange', (height) => {
        if (height == 0) {
          AppStorage.setOrCreate('main_blur', 0)
        }
      })
    } catch (error) {
      console.error("Window initialization error:", error);
    }
  }

  public static setKeepScreenStatus(context: Context, isOn: boolean) {
    window.getLastWindow(context).then((windowClass) => {
      windowClass.setWindowKeepScreenOn(isOn)?.catch(() => {
        console.error('setWindowKeepScreenOn error')
      })
    })?.catch(() => {
      console.error('getLastWindow error')
    })
  }

  public static setBarState(context: Context, status: boolean, navigationIndicator: boolean) {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      window.getLastWindow(context).then((windowClass) => {
        windowClass.setSpecificSystemBarEnabled('status', status, true)?.catch(() => {
          console.error('status error')
        })
        windowClass.setSpecificSystemBarEnabled('navigationIndicator', navigationIndicator, true)?.catch(() => {
          console.error('navigationIndicator error')
        })
      })?.catch(() => {
        console.error('setBarState error')
      })
    }
  }

  private static updateAvoidArea(windowClass: window.Window) {
    try {
      let cutOut = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT)
      let system = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      let nav = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
      const uiContext = WindowUtil.windowClass?.getUIContext()
      animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
        if (canIUse('SystemCapability.Window.SessionManager')) {
          SafeHeight.topSafeHeight = Math.max(uiContext?.px2vp(cutOut.topRect.height * 1.4)!,
            uiContext?.px2vp(system.topRect.height)!,
            windowClass.getWindowDecorHeight())
        }
        SafeHeight.bottomSafeHeight = uiContext?.px2vp(Math.max(nav.bottomRect.height, system.bottomRect.height * 1.4,
          cutOut.bottomRect.height * 1.4)) || 0
        // 'leftSafeHeight' uiContext?.px2vp(Math.max(cutOut.leftRect.width * 1.4, system.leftRect.width * 1.4))
        // 'rightSafeHeight' uiContext?.px2vp(Math.max(cutOut.rightRect.width * 1.4, system.rightRect.width * 1.4))
      })
    } catch (error) {
      console.error('updateAvoidArea error: ' + error)
    }
  }

  private static updatePCMode(context: Context) {
    if (canIUse('SystemCapability.Applications.Settings.Core')) {
      switch (settings.getValueSync(context, 'window_pcmode_switch_status', 'false',
        settings.domainName.USER_PROPERTY)) {
        case 'true':
          Pc.pcMode = true
          break
        case 'false':
          Pc.pcMode = false
          break
      }
    }
  }

  private static updateScreenSize(width: number | undefined, height: number | undefined) {
    try {
      let uiContext = WindowUtil.windowClass?.getUIContext()
      const screen_width =
        uiContext?.px2vp(width || WindowUtil.windowClass?.getWindowProperties().windowRect.width) || 0
      const screen_height =
        uiContext?.px2vp(height || WindowUtil.windowClass?.getWindowProperties().windowRect.height) || 0
      animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
        AppStorage.setOrCreate('screen_width', screen_width)
        AppStorage.setOrCreate('screen_height', screen_height)
      })
      WindowUtil.updateListEmpty(AppStorage.get('list_maximum_columns') as number)
    } catch (error) {
      console.error('windowClass exception' + error)
    }
  }

  private static updateListEmpty(maxColumns: number) {
    let list_empty_item: number[] = []
    let list_line =
      Math.max(Math.min(Math.floor((AppStorage.get('screen_width') as number | undefined || 0) / 230), maxColumns + 1),
        AppStorage.get('force_list_style') ? 2 : 1)
    for (let i = 0; i < list_line; i++) {
      list_empty_item.push(i)
    }
    setTimeout(() => {
      AppStorage.setOrCreate('list_line', list_line)
      AppStorage.setOrCreate('list_empty_item', list_empty_item)
    }, 100)
  }
}