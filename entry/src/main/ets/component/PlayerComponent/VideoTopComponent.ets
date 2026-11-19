import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import { SCREEN_EXTEND_LIST } from '../../common/Constants'
import type { PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { HiCar } from '../../utils/HiCarUtil'
import HiCarLayout from '../../utils/HiCarLayout'
import { uiMaterial } from '@kit.ArkUI'
import { MaterialCapability } from '../../common/MaterialCapability'

@ComponentV2
export struct VideoTopComponent {
  @Require @Param player: PlayerControllerInterface
  @Param titleOverride: string | undefined = undefined
  @Param isAnySubtitleActive: boolean = false
  @Param lockRotation: boolean = false
  @Param keyboardSubtitleMenuVisible: boolean = false
  @BuilderParam audioTrackMenuBuilder: () => void
  @BuilderParam videoTrackMenuBuilder: () => void
  @BuilderParam subtitlePanelComponent: () => void
  @BuilderParam danmakuMenuBuilder: () => void
  @BuilderParam chapterMenuBuilder: () => void
  @Event onLockRotationClick: () => Promise<void> = async () => {
  }

  private get displayTitle(): string {
    return VideoInfoUtil.getVideoTitle(this.titleOverride ?? this.player.nowPlaying?.title,
      this.player.nowPlaying?.format ?? '')
  }

  @Event onKeyboardSubtitleMenuChange: (visible: boolean) => void = () => {
  }
  @Event onControlsOverlay: (name: string, visible: boolean) => void = () => {
  }
  @Event onExitVideoClick: () => void = () => {
  }
  @Event onSelectedTextChange: (_text: string) => void = () => {
  }
  @Event pipStateChange: () => void = () => {
  }
  @Event onOpenPersonalScreenExtend: () => void = () => {
  }

  build() {
    if (HiCar.enabled) {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
        this.TopControls()
      }
      .padding({ left: 8, right: 8 })
      .width(Math.min(336, HiCarLayout.controlWidth(this.player.screenWidth - HiCar.leftInset - HiCar.rightInset)))
    } else {
      Row({ space: 8 }) {
        this.TopControls()
      }
      .padding({ left: 8, right: 8 })
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  TopControls() {
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
      .layoutWeight(HiCar.enabled ? 0 : 1)
      .width(HiCar.enabled ?
        Math.min(160, HiCarLayout.controlWidth(this.player.screenWidth - HiCar.leftInset - HiCar.rightInset)) :
        undefined)

    Button({ type: ButtonType.Circle, stateEffect: false }) {
      SymbolGlyph($r('sys.symbol.barrage_setting'))
        .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
        .fontColor(['#f0f0f0'])
        .opacity(0.8)
    }
    .accessibilityText($r('app.string.local_danmaku'))
    .attributeModifier(new ButtonFancyModifier(40, 40))
    .backgroundColor(Color.Transparent)
    .bindMenu(this.danmakuMenuBuilder, {
      onWillAppear: () => this.onControlsOverlay('danmaku-menu', true),
      onDidDisappear: () => this.onControlsOverlay('danmaku-menu', false),
      systemMaterial: MaterialCapability.hdsSupported ? new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THICK
      }) : undefined
    })

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
    .onClick(() => this.onKeyboardSubtitleMenuChange(!this.keyboardSubtitleMenuVisible))
    .bindMenu(this.keyboardSubtitleMenuVisible, this.subtitlePanelComponent, {
      onWillAppear: () => this.onControlsOverlay('subtitle-menu', true),
      onDidDisappear: () => {
        this.onKeyboardSubtitleMenuChange(false)
        this.onControlsOverlay('subtitle-menu', false)
      },
      systemMaterial: MaterialCapability.hdsSupported ? new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THICK
      }) : undefined
    })

    if (this.player.videoTracks.tracks.length > 1) {
      Button({ type: ButtonType.Circle, stateEffect: false }) {
        SymbolGlyph($r('sys.symbol.video'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .accessibilityText($r('app.string.video_track'))
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .backgroundColor(Color.Transparent)
      .bindMenu(this.videoTrackMenuBuilder, {
        onWillAppear: () => this.onControlsOverlay('video-track-menu', true),
        onDidDisappear: () => this.onControlsOverlay('video-track-menu', false),
        systemMaterial: MaterialCapability.hdsSupported ? new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.THICK
        }) : undefined
      })
    }

    Button({ type: ButtonType.Circle, stateEffect: false }) {
      SymbolGlyph($r('sys.symbol.opticaldisc'))
        .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
        .fontColor(['#f0f0f0'])
        .opacity(0.8)
    }
    .attributeModifier(new ButtonFancyModifier(40, 40))
    .backgroundColor(Color.Transparent)
    .bindMenu(this.audioTrackMenuBuilder,
      {
        onWillAppear: () => this.onControlsOverlay('audio-menu', true),
        onDidDisappear: () => this.onControlsOverlay('audio-menu', false),
        systemMaterial: MaterialCapability.hdsSupported ? new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.THICK
        }) : undefined
      })

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
        {
          onWillAppear: () => this.onControlsOverlay('chapter-menu', true),
          onDidDisappear: () => this.onControlsOverlay('chapter-menu', false),
          systemMaterial: MaterialCapability.hdsSupported ? new uiMaterial.ImmersiveMaterial({
            style: uiMaterial.ImmersiveStyle.THICK
          }) : undefined
        })
    }

    // 5. 屏幕扩展选择器 (仅在横屏显示)
    if (this.player.screenWidth > this.player.screenHeight) {
      // Use the same menu lifecycle as other controls; Select has no popup lifecycle callbacks.
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Text(this.player.selectedText?.startsWith('自定义比例:') ? '自定义比例' : this.player.selectedText)
          .fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('sys.color.white'))
      }
      .attributeModifier(new ButtonFancyModifier(80, 40))
      .backgroundColor(Color.Transparent)
      .bindMenu(this.AspectMenu, {
        onWillAppear: () => this.onControlsOverlay('aspect-menu', true),
        onDidDisappear: () => this.onControlsOverlay('aspect-menu', false),
        systemMaterial: MaterialCapability.hdsSupported ? new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.THICK
        }) : undefined
      })
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

  @Builder
  AspectMenu() {
    Menu() {
      Repeat<SelectOption>(SCREEN_EXTEND_LIST)
        .each((option: RepeatItem<SelectOption>) => {
          MenuItem({ content: option.item.value })
            .contentFontColor(this.isAspectRatioSelected(option.item.value as string) ? $r('sys.color.white') :
              $r('app.color.text_color'))
            .height(40)
            .backgroundColor(this.isAspectRatioSelected(option.item.value as string) ? $r('app.color.main_color') :
              Color.Transparent)
            .borderRadius(16)
            .onClick(() => {
              this.selectAspectRatio(option.item.value as string)
            })
        })
        .key((option: SelectOption) => option.value as string)
    }
  }

  private isAspectRatioSelected(text: string): boolean {
    const selected = this.player.selectedText
    return selected === text || (text === VideoInfoUtil.screenExtendMap[4] &&
      selected?.startsWith('自定义比例:') === true)
  }

  private selectAspectRatio(text: string): void {
    if (text === VideoInfoUtil.screenExtendMap[4]) {
      this.onOpenPersonalScreenExtend()
      return
    }
    this.onSelectedTextChange(text)
  }
}
