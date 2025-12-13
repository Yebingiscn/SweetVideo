import { PrivacySpaceErrorListDataSource } from '../../utils/DataUtil'
import { fileUri, fileIo as fs } from '@kit.CoreFileKit'
import { PathUtils } from '../../utils/PathUtils'
import { ImageFancyModifier, MenuFancyModifier } from '../../common/AttributeModifierConfig'
import Preferences from '../../database/Preferences'
import SelectFileUtil from '../../utils/SelectFileUtil'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { Privacy, SafeHeight, Setting } from '../../utils/ObservedUtil'

@Component
export struct PrivacySpaceErrorList {
  @State errorListDataSource: PrivacySpaceErrorListDataSource = new PrivacySpaceErrorListDataSource([])
  @State videoList: String[] = []
  @State longPressPreview: boolean = false
  @Consume('pathStack') pathStack: NavPathStack
  private listScroller: Scroller = new Scroller();

  async aboutToAppear(): Promise<void> {
    const videoMetaDataEncryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
    const videoFromSandbox = await fs.listFile(PathUtils.videoPath).catch(() => {
      console.error('get video fail')
    })
    // 确保 videoFromSandbox 是一个数组（如果出错则设为空数组）
    const videoFromSandboxArray = Array.isArray(videoFromSandbox) ? videoFromSandbox : []
    // 从 videoMetaDataEncryption 中提取所有 date 字段的值
    const existingDatesSet: Set<string> = new Set(videoMetaDataEncryption.map(item => item.date))
    // 找出在 videoFromSandboxArray 中存在，但在 existingDates 中不存在的元素
    this.videoList = videoFromSandboxArray.filter((item: string) =>
    !existingDatesSet.has(item)
    )
    this.errorListDataSource = new PrivacySpaceErrorListDataSource(this.videoList)
  }

  async delItem(date: string) {
    this.errorListDataSource.deleteData(this.videoList.findIndex(i => i === date))
    await SelectFileUtil.deletePrivacyVideo(date, date, Preferences.getVideoMetaDataEncryption(PathUtils.appContext!))
  }

  @Builder
  MenuBuilder(item: string) {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')), content: $r('app.string.delete')
      })
        .onClick(async () => {
          await this.delItem(item)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_circle')),
        content: '导出'
      })
        .onClick(async () => {
          await SelectFileUtil.exportFile(fileUri.getUriFromPath(PathUtils.videoPath + item), item, '',
            PathUtils.appContext!)
        })
    }
    .attributeModifier(new MenuFancyModifier())
  }

  @Builder
  VideoItemBuilder(errorVideo: string) {
    Row() {
      Image(fileUri.getUriFromPath(PathUtils.coverPath + errorVideo))
        .attributeModifier(new ImageFancyModifier(16, 80, 120))
      Column() {
        Row() {
          Text(errorVideo)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ left: 5 })
            .wordBreak(WordBreak.BREAK_ALL)
        }
      }.alignItems(HorizontalAlign.Start)
      .padding({ left: 15, right: 15 })
      .layoutWeight(1)
    }
    .backgroundColor(this.longPressPreview ? $r('app.color.start_window_background_blur') :
      $r('app.color.start_window_background'))
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }

  build() {
    NavDestination() {
      Column() {
        if (this.videoList.length === 0) {
          Text('没有异常，看起来一点 bug 也没有捏 (^人^)').textAlign(TextAlign.Center)
            .align(Alignment.Center)
            .width('100%').height('100%')
        } else {
          List({ scroller: this.listScroller, space: 10 }) {
            LazyForEach(this.errorListDataSource, (errorVideo: string) => {
              ListItem() {
                this.VideoItemBuilder(errorVideo)
              }
              .width('100%')
              .height('auto')
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
              .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.Sharp }))
              .bindContextMenu(this.MenuBuilder(errorVideo), ResponseType.LongPress, {
                backgroundBlurStyle: BlurStyle.BACKGROUND_ULTRA_THICK,
                preview: this.VideoItemBuilder(errorVideo),
                previewAnimationOptions: { hoverScale: [1.0, 1.2] },
                onAppear: () => {
                  this.longPressPreview = true
                },
                aboutToDisappear: () => {
                  this.longPressPreview = false
                }
              })
              .bindContextMenu(this.MenuBuilder(errorVideo), ResponseType.RightClick, {
                backgroundBlurStyle: BlurStyle.BACKGROUND_ULTRA_THICK,
                preview: this.VideoItemBuilder(errorVideo),
                previewAnimationOptions: { hoverScale: [1.0, 1.2] },
                onAppear: () => {
                  this.longPressPreview = true
                },
                aboutToDisappear: () => {
                  this.longPressPreview = false
                }
              })
            }, (errorVideo: string) => errorVideo)
          }
          .clip(false)
          .cachedCount(3)
          .layoutWeight(1)
          .padding({ left: 20, right: 20 })
          .width('100%')
          .height('auto')
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
          .chainAnimation(true)
          .scrollBar(BarState.Off)
        }
      }.width('100%')
      .height('100%')
    }
    .title('隐私空间异常数据')
    .padding({ top: SafeHeight.topSafeHeight })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .backdropBlur(Setting.backgroundDropBlur)
    .blur(Privacy.isPrivacyBackground ? 1000 : 0)
  }
}