import { loginComponentManager, LoginWithHuaweiIDButton } from '@kit.AccountKit';
import { LoginWithHWErrorCode } from '../../common/Constants';
import ToolsUtil from '../../utils/ToolsUtil';
import { FunctionalButton, functionalButtonComponentManager } from '@kit.ScenarioFusionKit';
import { XAnimation } from '../../utils/AnimationUtil';
import { hdsEffect } from '@kit.UIDesignKit';
import { HdsGL } from '../../common/AttributeModifierConfig';
import { curves } from '@kit.ArkUI';

@Builder
export function userLoginBuilder() {
  userLoginComponent()
}

@ObservedV2
export class UserData {
  @Trace isLogin: boolean = false
  @Trace userAvatar: ResourceStr = ''
  @Trace nickName: string | undefined
  @Trace authorizationCode: string = ''
  @Trace unionID: string = ''
  @Trace openID: string = ''
  @Trace idToken: string = ''
}

@ComponentV2
struct userLoginComponent {
  @Consumer('UserData') userData: UserData = new UserData()
  @Local button_gradient_state: hdsEffect.PressShadowType = hdsEffect.PressShadowType.NONE;
  @Local button_Light_state: hdsEffect.PointLightSourceType = HdsGL.sourceTypes[0]
  controller: loginComponentManager.LoginWithHuaweiIDButtonController =
    new loginComponentManager.LoginWithHuaweiIDButtonController()
      .setAgreementStatus(loginComponentManager.AgreementStatus.NOT_ACCEPTED)
      .onClickLoginWithHuaweiIDButton((error: BusinessError, response: loginComponentManager.HuaweiIDCredential) => {
        if (error) {
          this.dealAllError(error)
          return
        }
        if (response) {
          // 获取到Authorization Code
          // PreferencesUtil.putPreferencesValue("ownWorld", "authorizationCode", response.authorizationCode);
          // PreferencesUtil.putPreferencesValue("ownWorld", "unionID", response.unionID);
          // PreferencesUtil.putPreferencesValue("ownWorld", "openID", response.openID);
          // PreferencesUtil.putPreferencesValue("ownWorld", "idToken", response.idToken!);
          // PreferencesUtil.putPreferencesValue("ownWorld", "isLogin", true);
          // console.log(`Liquid:Succeeded in getting response.`);
          // getAvatarFromHuaweiAccount()
          // __User__.isLogin = true
          // __User__.authorizationCode = response.authorizationCode;
          // __User__.unionID = response.unionID;
          // __User__.openID = response.openID;
          // __User__.idToken = response.idToken!;
          return
        }
      })

