import { salmonLogger } from 'salmonlogger'
import { OPTIONS } from '../../common/Constants'
import { PlayerEngine } from '../../common/NavigationCommon'
import { MpvDecodingMethod } from '../../controller/MpvController/MpvTypes'
import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import { Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import { WindowUtil } from '../../utils/WindowUtil'
import { KeyCode } from '@kit.InputKit'

const TAG = 'XComponents'

@ComponentV2
export struct XComponents {
  @Consumer('player') player: PlayerControllerInterface =
    PlayerControllerFactory.createAVPlayerController() as PlayerControllerInterface
  @Param choosePlayer: string = ''
  @Param xComponentController: XComponentController | undefined = undefined
  @Param osdXController: XComponentController | undefined = undefined
  @Param osdVisibility: boolean = false
  @Param xComponentId: string | undefined = undefined
  @Param libraryName: string | undefined = undefined
  @Param barState: boolean = false
  @Event onXComponentLoad:
    (_controller: XComponentController | undefined, _engine: string) => void = () => {
  }
  @Event onKeyCodeSpace: () => void = () => {
  }
  @Event onKeyCodeEscape: () => void = () => {
  }
  @Event onKeyCodeRight: () => void = () => {
  }
  @Event onKeyCodeLeft: () => void = () => {
  }
  @Event onKeyCodeUpAndDown: (_event: KeyEvent) => void = () => {
  }
  @Event onOsdSurfaceLoad: (_surfaceId: string, _surfaceWidth: number, _surfaceHeight: number) => void = () => {
  }
  @Event onOsdSurfaceDestroy: (_surfaceId: string) => void = () => {
  }

  build() {
    Stack() {
      if (this.choosePlayer === PlayerEngine.AV_PLAYER) {
        AVPlayerXComponent({
          xComponentController: this.xComponentController,
          onAVPlayerComponentLoad: () => {
            this.onXComponentLoad(this.xComponentController, PlayerEngine.AV_PLAYER)
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
            this.onXComponentLoad(this.xComponentController, PlayerEngine.MPV_PLAYER)
          },
          onOsdSurfaceLoad: (surfaceId: string, surfaceWidth: number, surfaceHeight: number) => {
            this.onOsdSurfaceLoad(surfaceId, surfaceWidth, surfaceHeight)
          },
          onOsdSurfaceDestroy: (surfaceId: string) => {
            this.onOsdSurfaceDestroy(surfaceId)
          }
        })
      }
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
    .width(this.player?.playAreaWidth ?? '100%')
    .height(this.player?.playAreaHeight ?? '100%')
    .animation(this.player?.isGesturing ? undefined :
      { duration: (this.player?.playTime ?? 0) > 300 ? 300 : 0, curve: Curve.Ease })
    .rotate({ y: 2, angle: this.player?.angle ?? 0, perspective: 200 })
    .scale({ x: this.player?.scaleFactor ?? 1, y: this.player?.scaleFactor ?? 1 })
    .translate({ x: this.player?.translateX ?? 0, y: this.player?.translateY ?? 0 })
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
  @Event onMpvXComponent: () => void = () => {
  }
  @Event onOsdSurfaceLoad: (_surfaceId: string, _surfaceWidth: number, _surfaceHeight: number) => void = () => {
  }
  @Event onOsdSurfaceDestroy: (_surfaceId: string) => void = () => {
  }

  private activeOsdSurfaceId: string = ''

  private notifyOsdSurface(surfaceId: string): void {
    try {
      const surfaceRect = this.osdXController?.getXComponentSurfaceRect()
      const surfaceWidth = Math.round(surfaceRect?.surfaceWidth ?? 0)
      const surfaceHeight = Math.round(surfaceRect?.surfaceHeight ?? 0)
      if (surfaceWidth > 0 && surfaceHeight > 0) {
        this.activeOsdSurfaceId = surfaceId
        this.onOsdSurfaceLoad(surfaceId, surfaceWidth, surfaceHeight)
      }
    } catch (error) {
      salmonLogger.addLog(TAG, '[OSD] Failed to query OSD Surface geometry: ' + error, true)
    }
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
      // OSD 字幕叠加层：libass 小位图直接由 EGL/GLES 绘制并与视频 Surface 合成。
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
                this.notifyOsdSurface(surfaceId)
              } else {
                salmonLogger.addLog(TAG, '[OSD] Failed to get OSD Surface ID', false)
              }
            } catch (error) {
              salmonLogger.addLog(TAG, '[OSD] Error in OSD onLoad: ' + error, true)
            }
          })
          .onSizeChange((_oldValue: SizeOptions, _newValue: SizeOptions) => {
            const surfaceId = this.osdXController?.getXComponentSurfaceId()
            if (surfaceId) {
              this.notifyOsdSurface(surfaceId)
            }
          })
          .onDestroy(() => {
            const surfaceId = this.activeOsdSurfaceId
            this.activeOsdSurfaceId = ''
            if (surfaceId) {
              this.onOsdSurfaceDestroy(surfaceId)
            }
          })
      }
    }
  }
}

@ComponentV2
export struct AVPlayerXComponent {
  @Param xComponentController: XComponentController | undefined = undefined
  @Event onAVPlayerComponentLoad: () => void = () => {
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
