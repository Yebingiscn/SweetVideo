import { router } from '@kit.ArkUI';
import PreferencesUtil from '../utils/PreferencesUtil';
import { common } from '@kit.AbilityKit';
import WantProcessUtil from '../utils/WantProcessUtil';

@Entry
@Component
struct SplashPage {
  @StorageLink('allowBackgroundPlay') allowBackgroundPlay: boolean = true
  @StorageLink('allowPlayBackExist') allowPlayBackExist: boolean = false
  @StorageLink('fastForwardSeconds') fastForwardSeconds: string = '15'
  @StorageLink('defaultPlayer') defaultPlayer: string = 'FFMpeg播放器'
  @StorageLink('subtitleSize') subtitleSize: string = '22'
  privacyDialogController: CustomDialogController | null = new CustomDialogController({
    builder: PrivacyPolicyDialog({
      confirm: () => {
        this.onAgree()
      },
      cancel: () => {
        this.onCancel()
      }
    }),
    autoCancel: false,
    //点击弹窗外，弹窗dismiss
    onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
      //点击返回键及框外
      if (dismissDialogAction.reason == DismissReason.PRESS_BACK) {
        //dismissDialogAction.dismiss()
      }
      if (dismissDialogAction.reason == DismissReason.TOUCH_OUTSIDE) {
        //dismissDialogAction.dismiss()
      }
    },
    alignment: DialogAlignment.Center,
    offset: { dx: 0, dy: -20 },
    gridCount: 4,
    customStyle: false,
    cornerRadius: 10,
  })
  @State isCheckPrivacy: boolean = false;

  onCancel(): void {
    (getContext(this) as common.UIAbilityContext)?.terminateSelf()
  }

  async onAgree(): Promise<void> { //同意隐私政策
    if (this.privacyDialogController != undefined) {
      this.privacyDialogController.close()
    }
    this.isCheckPrivacy = true;
    //init(); // 在用户同意隐私政策后再调用此方法
    PreferencesUtil.putPreferencesValue("sweet_video", "IsPrivacy", true)
    this.initSdk()
  }

  async initSetting() {
    const isInitSetting = await PreferencesUtil.getPreferencesValue("sweet_video", "isInitSetting", false) as boolean
    if (!isInitSetting) {
      PreferencesUtil.putPreferencesValue("sweet_video", "allowBackgroundPlay", this.allowBackgroundPlay)
      PreferencesUtil.putPreferencesValue("sweet_video", "fastForwardTime", this.fastForwardSeconds)
      PreferencesUtil.putPreferencesValue("sweet_video", "defaultPlayer", this.defaultPlayer)
      PreferencesUtil.putPreferencesValue("sweet_video", "subTitleSize", this.subtitleSize)
      PreferencesUtil.putPreferencesValue("sweet_video", "allowPlayBackExist", this.allowPlayBackExist)
      PreferencesUtil.putPreferencesValue("sweet_video", "isInitSetting", true)
    } else {
      this.allowBackgroundPlay =
        await PreferencesUtil.getPreferencesValue("sweet_video", "allowBackgroundPlay",
          this.allowBackgroundPlay) as boolean
      this.allowPlayBackExist = await PreferencesUtil.getPreferencesValue("sweet_video", "allowPlayBackExist",
        this.allowPlayBackExist) as boolean
      this.fastForwardSeconds =
        await PreferencesUtil.getPreferencesValue("sweet_video", "fastForwardTime", this.fastForwardSeconds) as string
      this.defaultPlayer =
        await PreferencesUtil.getPreferencesValue("sweet_video", "defaultPlayer", this.defaultPlayer) as string
      this.subtitleSize =
        await PreferencesUtil.getPreferencesValue("sweet_video", "subTitleSize", this.subtitleSize) as string
    }
  }

  async aboutToAppear(): Promise<void> {

  }

  aboutToDisappear(): void {
    this.privacyDialogController = null
  }

  async onPageShow(): Promise<void> {
    this.check()
  }

  async check() {
    this.isCheckPrivacy = await PreferencesUtil.getPreferencesValue("sweet_video", "IsPrivacy", false) as boolean
    if (!this.isCheckPrivacy) {
      if (this.privacyDialogController != null) {
        this.privacyDialogController.open()
      }
    } else {
      this.initSdk()
    }
    WantProcessUtil.checkWant()
  }

  async initSdk() {
    //init();
    this.privacyDialogController?.close()
    await this.initSetting()
    router.replaceUrl({ url: 'pages/Index' }, router.RouterMode.Single)
  }

  build() {
  }
}

@CustomDialog
@Component
struct PrivacyPolicyDialog {
  controller?: CustomDialogController
  cancel: () => void = () => {
  }; // 初始化为空函数
  confirm: () => void = () => {
  }; // 初始化为空函数

  build() {
    Stack() {
      Column() {
        Text('用户协议和隐私政策').fontSize(18).fontColor($r('app.color.text_color')).margin({ top: 30, bottom: 10 })
        Scroll() {
          Column() {
            Text() {
              Span('《流心视频的使用条款与隐私声明》').fontColor($r('app.color.main_color')).onClick(() => {
                this.openWebUrl();
              })
              Span('\n流心视频（以下简称“本软件”）是由 叶滨 （以下简称“我们”）开发，供您（以下称“用户”）免费使用的本地音乐播放软件。\n' +
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
                '生效日期：2025年1月4日').fontSize(12).fontColor($r('app.color.text_color'))
            }.fontSize(16).fontColor('#666666').margin({
              left: 25,
              right: 25
            })

            Button('不同意').onClick(() => {
              this.cancel();
            }).fontColor('#999999').fontSize(15).backgroundColor(Color.Transparent)
            Button('同意')
              .onClick(() => {
                this.confirm();
              })
              .fontColor($r('sys.color.white'))
              .fontSize(17)
              .linearGradient({
                direction: GradientDirection.Right, colors: [[$r('app.color.main_color'), 0.0], ['#ff48cdf6', 1.0]]
              })
              .width('80%')
              .margin({
                top: 15, bottom: 21
              })
              .borderRadius(24)
          }
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
    }.backgroundColor($r('app.color.start_window_background')).borderRadius(13)
  }

  openWebUrl() {
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    let link: string = WantProcessUtil.PRIVACY_LINK
    WantProcessUtil.linkToWeb(context, link)
  }
}