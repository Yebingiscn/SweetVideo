import { router } from '@kit.ArkUI';
import PreferencesUtil from '../utils/PreferencesUtil';
import { common } from '@kit.AbilityKit';
import WantProcessUtil from '../utils/WantProcessUtil';

@Entry
@Component
struct SplashPage {
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

  onAgree(): void { //同意隐私政策
    if (this.privacyDialogController != undefined) {
      this.privacyDialogController.close()
    }
    this.isCheckPrivacy = true;
    //init(); // 在用户同意隐私政策后再调用此方法
    PreferencesUtil.putPreferencesValue("sweet_video", "IsPrivacy", true)
    this.initSdk()
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
  }

  initSdk() {
    //init();
    router.replaceUrl({ url: 'pages/Index', }, router.RouterMode.Single)
  }

  build() {
  }
}

@CustomDialog
@Component
struct PrivacyPolicyDialog {
  controller?: CustomDialogController
  cancel!: () => void
  confirm!: () => void

  build() {
    Stack() {
      Column() {
        Text('用户协议和隐私政策').fontSize(18).fontColor($r('sys.color.white')).margin({ top: 30, bottom: 19 })

        Scroll() {
          Text() {
            Span('欢迎使用本应用！为了保护您的隐私和使用安全，请仔细阅读我们的').fontColor($r('sys.color.white'))
            Span('《流心视频的使用条款与隐私声明》').fontColor($r('app.color.main_color')).onClick(() => {
              this.openWebUrl();
            })
            Span('。在确认您完全理解并同意之前，请不要使用此应用程序。谢谢！').fontColor($r('sys.color.white'))
          }.fontSize(16).fontColor('#666666').margin({
            left: 25,
            right: 25
          })
        }

        Column() {
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
              direction: GradientDirection.Right, colors: [[$r('app.color.main_color'), 0.0], ['#ff4859f6', 1.0]]
            })
            .width('80%')
            .margin({
              top: 15, bottom: 21
            })
            .borderRadius(24)
        }
      }
    }.backgroundColor($r('app.color.start_window_background')).borderRadius(13)
  }

  openWebUrl() {
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    let link: string = WantProcessUtil.PRIVACY_LINK
    WantProcessUtil.linkToWeb(context, link)
  }
}