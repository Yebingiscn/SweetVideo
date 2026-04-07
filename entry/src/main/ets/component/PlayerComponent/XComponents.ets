import { KeyCode } from '@kit.InputKit'
import { OPTIONS } from '../../common/Constants'
import { Subtitle3DMode } from '../../common/enum/SubtitleMode'
import NavigationAddress from '../../common/NavigationCommon'
import { AVPlayerController } from '../../controller/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import { PathUtils } from '../../utils/PathUtils'
import { WindowUtil } from '../../utils/WindowUtil'
import { SubtitleDisplayBuilder } from './SubtitleDisplayBuilder'

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
      if (this.osdVisibility) {
        XComponent({
          id: "mpv_osd_surface",
          type: XComponentType.SURFACE,
          controller: this.osdXController
        })
          .backgroundColor(Color.Transparent)  // 声明透明背景，确保合成器使用 SRC_OVER 而非 SRC
          .hitTestBehavior(HitTestMode.Transparent)
      }
    }

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
