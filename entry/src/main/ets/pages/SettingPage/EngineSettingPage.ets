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
  @Local private usbNames: string[] = ['自动选择唯一设备']
  private usbIds: string[] = ['']

  aboutToAppear(): void {
    try {
      const devices = UsbAudioSession.devices()
      this.usbIds = [''].concat(devices.map(device => UsbAudioSession.deviceKey(device)))
      this.usbNames = ['自动选择唯一设备'].concat(devices.map(device => device.productName || device.name))
    } catch (error) { ToolsUtil.showToast('当前设备不支持 USB 设备查询') }
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
            message: '默认播放引擎',
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
            message: 'MPV 解码：' + this.getMPVDecodeInfo(Setting.mpvDecodingMethod),
            tips: ['硬解（Surface）', '软解', '硬解（Buffer）'],
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
              symbol: $r('sys.symbol.hardware'), message: 'MPV USB 独占（实验性）',
              enable: Setting.mpvUsbExclusive,
              onChange: (checked: boolean) => { Setting.mpvUsbExclusive = checked; this.saveUsb() }
            })
            Text('按音源采样率输出，保持整数 PCM / DSD 数据原样。仅支持兼容的单声道或立体声 DAC；不支持时停止音频。关闭变速、音效和响度调整，下次打开媒体生效。')
              .fontSize(12).fontColor($r('sys.color.font_secondary'))
              .padding({ left: 16, right: 16, bottom: 12 })
            SettingsMenuItem({
              symbol: $r('sys.symbol.hardware'), message: 'USB 音频设备', list: this.usbNames,
              selected: Math.max(0, this.usbIds.indexOf(Setting.mpvUsbDevice)),
              onChange: (index: number) => {
                Setting.mpvUsbDevice = this.usbIds[index]
                Setting.mpvUsbDsdMode = 0
                this.saveUsb()
              }
            })
            SettingsMenuItem({
              symbol: $r('sys.symbol.hardware'), message: 'DSD 输出模式',
              list: ['关闭', 'DoP', 'Native DSD（实验性）'], selected: Setting.mpvUsbDsdMode,
              onChange: (index: number) => {
                if (index > 0 && !Setting.mpvUsbDevice) {
                  ToolsUtil.showToast('请先选择支持所选 DSD 模式的 USB 设备')
                  return
                }
                Setting.mpvUsbDsdMode = index
                this.saveUsb()
              }
            })
            Text('支持原始 DSD、DST 和 DSD WavPack 解压后直出。DoP 需 DAC 明确支持；Native 仅限兼容列表中的设备及固件，暂不支持所有 DAC。USB 音量在播放页的音轨面板调节，不改变系统音量；不支持硬件音量的 DAC 请使用设备旋钮。')
              .fontSize(12).fontColor($r('sys.color.font_secondary'))
              .padding({ left: 16, right: 16, bottom: 12 })
          }
        }

        ListItem() {
          SettingsSegmentButtonItem({
            symbol: $r('sys.symbol.rays'),
            message: 'MPV GPU 后端（仅 Buffer，不推荐改）',
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
            message: 'MPV 画质增强（仅 Buffer/软解）',
            tag: 'VIP',
            tips: MpvController.getShaderModeNames(),
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
            message: 'SDR 转 HDR（仅 Buffer/软解）',
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
            message: '视频超分辨率',
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
          mainTitle: '引擎设置',
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

  private getMPVDecodeInfo(decodingMethod: MpvDecodingMethod) {
    switch (decodingMethod) {
      case MpvDecodingMethod.HARDWARE_BUFFER:
        return '支持杜比P5，性能稍差'
      case MpvDecodingMethod.SOFTWARE:
        return '画面兼容最佳，功耗高'
      case MpvDecodingMethod.HARDWARE_SURFACE:
        return '性能最佳，不支持杜比P5'
      default:
        return 'Unknown'
    }
  }
}