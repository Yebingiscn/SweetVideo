import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import { SCALE_FACTORS, SCREEN_EXTEND_LIST } from '../../common/Constants'
import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { HiCar } from '../../utils/HiCarUtil'

@ComponentV2
export struct VideoTopComponent {
  @Consumer('player') player: PlayerControllerInterface =
    PlayerControllerFactory.createAVPlayerController() as PlayerControllerInterface
  @Param isAnySubtitleActive: boolean = false
  @Param lockRotation: boolean = false
  @BuilderParam audioTrackMenuBuilder: () => void
  @BuilderParam subtitlePanelComponent: () => void
  @BuilderParam danmakuMenuBuilder: () => void
  @BuilderParam chapterMenuBuilder: () => void
  @BuilderParam carSettingsMenu: () => void
  @BuilderParam carSpeedMenu: () => void
  @BuilderParam carNavigationMenu: () => void
  @Event onLockRotationClick: () => Promise<void> = async () => {
  }

  private get displayTitle(): string {
    return VideoInfoUtil.getVideoTitle(this.player.nowPlaying?.title)
  }

  @Event onExitVideoClick: () => void = () => {
  }
  @Event onOriginalRatio: () => void = () => {
  }
  @Event onStretchedToFullScreen: () => void = () => {
  }
  @Event onFullScreenByWidth: () => void = () => {
  }
  @Event onFullScreenByHeight: () => void = () => {
  }
  @Event onUniformScale: (_scale: number) => void = () => {
  }
  @Event onSpecificVideoProportions: (_playAreaSize: number[]) => void = () => {
  }
  @Event onSelectedTextChange: (_text: string) => void = () => {
  }
  @Event pipStateChange: () => void = () => {
  }
  @Event onOpenPersonalScreenExtend: () => void = () => {
  }

