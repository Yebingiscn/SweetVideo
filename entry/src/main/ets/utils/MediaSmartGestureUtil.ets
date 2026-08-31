import {
  BaseGestureHandlingProposal,
  GestureHandlingResolution,
  NoneActionProposal,
  SmartGestureController,
  UIContext
} from '@kit.ArkUI'
import { deviceInfo, SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import { salmonLogger } from 'salmonlogger'
import { Setting } from './ObservedUtil'

const TAG = 'MediaSmartGesture'
export const SHORT_VIDEO_SMART_SWIPER_ID = 'short_video_smart_swiper'

export interface MediaSmartGestureHandlers {
  canHandle: () => boolean
  onTap: () => void
  onSlide: () => BaseGestureHandlingProposal | undefined
}

// The visible playback surface remains a target even when the controls are unmounted.
// Apply the API 26 attribute behind a runtime guard, not unconditionally in build().
export class MediaSmartGestureModifier implements AttributeModifier<CommonAttribute> {
  private enabled: boolean

  constructor(enabled: boolean) {
    this.enabled = enabled
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP, SuppressWarningsType.COMPATIBILITY] })
  applyNormalAttribute(instance: CommonAttribute): void {
    if (MediaSmartGestureSession.isSupported()) {
      instance.smartGestureShortcut({
        action: GestureShortcut.PRIMARY,
        enabled: this.enabled,
        selectable: false
      })
    }
  }
}

// UIContext shares its controller between destinations. Only the visible playback
// page owns it; a late onHidden/aboutToDisappear must not disable its successor.
export class MediaSmartGestureSession {
  private static activeSession: MediaSmartGestureSession | undefined = undefined
  private static appForeground: boolean = false
  private uiContext: UIContext | undefined = undefined
  private controller: SmartGestureController | undefined = undefined
  private monitorRegistered: boolean = false
  private handlers: MediaSmartGestureHandlers

  constructor(handlers: MediaSmartGestureHandlers) {
    this.handlers = handlers
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  static isSupported(): boolean {
    return deviceInfo.sdkApiVersion >= 26 && canIUse('SystemCapability.ArkUI.ArkUI.Full')
  }

  static setAppForeground(foreground: boolean): void {
    MediaSmartGestureSession.appForeground = foreground
    const session = MediaSmartGestureSession.activeSession
    if (foreground) {
      session?.startMonitoring()
    } else {
      session?.stopMonitoring()
    }
  }

  show(uiContext: UIContext): void {
    if (MediaSmartGestureSession.activeSession !== this) {
      MediaSmartGestureSession.activeSession?.hide()
      MediaSmartGestureSession.activeSession = this
    }
    this.uiContext = uiContext
    this.startMonitoring()
  }

  hide(): void {
    this.stopMonitoring()
    if (MediaSmartGestureSession.activeSession === this) {
      MediaSmartGestureSession.activeSession = undefined
    }
    this.uiContext = undefined
  }

  private startMonitoring(): void {
    if (!MediaSmartGestureSession.appForeground || !Setting.smartGestureEnabled ||
      !MediaSmartGestureSession.isSupported() || !this.uiContext) {
      this.stopMonitoring()
      return
    }
    if (this.controller) {
      return
    }
    try {
      this.controller = this.uiContext.getSmartGestureController()
      this.controller.registerMonitor(this.monitorCallback)
      this.monitorRegistered = true
      this.controller.enableSmartTapAndSlideGestures(true)
      this.controller.clearSelected()
    } catch (error) {
      this.stopMonitoring()
      salmonLogger.addLog(TAG, `启用智慧手势失败: ${error}`, true)
    }
  }

  private stopMonitoring(): void {
    const controller = this.controller
    this.controller = undefined
    this.monitorRegistered = false
    if (!controller) {
      return
    }
    try {
      // Also undo a registration that failed after partially registering.
      controller.unregisterMonitor(this.monitorCallback)
    } catch (error) {
      salmonLogger.addLog(TAG, `注销智慧手势监听失败: ${error}`, true)
    }
    if (MediaSmartGestureSession.activeSession === this) {
      try {
        controller.enableSmartTapAndSlideGestures(false)
        controller.clearSelected()
      } catch (error) {
        salmonLogger.addLog(TAG, `关闭智慧手势失败: ${error}`, true)
      }
    }
  }

  // Only registered after isSupported(); API 23-25 never execute this callback.
  @SuppressWarnings({ rules: [SuppressWarningsType.COMPATIBILITY] })
  private readonly monitorCallback = (proposal: BaseGestureHandlingProposal): GestureHandlingResolution => {
    if (MediaSmartGestureSession.activeSession !== this || !this.monitorRegistered ||
      !MediaSmartGestureSession.appForeground) {
      return new GestureHandlingResolution(false)
    }
    // Wrist-turn follows system back dispatch, including menus and onBackPressed.
    // The tap/slide preference must not change that independent system gesture.
    if (proposal.operateIntention === OperateIntention.BACK_PRESS) {
      return new GestureHandlingResolution(true)
    }
    if (proposal.operateIntention !== OperateIntention.TAP &&
      proposal.operateIntention !== OperateIntention.SLIDE_FORWARD) {
      return new GestureHandlingResolution(false)
    }

    const resolution = new GestureHandlingResolution(true)
    // Consume the original proposal even when blocked or a media handler fails.
    // Otherwise one tap could both toggle playback and click a control underneath.
    resolution.selectedProposal = new NoneActionProposal()
    try {
      if (!Setting.smartGestureEnabled || !this.handlers.canHandle()) {
        return resolution
      }
      this.controller?.clearSelected()
      if (proposal.operateIntention === OperateIntention.TAP) {
        this.handlers.onTap()
      } else {
        resolution.selectedProposal = this.handlers.onSlide() ?? resolution.selectedProposal
      }
    } catch (error) {
      salmonLogger.addLog(TAG, `处理智慧手势失败: ${error}`, true)
    }
    return resolution
  }
}
