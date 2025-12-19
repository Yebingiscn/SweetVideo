import { UIAbility, Want } from '@kit.AbilityKit';
import { hiAppEvent, hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import WantProcessUtil from '../utils/WantProcessUtil';
import { RedPlayerConfigBuilder, RedPlayerInitManager, RedPlayerPreload } from '@rte-xhs/redplayer';
import LoggerImpl from '../utils/LoggerImpl';
import { PathUtils } from '../utils/PathUtils';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface';
import VideoOperateUtil from '../utils/VideoOperateUtil';
import { BusinessError } from '@ohos.base';
import PrivacySpaceUtil from '../utils/PrivacySpaceUtil';
import Preferences from '../database/Preferences';
import ToolsUtil from '../utils/ToolsUtil';
import { Pc, Privacy } from '../utils/ObservedUtil';
import { salmonLogger } from 'salmonlogger';

export default class EntryAbility extends UIAbility {
  watcher: hiAppEvent.Watcher | undefined = undefined

  async onCreate(want: Want) {
    const backgroundColorMode = Preferences.getBackgroundColorMode(this.context)
    ToolsUtil.setColorMode(this.context.getApplicationContext(), backgroundColorMode)
    //  PreferencesUtil.localPreferences(this.context, 'sweet_video')
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    AppStorage.setOrCreate('context', this.context)
    PathUtils.init(this.context);
    WantProcessUtil.want = want
    this.crashWatcher()
    this.initRedPlayer()
  }

  // 红薯播放器初始化
  initRedPlayer() {
    let configBuilder = new RedPlayerConfigBuilder()
    configBuilder.cachePath = this.context.cacheDir + '/red_player'
    configBuilder.logger = new LoggerImpl()
    RedPlayerInitManager.initPlayer(configBuilder)
    RedPlayerPreload.globalInit(this.context.cacheDir + '/red_player', 20, 4, 0)
  }

  //崩溃守卫
  crashWatcher() {
    // 构建崩溃事件的自定义参数
    let params: Record<string, hiAppEvent.ParamType> = {
      "test_data": 100,
    };
    // 崩溃事件的自定义参数
    hiAppEvent.setEventParam(params, hiAppEvent.domain.OS, hiAppEvent.event.APP_CRASH).then(() => {
      hilog.info(0x0000, 'testTag', `HiAppEvent success to set event param`);
    }).catch((err: BusinessError) => {
      hilog.error(0x0000, 'testTag', `HiAppEvent code: ${err.code}, message: ${err.message}`);
    });
    // 构建崩溃日志规格自定义参数
    let configParams: Record<string, hiAppEvent.ParamType> = {
      "extend_pc_lr_printing": true, // 使能扩展打印pc和lr寄存器附近的内存值
      "log_file_cutoff_sz_bytes": 102400, // 截断崩溃日志到100KB
      "simplify_vma_printing": true // 使能精简打印maps
    };

    // 设置崩溃日志配置参数
    hiAppEvent.setEventConfig(hiAppEvent.event.APP_CRASH, configParams).then(() => {
      hilog.info(0x0000, 'testTag', `HiAppEvent success to set event config.`);
    }).catch((err: BusinessError) => {
      hilog.error(0x0000, 'testTag', `HiAppEvent code: ${err.code}, message: ${err.message}`);
    });
    let events: string[] = [hiAppEvent.event.APP_CRASH, hiAppEvent.event.APP_FREEZE]
    // 需要编译API >= 20
    // if (deviceInfo.sdkApiVersion > 19) {
    //   events.push(hiAppEvent.event.APP_KILLED)
    // }
    // if (deviceInfo.sdkApiVersion > 19) {
    //   events.push(hiAppEvent.event.APP_KILLED)
    // }
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
    };
    try {
      if (this.watcher) {
        hiAppEvent.addWatcher(this.watcher);
      }
    } catch (error) {
      console.error('添加崩溃守卫失败' + error)
    }
  }

  // 应用在后台，接收外部应用拉起或者华为分享拉起
  async onNewWant(want: Want) {
    WantProcessUtil.want = want
    console.log(`onNewWant, want: ${want.abilityName}`);
  }

  onDestroy(): void {
    try {
      if (this.watcher) {
        hiAppEvent.removeWatcher(this.watcher);
      }
    } catch (error) {
      console.log('移除崩溃守卫失败' + error);
    }
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    try {
      if (canIUse('SystemCapability.Window.SessionManager')) {
        windowStage.setDefaultDensityEnabled(true); // 设置窗口不跟随系统显示大小变化重新布局
      }
    } catch (exception) {
      console.error(`Failed to set default density enabled. Cause code: ${exception.code}, message: ${exception.message}`);
    }
    try {
      salmonLogger.addLog('sweet_video', 'onWindowStageCreate success', false)
    } catch (error) {
      console.error('test error' + error)
    }
    // 进入启动页
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      VideoOperateUtil.windowStage = windowStage
      this.context.resourceManager.getStringValue($r('app.color.start_window_background_blur').id)
        .then(colorValue => {
          try {
            windowStage.getMainWindowSync().setWindowBackgroundColor(colorValue);
          } catch (error) {
            console.error('setWindowBackgroundColor error')
          }
        })
        .catch(() => {
          console.error('loadContent error')
        })
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
    });
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
      console.error('windowStageEvent error' + error)
    }
  }

  onWindowStageWillDestroy(): void {
    // 杀掉应用时保存播放记录
    const nowPlayingData =
      AppStorage.get('nowPlayingData') as (number | VideoMetadataFromPlayer | VideoMetadata[])[];
    if (nowPlayingData) {
      VideoOperateUtil.saveVideoTime(nowPlayingData[0] as number, nowPlayingData[1] as VideoMetadataFromPlayer,
        nowPlayingData[2] as VideoMetadata[], PathUtils.appContext!)
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
  }
}