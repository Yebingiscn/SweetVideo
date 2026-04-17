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

@Component
export struct XComponents {
  @Consume('player') player: AVPlayerController | MpvController
  @Prop choosePlayer: string
  @Prop subtitle: string
  @Prop hideSubtitle: boolean = false
  @Link subtitleVisibility: Visibility
  @Link subtitle3DMode: Subtitle3DMode
  xComponentController: XComponentController | undefined
  osdXController: XComponentController | undefined
  @Prop osdVisibility: boolean = false
  xComponentId: string | undefined
  libraryName: string | undefined
  @Prop @Watch('setScreen') barState: boolean = false
  onXComponentLoad = () => {
  }
  onKeyCodeSpace = () => {
  }
  onKeyCodeEscape = () => {
  }
  onKeyCodeRight = () => {
  }
  onKeyCodeLeft = () => {
  }
  onKeyCodeUpAndDown = (_event: KeyEvent) => {
  }
  onOsdSurfaceLoad = (_surfaceId: string) => {
  }

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
    .rotate({ y: 2, angle: this.player.angle, perspective: 200 })
    .translate({ x: this.player.translateX, y: this.player.translateY })
  }

  setScreen() {
    WindowUtil.setBarState(PathUtils.appContext!, this.barState, this.barState)
  }
}

@Component
export struct MpvXComponent {
  xComponentController: XComponentController | undefined
  xComponentId: string | undefined
  libraryName: string | undefined
  osdXController: XComponentController | undefined
  @Prop osdVisibility: boolean = false
  onMpvXComponent = () => {
  }
  onOsdSurfaceLoad = (_surfaceId: string) => {
  }

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
        .width('100%')
        .height('100%')
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
          .visibility(this.osdVisibility ? Visibility.Visible : Visibility.None)
          .width('100%')
          .height('100%')
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
    .width('100%')
    .height('100%')
  }
}

@Component
export struct AVPlayerXComponent {
  xComponentController: XComponentController | undefined
  onAVPlayerComponentLoad = () => {
  }

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
