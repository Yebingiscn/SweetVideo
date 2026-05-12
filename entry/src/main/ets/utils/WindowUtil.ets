import { display, window } from '@kit.ArkUI'
import { PathUtils } from './PathUtils'
import { salmonLogger } from 'salmonlogger'
import { DARK_MODE_BAR_COLOR, LIGHT_MODE_BAR_COLOR } from '../common/Constants'
import { Pc, SafeHeight } from './ObservedUtil'
import { deviceInfo, settings } from '@kit.BasicServicesKit'
import { ConfigurationConstant } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'WindowUtil'

// 用于设置窗口状态
export class WindowUtil {
  public static windowClass: window.Window | null = null
  public static deviceHeight: number = 0
  public static deviceWidth: number = 0
  private static instance: WindowUtil
  private static windowStage?: window.WindowStage
  private static isInit: boolean = false

  public static getInstance() {
    if (!WindowUtil.instance) {
      WindowUtil.instance = new WindowUtil()
    }
    return WindowUtil.instance
  }

  public static async getWindow() {
    return await window.getLastWindow(PathUtils.appContext!)?.catch(() => {
      salmonLogger.addLog(TAG, 'window error', true)
      return undefined
    })
  }

  public static async getWindowsStatus(): Promise<window.WindowStatusType | undefined> {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      try {
        return (await WindowUtil.getWindow())?.getWindowStatus()
      } catch (error) {
        salmonLogger.addLog(TAG, 'get windows status error', true)
        return undefined
      }
    }
    return undefined
  }

  public static async setLandscapeMultiWindow(windowClass: Promise<window.Window | undefined>, enable: boolean) {
    if (canIUse("SystemCapability.Window.SessionManager")) {
      if (windowClass) {
        const win = await windowClass
        const operation = enable ? win?.enableLandscapeMultiWindow() : win?.disableLandscapeMultiWindow()
        operation?.then(() => {
          AppStorage.setOrCreate('enableLandscapeMultiWindow', enable)
        })?.catch(() => {
          salmonLogger.addLog(TAG, `${enable ? 'enable' : 'disable'}LandscapeMultiWindow error`, true)
        })
      }
    }
  }

  public static async enableLandscapeMultiWindow(windowClass: Promise<window.Window | undefined>) {
    await WindowUtil.setLandscapeMultiWindow(windowClass, true)
  }

  public static async disableLandscapeMultiWindow(windowClass: Promise<window.Window | undefined>) {
    await WindowUtil.setLandscapeMultiWindow(windowClass, false)
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
        case window.WindowStatusType.MAXIMIZE:
          if (Pc.pcMode) {
            await WindowUtil?.maximize?.()
            return undefined
          }
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
      : window.Orientation.AUTO_ROTATION_PORTRAIT
  }

  public static setBarColor(color: string) {
    WindowUtil.windowClass?.setWindowSystemBarProperties({
      statusBarContentColor: color
    }).catch(() => {
      salmonLogger.addLog(TAG, 'setBarColor error', true)
    })
  }

  public static recoveryBarColor() {
    const currentColorMode = AppStorage.get('currentColorMode') as number
    if (currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      WindowUtil.setBarColor(LIGHT_MODE_BAR_COLOR)
    } else if (currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      WindowUtil.setBarColor(DARK_MODE_BAR_COLOR)
    } else {
      salmonLogger.addLog(TAG, 'currentColorMode is not valid', true)
    }
  }

  public static async maximize(): Promise<void> {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      try {
        if ((await WindowUtil.getWindow())?.getWindowStatus() === window.WindowStatusType.FLOATING ||
          (await WindowUtil.getWindow())?.getWindowStatus() === window.WindowStatusType.MAXIMIZE) {
          (await WindowUtil.getWindow())?.maximize()
            .then(() => {
              salmonLogger.addLog(TAG, 'test Succeed in maximizing the window.', false)
            })
            ?.catch((err: BusinessError) => {
              hilog.error(0x0000, 'testTag',
                `test Failed to maximize the window. Code: ${err.code}, message: ${err.message}`,
                JSON.stringify(err) ?? '')
            })
        }
      } catch (error) {
        salmonLogger.addLog(TAG, 'maximize error', true)
      }
    }
  }

  public static async recover(): Promise<void> {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      try {
        if ((await WindowUtil.getWindow())?.getWindowStatus() === window.WindowStatusType.FULL_SCREEN ||
          (await WindowUtil.getWindow())?.getWindowStatus() === window.WindowStatusType.MAXIMIZE) {
          (await WindowUtil.getWindow())?.recover()
            .then(() => {
              salmonLogger.addLog(TAG, 'test Succeed in recovering the window.', false)
            })
            ?.catch((err: BusinessError) => {
              salmonLogger.addLog(TAG, `test Failed to recover the window. Code: ${err.code}, message: ${err.message}`,
                true)
            })
        }
      } catch (error) {
        salmonLogger.addLog(TAG, 'recover error', true)
      }
    }
  }

  public static setWindowStage(windowStage: window.WindowStage): void {
    WindowUtil.windowStage = windowStage
    WindowUtil.windowStage.getMainWindow((err, windowClass: window.Window) => {
      if (err.code) {
        salmonLogger.addLog(TAG, `Failed to obtain the main window. Code:${err.code}, message:${err.message}`, true)
        return
      }
      try {
        const properties = windowClass.getWindowProperties()
        let area: window.AvoidArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
        let naviBarArea: window.AvoidArea =
          windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
        AppStorage.setOrCreate('deviceWidth', properties.windowRect.width)
        AppStorage.setOrCreate('deviceHeight', properties.windowRect.height)
        AppStorage.setOrCreate('statusBarHeight', area.topRect.height)
        AppStorage.setOrCreate('navBarHeight', naviBarArea.bottomRect.height)
      } catch (error) {
        salmonLogger.addLog(TAG, 'window error', true)
      }
    })
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
        WindowUtil.windowClass.setWindowDecorVisible(true)
        if (canIUse('SystemCapability.Applications.Settings.Core')) {
          settings.registerKeyObserver(context, 'window_pcmode_switch_status',
            settings.domainName.USER_PROPERTY, () => WindowUtil.updatePCMode(context))
        }
      }
      WindowUtil.updatePCMode(context)
      WindowUtil.updateAvoidArea(WindowUtil.windowClass)
      const windowRect = WindowUtil.windowClass.getWindowProperties().windowRect
      WindowUtil.updateScreenSize(windowRect.width, windowRect.height)
      WindowUtil.getScreenSize()
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
      salmonLogger.addLog(TAG, 'Window initialization error', true)
    }
  }

  public static setKeepScreenStatus(context: Context, isOn: boolean) {
    window.getLastWindow(context).then((windowClass) => {
      windowClass.setWindowKeepScreenOn(isOn)?.catch(() => {
        salmonLogger.addLog(TAG, 'setWindowKeepScreenOn error', true)
      })
    })?.catch(() => {
      salmonLogger.addLog(TAG, 'getLastWindow error', true)
    })
  }

  public static setBarState(context: Context, status: boolean, navigationIndicator: boolean) {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      window.getLastWindow(context).then((windowClass) => {
        windowClass.setSpecificSystemBarEnabled('status', status, true)?.catch(() => {
          salmonLogger.addLog(TAG, 'status error', true)
        })
        windowClass.setSpecificSystemBarEnabled('navigationIndicator', navigationIndicator, true)?.catch(() => {
          salmonLogger.addLog(TAG, 'navigationIndicator error', true)
        })
      })?.catch(() => {
        salmonLogger.addLog(TAG, 'setBarState error', true)
      })
    }
  }

  static async minimizeClick(context: Context) {
    try {
      let windowClass = await window.getLastWindow(context)
      windowClass.minimize((err: BusinessError) => {
        const errCode: number = err.code
        if (errCode) {
          salmonLogger.addLog(TAG, `Failed to minimize the window. Code: ${err.code}, message: ${err.message}`, true)
          return
        }
      })
    } catch (error) {
      salmonLogger.addLog(TAG, 'minimizeClick error', true)
    }
  }

  private static getScreenSize() {
    try {
      let displayClass = display.getDefaultDisplaySync()
      // 获取屏幕宽度（单位：px）
      WindowUtil.deviceWidth = displayClass.width
      // 获取屏幕高度（单位：px）
      WindowUtil.deviceHeight = displayClass.height
    } catch (error) {
      salmonLogger.addLog(TAG, 'getScreenSize error', true)
    }
  }

  private static updateAvoidArea(windowClass: window.Window) {
    try {
      let cutOut = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT)
      let system = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      let nav = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
      const uiContext = WindowUtil.windowClass?.getUIContext()
      if (canIUse('SystemCapability.Window.SessionManager')) {
        SafeHeight.topSafeHeight = Math.max(uiContext?.px2vp(cutOut.topRect.height * 1.4)!,
          uiContext?.px2vp(system.topRect.height)!, Pc.pcMode ? 0 : windowClass.getWindowDecorHeight())
      }
      SafeHeight.bottomSafeHeight = uiContext?.px2vp(Math.max(nav.bottomRect.height, system.bottomRect.height * 1.4,
        cutOut.bottomRect.height * 1.4)) || 0
    } catch (error) {
      salmonLogger.addLog(TAG, 'updateAvoidArea error', true)
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
          if (deviceInfo.deviceType === '2in1') {
            Pc.pcMode = true
            break
          }
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
      AppStorage.setOrCreate('screen_width', screen_width)
      AppStorage.setOrCreate('screen_height', screen_height)

      WindowUtil.updateListEmpty(AppStorage.get('list_maximum_columns') as number)
    } catch (error) {
      salmonLogger.addLog(TAG, 'windowClass exception', true)
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