import { loginComponentManager, LoginWithHuaweiIDButton } from '@kit.AccountKit';
import { hdsEffect } from '@kit.UIDesignKit';
import { HdsGL } from '../../common/AttributeModifierConfig';
import { PathUtils } from '../../utils/PathUtils';
import Preferences from '../../database/Preferences';
import AccountUtil from '../../utils/AccountUtil';
import { DANGER_COLOR } from '../../common/Constants';
import { XAnimation } from '../../utils/AnimationUtil';
import { SafeHeight } from '../../utils/ObservedUtil';
import SelectFileUtil from '../../utils/SelectFileUtil';
import { FunctionalButton, functionalButtonComponentManager } from '@kit.ScenarioFusionKit';
import { curves } from '@kit.ArkUI';

@Builder
export function userLoginBuilder() {
  userLoginComponent()
}

@ObservedV2
export default class UserInfoData {
  @Trace isLogin: boolean = false
  @Trace userAvatar: ResourceStr = ''
  @Trace nickName: string | undefined
  @Trace authorizationCode: string = ''
  @Trace unionID: string = ''
  @Trace openID: string = ''
  @Trace idToken: string = ''
}

export let userData: UserInfoData = new UserInfoData()

@ComponentV2
struct userLoginComponent {
  userData: UserInfoData = userData
  @Local button_gradient_state: hdsEffect.PressShadowType = hdsEffect.PressShadowType.NONE
  @Local button_Light_state: hdsEffect.PointLightSourceType = HdsGL.sourceTypes[0]
  controller: loginComponentManager.LoginWithHuaweiIDButtonController =
    new loginComponentManager.LoginWithHuaweiIDButtonController()
      .setAgreementStatus(loginComponentManager.AgreementStatus.NOT_ACCEPTED)
      .onClickLoginWithHuaweiIDButton((error: BusinessError, response: loginComponentManager.HuaweiIDCredential) => {
        if (error) {
          AccountUtil.dealAllError(error)
          return
        }
        if (response) {
          Preferences.saveUserAuthorizationCode(PathUtils.appContext!, response.authorizationCode)
          Preferences.saveUserUnionID(PathUtils.appContext!, response.unionID)
          Preferences.saveUserOpenID(PathUtils.appContext!, response.openID)
          Preferences.saveUserIdToken(PathUtils.appContext!, response.idToken!)
          Preferences.saveUserIsLogin(PathUtils.appContext!, true)
          userData.authorizationCode = response.authorizationCode
          userData.unionID = response.unionID
          userData.openID = response.openID
          userData.idToken = response.idToken!
          AccountUtil.getAvatarFromHuaweiAccount(() => {
            userData.isLogin = true
          })
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
                  .backgroundColor($r('sys.color.scrollbar_color_foreground'))
              },
            },
            // When OpenType is set to CHOOSE_AVATAR, the callback must be onChooseAvatar.
            controller: new functionalButtonComponentManager.FunctionalButtonController().onChooseAvatar(async (err,
              data) => {
              if (err) {
                // Error processing.
                return
              }
              try {
                this.userData.userAvatar = data.avatarUri!
                const pixelMap = await AccountUtil.fileToPixelMap(data.avatarUri!)
                const localAvatarUri = await SelectFileUtil.savePixelMapToFile(PathUtils.photoPath!, 'avatar', pixelMap)
                Preferences.saveUserAvatar(PathUtils.appContext!, localAvatarUri)
              } catch (err) {
                AccountUtil.dealAllError(err)
              }
            })
          })
        }
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
              this.button_gradient_state = hdsEffect.PressShadowType.NONE
              this.button_Light_state = HdsGL.sourceTypes[2]
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.button_gradient_state = hdsEffect.PressShadowType.NONE
              this.button_Light_state = HdsGL.sourceTypes[0]
            }
          })
        })

        Column() {
          Text(this.userData.nickName)
            .padding({ top: 3, bottom: 5 })
            .borderRadius(20)
            .transition(XAnimation.getAnimation('bottom'))
            .visualEffect(new hdsEffect.HdsEffectBuilder().pointLight({ illuminatedType: HdsGL.illuminatedType[1] })
              .buildEffect())
          Button('退出登录')
            .fontColor(Color.White)
            .fontSize(15)
            .backgroundColor(DANGER_COLOR)
            .align(Alignment.Center)
            .margin({ top: 10, bottom: 10 })
            .onClick(async () => {
              userData.isLogin = false
              userData.authorizationCode = ''
              userData.unionID = ''
              userData.openID = ''
              userData.nickName = undefined
              userData.idToken = ''
              await SelectFileUtil.deletePhoto('avatar')
              Preferences.saveUserIsLogin(PathUtils.appContext!, false)
              Preferences.saveUserAvatar(PathUtils.appContext!, '')
              Preferences.saveUserAuthorizationCode(PathUtils.appContext!, '')
              Preferences.saveUserUnionID(PathUtils.appContext!, '')
              Preferences.saveUserOpenID(PathUtils.appContext!, '')
              Preferences.saveUserIdToken(PathUtils.appContext!, '')
              Preferences.saveUserNickName(PathUtils.appContext!, '')
              userData.userAvatar = ''
              this.controller.setAgreementStatus(loginComponentManager.AgreementStatus.NOT_ACCEPTED)
            })
        }.padding({ bottom: SafeHeight.bottomSafeHeight })

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
        }.padding({ bottom: SafeHeight.bottomSafeHeight })
      }
    }
  }
}