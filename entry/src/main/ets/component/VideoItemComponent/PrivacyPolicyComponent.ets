import Preferences from '../../database/Preferences';
import { OOBEVersion } from '../../utils/DataSyncUtil';
import { SafeHeight } from '../../utils/ObservedUtil';
import { PathUtils } from '../../utils/PathUtils';
import ToolsUtil from '../../utils/ToolsUtil';
import WantProcessUtil from '../../utils/WantProcessUtil';

@Component
export struct PrivacyPolicyComponent {
  @Link isPresent: boolean

  @Builder
  privacyInfoBuilder() {
    Column() {
      Scroll() {
        Text() {
          Span(`《${ToolsUtil.getStringResource($r('app.string.EntryAbility_label').id)}的使用条款与隐私声明》`)
            .fontColor($r('app.color.main_color'))
            .onClick(() => {
              this.openWebUrl();
            })
          Span('\n\n' +
            '流心播放器（以下简称“本软件”）是由 郴州液态科技有限公司 （以下简称“我们”）开发，供您（以下称“用户”）免费使用的本地音视频播放软件。\n' +
            '\n' +
            '一、服务与内容\n' +
            '\n' +
            '本软件为本地的单机应用程序，不依赖于任何在线服务，亦不会通过网络提供功能支持。\n' +
            '本软件不提供任何形式的音视频文件，包括但不限于视频、视频资源或流媒体服务。\n' +
            '用户需自行准备视频文件，并确保所使用的视频文件的合法性和合规性，我们对用户导入的视频内容不承担任何责任。\n\n' +
            '二、隐私政策\n' +
            '\n' +
            '为了确保用户体验，用户使用所产生的部分数据会存储于本应用的沙箱中。\n' +
            '本软件尊重用户的隐私，不会收集、存储或上传任何形式的用户数据。\n' +
            '本软件的所有功能均在本地设备上运行，用户的数据完全由用户自行管理。\n' +
            '如用户主动分享数据或将数据导出至其他平台，相关责任由用户自行承担。\n\n' +
            '三、用户的权利\n' +
            '\n' +
            '用户有权根据本条款的约定，合法安装、使用本软件，并享受本软件提供的所有功能。 用户有权接收并安装本软件的更新和升级版本，前提是这些更新和升级版本依然遵守本使用条款。\n 用户有权自行管理、删除其在本软件中的所有本地数据（如视频文件、播放记录等）。\n 用户有权向本软件的开发者提供反馈、建议，我们将酌情考虑。请注意，如果这样做，将会授予我们在本软件中无偿使用和加入用户建议的权力。\n' +
            '\n' +
            '四、著作权及使用限制\n' +
            '\n' +
            '本软件及其相关文档（包括但不限于界面设计、功能逻辑、源代码及其他内容）的著作权归我们所有，受中华人民共和国的法律保护。\n\n' +
            '五、打赏服务\n' +
            '\n' +
            '本软件所有基础功能完全免费，但设有打赏功能，允许用户向我们自愿提供经济支持。\n' +
            '一旦打赏完成，我们将不提供退款服务。\n' +
            '用户在使用打赏功能时，应遵循合法、合规的支付行为，我们对打赏行为的合法性不承担任何责任。\n\n' +
            '六、服务内容变更\n' +
            '\n' +
            '我们保留随时变更、中断或终止服务而无需另外通知的权力。\n' +
            '用户接受我们行使变更、中断或终止服务的权力，我们无需对用户或第三方负任何责任\n\n' +
            '生效日期：2025 年 10月 24日')
            .fontSize(12)
            .fontColor($r('app.color.text_color'))
        }
        .fontSize(15)
        .fontColor($r('app.color.text_color'))
      }.scrollBar(BarState.Off).width('100%').height('85%').padding({ left: 15, right: 15 })

      Row() {
        Button('拒绝并退出')
          .onClick(() => {
            PathUtils.appContext!.terminateSelf()?.catch((error: Error) => {
              ToolsUtil.showToast('关闭弹窗失败' + error)
            })
          })
          .fontColor(Color.Red)
          .fontSize(15)
          .backgroundColor(Color.Transparent)
          .align(Alignment.Center)
          .width('40%')

        Button('同意并继续')
          .onClick(() => {
            ToolsUtil.startVibration()
            Preferences.saveOOBEVersion(PathUtils.appContext!, OOBEVersion)
            this.isPresent = false; // 直接关闭弹窗
          })
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
          .fontColor($r('sys.color.white'))
          .fontSize(17)
          .linearGradient({
            direction: GradientDirection.Right,
            colors: [[$r('app.color.main_color'), 0.0], ['#ff48cdf6', 1.0]]
          })
          .width('40%')
          .borderRadius(16)
      }.width('100%')
      .height(60)
      .justifyContent(FlexAlign.SpaceEvenly)
    }
    .width('100%')
    .height('100%').margin({ bottom: SafeHeight.bottomSafeHeight })
  }

  build() {
    Stack() {
    }.bindSheet($$this.isPresent, this.privacyInfoBuilder, {
      detents: [SheetSize.FIT_CONTENT],
      height: SheetSize.LARGE,
      preferType: SheetType.CENTER,
      enableOutsideInteractive: false,
      showClose: false,
      dragBar: false,
      title: { title: '用户协议和隐私政策' },
      onWillDismiss: ((DismissSheetAction: DismissSheetAction) => {
        if (DismissSheetAction.reason == DismissReason.SLIDE_DOWN ||
          DismissSheetAction.reason == DismissReason.PRESS_BACK ||
          DismissSheetAction.reason == DismissReason.TOUCH_OUTSIDE) {
          PathUtils.appContext?.terminateSelf()?.catch(() => {
            console.error('exit app error')
          })
        }
      }),
    })
  }

  openWebUrl() {
    let link: string = WantProcessUtil.PRIVACY_LINK
    WantProcessUtil.linkToWeb(PathUtils.appContext!, link)
  }
}