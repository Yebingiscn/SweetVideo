import { MpvPlaybackEffects } from '../../controller/MpvController/MpvPlaybackEffects'
import { UsbAudioSession } from '../../utils/UsbAudioSession'
import ToolsUtil from '../../utils/ToolsUtil'
import { SettingsMenuItem } from '../../component/SettingComponent/SettingsMenuItem'
import { SettingsSegmentButtonItem } from '../../component/SettingComponent/SettingsSegmentButtonItem'
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem'
import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem'
import {
  SettingsItemModifier,
  SettingsTitleModifier,
  SymbolGlyphFancyModifier
} from '../../common/AttributeModifierConfig'
import { MpvConfigStore } from '../../utils/MpvConfigStore'
import { picker } from '@kit.CoreFileKit'
import { MpvDecodingMethod, MpvGpuApi } from '../../controller/MpvController/MpvTypes'
import Preferences from '../../database/Preferences'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import { userData } from '../../component/common/UserLoginComponent'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { LengthMetrics } from '@kit.ArkUI'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'

@ComponentV2
export struct EngineSettingPage {
  private listScroller: Scroller = new Scroller()
  @Local private usbNames: string[] = [ToolsUtil.getStringResource($r('app.string.usb_auto_select').id)]
  private usbIds: string[] = ['']
  @Local private confEnabled: boolean = false
  @Local private confVisible: boolean = false
  @Local private confDraft: string = ''
  @Local private confBusy: boolean = false
  @Local private confError: string = ''