  build() {
    if (this.userData.isLogin) {
      Column({ space: 15 }) {
        Button() {
          FunctionalButton({
            params: {
              // OpenType.CHOOSE_AVATAR indicates that the button is used to select an avatar.
              openType: functionalButtonComponentManager.OpenType.CHOOSE_AVATAR,
              label: '',
              // Adjust the button style.
              styleOption: {
                styleConfig: new functionalButtonComponentManager.ButtonConfig()
                  .type(ButtonType.Circle)
                  .backgroundImage(this.userData.userAvatar)
                  .backgroundImageSize(ImageSize.Contain)
                  .width(150)
                  .height(150)
                  .backgroundColor('#E5E5E5')
              },
            },
            // When OpenType is set to CHOOSE_AVATAR, the callback must be onChooseAvatar.
            controller: new functionalButtonComponentManager.FunctionalButtonController().onChooseAvatar(async (err,
              data) => {
              if (err) {
                // Error processing.
                return;
              }
              try {
                this.userData.userAvatar = data.avatarUri!


              } catch (err) {
              }
              // Success processing.
            })
          })
            .transition(XAnimation.getAnimation('bottom'))
            .backgroundColor(Color.Transparent)
            .borderRadius('100%')
            .visualEffect(new hdsEffect.HdsEffectBuilder()
              .pressShadow(this.button_gradient_state)
              .pointLight({ sourceType: this.button_Light_state, illuminatedType: HdsGL.illuminatedType[1] })
              .buildEffect()
            )
            .onTouch((event: TouchEvent) => {
              this.getUIContext().animateTo({ duration: 300, curve: curves.responsiveSpringMotion(0.4, 0.75) }, () => {
                if (event.type === TouchType.Down) {
                  this.button_gradient_state = hdsEffect.PressShadowType.NONE;
                  this.button_Light_state = HdsGL.sourceTypes[2]
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.button_gradient_state = hdsEffect.PressShadowType.NONE;
                  this.button_Light_state = HdsGL.sourceTypes[0]
                }
              })
            })
        }

        Column() {
          Text('用户昵称：' + this.userData.nickName)
          Button('退出登录')
        }

      }
    } else {
      Column({ space: 10 }) {
        Row() {
          Column() {
            Image($r('app.media.Foreground'))
              .aspectRatio(1)
              .draggable(false)
              .layoutWeight(1)
              .objectFit(ImageFit.Contain)
              .constraintSize({ maxWidth: 200, maxHeight: 200 })
            Text($r('app.string.EntryAbility_label'))
              .fontSize(36)
              .fontWeight(FontWeight.Bold)
              .opacity(0.9)
              .maxLines(1)
              .margin({ top: 5 })
              .fontColor('#ff004d99')
              .margin({ bottom: 30 })
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
        }
        .visualEffect(new hdsEffect.HdsEffectBuilder().pointLight({ illuminatedType: HdsGL.illuminatedType[1] })
          .buildEffect())
        .backgroundImage($r('app.media.Background'))
        .borderRadius(20)
        .clip(true)
        .backgroundImageSize(ImageSize.FILL)
        .margin({ right: 16, left: 16 })
        .layoutWeight(1)
        .padding(20)

        LoginWithHuaweiIDButton({
          params: {
            style: loginComponentManager.Style.BUTTON_RED,
            extraStyle: {
              buttonStyle: new loginComponentManager.ButtonStyle().loadingStyle({
                show: true
              })
            },
            borderRadius: 20,
            loginType: loginComponentManager.LoginType.ID,
            supportDarkMode: true,
            riskLevel: true,

          },
          controller: this.controller
        }).size({ height: 38, width: 250 })
        Row() {
          Toggle({ type: ToggleType.Checkbox })
            .size({ width: 20, height: 20 })
            .onChange((isOn: boolean) => {
              if (isOn) {
                this.controller.setAgreementStatus(loginComponentManager.AgreementStatus.ACCEPTED)
              } else {
                this.controller.setAgreementStatus(loginComponentManager.AgreementStatus.NOT_ACCEPTED)
              }
            })
          Text('我已阅读并同意')
        }
      }
    }
  }

  // 错误处理
  dealAllError(error: BusinessError): void {
    console.log(`Liquid:Failed to login, errorCode=${error.code}, errorMsg=${error.message}`)
    // 在应用登录涉及UI交互场景下，建议按照如下错误码指导提示用户
    if (error.code === LoginWithHWErrorCode.ERROR_CODE_LOGIN_OUT) {
      // 用户未登录华为账号，请登录华为账号并重试或者尝试使用其他方式登录
      ToolsUtil.showToast('用户未登录华为账号，请登录华为账号并重试或者尝试使用其他方式登录')
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_NETWORK_ERROR) {
      // 网络异常，请检查当前网络状态并重试或者尝试使用其他方式登录
      ToolsUtil.showToast('网络异常，请检查当前网络状态并重试或者尝试使用其他方式登录')
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_INTERNAL_ERROR) {
      // 登录失败，请尝试使用其他方式登录
      ToolsUtil.showToast('登录失败，请尝试使用其他方式登录')
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_USER_CANCEL) {
      // 用户取消授权
      ToolsUtil.showToast('用户取消授权')
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_SYSTEM_SERVICE) {
      ToolsUtil.showToast('系统服务异常，请稍后重试或者尝试使用其他方式登录')
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_REQUEST_REFUSE) {
      // 重复请求，应用无需处理
    } else if (error.code === LoginWithHWErrorCode.ERROR_CODE_AGREEMENT_STATUS_NOT_ACCEPTED) {
      // 用户未同意协议
      // this.startAnimation()
    } else {
      ToolsUtil.showToast('应用登录失败，请尝试使用其他方式登录')
      // 应用登录失败，请尝试使用其他方式登录
    }
  }
}
