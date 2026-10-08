import { MpvPlaybackEffects } from '../../controller/MpvController/MpvPlaybackEffects'
import { UsbAudioSession } from '../../utils/UsbAudioSession'
import ToolsUtil from '../../utils/ToolsUtil'
import { SettingsMenuItem } from '../../component/SettingComponent/SettingsMenuItem'
import { SettingsSegmentButtonItem } from '../../component/SettingComponent/SettingsSegmentButtonItem'
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem'
import { MpvController } from '../../controller/MpvController/MpvController'
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

  aboutToAppear(): void {
    try {
      const devices = UsbAudioSession.devices()
      this.usbIds = [''].concat(devices.map(device => UsbAudioSession.deviceKey(device)))
      this.usbNames = [ToolsUtil.getStringResource($r('app.string.usb_auto_select').id)].concat(devices.map(device => device.productName || device.name))
    } catch (error) { ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.usb_query_unsupported').id)) }
    if (Setting.mpvUsbDevice && !this.usbIds.includes(Setting.mpvUsbDevice)) {
      this.usbIds.push(Setting.mpvUsbDevice)
      this.usbNames.push(ToolsUtil.getStringResource($r('app.string.usb_device_disconnected').id))
    }
  }

  private saveUsb(): void {
    Preferences.saveMpvUsb(PathUtils.appContext!, Setting.mpvUsbExclusive, Setting.mpvUsbDsdMode, Setting.mpvUsbDevice)
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
          SettingsSegmentButtonItem({
            symbol: $r('sys.symbol.hardware'),
            message: ToolsUtil.getStringResource($r('app.string.mpv_decoding_prefix').id) + this.getMPVDecodeInfo(Setting.mpvDecodingMethod),
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
              symbol: $r('sys.symbol.hardware'), message: ToolsUtil.getStringResource($r('app.string.mpv_usb_exclusive').id),
              enable: Setting.mpvUsbExclusive,
              onChange: (checked: boolean) => { Setting.mpvUsbExclusive = checked; this.saveUsb() }
            })
            Text($r('app.string.mpv_usb_exclusive_desc'))
              .fontSize(12).fontColor($r('sys.color.font_secondary'))
              .padding({ left: 16, right: 16, bottom: 12 })
            SettingsMenuItem({
              symbol: $r('sys.symbol.hardware'), message: ToolsUtil.getStringResource($r('app.string.usb_audio_device').id), list: this.usbNames,
              selected: Math.max(0, this.usbIds.indexOf(Setting.mpvUsbDevice)),
              onChange: (index: number) => {
                Setting.mpvUsbDevice = this.usbIds[index]
                Setting.mpvUsbDsdMode = 0
                this.saveUsb()
              }
            })
            SettingsMenuItem({
              symbol: $r('sys.symbol.hardware'), message: ToolsUtil.getStringResource($r('app.string.dsd_output_mode').id),
              list: [$r('app.string.off'), 'DoP', $r('app.string.native_dsd')], selected: Setting.mpvUsbDsdMode,
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
