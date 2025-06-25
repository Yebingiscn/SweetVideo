import { ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import WantProcess from '../utils/WantProcessUtil';
import WantProcessUtil from '../utils/WantProcessUtil';
import { systemShare } from '@kit.ShareKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { RedPlayerConfigBuilder, RedPlayerInitManager, RedPlayerPreload } from '@rte-xhs/redplayer';
import LoggerImpl from '../utils/LoggerImpl';
import { PathUtils } from '../utils/PathUtils';

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want): Promise<void> {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    //  PreferencesUtil.localPreferences(this.context, 'sweet_video')
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    AppStorage.setOrCreate('context', this.context)
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    PathUtils.init(this.context);
    // 检测是否应用未启动时外部应用拉起，检测相应链接，适用于文件管理器
    if (want.uri) {
      WantProcess.want_uri = want.uri
      WantProcessUtil.has_new_want = true
    }
    // 检测是否应用未启动时通过华为分享拉起，检测相应链接，适用于相册
    await this.handleParam(want)
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

  // 华为分享拉起接收
  // 1. 改造 handleParam 为异步函数，让其返回 Promise
  async handleParam(want: Want) {
    try {
      // 通过 await 等待异步操作完成
      const data = await systemShare.getSharedData(want);
      const records = data.getRecords();
      for (const record of records) {
        if (record.uri) {
          WantProcess.want_uri = record.uri;
          WantProcess.isSystemShare = true;
          WantProcessUtil.has_new_want = true;
          break;
        }
      }
    } catch (error) {
      const businessError = error as BusinessError;
      console.error(`Failed: Code ${businessError.code}, ${businessError.message}`);
    }
  }

  // 应用在后台，接收外部应用拉起或者华为分享拉起
  async onNewWant(want: Want) {
    await this.handleParam(want)
    if (want.uri) {
      WantProcess.want_uri = want.uri
      WantProcessUtil.has_new_want = true
    }
    console.log(`onNewWant, want: ${want.abilityName}`);
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    try {
      windowStage.setDefaultDensityEnabled(true); // 设置窗口不跟随系统显示大小变化重新布局
    } catch (exception) {
      console.error(`Failed to set default density enabled. Cause code: ${exception.code}, message: ${exception.message}`);
    }
    // 进入启动页
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      AppStorage.setOrCreate('windowStage', windowStage);
      this.context.resourceManager.getStringValue($r('app.color.start_window_background_blur').id)
        .then(colorValue => {
          windowStage.getMainWindowSync().setWindowBackgroundColor(colorValue);
        });
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageWillDestroy(): void {
    AppStorage.setOrCreate('destroy_signal', true) // 提示播放器保存记录
    console.error('test will destroy')
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