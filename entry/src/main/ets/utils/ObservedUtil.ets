import { UIUtils } from '@kit.ArkUI'
import { BackgroundColorMode } from '../common/enum/BackgroundColorMode'
import { CoverLayoutMode, ListDisplayMode } from '../common/enum/DisplayMode'
import { MpvDecodingMethod } from '../controller/MpvController/MpvTypes'

class SettingUtil {
  public backgroundImageSrc: string = ''
  public backgroundDropBlur: number = 0
  public backgroundColorMode: BackgroundColorMode = BackgroundColorMode.AUTO
  public enableBackgroundDarkImage: boolean = false
  public allowBackgroundPlay: boolean = true
  public allowPlayBackExist: boolean = false
  public fastForwardSeconds: string = '15'
  public recentPlay: boolean = true
  public showToast: boolean = true
  public defaultPlayerEngine: string = '系统播放器'
  public subtitleSize: string = '22'
  public allowDoubleFastForward: boolean = true
  public skipIntroTime: string = '0'
  public listDisplayMode: ListDisplayMode = ListDisplayMode.LIST_DISPLAY
  public coverLayout: CoverLayoutMode = CoverLayoutMode.VERTICAL_PLATE
  public mpvDecodingMethod: MpvDecodingMethod = MpvDecodingMethod.HARDWARE_SURFACE
  public superResolutionState: boolean = false
  public smartRotation: boolean = true
  public longPressSpeed: number = 3
  public showSettingPageEntry: boolean = true
  public allowGestureEntry: boolean = true
  public showFrameImgStatus: boolean = true
  public jumpToHistoryTimeStatus: boolean = true
}

class SafeHeightUtil {
  public topSafeHeight: number = 0
  public bottomSafeHeight: number = 0
}

class PrivacyBackgroundUtil {
  public isPrivacyBackground: boolean = false
}

class PcUtil {
  public pcMode: boolean = false
}

export const SafeHeight = UIUtils.makeObserved(new SafeHeightUtil())

export const Setting = UIUtils.makeObserved(new SettingUtil())

export const Privacy = UIUtils.makeObserved(new PrivacyBackgroundUtil())

export const Pc = UIUtils.makeObserved(new PcUtil())