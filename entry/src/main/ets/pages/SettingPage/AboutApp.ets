import WantProcessUtil from '../../utils/WantProcessUtil'
import { PathUtils } from '../../utils/PathUtils'
import { DefaultDialogShadow, ImageFancyModifier } from '../../common/AttributeModifierConfig'
import { InfoConfirmDialog } from '../../component/Dialog/InfoConfirmDialog'
import { Markdown, MarkdownController } from '@luvi/lv-markdown-in'
import ToolsUtil from '../../utils/ToolsUtil'
import { salmonLogger } from 'salmonlogger'
import { LiqD } from '../../component/common/LiqD'
import { PrivacyPolicyComponent } from '../../component/VideoItemComponent/PrivacyPolicyComponent'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { LengthMetrics } from '@kit.ArkUI'
import { HdsNavDestination, HideMode, ScrollEffectType } from '@kit.UIDesignKit'

const TAG = 'AboutApp'

// 链接项数据结构
interface LinkItem {
  icon: Resource
  text: string
  link?: string
  isDialog?: boolean
}

@ComponentV2
export struct AboutApp {
  @Local version_code: string = ''
  @Local isPresent: boolean = false
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  controller: MarkdownController = new MarkdownController()
  private QQ_GROUP_LINK: string = 'https://qm.qq.com/q/ejj8jbUDBu'
  private AI_FA_DIAN_LINK: string = 'https://www.ifdian.net/a/SweetVideo'
  private GITHUB_HOME_LINK: string = "https://github.com/Yebingiscn/SweetVideo"
  // 链接项配置
  private linkItems: LinkItem[] = [
    { icon: $r('sys.symbol.cat_fill'), text: '代码已开源，欢迎 ⭐', link: this.GITHUB_HOME_LINK },
    {
      icon: $r('sys.symbol.book_1'),
      text: ToolsUtil.getStringResource($r('app.string.EntryAbility_label').id) + '的使用条款与隐私声明',
      isDialog: true
    },
    { icon: $r('sys.symbol.person_2'), text: 'QQ 交流群：973792610', link: this.QQ_GROUP_LINK },
    { icon: $r('sys.symbol.fish'), text: '赞赏作者', link: this.AI_FA_DIAN_LINK }
  ]
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
    this.controller.setTitleColor($r("app.color.text_color"))
    this.controller.setTextColor($r("app.color.text_color"))
    this.controller.setTableTitleBackgroundColor($r('app.color.start_window_background_blur'))
    this.controller.setQuoteBackgroundColor($r('app.color.start_window_background_blur'))
    this.controller.setTableBackgroundColor($r('app.color.start_window_background_blur'))
    this.controller.setTableInterleaveBackgroundColor($r('app.color.start_window_background_blur'))
    this.controller.setTableTitleTextColor($r("app.color.text_color"))
    this.controller.setTableInterleaveTextColor($r("app.color.text_color"))
    this.controller.setTableNormalTextColor($r("app.color.text_color"))
    this.controller.setTableBorderRadius(16)
    this.controller.setLazyRender(true)
  }

  // 链接按钮构建器
  @Builder
  LinkButton(item: LinkItem) {
    Button({ type: ButtonType.Normal }) {
      Row() {
        SymbolGlyph(item.icon).fontSize(25).fontColor([$r('app.color.text_color')])
        Text(item.text)
          .fontSize(15)
          .fontColor($r('app.color.text_color'))
          .margin({ left: 10 })
          .maxLines(2)
          .layoutWeight(1)
      }.width('100%')
    }
    .width('48%')
    .height(80)
    .padding(15)
    .borderRadius(16)
    .align(Alignment.Start)
    .backgroundColor($r('app.color.start_window_background_blur'))
    .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
    .onClick(() => {
      if (item.isDialog) {
        this.isPresent = true
      } else if (item.link) {
        this.tempLink = item.link
        this.linkConfirmDialog.open()
      }
    })
  }

  build() {
    HdsNavDestination() {
      Scroll(this.listScroller) {
        Column({ space: 10 }) {
          // 头部区域
          Stack() {
            Image($r("app.media.Background"))
              .attributeModifier(new ImageFancyModifier(16, '100%', 140))
              .zIndex(1)
            Row() {
              Image($r("app.media.Foreground"))
                .width(60).height(60)
                .autoResize(true)
                .interpolation(ImageInterpolation.Low)
              Text(`${ToolsUtil.getStringResource($r('app.string.EntryAbility_label').id)}${this.version_code}`)
                .fontSize(20)
                .fontColor($r('sys.color.white'))
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .margin({ left: 5 })
                .onAppear(async () => {
                  this.version_code = await ToolsUtil.getVersionName()
                })
            }.width('100%').justifyContent(FlexAlign.Center).zIndex(2)
          }.width('100%')

          LiqD()

          // 链接按钮区域 - 使用 Flex 替代两个 Row
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween, alignContent: FlexAlign.SpaceBetween }) {
            Repeat<LinkItem>(this.linkItems)
              .each((ri: RepeatItem<LinkItem>) => {
                this.LinkButton(ri.item)
              })
          }.width('100%').height(170)

          // Markdown 说明区域
          Column() {
            Markdown({
              controller: this.controller,
              mode: "rawfile",
              context: PathUtils.appContext!,
              rawfilePath: "README.md",
              callback: {
                complete: () => {
                  salmonLogger.addLog(TAG, "Markdown component load success.")
                },
                fail: (code: number, message: string) => {
                  salmonLogger.addLog(TAG, `Markdown load error. code: ${code}, message: ${message}`, true)
                }
              }
            })
          }
          .width('100%')
          .padding(15)
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)
          .backgroundColor($r('app.color.start_window_background_blur'))

          // 版权信息
          Text('郴州液态科技有限公司 版权所有 © 2025')
            .fontSize(14)
            .width('100%')
            .textAlign(TextAlign.Center)

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
      .clip(false)
      .margin({ left: 16, right: 16 })
      .layoutWeight(1)
      .height('100%')
      .align(Alignment.Top)
      .borderRadius(16)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ bottom: SafeHeight.bottomSafeHeight })
    }
    .hideToolBar(true)
    .padding({ top: SafeHeight.topSafeHeight })
    .titleBar({
      enableComponentSafeArea: true,
      padding: { start: LengthMetrics.vp(5), end: LengthMetrics.vp(5) },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        originalStyle: {
          backgroundStyle: { backgroundColor: $r('sys.color.ohos_id_color_background') },
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary'), subTitleColor: $r('sys.color.font_secondary') },
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
          backgroundStyle: { backgroundColor: $r('sys.color.ohos_id_color_background_transparent') },
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary'), subTitleColor: $r('sys.color.font_secondary') },
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
      content: { title: { mainTitle: '关于此应用' } }
    })
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideBottomBuilder: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP
    })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ?
        Setting.backgroundBlurImageSrc : Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .hideBackButton(false)
    .bindToScrollable([this.listScroller])
  }
}
