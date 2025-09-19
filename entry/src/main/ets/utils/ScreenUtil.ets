import { display, window } from '@kit.ArkUI';
import { Context } from '@kit.AbilityKit';
import { settings } from '@kit.BasicServicesKit';

class Screen {
  isInit: boolean = false
  windowClass: window.Window | null = null

  async init(context: Context) {
    if (this.isInit) {
      return
    }
    try {
      this.windowClass = await window.getLastWindow(context)
      this.isInit = true
      await this.windowClass.setWindowLayoutFullScreen(true)
      if (canIUse('SystemCapability.Window.SessionManager')) {
        this.windowClass.setWindowDecorVisible(false)
        if (canIUse('SystemCapability.Applications.Settings.Core')) {
          settings.registerKeyObserver(context, 'window_pcmode_switch_status',
            settings.domainName.USER_PROPERTY, () => this.updatePCMode(context))
        }
      }
      this.updatePCMode(context)
      this.updateAvoidArea(this.windowClass)
      const windowRect = this.windowClass.getWindowProperties().windowRect
      this.updateScreenSize(windowRect.width, windowRect.height)
      this.windowClass.on('windowSizeChange', (size) => {
        this.updateScreenSize(size.width, size.height)
        this.updateAvoidArea(this.windowClass!)
      })
      this.windowClass.on('avoidAreaChange', () => {
        this.updateAvoidArea(this.windowClass!)
      })
      this.windowClass.on('keyboardHeightChange', (height) => {
        if (height == 0) {
          AppStorage.setOrCreate('main_blur', 0)
        }
      })
    } catch (error) {
      console.error("Window initialization error:", error);
    }
  }

  updateAvoidArea(windowClass: window.Window) {
    try {
      let cutOut = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT)
      let system = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      let nav = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
      const uiContext = this.windowClass?.getUIContext()
      animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
        if (canIUse('SystemCapability.Window.SessionManager')) {
          AppStorage.setOrCreate('topSafeHeight', Math.max(uiContext?.px2vp(cutOut.topRect.height * 1.4)!,
            uiContext?.px2vp(system.topRect.height)!,
            windowClass.getWindowDecorHeight()))
        }
        AppStorage.setOrCreate('bottomSafeHeight',
          uiContext?.px2vp(Math.max(nav.bottomRect.height, system.bottomRect.height * 1.4,
            cutOut.bottomRect.height * 1.4)))
        AppStorage.setOrCreate('leftSafeHeight',
          uiContext?.px2vp(Math.max(cutOut.leftRect.width * 1.4, system.leftRect.width * 1.4)))
        AppStorage.setOrCreate('rightSafeHeight',
          uiContext?.px2vp(Math.max(cutOut.rightRect.width * 1.4, system.rightRect.width * 1.4)))
      })
    } catch (error) {
      console.error('updateAvoidArea error: ' + error)
    }
  }

  updatePCMode(context: Context) {
    if (canIUse('SystemCapability.Applications.Settings.Core')) {
      switch (settings.getValueSync(context, 'window_pcmode_switch_status', 'false',
        settings.domainName.USER_PROPERTY)) {
        case 'true':
          AppStorage.setOrCreate('pcMode', true)
          break
        case 'false':
          AppStorage.setOrCreate('pcMode', false)
          break
      }
    }
  }

  setBarState(context: Context, status: boolean, navigationIndicator: boolean) {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      window.getLastWindow(context).then((windowClass) => {
        windowClass.setSpecificSystemBarEnabled('status', status).catch(() => {
          console.error('status error')
        })
        windowClass.setSpecificSystemBarEnabled('navigationIndicator', navigationIndicator).catch(() => {
          console.error('navigationIndicator error')
        })
      }).catch(() => {
        console.error('setBarState error')
      })
    }
  }

  setKeepScreenOn(context: Context, isOn: boolean) {
    window.getLastWindow(context).then((windowClass) => {
      windowClass.setWindowKeepScreenOn(isOn).catch(() => {
        console.error('setWindowKeepScreenOn error')
      })
    }).catch(() => {
      console.error('getLastWindow error')
    })
  }

  updateScreenSize(width: number | undefined, height: number | undefined) {
    try {
      let uiContext = this.windowClass?.getUIContext()
      const screen_width = uiContext?.px2vp(width || display.getPrimaryDisplaySync().width)
      const screen_height = uiContext?.px2vp(height || display.getDefaultDisplaySync().height)
      animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
        AppStorage.setOrCreate('screen_width', screen_width)
        AppStorage.setOrCreate('screen_height', screen_height)
      })
      this.updateListEmpty(AppStorage.get('list_maximum_columns') as number)
    } catch (error) {
      console.error('windowClass exception' + error)
    }
  }

  updateListEmpty(maxColumns: number) {
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

const ScreenUtil = new Screen()

export default ScreenUtil