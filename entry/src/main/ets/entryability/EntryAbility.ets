import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit'
import { hiAppEvent, hilog } from '@kit.PerformanceAnalysisKit'
import { window } from '@kit.ArkUI'
import { salmonLogger } from 'salmonlogger'
import Preferences from '../database/Preferences'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { Pc, Privacy, Setting } from '../utils/ObservedUtil'
import { PathUtils } from '../utils/PathUtils'
import PrivacySpaceUtil from '../utils/PrivacySpaceUtil'
import SelectFileUtil from '../utils/SelectFileUtil'
import ToolsUtil from '../utils/ToolsUtil'
import VideoOperateUtil from '../utils/VideoOperateUtil'
import WantProcessUtil from '../utils/WantProcessUtil'
import { WindowUtil } from '../utils/WindowUtil'
import KnockShareUtil from '../utils/KnockShareUtil'
import { MediaSmartGestureSession } from '../utils/MediaSmartGestureUtil'
import { MpvLogBridge } from '../utils/MpvLogBridge'

const TAG = 'EntryAbility'

export default class EntryAbility extends UIAbility {
  watcher: hiAppEvent.Watcher | undefined = undefined
  private mainWindow: window.Window | undefined = undefined

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    const backgroundColorMode = Preferences.getBackgroundColorMode(this.context)
    ToolsUtil.setColorMode(this.context.getApplicationContext(), backgroundColorMode)
    //  PreferencesUtil.localPreferences(this.context, 'sweet_video')
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate')
    AppStorage.setOrCreate('context', this.context)
    PathUtils.init(this.context)
    // Process-wide, not per video: keep teardown diagnostics across core resets.
    MpvLogBridge.start()
    WantProcessUtil.want = want
    this.crashWatcher()
    if (launchParam.launchReason === AbilityConstant.LaunchReason.CONTINUATION) {
      if (want.parameters) {
        WantProcessUtil.restoreContinueData(want);
      }
    }
  }

  //崩溃守卫
  crashWatcher() {
    // 构建崩溃事件的自定义参数
    let params: Record<string, hiAppEvent.ParamType> = {
      "test_data": 100,
    }
    // 崩溃事件的自定义参数
    hiAppEvent.setEventParam(params, hiAppEvent.domain.OS, hiAppEvent.event.APP_CRASH)?.catch((err: BusinessError) => {
      hilog.error(0x0000, 'testTag', `HiAppEvent code: ${err.code}, message: ${err.message}`)
    })
    // 构建崩溃日志规格自定义参数
    let configParams: Record<string, hiAppEvent.ParamType> = {
      "extend_pc_lr_printing": true, // 使能扩展打印pc和lr寄存器附近的内存值
      "log_file_cutoff_sz_bytes": 102400, // 截断崩溃日志到100KB
      "simplify_vma_printing": true // 使能精简打印maps
    }

    // 设置崩溃日志配置参数
    hiAppEvent.setEventConfig(hiAppEvent.event.APP_CRASH, configParams).catch((err: BusinessError) => {
      hilog.error(0x0000, 'testTag', `HiAppEvent code: ${err.code}, message: ${err.message}`)
    })
    let events: string[] = [hiAppEvent.event.APP_CRASH, hiAppEvent.event.APP_FREEZE, hiAppEvent.event.APP_KILLED]
    this.watcher = {
      // 自定义观察者名称，系统会使用名称来标识不同的观察者
      name: "SweetCore",
      // 可以订阅感兴趣的系统事件，此处是订阅了崩溃事件
      appEventFilters: [
        {
          domain: hiAppEvent.domain.OS,
          names: events
        },
      ],
      // 自行实现订阅实时回调函数，以便对订阅获取到的事件数据进行自定义处理
      onReceive: (_domain: string, appEventGroups: Array<hiAppEvent.AppEventGroup>) => {
        AppStorage.setOrCreate('crashLog', appEventGroups)
      }
    }
    try {
      if (this.watcher) {
        hiAppEvent.addWatcher(this.watcher)
      }
    } catch (error) {
      salmonLogger.addLog(TAG, '添加崩溃守卫失败' + error, true)
    }
  }

  // 应用在后台，接收外部应用拉起或者华为分享拉起
  async onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam) {
    WantProcessUtil.want = want
    salmonLogger.addLog(TAG, `onNewWant, want: ${want.abilityName}`)
    if (launchParam.launchReason === AbilityConstant.LaunchReason.CONTINUATION) {
      if (want.parameters) {
        WantProcessUtil.restoreContinueData(want)
      }
    }

  }

  onDestroy(): void {
    KnockShareUtil.stop()
    this.savePlayData()
    try {
      if (this.watcher) {
        hiAppEvent.removeWatcher(this.watcher)
      }
    } catch (error) {
      salmonLogger.addLog(TAG, '移除崩溃守卫失败' + error)
    }
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate')
    try {
      this.mainWindow = windowStage.getMainWindowSync()
      if (canIUse('SystemCapability.Window.SessionManager')) {
        const defaultDensityEnabled = Preferences.getDefaultDensityEnabled(this.context)
        windowStage.setDefaultDensityEnabled(defaultDensityEnabled)
      }
      // 窗口尺寸自动保存
      let promise = windowStage.setWindowRectAutoSave(true).catch(() => {
        salmonLogger.addLog(TAG, `Failed to set window rect auto-save`, true)
      })
      promise.then(() => {
        salmonLogger.addLog(TAG, `Succeeded in setting window rect auto-save`)
      }).catch((err: BusinessError) => {
        salmonLogger.addLog(TAG,
          `Failed to set window rect auto-save. Cause code: ${err.code}, message: ${err.message}`, true)
      });
    } catch (exception) {
      salmonLogger.addLog(TAG,
        `Failed to set default density enabled. Cause code: ${exception.code}, message: ${exception.message}`, true)
    }
    // 进入启动页
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '')
        return
      }
      VideoOperateUtil.windowStage = windowStage
      if (this.mainWindow) {
        KnockShareUtil.start(this.context, this.mainWindow)
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.')
      // 是否进入后台
      try {
        windowStage.on('windowStageEvent', async (windowEvent) => {
          if (!PrivacySpaceUtil.getPrivacyMode()) {
            return
          }
          switch (windowEvent) {
            case window.WindowStageEventType.SHOWN:
            case window.WindowStageEventType.ACTIVE:
            case window.WindowStageEventType.RESUMED: {
              Privacy.isPrivacyBackground = false
              break
            }
            case window.WindowStageEventType.HIDDEN:
            case window.WindowStageEventType.PAUSED: {
              Privacy.isPrivacyBackground = true
              break
            }
            // pc 模式下窗口失焦隐私空间模糊，手机平板分屏、悬浮窗下不模糊
            case window.WindowStageEventType.INACTIVE: {
              Privacy.isPrivacyBackground = Pc.pcMode
            }
          }
        })
      } catch (error) {
        salmonLogger.addLog(TAG, 'windowStageEvent error' + error, true)
      }
    })
  }

  onWindowStageWillDestroy(): void {
    KnockShareUtil.stop()
    this.savePlayData()
    try {
      if (VideoOperateUtil.windowStage) {
        VideoOperateUtil.windowStage.off('windowStageEvent');
      }
    } catch (err) {
      let code = (err as BusinessError).code;
      let message = (err as BusinessError).message;
      salmonLogger.addLog(TAG, `Failed to remove windowStageEvent. Cause code: ${code}, message: ${message}`, true)
    }
  }

  async onContinue(wantParam: Record<string, Object>): Promise<AbilityConstant.OnContinueResult> {
    const nowPlayingData =
      AppStorage.get('nowPlayingData') as (number | VideoMetadata | boolean)[]
    if (nowPlayingData && nowPlayingData[1]) {
      wantParam['continueTime'] = nowPlayingData[0] as number
      wantParam['data'] = nowPlayingData[1] as VideoMetadata
      wantParam['skipHistory'] = nowPlayingData[2] as boolean
    }
    return AbilityConstant.OnContinueResult.AGREE
  }


  onWindowStageDestroy(): void {
    MediaSmartGestureSession.setAppForeground(false)
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy')
  }

  onForeground(): void {
    MediaSmartGestureSession.setAppForeground(true)
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground')
    ToolsUtil.setVibrationEnabled(true)
    if (this.mainWindow) {
      KnockShareUtil.start(this.context, this.mainWindow)
    }
  }

  onBackground(): void {
    MediaSmartGestureSession.setAppForeground(false)
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground')
    KnockShareUtil.stop()
    ToolsUtil.setVibrationEnabled(false)
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    let newColorMode = newConfig.colorMode
    let currentColorMode = AppStorage.get<ConfigurationConstant.ColorMode>('currentColorMode')
    if (newColorMode === currentColorMode) {
      return
    }
    setTimeout(async () => {
      Setting.backgroundImageSrc = SelectFileUtil.getImageUri()
      if (Setting.backgroundDropBlur > 0 && Setting.backgroundImageSrc.length > 0) {
        await SelectFileUtil.updateBlurBackground(Setting.backgroundDropBlur)
      }
    }, 100)
    // 更新缓存中的颜色模式
    AppStorage.setOrCreate('currentColorMode', newConfig.colorMode)
    WindowUtil.recoveryBarColor()
  }

  private savePlayData() {
    const nowPlayingData =
      AppStorage.get('nowPlayingData') as (number | VideoMetadata | boolean)[]
    if (nowPlayingData && !nowPlayingData[2]) {
      VideoOperateUtil.saveVideoTime(nowPlayingData[0] as number, nowPlayingData[1] as VideoMetadata,
        PathUtils.appContext!)
    }
  }
}
