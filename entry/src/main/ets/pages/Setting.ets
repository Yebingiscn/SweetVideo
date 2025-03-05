import ToolsUtil from '../utils/ToolsUtil'
import router from '@ohos.router'
import PreferencesUtil from '../utils/PreferencesUtil'
import DataSyncUtil from '../utils/DataSyncUtil'

@Entry
@Component
struct SettingsPage {
  @StorageLink('allowBackgroundPlay') allowBackgroundPlay: boolean = true
  @StorageLink('allowPlayBackExist') allowPlayBackExist: boolean = false
  @StorageLink('fastForwardSeconds') fastForwardSeconds: string = '15'
  @StorageLink('defaultPlayer') defaultPlayer: string = 'FFMpeg播放器'
  @StorageLink('subtitleSize') subtitleSize: string = '22'
  fastForwardSecondsList = ['15', '30', '60', '120']
  subtitleSizeList = ['19', '20', '21', '22', '23', '24', '25', '26']

  build() {
    Column() {
      Row({ space: 12 }) {
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
          router.back()
        })

        Text('设置')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
      }.margin({ top: DataSyncUtil.getActuallyTopSafeHeight() })
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 12,
        bottom: 12
      })
      .justifyContent(FlexAlign.Start)

      Scroll() {
        Column() {
          Row() {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.info_circle')).fontSize(25)
                Text('关于应用')
                  .fontSize(18)
                  .fontColor($r('app.color.text_color'))
                  .margin({ left: 10, right: 12 })
              }
            }
            .align(Alignment.Center)
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
            .backgroundColor($r('app.color.start_window_background_blur'))
            .animation({ duration: 300, curve: Curve.Ease })
            .height(80)
            .width('100%')
            .borderRadius(10)
            .onClick(() => {
              ToolsUtil.routerWhereOnlyUri('pages/AboutApp')
            })
          }
          .padding(16)
          .width('100%')
          .backgroundColor($r('app.color.start_window_background_blur'))
          .borderRadius(10)

          Row() {
            Text('允许后台播放')
              .fontSize(18)
              .flexGrow(1)
            Toggle({ type: ToggleType.Switch, isOn: this.allowBackgroundPlay })
              .onChange((value: boolean) => {
                this.allowBackgroundPlay = value
                PreferencesUtil.putPreferencesValue("sweet_video", "allowBackgroundPlay", this.allowBackgroundPlay)
              })
              .selectedColor($r('app.color.main_color'))
          }
          .padding(16)
          .width('100%')
          .backgroundColor($r('app.color.start_window_background_blur'))
          .borderRadius(10)
          .margin({ top: 12 })

          Row() {
            Text('播放器使用返回手势直接退出')
              .fontSize(18)
              .flexGrow(1)
            Toggle({ type: ToggleType.Switch, isOn: this.allowPlayBackExist })
              .onChange((value: boolean) => {
                this.allowPlayBackExist = value
                PreferencesUtil.putPreferencesValue("sweet_video", "allowPlayBackExist", this.allowPlayBackExist)
              })
              .selectedColor($r('app.color.main_color'))
          }
          .padding(16)
          .width('100%')
          .backgroundColor($r('app.color.start_window_background_blur'))
          .borderRadius(10)
          .margin({ top: 12 })

          Row() {
            Text('快进（后退）时长（秒）')
              .fontSize(18)
              .flexGrow(1)
            Select([
              { value: '15' },
              { value: '30' },
              { value: '60' },
              { value: '120' }])
              .font({ size: 18, weight: FontWeight.Medium })
              .value(this.fastForwardSeconds)
              .fontColor($r('app.color.text_color'))
              .selected(this.fastForwardSecondsList.indexOf(this.fastForwardSeconds))
              .onSelect((_index: number, text?: string | undefined) => {
                this.fastForwardSeconds = text!
                PreferencesUtil.putPreferencesValue("sweet_video", "fastForwardTime", this.fastForwardSeconds)
              })
          }
          .padding(16)
          .width('100%')
          .backgroundColor($r('app.color.start_window_background_blur'))
          .borderRadius(10)
          .margin({ top: 12 })

          Row() {
            Text('外链默认播放器')
              .fontSize(18)
              .flexGrow(1)
            Select([
              { value: '系统播放器' },
              { value: 'FFMpeg播放器' }])
              .font({ size: 18, weight: FontWeight.Medium })
              .value(this.defaultPlayer)
              .selected(this.defaultPlayer == 'FFMpeg播放器' ? 1 : 0)
              .fontColor($r('app.color.text_color'))
              .onSelect((_index: number, text?: string | undefined) => {
                this.defaultPlayer = text!
                PreferencesUtil.putPreferencesValue("sweet_video", "defaultPlayer", this.defaultPlayer)
              })
          }
          .padding(16)
          .width('100%')
          .backgroundColor($r('app.color.start_window_background_blur'))
          .borderRadius(10)
          .margin({ top: 12 })

          Row() {
            Text('字幕字体大小')
              .fontSize(18)
              .flexGrow(1)
            Select([
              { value: '19' },
              { value: '20' },
              { value: '21' },
              { value: '22' },
              { value: '23' },
              { value: '24' },
              { value: '25' },
              { value: '26' }])
              .font({ size: 18, weight: FontWeight.Medium })
              .value(this.subtitleSize)
              .selected(this.subtitleSizeList.indexOf(this.subtitleSize))
              .fontColor($r('app.color.text_color'))
              .onSelect((_index: number, text?: string | undefined) => {
                this.subtitleSize = text!
                PreferencesUtil.putPreferencesValue("sweet_video", "subTitleSize", this.subtitleSize)
              })
          }
          .padding(16)
          .width('100%')
          .backgroundColor($r('app.color.start_window_background_blur'))
          .borderRadius(10)
          .margin({ top: 12 })
        }
        .padding({ left: 16, right: 16 })
        .width('100%')
      }
      .align(Alignment.Top)
      .scrollable(ScrollDirection.Vertical) // 启用垂直滚动
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring) // 滚动边缘效果
      .width('100%')
      .height('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .backgroundColor($r('app.color.start_window_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}