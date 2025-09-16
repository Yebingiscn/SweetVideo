import WantProcessUtil from '../utils/WantProcessUtil';
import ToolsUtil from '../utils/ToolsUtil';
import { PathUtils } from '../utils/PathUtils';

@CustomDialog
@Component
export struct PrivacyPolicyDialog {
  controller?: CustomDialogController
  @State isPresent: boolean = false;
  cancel: () => void = () => {
  }; // 初始化为空函数
  confirm: () => void = () => {
  }; // 初始化为空函数

  @Builder
  privacyInfoBuilder() {
    Column() {
      Text() {
        Span('《' + getContext(this).resourceManager.getStringSync($r('app.string.EntryAbility_label').id) +
          '的使用条款与隐私声明》')
          .fontColor($r('app.color.main_color'))
          .onClick(() => {
            this.openWebUrl();
          })
        Span('\n' + getContext(this).resourceManager.getStringSync($r('app.string.EntryAbility_label').id) +
          '（以下简称“本软件”）是由 叶滨 （以下简称“我们”）开发，供您（以下称“用户”）免费使用的本地音乐播放软件。\n' +
          '\n' +
          '一、服务与内容\n' +
          '1. 本软件为本地的单机应用程序，不依赖于任何在线服务，亦不会通过网络提供功能支持。\n' +
          '2. 本软件不提供任何形式的视频文件，包括但不限于视频、视频资源或流媒体服务。\n' +
          '3. 用户需自行准备视频文件，并确保所使用的视频文件的合法性和合规性，我们对用户导入的视频内容不承担任何责任。\n\n' +
          '二、隐私政策\n' +
          '1. 本软件尊重用户的隐私，不会收集、存储或上传任何形式的用户数据。\n' +
          '2. 本软件的所有功能均在本地设备上运行，用户的数据完全由用户自行管理。\n' +
          '3. 如用户主动分享数据或将数据导出至其他平台，相关责任由用户自行承担。\n\n' +
          '三、用户的权利\n' +
          '1. 用户有权根据本条款的约定，合法安装、使用本软件，并享受本软件提供的所有功能。\n' +
          '2. 用户有权接收并安装本软件的更新和升级版本，前提是这些更新和升级版本依然遵守本使用条款。\n' +
          '3. 用户有权自行管理、删除其在本软件中的所有本地数据（如视频文件、播放记录等）。\n' +
          '4. 用户有权向本软件的开发者提供反馈、建议，我们将酌情考虑。\n' +
          '生效日期：2025年1月4日')
          .fontSize(12)
          .fontColor($r('app.color.text_color'))
      }
      .fontSize(15)
      .fontColor($r('app.color.text_color'))

      // 调整按钮布局
      Flex({
        wrap: FlexWrap.NoWrap,
        direction: FlexDirection.Row,
        justifyContent: FlexAlign.SpaceAround
      }) { // 子组件在容器主轴上行布局
        Button('拒绝并退出')
          .onClick(() => {
            this.cancel();
          })
          .fontColor(Color.Red)
          .fontSize(15)
          .backgroundColor(Color.Transparent)
          .align(Alignment.Center)
          .width('40%')

        Button('同意并继续')
          .onClick(() => {
            ToolsUtil.startVibration()
            this.confirm();
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
          .borderRadius(24)
      }
      .width('100%')
      .margin({ top: 20, bottom: 20 })
    }.backgroundImage($r("app.media.sweet_video"))
    .backgroundImagePosition(Alignment.Center)
    .backdropBlur(150)
    .padding({ left: 15, right: 15 })
  }

  build() {
    Stack() {
    }.bindSheet($$this.isPresent, this.privacyInfoBuilder(), {
      height: SheetSize.FIT_CONTENT,
      preferType: SheetType.CENTER,
      enableOutsideInteractive: false,
      showClose: false,
      title: { title: '用户协议和隐私政策' },
      onWillDismiss: ((DismissSheetAction: DismissSheetAction) => {
        if (DismissSheetAction.reason == DismissReason.SLIDE_DOWN ||
          DismissSheetAction.reason == DismissReason.PRESS_BACK ||
          DismissSheetAction.reason == DismissReason.TOUCH_OUTSIDE) {
          PathUtils.appContext?.terminateSelf()
        }
      }),
    })
    .onAppear(() => {
      this.isPresent = !this.isPresent;
    })
  }

  openWebUrl() {
    let link: string = WantProcessUtil.PRIVACY_LINK
    WantProcessUtil.linkToWeb(PathUtils.appContext!, link)
  }
}