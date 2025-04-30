import { common, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import WantProcess from '../utils/WantProcessUtil';
import WantProcessUtil from '../utils/WantProcessUtil';
import { WindowUtil } from '../utils/WindowUtil';
import { systemShare } from '@kit.ShareKit';
import { BusinessError } from '@kit.BasicServicesKit';

const context = getContext() as common.UIAbilityContext;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    //  PreferencesUtil.localPreferences(this.context, 'sweet_video')
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    AppStorage.setOrCreate('context', this.context)
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    // 检测是否应用未启动时外部应用拉起，检测相应链接，适用于文件管理器
    if (want.uri) {
      WantProcess.want_uri = want.uri
    }
    // 检测是否应用未启动时通过华为分享拉起，检测相应链接，适用于相册
    this.handleParam(want, false)
  }

  // 华为分享拉起接收
  handleParam(want: Want, isNewWant: boolean) {
    systemShare.getSharedData(want)
      .then((data: systemShare.SharedData) => {
        data.getRecords().forEach((record: systemShare.SharedRecord) => {
          WantProcess.want_uri = record.uri!
          WantProcess.isSystemShare = true
          if (isNewWant) {
            WantProcessUtil.checkWant(context)
          }
          return
        });
      })
      .catch((error: BusinessError) => {
        console.error(`Failed to getSharedData. Code: ${error.code}, message: ${error.message}`);
      })
  }

  // 应用在后台，接收外部应用拉起或者华为分享拉起
  onNewWant(want: Want) {
    this.handleParam(want, true)
    if (want.uri) {
      WantProcess.want_uri = want.uri
    }
    console.log(`onNewWant, want: ${want.abilityName}`);
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    // 进入启动页
    windowStage.loadContent('pages/PrivacyInfo', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      WindowUtil.getInstance().setWindowStage(windowStage);
      AppStorage.setOrCreate('windowStage', windowStage);
      windowStage.getMainWindowSync().setWindowBackgroundColor('#DCDCDC'); // 配置窗口整体底色
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
    });
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