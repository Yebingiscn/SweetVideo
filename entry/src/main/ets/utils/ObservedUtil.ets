import { BackgroundColorMode } from '../common/enum/BackgroundColorMode'
import { CoverLayoutMode, ListDisplayMode } from '../common/enum/DisplayMode'
import { MpvDecodingMethod, MpvGpuApi } from '../controller/MpvController/MpvTypes'
import { UIUtils } from '@kit.ArkUI'
import { SubtitlePreferredLanguage } from '../common/enum/SubtitleLanguage'

class SettingUtil {
  public backgroundImageSrc: string = ''
  public backgroundBlurImageSrc: string = ''
  public backgroundDropBlur: number = 0
  public backgroundColorMode: BackgroundColorMode = BackgroundColorMode.AUTO
  public enableBackgroundDarkImage: boolean = false
  public allowBackgroundPlay: boolean = true
  public allowConcurrentPlay: boolean = false
  public autoActivePip: boolean = false
  public autoResumeOnReturn: boolean = false
  public allowPlayBackExist: boolean = false
  public fastForwardSeconds: string = '15'
  public smartGestureEnabled: boolean = false
  public recentPlay: boolean = true
  public showToast: boolean = true
  public defaultPlayerEngine: string = '系统播放器'
  public shortVideoMode: boolean = false
  public subtitleSize: string = '22'
  public subtitlePosition: number = 90
  public subtitlePreferredLanguage: SubtitlePreferredLanguage = SubtitlePreferredLanguage.SIMPLIFIED_CHINESE
  public subtitleColor: string = '#F0F0F0'
  public subtitleBold: boolean = false
  public subtitleItalic: boolean = false
  public subtitleBorderSize: number = 1
  public subtitleBorderColor: string = '#000000'
  public subtitleShadowEnabled: boolean = true
  public subtitleShadowSize: number = 6
  public subtitleShadowColor: string = '#000000'
  public subtitleBackgroundOpacity: number = 0
  public allowDoubleFastForward: boolean = true
  public skipIntroTime: string = '0'
  public skipOutroTime: string = '0'
  public listDisplayMode: ListDisplayMode = ListDisplayMode.LIST_DISPLAY
  public coverLayout: CoverLayoutMode = CoverLayoutMode.VERTICAL_PLATE
  public mpvDecodingMethod: MpvDecodingMethod = MpvDecodingMethod.HARDWARE_SURFACE
  public mpvGpuApi: MpvGpuApi = MpvGpuApi.OPENGL
  public mpvShaderMode: number = 0
  public superResolutionState: boolean = false
  public smartRotation: boolean = true
  public longPressSpeed: number = 3
  public showSettingPageEntry: boolean = true
  public allowGestureEntry: boolean = true
  public showFrameImgStatus: boolean = true
  public jumpToHistoryTimeStatus: boolean = true
  public enableAiPrivacyAntiPeep: boolean = false
  public defaultBrightness: number = 0
  public listItemBackgroundBlur: boolean = false
  public maxListLine: number = 5
  public defaultDensityEnabled: boolean = true
}

class SafeHeightUtil {
  public topSafeHeight: number = 0
  public bottomSafeHeight: number = 0
}

export class PrivacySecureUtil {
  public isPrivacyBackground: boolean = false
  public receivedFilesVersion: number = 0
}

class PcUtil {
  public pcMode: boolean = false
}

export const SafeHeight = UIUtils.makeObserved(new SafeHeightUtil())

export const Setting = UIUtils.makeObserved(new SettingUtil())

export const Privacy = UIUtils.makeObserved(new PrivacySecureUtil())

export const Pc = UIUtils.makeObserved(new PcUtil())
