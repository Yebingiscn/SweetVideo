import { KeyCode } from '@kit.InputKit'
import { salmonLogger } from 'salmonlogger'
import { OPTIONS } from '../../common/Constants'
import { Subtitle3DMode } from '../../common/enum/SubtitleMode'
import NavigationAddress from '../../common/NavigationCommon'
import { AVPlayerController } from '../../controller/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import { MpvDecodingMethod } from '../../controller/MpvController/MpvTypes'
import { Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import { WindowUtil } from '../../utils/WindowUtil'
import { SubtitleDisplayBuilder } from './SubtitleDisplayBuilder'

const TAG = 'XComponents'

@ComponentV2
export struct XComponents {
  @Consumer('player') player: AVPlayerController | MpvController = new AVPlayerController()
  @Param choosePlayer: string = ''
  @Param subtitle: string = ''
  @Param hideSubtitle: boolean = false
  @Param subtitleVisibility: Visibility = Visibility.None
  @Param subtitle3DMode: Subtitle3DMode = Subtitle3DMode.DISABLED
  @Param xComponentController: XComponentController | undefined = undefined
  @Param osdXController: XComponentController | undefined = undefined
  @Param osdVisibility: boolean = false
  @Param xComponentId: string | undefined = undefined
  @Param libraryName: string | undefined = undefined
  @Param barState: boolean = false
  @Event onXComponentLoad: () => void = () => {}
  @Event onKeyCodeSpace: () => void = () => {}
  @Event onKeyCodeEscape: () => void = () => {}
  @Event onKeyCodeRight: () => void = () => {}
  @Event onKeyCodeLeft: () => void = () => {}
  @Event onKeyCodeUpAndDown: (_event: KeyEvent) => void = () => {}
  @Event onOsdSurfaceLoad: (_surfaceId: string) => void = () => {}

  build() {
    Stack() {
      if (this.choosePlayer === NavigationAddress.AV_PLAYER) {
        AVPlayerXComponent({
          xComponentController: this.xComponentController,
          onAVPlayerComponentLoad: () => {
            this.onXComponentLoad()
          },
        })
      } else {
        MpvXComponent({
          xComponentController: this.xComponentController,
          xComponentId: this.xComponentId,
          libraryName: this.libraryName,
          osdXController: this.osdXController,
          osdVisibility: this.osdVisibility,
          onMpvXComponent: () => {
            this.onXComponentLoad()
          },
          onOsdSurfaceLoad: (surfaceId: string) => {
            this.onOsdSurfaceLoad(surfaceId)
          },
        })
      }
      SubtitleDisplayBuilder({
        subtitle: this.subtitle,
        screenWidth: this.player.screenWidth,
        screenHeight: this.player.screenHeight,
        showControl: this.player.showControl,
        subTitleVisibility: this.hideSubtitle ? Visibility.None : this.subtitleVisibility,
        subtitle3DMode: this.subtitle3DMode
      })
    }
    .onKeyEvent((event?: KeyEvent) => {
      if (!event || event.type !== KeyType.Down) {
        return
      }
      if (event.keyCode === KeyCode.KEYCODE_SPACE) {
        this.onKeyCodeSpace()
      }
      if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
        this.onKeyCodeEscape()
      }
      if (event.keyCode === KeyCode.KEYCODE_DPAD_RIGHT) {
        this.onKeyCodeRight()
      }
      if (event.keyCode === KeyCode.KEYCODE_DPAD_LEFT) {
        this.onKeyCodeLeft()
      }
      if (event.keyCode === KeyCode.KEYCODE_DPAD_UP || event.keyCode === KeyCode.KEYCODE_DPAD_DOWN) {
        this.onKeyCodeUpAndDown(event)
      }
    })
    .width(this.player.playAreaWidth)
    .height(this.player.playAreaHeight)
    .animation({ duration: this.player.playTime > 300 ? 300 : 0, curve: Curve.Ease })
    .rotate({ y: 2, angle: this.player.angle, perspective: 200 })
    .translate({ x: this.player.translateX, y: this.player.translateY })
  }

  @Monitor('barState')
  setScreen() {
    WindowUtil.setBarState(PathUtils.appContext!, this.barState, this.barState)
  }
}

@ComponentV2
export struct MpvXComponent {
  @Param xComponentController: XComponentController | undefined = undefined
  @Param xComponentId: string | undefined = undefined
  @Param libraryName: string | undefined = undefined
  @Param osdXController: XComponentController | undefined = undefined
  @Param osdVisibility: boolean = false
  @Event onMpvXComponent: () => void = () => {}
  @Event onOsdSurfaceLoad: (_surfaceId: string) => void = () => {}

  build() {
    Column() {
      XComponent({
        type: XComponentType.SURFACE,
        controller: this.xComponentController,
        id: this.xComponentId,
        libraryname: this.libraryName,
      })
        .focusable(true)
        .defaultFocus(true)
        .enableAnalyzer(true)
        .onLoad(() => {
          this.onMpvXComponent()
        })
        .position({ x: 0, y: 0 })
      // OSD 字幕叠加层 XComponent（Surface 模式下由 ohcodec-osd VO 渲染字幕）
      // 注意：SURFACE 类型 XComponent 在首帧提交前是不透明的，会遮挡视频。
      // 解决方案：初始为 None，视频开始播放后延迟 500ms 再变 Visible，
      // 此时 ohos_osd_create 已提交透明帧，surface 不再是黑色覆盖层。
      if (Setting.mpvDecodingMethod === MpvDecodingMethod.HARDWARE_SURFACE && this.osdVisibility) {
        XComponent({
          id: "mpv_osd_surface",
          type: XComponentType.SURFACE,
          controller: this.osdXController
        })
          .backgroundColor(Color.Transparent)  // 声明透明背景，确保合成器使用 SRC_OVER 而非 SRC
          .hitTestBehavior(HitTestMode.Transparent)
          .onLoad(() => {
            try {
              const surfaceId = this.osdXController?.getXComponentSurfaceId()
              if (surfaceId) {
                this.onOsdSurfaceLoad(surfaceId)
              } else {
                salmonLogger.addLog(TAG, '[OSD] Failed to get OSD Surface ID', false)
              }
            } catch (error) {
              salmonLogger.addLog(TAG, '[OSD] Error in OSD onLoad: ' + error, true)
            }
          })
      }
    }
  }
}

@ComponentV2
export struct AVPlayerXComponent {
  @Param xComponentController: XComponentController | undefined = undefined
  @Event onAVPlayerComponentLoad: () => void = () => {}


  build() {
    XComponent({
      type: XComponentType.SURFACE,
      controller: this.xComponentController,
      imageAIOptions: OPTIONS
    })
      .onLoad(() => {
        this.onAVPlayerComponentLoad()
      })
      .focusable(true)
      .defaultFocus(true)
      .enableAnalyzer(true)
  }
}
