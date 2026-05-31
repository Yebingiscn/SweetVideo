import WantProcessUtil from '../../utils/WantProcessUtil'
import { PathUtils } from '../../utils/PathUtils'
import { DefaultDialogShadow, ImageFancyModifier } from '../../common/AttributeModifierConfig'
import { InfoConfirmDialog } from '../../component/Dialog/InfoConfirmDialog'
import { Markdown, MarkdownController } from '@luvi/lv-markdown-in'
import { salmonLogger } from 'salmonlogger'
import { LiqD } from '../../component/common/LiqD'
import { PrivacyPolicyComponent } from '../../component/VideoItemComponent/PrivacyPolicyComponent'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { LengthMetrics } from '@kit.ArkUI'
import { HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'

const TAG = 'AboutApp'

@ComponentV2
export struct AboutApp {
  @Local version_code: string = ''
  @Local isPresent: boolean = false
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  controller: MarkdownController = new MarkdownController()
  private GITHUB_HOME_LINK: string = "https://github.com/Yebingiscn/SweetVideo" // 项目主页
  private QQ_GROUP_LINK: string = 'https://qm.qq.com/q/ejj8jbUDBu'
  private AI_FA_DIAN_LINK: string = 'https://www.ifdian.net/a/SweetVideo'
  private tempLink: string = ''
  linkConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog({
      confirm: async () => {
        WantProcessUtil.linkToWeb(PathUtils.appContext!, this.tempLink)
        this.tempLink = ''
      },
      textInfo: '即将跳转至外部网页，是否跳转？'
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  private listScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.controller
      .setTitleColor($r("app.color.text_color"))
      .setTextColor($r("app.color.text_color"))
      .setTableTitleBackgroundColor($r('app.color.start_window_background_blur'))
      .setQuoteBackgroundColor($r('app.color.start_window_background_blur'))
      .setTableBackgroundColor($r('app.color.start_window_background_blur'))
  }

  build() {
    HdsNavDestination() {
      Scroll(this.listScroller) {
        Column({ space: 10 }) {
          Stack() {
            Image($r("app.media.Background"))
              .attributeModifier(new ImageFancyModifier(16, '100%', 140))
              .zIndex(1)
            Row() {
              Image($r("app.media.Foreground"))
                .backgroundImageSize(ImageSize.Cover)
                .autoResize(true)
                .interpolation(ImageInterpolation.Low)
                .width(60)
                .height(60)
              Text(`${ToolsUtil.getStringResource($r('app.string.EntryAbility_label').id)}` + this.version_code)
                .fontSize(20)
                .fontColor($r('sys.color.white'))
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .margin({ left: 5 })
                .onAppear(async () => {
                  this.version_code = await ToolsUtil.getVersionName()
                })
            }.width('100%')
            .justifyContent(FlexAlign.Center)
            .zIndex(2)
          }.width('100%')

          Row({ space: '4%' }) { // 统一间距处理
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.cat_fill')).fontSize(25).fontColor([$r('app.color.text_color')])
                Text('代码已开源，欢迎 ⭐')
                  .fontSize(15)
                  .fontColor($r('app.color.text_color'))
                  .margin({ left: 10, right: 2 })
                  .maxLines(2)
                  .width('80%')
              }.width('100%')
            }
            .align(Alignment.Start)
            .padding(15)
            .borderRadius(16)
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
            .height(80)
            .width('48%')
            .backgroundColor($r('app.color.start_window_background_blur'))
            .onClick(() => {
              this.tempLink = this.GITHUB_HOME_LINK
              this.linkConfirmDialog.open()
            })

            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.book_1')).fontSize(25).fontColor([$r('app.color.text_color')])
                Text(ToolsUtil.getStringResource($r('app.string.EntryAbility_label').id) +
                  '的使用条款与隐私声明')
                  .fontSize(15)
                  .fontColor($r('app.color.text_color'))
                  .margin({ left: 10, right: 12 })
                  .width('80%')
              }.width('100%')
            }
            .align(Alignment.Start)
            .padding(15)
            .borderRadius(16)
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
            .height(80)
            .width('48%')
            .backgroundColor($r('app.color.start_window_background_blur'))
            .onClick(() => {
              this.isPresent = true
            })
          }.width('100%').justifyContent(FlexAlign.SpaceBetween)

          Row({ space: '4%' }) {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.person_2')).fontSize(25).fontColor([$r('app.color.text_color')])
                Text('QQ 交流群：973792610')
                  .fontSize(15)
                  .fontColor($r('app.color.text_color'))
                  .margin({ left: 10, right: 2 })
                  .maxLines(2)
                  .width('80%')
              }.width('100%')
            }
            .align(Alignment.Start)
            .padding(15)
            .borderRadius(16)
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
            .height(80)
            .width('48%')
            .backgroundColor($r('app.color.start_window_background_blur'))
            .onClick(() => {
              this.tempLink = this.QQ_GROUP_LINK
              this.linkConfirmDialog.open()
            })

            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.fish')).fontSize(25).fontColor([$r('app.color.text_color')])
                Text('赞赏作者')
                  .fontSize(15)
                  .fontColor($r('app.color.text_color'))
                  .margin({ left: 10, right: 12 })
                  .width('80%')
              }.width('100%')
            }
            .align(Alignment.Start)
            .padding(15)
            .borderRadius(16)
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
            .height(80)
            .width('48%')
            .backgroundColor($r('app.color.start_window_background_blur'))
            .onClick(() => {
              this.tempLink = this.AI_FA_DIAN_LINK
              this.linkConfirmDialog.open()
            })
          }.margin({ top: 10 }).width('100%').justifyContent(FlexAlign.SpaceBetween)

          Column({ space: 8 }) {
            Markdown({
              controller: this.controller,
              mode: "rawfile",
              context: PathUtils.appContext!, // 资源文件模式必填参数
              rawfilePath: "README.md", // 资源文件地址
              callback: {
                complete: () => {
                  salmonLogger.addLog(TAG, "Markdown component load success.")
                  salmonLogger.addLog(this.pathStack.getAllPathName()[0],
                    "Markdown component load success.", false)
                },
                fail: (code: number, message: string) => {
                  salmonLogger.addLog(TAG, "Markdown component load error. code: " + code + ", message: " + message,
                    true)
                  salmonLogger.addLog(this.pathStack.getAllPathName()[0],
                    "Markdown component load error. code: " + code + ", message: " + message, true)
                }
              }
            })
          }
          .margin({ top: 10 })
          .padding(15)
          .alignItems(HorizontalAlign.Start)
          .borderRadius(16)
          .width('100%')
          .backgroundColor($r('app.color.start_window_background_blur'))

          LiqD()

          Text('郴州液态科技有限公司 版权所有 © 2025')
            .fontSize(14)
            .fontWeight(FontWeight.Regular)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 10 })

          if (this.isPresent) {
            PrivacyPolicyComponent({
              isPresent: this.isPresent,
              onIsPresentChange: (v: boolean) => {
                this.isPresent = v
              }
            })
          }
        }
      }
      .margin({ left: 16, right: 16 })
      .layoutWeight(1)
      .align(Alignment.Top)
      .height('100%')
      .borderRadius(16)
      .clip(false)
      .scrollBar(BarState.Off)
      .scrollable(ScrollDirection.Vertical) // 启用垂直滚动
      .edgeEffect(EdgeEffect.Spring) // 滚动边缘效果
      .padding({ bottom: SafeHeight.bottomSafeHeight })
    }
    .hideToolBar(true)
    .padding({ top: SafeHeight.topSafeHeight })
    .titleBar({
      enableComponentSafeArea: true, // 将标题栏设置为组件级安全区，内容区可避让标题栏
      padding: {
        start: LengthMetrics.vp(5),
        end: LengthMetrics.vp(5)
      },
      style: {
        // 设置导航组件标题栏样式，推荐使用默认样式
        // 标题栏动态模糊样式，包括是否使能滚动动态模糊，动态模糊类型，动态模糊生效的滚动距离等
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        originalStyle: {
          // 内容区滚动前初始样式设置
          backgroundStyle: {
            // 标题栏背板样式设置
            backgroundColor: $r('sys.color.ohos_id_color_background'),
          },
          contentStyle: {
            // 标题栏内容区样式设置，包括标题区域，菜单区域，返回按钮区域
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
          // 内容区滚动超过blurEffectiveEndOffset后样式设置
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
          mainTitle: '关于此应用',
        }
      },
    })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .hideBackButton(false)
    .bindToScrollable([this.listScroller]) // 绑定导航组件和可滚动容器组件
  }
}