import { ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
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

export default class EntryAbility extends UIAbility {
  watcher: hiAppEvent.Watcher | undefined = undefined

  async onCreate(want: Want): Promise<void> {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (error) {
      console.error('sweet video error set color mode error')
    }
    //  PreferencesUtil.localPreferences(this.context, 'sweet_video')
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    AppStorage.setOrCreate('context', this.context)
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    PathUtils.init(this.context);
    WantProcessUtil.want = want
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
    this.watcher = {
      // 自定义观察者名称，系统会使用名称来标识不同的观察者
      name: "watcher",
      // 可以订阅感兴趣的系统事件，此处是订阅了崩溃事件
      appEventFilters: [
        {
          domain: hiAppEvent.domain.OS,
          names: [hiAppEvent.event.APP_CRASH]
        }
      ],
      // 自行实现订阅实时回调函数，以便对订阅获取到的事件数据进行自定义处理
      onReceive: (domain: string, appEventGroups: Array<hiAppEvent.AppEventGroup>) => {
        hilog.info(0x0000, 'testTag', `HiAppEvent onReceive: domain=${domain}`);
        for (const eventGroup of appEventGroups) {
          // 开发者可以根据事件集合中的事件名称区分不同的系统事件
          hilog.info(0x0000, 'testTag', `HiAppEvent eventName=${eventGroup.name}`);
          for (const eventInfo of eventGroup.appEventInfos) {
            // 开发者可以对事件集合中的事件数据进行自定义处理，此处是将事件数据打印在日志中
            hilog.info(0x0000, 'testTag', `HiAppEvent eventInfo.domain=${eventInfo.domain}`);
            hilog.info(0x0000, 'testTag', `HiAppEvent eventInfo.name=${eventInfo.name}`);
            hilog.info(0x0000, 'testTag', `HiAppEvent eventInfo.eventType=${eventInfo.eventType}`);
            // 开发者可以获取到崩溃事件发生的时间戳
            hilog.info(0x0000, 'testTag', `HiAppEvent eventInfo.params.time=${eventInfo.params['time']}`);
            // 开发者可以获取到崩溃事件发生的崩溃类型
            hilog.info(0x0000, 'testTag', `HiAppEvent eventInfo.params.crash_type=${eventInfo.params['crash_type']}`);
            // 开发者可以获取到崩溃应用的前后台状态
            hilog.info(0x0000, 'testTag', `HiAppEvent eventInfo.params.foreground=${eventInfo.params['foreground']}`);
            // 开发者可以获取到崩溃应用的版本信息
            hilog.info(0x0000, 'testTag',
              `HiAppEvent eventInfo.params.bundle_version=${eventInfo.params['bundle_version']}`);
            // 开发者可以获取到崩溃应用的包名
            hilog.info(0x0000, 'testTag', `HiAppEvent eventInfo.params.bundle_name=${eventInfo.params['bundle_name']}`);
            // 开发者可以获取到崩溃应用的进程id
            hilog.info(0x0000, 'testTag', `HiAppEvent eventInfo.params.pid=${eventInfo.params['pid']}`);
            hilog.info(0x0000, 'testTag', `HiAppEvent eventInfo.params.uid=${eventInfo.params['uid']}`);
            hilog.info(0x0000, 'testTag', `HiAppEvent eventInfo.params.uuid=${eventInfo.params['uuid']}`);
            // 开发者可以获取到崩溃事件发生的异常类型、异常原因和异常调用栈
            hilog.info(0x0000, 'testTag',
              `HiAppEvent eventInfo.params.exception=${JSON.stringify(eventInfo.params['exception'])}`);
            // 开发者可以获取到崩溃事件发生时日志信息
            hilog.info(0x0000, 'testTag', `HiAppEvent eventInfo.params.hilog.size=${eventInfo.params['hilog'].length}`);
            // 开发者可以获取到崩溃事件发生时的崩溃日志文件
            hilog.info(0x0000, 'testTag',
              `HiAppEvent eventInfo.params.external_log=${JSON.stringify(eventInfo.params['external_log'])}`);
            hilog.info(0x0000, 'testTag',
              `HiAppEvent eventInfo.params.log_over_limit=${eventInfo.params['log_over_limit']}`);
            // 开发者可以获取到崩溃事件的自定义数据test_data
            hilog.info(0x0000, 'testTag', `HiAppEvent eventInfo.params.test_data=${eventInfo.params['test_data']}`);
          }
        }
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
    // 进入启动页
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      VideoOperateUtil.windowStage = windowStage
      try {
        windowStage.getMainWindowSync().setWindowBackgroundColor("#000000");
      } catch (error) {
        console.error('配置窗口底色失败：' + error)
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
    });
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