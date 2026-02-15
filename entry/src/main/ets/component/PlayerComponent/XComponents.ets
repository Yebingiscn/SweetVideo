import { KeyCode } from '@kit.InputKit'
import { OPTIONS } from '../../common/Constants'
import { Subtitle3DMode } from '../../common/enum/SubtitleMode'
import NavigationAddress from '../../common/NavigationCommon'
import { SubtitleDisplayBuilder } from './SubtitleDisplayBuilder'

@Component
export struct XComponents {
  @Prop playAreaWidth: number
  @Prop playAreaHeight: number
  @Prop playTime: number
  @Prop choosePlayer: string
  @Prop subtitle: string
  @Prop screenWidth: number
  @Prop screenHeight: number
  @Prop angle: number
  @Link showControl: boolean
  @Link subtitleVisibility: Visibility
  @Link subtitle3DMode: Subtitle3DMode
  xComponentController: XComponentController | undefined
  xComponentId: string | undefined
  libraryName: string | undefined
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
          onMpvXComponent: () => {
            this.onXComponentLoad()
          },
        })
      }
      SubtitleDisplayBuilder({
        subtitle: this.subtitle,
        screenWidth: this.screenWidth,
        screenHeight: this.screenHeight,
        showControl: this.showControl,
        subTitleVisibility: this.subtitleVisibility,
        subtitle3DMode: this.subtitle3DMode,
        playAreaWidth: this.playAreaWidth,
        playAreaHeight: this.playAreaHeight
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
    .width(this.playAreaWidth)
    .height(this.playAreaHeight)
    .animation({ duration: this.playTime > 300 ? 300 : 0, curve: Curve.Ease })
    .rotate({ y: 2, angle: this.angle, perspective: 200 })
  }
}

@Component
export struct MpvXComponent {
  xComponentController: XComponentController | undefined
  xComponentId: string | undefined
  libraryName: string | undefined
  onMpvXComponent = () => {
  }

  build() {
    XComponent({
      type: XComponentType.SURFACE,
      controller: this.xComponentController,
      id: this.xComponentId,
      libraryname: this.libraryName,
    }).focusable(true)
      .defaultFocus(true)
      .enableAnalyzer(true)
      .onLoad(async () => {
        this.onMpvXComponent()
      })
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
    }).onLoad(() => {
      this.onAVPlayerComponentLoad()
    }).focusable(true)
      .defaultFocus(true)
      .enableAnalyzer(true)
  }
}