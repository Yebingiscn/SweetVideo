import MediaLibraryService from '../utils/MediaLibraryService'
import { SearchComponent } from '../component/VideoItemComponent/SearchComponent'
import VideoListItem from '../component/VideoItemComponent/VideoListItemComponent'
import Preferences from '../database/Preferences'
import { GlobalSearchModel, SearchVideoEntry } from '../utils/GlobalSearchModel'
import { VisualSearchService } from '../utils/VisualSearchService'
import { PathUtils } from '../utils/PathUtils'
import SelectFileUtil from '../utils/SelectFileUtil'
import ToolsUtil from '../utils/ToolsUtil'
import { Setting } from '../utils/ObservedUtil'
import { hdsMaterial, HdsNavDestination, HideMode, ScrollEffectType } from '@kit.UIDesignKit'
import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI'
import { SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import { motion } from '@kit.MultimodalAwarenessKit'
import IntellectualGripPostureUtil from '../utils/IntellectualGripPostureUtil'
import { XAnimation } from '../utils/AnimationUtil'
import { ButtonFancyModifier, MenuFancyModifier, SymbolGlyphFancyModifier } from '../common/AttributeModifierConfig'

@ComponentV2
export struct GlobalSearch {
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local query: string = ''
  @Local byPicture: boolean = false
  @Local entries: SearchVideoEntry[] = []
  @Local results: SearchVideoEntry[] = []
  @Local busy: boolean = false
  @Local message: string = ''
  @Local pictureSupported: boolean = false
  @Local is_edit: boolean = false
  @Local HoldingHand: motion.HoldingHandStatus | null = null
  private controller: SearchController = new SearchController()
  private generation: number = 0
  private active: boolean = false
  private running: boolean = false
  private pendingSearch: boolean = false
  private listScroller: Scroller = new Scroller()

  aboutToDisappear(): void {
    this.hide()
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  build() {
    HdsNavDestination() {
      Column({ space: 8 }) {
        if (!this.pictureSupported) {
          Text($r('app.string.visual_search_device_unsupported')).fontSize(12).fontColor($r('sys.color.font_secondary'))
        }
        if (this.byPicture) {
          Text($r('app.string.visual_search_cover_desc')).fontSize(12).fontColor($r('sys.color.font_secondary'))
        }
        Row({ space: 8 }) {
          if (this.busy) {
            LoadingProgress().width(20).height(20)
          }
          Text(this.message).fontSize(13).fontColor($r('sys.color.font_secondary')).layoutWeight(1)
        }.width('100%')

        List({ scroller: this.listScroller, space: 10 }) {
          Repeat<SearchVideoEntry>(this.results)
            .each((entry: RepeatItem<SearchVideoEntry>) => {
              ListItem() {
                Column({ space: 6 }) {
                  VideoListItem({ item: entry.item.video })
                  Text(entry.item.folders.join('、'))
                    .fontSize(12)
                    .fontColor($r('sys.color.font_secondary'))
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                }
              }
              .onClick(async () => {
                const video = entry.item.video
                if (ToolsUtil.isNetworkUrl(video.uri) || await SelectFileUtil.isFileExist(video.uri, true)) {
                  await ToolsUtil.routerWhere(this.pathStack, video, this.results.map(result => result.video))
                }
              })
            })
            .key((entry: SearchVideoEntry) => entry.video.uri || entry.video.date)
            .virtualScroll()
        }.layoutWeight(1).width('100%').height('100%')
      }
      .padding({ left: 16, right: 16, top: 8 })
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .clip(false)
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      padding: { start: LengthMetrics.vp(5), end: LengthMetrics.vp(5) },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background'),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        }
      },
      content: {
        title: {
          mainTitle: $r('app.string.global_search'),
        },
        bottomBuilder: { builder: (): void => this.SearchBarBuilder() },
      },
    })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .bindToScrollable([this.listScroller])
    .dynamicHideTitleBar({
      hideTitleArea: false,
      hideBottomBuilder: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP
    })
    .onBackPressed(() => {
      if (this.query.length > 0) {
        this.query = ''
        this.controller.stopEditing()
        this.updateResults()
        return true
      }
      return false
    })
    .onShown(() => {
      this.refresh()
    })
    .onHidden(() => {
      this.hide()
    })
    .onReady(() => {
      IntellectualGripPostureUtil.createHoldingHandStatus((data: motion.HoldingHandStatus) => {
        this.HoldingHand = data
      })
    })
    .onWillDisappear(() => {
      IntellectualGripPostureUtil.destroyHoldingHandStatus()
    })
  }

  @Builder
  SearchBarBuilder() {
    Row({ space: 10 }) {
      SearchComponent({
        controller: this.controller,
        searchValue: this.query,
        placeholder: this.byPicture ? $r('app.string.describe_cover_example') : $r('app.string.search_all_media'),
        onSearchValueChange: (value: string) => {
          this.query = value
          this.updateResults()
        },
        onSubmit: () => {
          void this.submit()
        },
        onEditChange: (isEditing: boolean) => {
          XAnimation.runWithAnimation(() => {
            this.is_edit = isEditing
          })
        }
      })

      if (!this.is_edit) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph(this.byPicture ? $r('sys.symbol.AI_livephoto') : $r('sys.symbol.textformat'))
            .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
        }
        .backdropBlur(150)
        .attributeModifier(new ButtonFancyModifier(35, 35))
        .transition(XAnimation.getAnimation('right', 0, false))
        .bindMenu(this.SearchModeMenuBuilder, { showInSubWindow: false })
      }
    }
    .width('95%')
    .justifyContent(FlexAlign.Start)
    .reverse(IntellectualGripPostureUtil.isLeftHoldHand(this.HoldingHand))
    .animation({ duration: 300, curve: Curve.Ease })
  }

  @Builder
  SearchModeMenuBuilder() {
    Menu() {
      MenuItem({
        content: $r('app.string.search_by_name'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat')),
        labelInfo: !this.byPicture ? $r('app.string.current_label') : ''
      })
        .onClick(() => {
          this.byPicture = false
          this.updateResults()
        })
      MenuItem({
        content: $r('app.string.search_by_cover'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.AI_livephoto')),
        labelInfo: this.byPicture ? $r('app.string.current_label') : ''
      })
        .onClick(() => {
          if (this.pictureSupported) {
            this.byPicture = true
            this.updateResults()
          }
        })
    }.attributeModifier(new MenuFancyModifier())
  }

  private refresh(): void {
    this.active = true
    this.generation++
    this.busy = false
    this.pictureSupported = VisualSearchService.isSupported()
    this.entries = GlobalSearchModel.collect(Preferences.getFileFolder(PathUtils.appContext!))
    this.updateResults()
  }

  private updateResults(): void {
    this.generation++
    this.busy = false
    if (this.byPicture) {
      this.results = []
      this.message = ToolsUtil.getStringResource($r('app.string.describe_cover_hint').id)
      return
    }
    const matches = new Set(MediaLibraryService.getItemFromSearch(
      this.entries.map(entry => entry.video), this.query).map(video => video.uri))
    this.results = this.query.trim() ? this.entries.filter(entry => matches.has(entry.video.uri)) : this.entries
    this.message = ToolsUtil.getStringResourceArgs($r('app.string.all_folders_video_count').id, this.results.length)
  }

  private async submit(): Promise<void> {
    if (!this.byPicture) {
      this.updateResults()
      this.controller.stopEditing()
      return
    }
    if (this.running) {
      this.pendingSearch = true
      this.busy = true
      this.message = ToolsUtil.getStringResource($r('app.string.preparing_cover_search_latest').id)
      return
    }
    const query = this.query.trim()
    if (!query || query.length > 100 || !/[\u3400-\u9fff]/.test(query)) {
      this.message = ToolsUtil.getStringResource($r('app.string.cover_desc_range_hint').id)
      return
    }
    const generation = ++this.generation
    this.running = true
    this.busy = true
    this.results = []
    this.message = ToolsUtil.getStringResource($r('app.string.preparing_cover_search').id)
    this.controller.stopEditing()
    try {
      const paths = this.entries.map(entry => PathUtils.coverPath + entry.video.date)
      const result = await VisualSearchService.search(paths, PathUtils.sandboxPath + '/visual-search-index.json', query,
        (completed: number, total: number) => {
          if (this.active && generation === this.generation) {
            this.message = completed === total ? ToolsUtil.getStringResource($r('app.string.searching_cover').id) : ToolsUtil.getStringResourceArgs2($r('app.string.preparing_cover_search_progress').id, completed, total)
          }
        })
      if (!this.active || generation !== this.generation) {
        return
      }
      const byPath = new Map<string, SearchVideoEntry>()
      this.entries.forEach(entry => byPath.set(PathUtils.coverPath + entry.video.date, entry))
      const matches: SearchVideoEntry[] = []
      result.hits.forEach(hit => {
        const entry = byPath.get(hit.imagePath)
        if (entry) {
          matches.push(entry)
        }
      })
      this.results = matches
      this.message = result.indexed === 0 ? ToolsUtil.getStringResource($r('app.string.no_cover_for_search').id) :
        ToolsUtil.getStringResourceArgs($r('app.string.cover_search_result').id, matches.length)
      if (result.skipped > 0) {
        this.message += ToolsUtil.getStringResourceArgs($r('app.string.cover_search_skipped').id, result.skipped)
      }
    } catch {
      if (this.active && generation === this.generation) {
        this.message = ToolsUtil.getStringResource($r('app.string.cover_search_unavailable').id)
      }
    } finally {
      this.running = false
      if (this.active && generation === this.generation) {
        this.busy = false
      }
      if (this.pendingSearch) {
        this.pendingSearch = false
        if (this.active && this.byPicture) {
          this.busy = false
          void this.submit()
        }
      }
    }
  }

  private hide(): void {
    this.active = false
    this.pendingSearch = false
    this.generation++
  }
}