  build() {
    if (HiCar.enabled) {
      this.HiCarTop()
    } else {
    Row({ space: 8 }) {
      // 1. 返回按钮
      Button({ type: ButtonType.Circle, stateEffect: false }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.onExitVideoClick()
      })

      Button({ type: ButtonType.Circle, stateEffect: false }) {
        SymbolGlyph($r('sys.symbol.rectangle_portrait_filled_on_rectangle_portrait'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.pipStateChange()
      })

      // 2. 视频标题 (占据中间主要空间)
      Text(this.displayTitle)
        .fontSize(23)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.MARQUEE })
        .fontColor($r('sys.color.white'))
        .opacity(0.8)
        .layoutWeight(1)

      Button({ type: ButtonType.Circle, stateEffect: false }) {
        SymbolGlyph($r('sys.symbol.barrage_setting'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .accessibilityText($r('app.string.local_danmaku'))
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .backgroundColor(Color.Transparent)
      .bindMenu(this.danmakuMenuBuilder, { backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN })

      // 3. 字幕按钮
      Button({ type: ButtonType.Circle, stateEffect: false }) {
        SymbolGlyph(this.isAnySubtitleActive ?
          $r('sys.symbol.textformat_size_square_fill') : $r('sys.symbol.textformat_size_square'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .backgroundColor(Color.Transparent)
      .bindMenu(this.subtitlePanelComponent, { backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN })

      Button({ type: ButtonType.Circle, stateEffect: false }) {
        SymbolGlyph($r('sys.symbol.opticaldisc'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .backgroundColor(Color.Transparent)
      .bindMenu(this.audioTrackMenuBuilder,
        { backgroundBlurStyle: BlurStyle.COMPONENT_THIN })

      if (this.player.hasChapterSupport() && this.player.chapterList.length > 0) {
        Button({ type: ButtonType.Circle, stateEffect: false }) {
          SymbolGlyph($r('sys.symbol.list_bullet'))
            .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
            .fontColor(['#f0f0f0'])
            .opacity(0.8)
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor(Color.Transparent)
        .bindMenu(this.chapterMenuBuilder,
          { backgroundBlurStyle: BlurStyle.COMPONENT_THIN })
      }

      // 5. 屏幕扩展选择器 (仅在横屏显示)
      if (this.player.screenWidth > this.player.screenHeight) {
        Select(SCREEN_EXTEND_LIST)
          .font({ size: 18, weight: FontWeight.Medium })
          .value(this.player.selectedText?.startsWith('自定义比例:') ? '自定义比例' : this.player.selectedText)
          .selected(this.player.selectedText?.startsWith('自定义比例:') ? 4 :
            VideoInfoUtil.screenExtendMap.indexOf(this.player.selectedText!))
          .fontColor($r('sys.color.white'))
          .onSelect((_index: number, text?: string | undefined) => {
            const selectedText = text
            this.screenExtend(text!)
            this.onSelectedTextChange(selectedText!)
          })
          .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
          .menuBackgroundBlurStyle(BlurStyle.COMPONENT_THIN)
      }

      // 6. 旋转锁定按钮
      Button({ type: ButtonType.Circle, stateEffect: false }) {
        SymbolGlyph(this.lockRotation ? $r('sys.symbol.lock_fill') : $r('sys.symbol.rotate_left'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .attributeModifier(new ButtonFancyModifier(35, 40))
      .backgroundColor(Color.Transparent)
      .onClick(async () => {
        await this.onLockRotationClick()
      })
    }
    .padding({ left: 8, right: 8 })
    .width('100%')
    .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  HiCarTop() {
    Row({ space: 12 }) {
      Button({ type: ButtonType.Circle, stateEffect: false }) {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(28).fontColor([Color.White])
      }
      .width(56).height(56).backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.back_label'))
      .onClick(() => this.onExitVideoClick())
      Button({ type: ButtonType.Circle, stateEffect: false }) {
        SymbolGlyph($r('sys.symbol.gearshape')).fontSize(28).fontColor([Color.White])
      }
      .width(56).height(56).backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.hicar_more_controls'))
      .bindMenu(this.HiCarMoreMenu)
      Text(this.displayTitle)
        .fontSize(22).fontColor(Color.White).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  HiCarMoreMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.hicar_playlist'), builder: this.carNavigationMenu }).height(56)
      MenuItem({ content: $r('app.string.setting'), builder: this.carSettingsMenu }).height(56)
      MenuItem({ content: $r('app.string.hicar_speed'), builder: this.carSpeedMenu }).height(56)
      MenuItem({ content: $r('app.string.hicar_audio'), builder: this.audioTrackMenuBuilder }).height(56)
      MenuItem({ content: $r('app.string.hicar_subtitles'), builder: this.subtitlePanelComponent }).height(56)
      MenuItem({ content: $r('app.string.local_danmaku'), builder: this.danmakuMenuBuilder }).height(56)
      if (this.player.hasChapterSupport() && this.player.chapterList.length > 0) {
        MenuItem({ content: $r('app.string.hicar_chapters'), builder: this.chapterMenuBuilder }).height(56)
      }
      MenuItem({ content: $r('app.string.hicar_aspect'), builder: (): void => this.HiCarAspectMenu() }).height(56)
    }
    .fontSize(22)
  }

  @Builder
  HiCarAspectMenu() {
    Menu() {
      ForEach(SCREEN_EXTEND_LIST, (option: SelectOption) => {
        MenuItem({ content: option.value })
          .height(56)
          .onClick(() => {
            const text = option.value as string
            this.screenExtend(text)
            this.onSelectedTextChange(text)
          })
      }, (option: SelectOption) => option.value as string)
    }
  }

  private screenExtend(text: string) {
    if (VideoInfoUtil.ASPECT_RATIO_MAP.has(text)) {
      const playAreaSize = VideoOperateUtil.setVideoAspectRatio(
        VideoInfoUtil.ASPECT_RATIO_MAP.get(text)!,
        VideoInfoUtil.playAreaWidth,
        VideoInfoUtil.playAreaHeight
      )
      this.onSpecificVideoProportions(playAreaSize)
      return
    }
    switch (text) {
      case VideoInfoUtil.screenExtendMap[0]:
        this.onOriginalRatio()
        break
      case VideoInfoUtil.screenExtendMap[1]:
        this.onStretchedToFullScreen()
        break
      case VideoInfoUtil.screenExtendMap[2]: // 适应宽度
        this.onFullScreenByWidth()
        break
      case VideoInfoUtil.screenExtendMap[3]: // 适应高度
        this.onFullScreenByHeight()
        break
      case VideoInfoUtil.screenExtendMap[4]: // 自定义比例
        this.onOpenPersonalScreenExtend()
      default:
        const scale = text ? SCALE_FACTORS.get(text) : undefined
        if (scale) {
          this.onUniformScale(scale)
        }
        break
    }
  }
}
