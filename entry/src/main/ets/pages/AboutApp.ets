import ToolsUtil from '../utils/ToolsUtil';
import WantProcessUtil from '../utils/WantProcessUtil';
import VideoInfoUtil from '../utils/VideoInfoUtil';
import { PathUtils } from '../utils/PathUtils';

@Component
export struct AboutApp {
  @State version_code: string = ''
  @Consume('pathStack') pathStack: NavPathStack
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 10 }) {
          Column() {
            Stack() {
              Image($r("app.media.Background"))
                .backgroundImageSize(ImageSize.Cover)
                .borderRadius(20)
                .width('100%')
                .height(140)
                .autoResize(true)
                .interpolation(ImageInterpolation.Low)
                .zIndex(1)
              Row() {
                Image($r("app.media.Foreground"))
                  .backgroundImageSize(ImageSize.Cover)
                  .autoResize(true)
                  .interpolation(ImageInterpolation.Low)
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
          }.width('100%')

          Column() {
            Row({ space: 10 }) {
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
              .padding(15)
              .borderRadius(20)
              .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
              .height(80)
              .width('48%')
              .backgroundColor($r('app.color.start_window_background_blur'))
              .onClick(() => {
                let link: string = WantProcessUtil.GITHUB_HOME_LINK;
                WantProcessUtil.linkToWeb(PathUtils.appContext!, link)
              })

              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Row() {
                  SymbolGlyph($r('sys.symbol.person_shield')).fontSize(25).fontColor([$r('app.color.text_color')])
                  Text(getContext(this).resourceManager.getStringSync($r('app.string.EntryAbility_label').id) +
                    '的使用条款与隐私声明')
                    .fontSize(15)
                    .fontColor($r('app.color.text_color'))
                    .margin({ left: 10, right: 12 })
                    .width('80%')
                }
              }
              .align(Alignment.Start)
              .padding(15)
              .borderRadius(20)
              .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
              .height(80)
              .width('48%')
              .backgroundColor($r('app.color.start_window_background_blur'))
              .onClick(() => {
                WantProcessUtil.linkToWeb(PathUtils.appContext!, WantProcessUtil.PRIVACY_LINK)
              })
            }
          }.width('100%')

          Column({ space: 8 }) {
            Text('应用简介')
              .fontSize(20).fontWeight(FontWeight.Medium)
            Column({ space: 2 }) {
              Text('一款运行在 HarmonyOS Next 上的精致、简约的本地视频播放器，使用 ArkTS 语言开发，具有美观的设计和优雅的动画。')
                .fontSize(15)
              Text('基于开源项目流心视频，本应用根据原作者授权并基于 MIT 协议二次开发而来。')
                .fontSize(15)
            }
            .alignItems(HorizontalAlign.Start)
          }
          .padding(15)
          .alignItems(HorizontalAlign.Start)
          .borderRadius(20)
          .width('100%')
          .backgroundColor($r('app.color.start_window_background_blur'))

          Column({ space: 8 }) {
            Text('播放器支持格式和注意事项')
              .fontSize(20).fontWeight(FontWeight.Medium)
            Column({ space: 2 }) {
              Text(VideoInfoUtil.support_video_format.concat(VideoInfoUtil.support_audio_format).toString())
                .fontSize(17)
              Text('1. rmvb, wmv, avi格式仅能使用 FFMpeg 播放器，其余格式若系统播放器无法播放或者没有声音，请首页长按视频选择 FFMpeg 播放器播放')
                .fontSize(14).opacity(0.7)
              Text('2. FFMpeg 播放器目前不支持 HDR 映射，不支持 HDR Vivid，不支持“高效视频格式”，不适合播放高码率视频')
                .fontSize(14).opacity(0.7)
            }.alignItems(HorizontalAlign.Start)
          }
          .padding(15)
          .alignItems(HorizontalAlign.Start)
          .borderRadius(20)
          .width('100%')
          .backgroundColor($r('app.color.start_window_background_blur'))

          Column({ space: 8 }) {
            Text('特别鸣谢')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)

            Column({ space: 2 }) {
              Text('流心视频开源项目作者：鱼Salmon')
                .fontSize(14)
                .fontColor($r('app.color.text_color'))
              Text('图标、头图等素材：科蓝kl')
                .fontSize(14)
                .fontColor($r('app.color.text_color'))
              Text('记账本 R 的作者：漫漫是我宝')
                .fontSize(14)
                .fontColor($r('app.color.text_color'))
              Text('测试视频提供：萧十一狼')
                .fontSize(14)
                .fontColor($r('app.color.text_color'))
              Text('折叠屏适配：微车游')
                .fontSize(14)
                .fontColor($r('app.color.text_color'))
              Text('kimufly')
                .fontSize(14)
                .fontColor($r('app.color.text_color'))
            }.alignItems(HorizontalAlign.Start)
          }
          .padding(15)
          .alignItems(HorizontalAlign.Start)
          .borderRadius(20)
          .width('100%')
          .backgroundColor($r('app.color.start_window_background_blur'))

          Column({ space: 8 }) {
            Text(getContext(this).resourceManager.getStringSync($r('app.string.EntryAbility_label').id) +
              '由以下开源项目提供支持')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)

            Column({ space: 2 }) {
              Text('pinyin4js')
                .fontSize(14)
              Text('ohos_ijkplayer')
                .fontSize(14)
              Text('RedPlayer')
                .fontSize(14)
              Text('subtitles')
                .fontSize(14)
            }.alignItems(HorizontalAlign.Start)
          }
          .backgroundColor($r('app.color.start_window_background_blur'))
          .padding(15)
          .alignItems(HorizontalAlign.Start)
          .borderRadius(20)
          .width('100%')
        }

      }
      .margin({ left: 16, right: 16 })
      .layoutWeight(1)
      .align(Alignment.Top)
      .height('100%')
      .borderRadius(20)
      .clip(true)
      .scrollBar(BarState.Off)
      .scrollable(ScrollDirection.Vertical) // 启用垂直滚动
      .edgeEffect(EdgeEffect.Spring) // 滚动边缘效果
    }
    .hideToolBar(true)
    .padding({ top: this.topSafeHeight })
    .title('关于此应用')
    .backgroundColor($r('app.color.start_window_background'))
  }
}