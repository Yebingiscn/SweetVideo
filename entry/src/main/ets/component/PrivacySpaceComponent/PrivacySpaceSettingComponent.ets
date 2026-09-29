import NavigationAddress from '../../common/NavigationCommon'
import Preferences from '../../database/Preferences'
import DlpAntiPeepUtil from '../../utils/DlpAntiPeepUtil'
import { Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import { SettingsClickItem } from '../SettingComponent/SettingsClickItem'
import { SettingsToggleItem } from '../SettingComponent/SettingsToggleItem'
import { PrivacyAuthMode } from '../../common/enum/PrivacyAuthMode'
import BiometricAccessUtil from '../../utils/BiometricAccessUtil'
import { userAuth } from '@kit.UserAuthenticationKit'
import {
  SettingsItemModifier,
  SettingsTitleModifier,
  SymbolGlyphFancyModifier
} from '../../common/AttributeModifierConfig'
import ToolsUtil from '../../utils/ToolsUtil'

@ComponentV2
export struct PrivacySpaceSettingComponent {
  @Param isPresent: boolean = false
  @Param passwd: string = ''
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Event onIsPresentChange: (v: boolean) => void = () => {
  }
  @Event onEditPasswdDialogOpen: () => void = () => {
  }

  @Local authModeOptions: SelectOption[] = []
  @Local authModeSelected: number = 0

  aboutToAppear(): void {
    this.refreshAuthModeOptions()
  }

  private refreshAuthModeOptions() {
    const options: SelectOption[] = []
    if (BiometricAccessUtil.checkAuthTypeSupported(userAuth.UserAuthType.FACE)) {
      options.push({ value: ToolsUtil.getStringResource($r('app.string.privacy_auth_mode_face').id) })
    }
    if (BiometricAccessUtil.checkAuthTypeSupported(userAuth.UserAuthType.FINGERPRINT)) {
      options.push({ value: ToolsUtil.getStringResource($r('app.string.privacy_auth_mode_fingerprint').id) })
    }
    options.push({ value: ToolsUtil.getStringResource($r('app.string.privacy_auth_mode_password').id) })
    this.authModeOptions = options

    const currentMode = Setting.privacyAuthMode
    const faceLabel = ToolsUtil.getStringResource($r('app.string.privacy_auth_mode_face').id)
    const fingerprintLabel = ToolsUtil.getStringResource($r('app.string.privacy_auth_mode_fingerprint').id)
    const passwordLabel = ToolsUtil.getStringResource($r('app.string.privacy_auth_mode_password').id)
    if (currentMode === PrivacyAuthMode.FACE && options.some(o => o.value === faceLabel)) {
      this.authModeSelected = options.findIndex(o => o.value === faceLabel)
    } else if (currentMode === PrivacyAuthMode.FINGERPRINT && options.some(o => o.value === fingerprintLabel)) {
      this.authModeSelected = options.findIndex(o => o.value === fingerprintLabel)
    } else {
      this.authModeSelected = options.findIndex(o => o.value === passwordLabel)
    }
  }

  private onAuthModeChange(index: number) {
    const selected = this.authModeOptions[index]?.value ?? ''
    const faceLabel = ToolsUtil.getStringResource($r('app.string.privacy_auth_mode_face').id)
    const fingerprintLabel = ToolsUtil.getStringResource($r('app.string.privacy_auth_mode_fingerprint').id)
    if (selected === faceLabel) {
      Setting.privacyAuthMode = PrivacyAuthMode.FACE
    } else if (selected === fingerprintLabel) {
      Setting.privacyAuthMode = PrivacyAuthMode.FINGERPRINT
    } else {
      Setting.privacyAuthMode = PrivacyAuthMode.PASSWORD
    }
    Preferences.savePrivacyAuthMode(PathUtils.appContext!, Setting.privacyAuthMode)
  }

  build() {
    Column() {
      SettingsClickItem({
        symbol: $r('sys.symbol.lock'),
        message: '重设密码',
        onPress: () => {
          this.onIsPresentChange(false)
          this.onEditPasswdDialogOpen()
        }
      })

      Row() {
        SymbolGlyph($r('sys.symbol.lock_shield'))
          .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
        Text($r('app.string.privacy_auth_mode_title'))
          .attributeModifier(new SettingsTitleModifier())
          .layoutWeight(1)
        Select(this.authModeOptions)
          .selected(this.authModeSelected)
          .value(this.authModeOptions[this.authModeSelected]?.value ?? '密码')
          .font({ size: 16 })
          .selectedOptionFont({ size: 16, weight: FontWeight.Medium })
          .optionFont({ size: 16 })
          .backgroundColor($r('app.color.start_window_background_blur'))
          .borderRadius(8)
          .width(100)
          .onSelect((index: number) => {
            this.authModeSelected = index
            this.onAuthModeChange(index)
          })
      }
      .width('100%')
      .height(55)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .attributeModifier(new SettingsItemModifier())

      SettingsToggleItem({
        symbol: $r('sys.symbol.checkmark_shield'),
        message: '设置中显示入口',
        enable: Setting.showSettingPageEntry,
        onChange: (checked: boolean) => {
          Setting.showSettingPageEntry = checked
          Preferences.saveShowSettingPageEntry(PathUtils.appContext!, Setting.showSettingPageEntry)
        }
      })

      SettingsToggleItem({
        symbol: $r('sys.symbol.arrow_up_left_and_arrow_down_right'),
        message: '首页双指捏合往外划开进入',
        enable: Setting.allowGestureEntry,
        onChange: (checked: boolean) => {
          Setting.allowGestureEntry = checked
          Preferences.saveAllowGestureEntry(PathUtils.appContext!, Setting.allowGestureEntry)
        }
      })

      SettingsToggleItem({
        symbol: $r('sys.symbol.private_browsing_mode'),
        message: 'AI隐私防窥',
        enable: Setting.enableAiPrivacyAntiPeep,
        onChange: (checked: boolean) => {
          Setting.enableAiPrivacyAntiPeep = checked
          Preferences.saveEnableAiPrivacyAntiPeep(PathUtils.appContext!, Setting.enableAiPrivacyAntiPeep)
          if (checked) {
            DlpAntiPeepUtil.checkDlpAntiPeepStatus()
          } else {
            DlpAntiPeepUtil.closeDlpAntiPeepStatus()
          }
        }
      })

      SettingsClickItem({
        symbol: $r('sys.symbol.staroflife_rectangle'),
        message: '有视频不见了？点这里',
        onPress: () => {
          this.onIsPresentChange(false)
          this.pathStack.pushPathByName(NavigationAddress.PRIVACY_ERROR_LIST, true)
        }
      })

      Column({ space: 8 }) {
        Text('清理提示')
          .fontSize(20).fontWeight(FontWeight.Medium)
        Text('删除隐私空间的视频后，系统存储中的占用情况可能不会立即刷新。若需要查看准确的空间释放情况，建议重启手机。')
          .fontSize(15)
      }
      .padding(15)
      .alignItems(HorizontalAlign.Start)
      .borderRadius(16)
      .width('100%')
      .backgroundColor($r('app.color.start_window_background_blur'))
      .margin({ top: 10 })
    }.width('100%').height('100%').padding({ left: 16, right: 16 })
  }
}