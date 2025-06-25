import { display, window } from '@kit.ArkUI'
import { Context } from '@kit.AbilityKit'
import { settings } from '@kit.BasicServicesKit'

class Screen {
  isInit: boolean = false

  init(context: Context) {
    if (this.isInit) {
      return
    }
    window.getLastWindow(context).then((windowClass) => {
      this.isInit = true
      windowClass.setWindowLayoutFullScreen(true)
      windowClass.setWindowDecorVisible(false)
      settings.registerKeyObserver(context, 'window_pcmode_switch_status', settings.domainName.USER_PROPERTY, () => {
        this.updatePCMode(context)
      });
      this.updatePCMode(context)
      this.updateAvoidArea(windowClass)
      this.updateScreenSize(windowClass.getWindowProperties().windowRect.width,
        windowClass.getWindowProperties().windowRect.height)
      windowClass.on('windowSizeChange', (size) => {
        this.updateScreenSize(size.width, size.height)
      })
      windowClass.on('systemAvoidAreaChange', () => {
        this.updateAvoidArea(windowClass)
      })
      windowClass.on('keyboardHeightChange', (height) => {
        if (height == 0) {
          AppStorage.setOrCreate('main_blur', 0)
        }
      })
    })
  }

  async updateAvoidArea(windowClass: window.Window) {
    let cutOut = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT)
    let system = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
    let nav = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
    animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
      AppStorage.setOrCreate('topSafeHeight',
        px2vp(Math.max(cutOut.topRect.height * 1.4, system.topRect.height, windowClass.getWindowDecorHeight())))
      AppStorage.setOrCreate('bottomSafeHeight',
        px2vp(Math.max(nav.bottomRect.height, system.bottomRect.height * 1.4, cutOut.bottomRect.height * 1.4)))
      AppStorage.setOrCreate('leftSafeHeight',
        px2vp(Math.max(cutOut.leftRect.width * 1.4, system.leftRect.width * 1.4)))
      AppStorage.setOrCreate('rightSafeHeight',
        px2vp(Math.max(cutOut.rightRect.width * 1.4, system.rightRect.width * 1.4)))
    })
  }

  updatePCMode(context: Context) {
    switch (settings.getValueSync(context, 'window_pcmode_switch_status', 'false', settings.domainName.USER_PROPERTY)) {
      case 'true':
        AppStorage.setOrCreate('pcMode', true)
        break
      case 'false':
        AppStorage.setOrCreate('pcMode', false)
        break
    }
  }

  setBarState(context: Context, status: boolean, navigationIndicator: boolean) {
    window.getLastWindow(context).then((windowClass) => {
      windowClass.setSpecificSystemBarEnabled('status', status)
      windowClass.setSpecificSystemBarEnabled('navigationIndicator', navigationIndicator)
    })
  }

  setKeepScreenOn(context: Context, isOn: boolean) {
    window.getLastWindow(context).then((windowClass) => {
      windowClass.setWindowKeepScreenOn(isOn)
    })
  }

  async updateScreenSize(width: number | undefined, height: number | undefined) {
    let screen_width = px2vp(width || display.getPrimaryDisplaySync().width)
    let screen_height = px2vp(height || display.getDefaultDisplaySync().height)
    animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
      AppStorage.setOrCreate('screen_width', screen_width)
      AppStorage.setOrCreate('screen_height', screen_height)
    })
    this.updateListEmpty(AppStorage.get('list_maximum_columns') as number)
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