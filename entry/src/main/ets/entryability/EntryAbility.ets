import { ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import WantProcessUtil from '../utils/WantProcessUtil';
import { RedPlayerConfigBuilder, RedPlayerInitManager, RedPlayerPreload } from '@rte-xhs/redplayer';
import LoggerImpl from '../utils/LoggerImpl';
import { PathUtils } from '../utils/PathUtils';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface';
import VideoOperateUtil from '../utils/VideoOperateUtil';

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want): Promise<void> {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
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

  // 应用在后台，接收外部应用拉起或者华为分享拉起
  async onNewWant(want: Want) {
    WantProcessUtil.want = want
    console.log(`onNewWant, want: ${want.abilityName}`);
  }

  onDestroy(): void {
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
      this.context.resourceManager.getStringValue($r('app.color.start_window_background_blur').id)
        .then(colorValue => {
          windowStage.getMainWindowSync().setWindowBackgroundColor(colorValue);
        });
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