  aboutToAppear(): void {
    try {
      this.confEnabled = MpvConfigStore.enabled()
    } catch (_error) {
      this.confEnabled = false
    }
    try {
      const devices = UsbAudioSession.devices()
      this.usbIds = [''].concat(devices.map(device => UsbAudioSession.deviceKey(device)))
      this.usbNames = [ToolsUtil.getStringResource($r('app.string.usb_auto_select').id)].concat(
        devices.map(device => device.productName || device.name))
    } catch (error) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.usb_query_unsupported').id))
    }
    if (Setting.mpvUsbDevice && !this.usbIds.includes(Setting.mpvUsbDevice)) {
      this.usbIds.push(Setting.mpvUsbDevice)
      this.usbNames.push(ToolsUtil.getStringResource($r('app.string.usb_device_disconnected').id))
    }
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  build() {
    HdsNavDestination() {
      List({ scroller: this.listScroller }) {
        ListItem() {
          SettingsMenuItem({
            symbol: $r('sys.symbol.play_round_rectangle'),
            message: ToolsUtil.getStringResource($r('app.string.default_player_engine').id),
            list: VideoInfoUtil.playerEngineList,
            selected: Math.max(VideoInfoUtil.playerEngineList.findIndex(i => i == Setting.defaultPlayerEngine), 0),
            onChange: (index: number) => {
              Setting.defaultPlayerEngine = VideoInfoUtil.playerEngineList[index]
              Preferences.saveDefaultPlayerEngine(PathUtils.appContext!, Setting.defaultPlayerEngine)
            }
          })
        }

        ListItem() {
          Column({ space: 4 }) {
            this.ConfToggle()
            SettingsClickItem({
              symbol: $r('sys.symbol.hardware'),
              message: $r('app.string.mpv_conf_edit'),
              onPress: () => {
                this.openConf()
              }
            })
            Text($r('app.string.mpv_conf_next_core'))
              .fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
              .padding({ left: 16, right: 16, bottom: 12 })
          }
        }

        ListItem() {
          SettingsSegmentButtonItem({
            symbol: $r('sys.symbol.hardware'),
            message: ToolsUtil.getStringResource($r('app.string.mpv_decoding_prefix').id) +
              this.getMPVDecodeInfo(Setting.mpvDecodingMethod),
            tips: [$r('app.string.hw_surface'), $r('app.string.sw_decode'), $r('app.string.hw_buffer')],
            tabSelectedIndex: Setting.mpvDecodingMethod,
            onButtonClick: (tabSelectedIndex: number) => {
              Setting.mpvDecodingMethod = tabSelectedIndex
              Preferences.saveMpvDecodingMethod(PathUtils.appContext!, tabSelectedIndex)
            }
          })
        }

        ListItem() {
          Column({ space: 4 }) {
            SettingsToggleItem({
              symbol: $r('sys.symbol.hardware'),
              message: ToolsUtil.getStringResource($r('app.string.mpv_deinterlace').id),
              enable: Setting.mpvAutoDeinterlace,
              onChange: (checked: boolean) => {
                Setting.mpvAutoDeinterlace = checked
                Preferences.saveMpvAutoDeinterlace(PathUtils.appContext!, checked)
              }
            })
            Text($r('app.string.mpv_deinterlace_desc'))
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 12 })
          }
        }

        ListItem() {
          Column({ space: 4 }) {
            SettingsToggleItem({
              symbol: $r('sys.symbol.hardware'),
              message: ToolsUtil.getStringResource($r('app.string.mpv_passthrough').id),
              enable: Setting.mpvAudioPassthrough,
              onChange: (checked: boolean) => {
                Setting.mpvAudioPassthrough = checked
                Preferences.saveMpvAudioPassthrough(PathUtils.appContext!, checked)
              }
            })
            Text($r('app.string.mpv_passthrough_desc'))
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 12 })
          }
        }

        ListItem() {
          Column({ space: 4 }) {
            SettingsToggleItem({
              symbol: $r('sys.symbol.hardware'),
              message: ToolsUtil.getStringResource($r('app.string.mpv_usb_exclusive').id),
              enable: Setting.mpvUsbExclusive,
              onChange: (checked: boolean) => {
                Setting.mpvUsbExclusive = checked;
                this.saveUsb()
              }
            })
            Text($r('app.string.mpv_usb_exclusive_desc'))
              .fontSize(12).fontColor($r('sys.color.font_secondary'))
              .padding({ left: 16, right: 16, bottom: 12 })
            SettingsMenuItem({
              symbol: $r('sys.symbol.hardware'),
              message: ToolsUtil.getStringResource($r('app.string.usb_audio_device').id),
              list: this.usbNames,
              selected: Math.max(0, this.usbIds.indexOf(Setting.mpvUsbDevice)),
              onChange: (index: number) => {
                Setting.mpvUsbDevice = this.usbIds[index]
                Setting.mpvUsbDsdMode = 0
                this.saveUsb()
              }
            })
            SettingsMenuItem({
              symbol: $r('sys.symbol.hardware'),
              message: ToolsUtil.getStringResource($r('app.string.dsd_output_mode').id),
              list: [$r('app.string.off'), 'DoP', $r('app.string.native_dsd')],
              selected: Setting.mpvUsbDsdMode,
              onChange: (index: number) => {
                if (index > 0 && !Setting.mpvUsbDevice) {
                  ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.dsd_select_device').id))
                  return
                }
                Setting.mpvUsbDsdMode = index
                this.saveUsb()
              }
            })
            Text($r('app.string.dsd_desc'))
              .fontSize(12).fontColor($r('sys.color.font_secondary'))
              .padding({ left: 16, right: 16, bottom: 12 })
          }
        }

        ListItem() {
          SettingsSegmentButtonItem({
            symbol: $r('sys.symbol.rays'),
            message: ToolsUtil.getStringResource($r('app.string.mpv_gpu_backend').id),
            tag: 'VIP',
            tips: ['OpenGL', 'Vulkan'],
            tabSelectedIndex: Setting.mpvGpuApi,
            itemEnabled: userData.isVip,
            onButtonClick: (tabSelectedIndex: number) => {
              Setting.mpvGpuApi = tabSelectedIndex as MpvGpuApi
              Preferences.saveMpvGpuApi(PathUtils.appContext!, Setting.mpvGpuApi)
            }
          })
        }

        ListItem() {
          SettingsSegmentButtonItem({
            symbol: $r('sys.symbol.wand_and_stars'),
            message: ToolsUtil.getStringResource($r('app.string.mpv_quality_boost').id),
            tag: 'VIP',
            tips: MpvPlaybackEffects.getShaderModeNames(),
            tabSelectedIndex: Setting.mpvShaderMode,
            itemEnabled: userData.isVip,
            onButtonClick: (tabSelectedIndex: number) => {
              Setting.mpvShaderMode = tabSelectedIndex
              Preferences.saveMpvShaderMode(PathUtils.appContext!, tabSelectedIndex)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.hdr'),
            message: ToolsUtil.getStringResource($r('app.string.sdr_to_hdr').id),
            tag: 'VIP',
            enable: Setting.mpvSdrToHdr,
            itemEnabled: userData.isVip,
            onChange: (checked: boolean) => {
              Setting.mpvSdrToHdr = checked
              Preferences.saveMpvSdrToHdr(PathUtils.appContext!, checked)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.camera_master_ai'),
            message: ToolsUtil.getStringResource($r('app.string.super_resolution').id),
            tag: 'VIP',
            enable: Setting.superResolutionState,
            itemEnabled: userData.isVip,
            onChange: (checked: boolean) => {
              Setting.superResolutionState = checked
              Preferences.saveSuperResolutionState(PathUtils.appContext!, Setting.superResolutionState)
            }
          })
        }
      }
      .align(Alignment.Top)
      .borderRadius(16)
      .margin({ left: 16, right: 16 })
      .clip(false)
      .scrollBar(BarState.Off)
      .height('100%')
      .width('95%')
      .layoutWeight(1)
      .contentEndOffset(SafeHeight.bottomSafeHeight)
    }
    .hideToolBar(true)
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      padding: { start: LengthMetrics.vp(5), end: LengthMetrics.vp(5) },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background'),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        }
      },
      content: {
        title: {
          mainTitle: $r('app.string.settings_engine'),
        }
      },
    })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .hideBackButton(false)
    .bindToScrollable([this.listScroller])
    .bindSheet(this.confVisible, this.ConfEditor(), {
      height: SheetSize.LARGE,
      showClose: true,
      title: { title: $r('app.string.mpv_conf_title') },
      backgroundColor: $r('app.color.start_window_background'),
      onDisappear: () => {
        this.confVisible = false
      }
    })
  }

  private saveUsb(): void {
    Preferences.saveMpvUsb(PathUtils.appContext!, Setting.mpvUsbExclusive, Setting.mpvUsbDsdMode, Setting.mpvUsbDevice)
  }

  private openConf(): void {
    try {
      this.confDraft = MpvConfigStore.read()
      this.confError = ''
      this.confVisible = true
    } catch (_error) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.mpv_conf_read_failed').id))
    }
  }

  private async importConf(): Promise<void> {
    if (this.confBusy) {
      return
    }
    this.confBusy = true
    this.confError = ''
    try {
      const options = new picker.DocumentSelectOptions()
      options.maxSelectNumber = 1
      options.fileSuffixFilters = ['mpv.conf|.conf,.txt']
      const uris = await new picker.DocumentViewPicker(PathUtils.appContext!).select(options)
      if (uris.length > 0) {
        const draft = await MpvConfigStore.importFile(uris[0])
        if (this.confVisible) {
          this.confDraft = draft
        }
      }
    } catch (_error) {
      this.confError = ToolsUtil.getStringResource($r('app.string.mpv_conf_import_failed').id)
    } finally {
      this.confBusy = false
    }
  }

  private async saveConf(): Promise<void> {
    if (this.confBusy) {
      return
    }
    this.confBusy = true
    this.confError = ''
    try {
      await MpvConfigStore.save(this.confDraft)
      this.confVisible = false
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.mpv_conf_saved').id))
    } catch (error) {
      this.confError = error instanceof Error ? error.message :
        ToolsUtil.getStringResource($r('app.string.mpv_conf_save_failed').id)
    } finally {
      this.confBusy = false
    }
  }

  @Builder
  private ConfEditor() {
    Column({ space: 12 }) {
      Text($r('app.string.mpv_conf_desc'))
        .fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
      TextArea({ text: this.confDraft, placeholder: '# mpv.conf\n# key=value\ncontrast=5\nbrightness=0' })
        .fontFamily('monospace')
        .fontSize(14)
        .layoutWeight(1)
        .width('100%')
        .maxLength(MpvConfigStore.MAX_BYTES)
        .enabled(!this.confBusy)
        .onChange((value: string) => {
          this.confDraft = value;
          this.confError = ''
        })
      if (this.confError.length > 0) {
        Text(this.confError).fontSize(12).fontColor($r('sys.color.font_emphasize')).width('100%')
      }
      Row({ space: 12 }) {
        Button($r('app.string.mpv_conf_import')).layoutWeight(1).enabled(!this.confBusy)
          .onClick(() => {
            this.importConf()
          })
        Button($r('app.string.mpv_conf_save')).layoutWeight(1).enabled(!this.confBusy)
          .onClick(() => {
            this.saveConf()
          })
      }.width('100%')
    }.padding(16).width('100%').height('100%')
  }

  @Builder
  private ConfToggle() {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.hardware'))
        .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
      Text($r('app.string.mpv_conf_title'))
        .attributeModifier(new SettingsTitleModifier()).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: $$this.confEnabled })
        .selectedColor($r('app.color.main_color'))
        .width(45)
        .height(27)
        .flexShrink(0)
        .onChange((enabled: boolean) => {
          try {
            MpvConfigStore.setEnabled(enabled)
            ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.mpv_conf_next_core').id))
          } catch (_error) {
            this.confEnabled = !enabled
            ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.mpv_conf_invalid').id))
          }
        })
    }.width('100%').height(55).attributeModifier(new SettingsItemModifier())
  }

  private getMPVDecodeInfo(decodingMethod: MpvDecodingMethod): string {
    switch (decodingMethod) {
      case MpvDecodingMethod.HARDWARE_BUFFER:
        return ToolsUtil.getStringResource($r('app.string.decode_support_dv_p5').id)
      case MpvDecodingMethod.SOFTWARE:
        return ToolsUtil.getStringResource($r('app.string.decode_compat_best').id)
      case MpvDecodingMethod.HARDWARE_SURFACE:
        return ToolsUtil.getStringResource($r('app.string.decode_performance_best').id)
      default:
        return 'Unknown'
    }
  }
}
