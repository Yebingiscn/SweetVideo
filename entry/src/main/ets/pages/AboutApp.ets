import ToolsUtil from '../utils/ToolsUtil';
import { common } from '@kit.AbilityKit';
import WantProcessUtil from '../utils/WantProcessUtil';


@Entry
@Component
struct AboutApp {
  @State version_code: string = ''

  build() {
    List() {
      ListItem() {
        Column() {
          Row() {
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph($r('sys.symbol.arrow_left'))
                .fontSize(20)
                .fontColor([$r('app.color.text_color')])
            }
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
            .height(40)
            .width(80)
            .backgroundColor($r('app.color.start_window_background_blur'))
            .onClick(() => {
              ToolsUtil.routerWhereOnlyUri('pages/Index')
            })
            .margin(Alignment.Start)

            Text('关于应用')
              .fontSize(20)
              .width(100)
              .height(50)
              .margin(Alignment.Center)
          }
        }
      }.margin({ top: 40, left: 20 })

      ListItem() {
        Column({ space: 20 }) {
          Stack() {
            Image($r("app.media.Background"))
              .backgroundImageSize(ImageSize.Cover)
              .borderRadius(10)
              .width('100%')
              .height('20%')
              .zIndex(1)
            Row() {
              Image($r("app.media.Foreground"))
                .backgroundImageSize(ImageSize.Cover)
                .width(80)
                .height(80)
              Text($r('app.string.EntryAbility_label'))
                .fontSize(25)
                .fontColor('#ffff')
                .margin({ left: 5, right: 5 })
              Text(this.version_code)
                .fontSize(25)
                .fontColor('#ffff')
                .onAppear(async () => {
                  this.version_code = await ToolsUtil.getVersionCode()
                })
            }.width('100%')
            .justifyContent(FlexAlign.Center)
            .zIndex(2)
          }
        }
      }.margin({ top: 20, left: 20, right: 20 })

      ListItem() {
        Column({ space: 20 }) {
          Row() {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                Image($r('app.media.github'))
                  .height(25)
                  .width(25)
                  .backgroundImageSize(ImageSize.Contain)
                Text('项目地址，欢迎 star')
                  .fontSize(15)
                  .fontColor($r('app.color.text_color'))
                  .margin({ left: 10, right: 2 })
                  .maxLines(2)
                  .width('80%')
              }
            }
            .align(Alignment.Start)
            .padding(10)
            .borderRadius(10)
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
            .height('11%')
            .width('48%')
            .backgroundColor($r('app.color.start_window_background_blur'))
            .transition(TransitionEffect.OPACITY.animation({ duration: 500 })
              .combine(TransitionEffect.translate({ x: 100 })))
            .onClick(() => {
              let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
              let link: string = WantProcessUtil.GITHUB_HOME_LINK;
              WantProcessUtil.linkToWeb(context, link)
            })

            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.person_shield')).fontSize(25).fontColor([$r('app.color.text_color')])
                Text('用户协议')
                  .fontSize(15)
                  .fontColor($r('app.color.text_color'))
                  .margin({ left: 10, right: 12 })
              }
            }
            .margin({ left: 10 })
            .align(Alignment.Start)
            .padding(10)
            .borderRadius(10)
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
            .height('11%')
            .width('48%')
            .backgroundColor($r('app.color.start_window_background_blur'))
            .transition(TransitionEffect.OPACITY.animation({ duration: 500 })
              .combine(TransitionEffect.translate({ x: 100 })))
            .onClick(() => {
              let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
              let link: string =  WantProcessUtil.PRIVACY_LINK
              WantProcessUtil.linkToWeb(context, link)
            })
          }
        }
      }.margin({ top: 20, left: 20, right: 20 })

      ListItem() {
        Column({ space: 20 }) {
          Row() {
            Text('播放器支持格式')
              .fontSize(20)
              .fontColor($r('app.color.text_color'))
          }.margin({ top: 15 })

          Row() {
            Column() {
              Text('mp4, flv, mkv, ts, mov, rmvb*, wmv*')
                .fontSize(18)
                .fontColor($r('app.color.text_color'))
              Text('带*格式仅能使用 FFMpeg 播放器，其余格式若系统播放器无法播放或者没有声音，请首页长按视频选择 FFMpeg 播放器播放')
                .fontSize(15)
                .fontColor($r('app.color.text_color'))
              Text('FFMpeg 播放器目前不支持 HDR 映射，不支持 HDR Vivid，不支持“高效视频格式”，不适合播放高码率视频')
                .fontSize(15)
                .fontColor($r('app.color.text_color'))
            }
          }.margin({ left: 2, right: 10 })
        }
        .borderRadius(10)
        .height('25%')
        .width('100%')
        .backgroundColor($r('app.color.start_window_background_blur'))
      }.width('90%').margin({ top: 20, left: 20, right: 20 })

      ListItem() {
        Column({ space: 20 }) {
          Row() {
            Text('应用简介')
              .fontSize(20)
              .fontColor($r('app.color.text_color'))
          }.margin({ top: 15 })

          Row() {
            Column() {
              Text('一款运行在 HarmonyOS Next 上的精致、简约的本地视频播放器，使用 ArkTS 语言开发，具有美观的设计和优雅的动画。')
                .fontSize(15)
                .fontColor($r('app.color.text_color'))
              Text('基于开源项目流心视频，本应用根据原作者授权并基于 MIT 协议二次开发而来。')
                .fontSize(15)
                .fontColor($r('app.color.text_color'))
            }.margin({ left: 2, right: 10 })
          }
        }
        .borderRadius(10)
        .height('20%')
        .backgroundColor($r('app.color.start_window_background_blur'))
      }.margin({ top: 20, left: 20, right: 20 })


      ListItem() {
        Column({ space: 20 }) {
          Row() {
            Text('特别鸣谢')
              .fontSize(20)
              .fontColor($r('app.color.text_color'))
          }.margin({ top: 15 })

          Row() {
            Column() {
              Text('流心视频开源项目作者：鱼Salmon')
                .fontSize(15)
                .fontColor($r('app.color.text_color'))
              Text('图标、头图等素材：科蓝kl')
                .fontSize(15)
                .fontColor($r('app.color.text_color'))
              Text('记账本 R 的作者：漫漫是我宝')
                .fontSize(15)
                .fontColor($r('app.color.text_color'))
              Text('测试视频提供：萧十一狼')
                .fontSize(15)
                .fontColor($r('app.color.text_color'))
            }
          }
        }
        .borderRadius(10)
        .height('20%').width('100%')
        .backgroundColor($r('app.color.start_window_background_blur'))
      }.margin({ top: 20, left: 20, right: 20 }).width('90%')

      ListItem() {
        Column({ space: 20 }) {
          Row() {
            Text('流心视频由以下开源项目提供支持')
              .fontSize(20)
              .fontColor($r('app.color.text_color'))
          }.margin({ top: 15 })

          Row() {
            Column() {
              Text('pinyin4js')
                .fontSize(15)
                .fontColor($r('app.color.text_color'))
              Text('ohos_ijkplayer')
                .fontSize(15)
                .fontColor($r('app.color.text_color'))
            }
          }
        }
        .borderRadius(10)
        .height('15%')
        .width('100%')
        .backgroundColor($r('app.color.start_window_background_blur'))
      }.width('90%').margin({ top: 20, left: 20, right: 20 })
    }
    .backgroundColor($r('app.color.start_window_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}