import { CircleShape, display, PathShape } from '@kit.ArkUI'
import { salmonLogger } from 'salmonlogger'

const commands =
  `M 72.91 15.95 Q 86.19 0.44 99.12 15.37 Q 39.53 69.56 66 107 Q 86 135 120 127 Q 112 133 106 135 Q 87 142 67 135 Q 34 121 32 85 Q 31.51 55.81 72.18 16.56 M 97 29 Q 104 23 111 29 Q 145.74 61.4 143 85 Q 141.51 96.77 136 104 Q 133.24 99.92 130.12 96.73 Q 133.57 90.3 134 85 Q 136.55 66.78 109 41 Q 104 38 100 41 Q 70.59 68.91 74.9 85.5 Q 78 105 98 111 Q 109.25 112 114 110 Q 114.3 115.21 117.31 118.24 Q 108.47 120.85 104.92 120.53 Q 96.75 120.72 89.71 117.74 Q 65.85 106.49 65 82 Q 64.37 59.12 97 29 M 123.03 96.52 Q 125.69 93.38 128.27 96.54 Q 136.4 104.37 136.25 110.45 Q 135.69 117.41 128.96 120.14 Q 124.55 121.22 121.98 119.96 Q 115.76 117.41 115.06 110.63 Q 114.33 105.26 122.98 96.5`
const TAG = "LiqD"

@ObservedV2
class bool {
  @Trace size: number = this.random(300, 800)
  @Trace position: Position = { x: 0, y: 0 }
  @Trace color: ResourceColor = this.rdColor()

  updateP(re: Size) {
    this.position = { x: this.random(0, re.width) / 2, y: this.random(0, re.height) - re.height / 2 }
  }

  updateE() {
    this.size = this.random(50, 500)
    this.color = this.rdColor()
  }

  random(min: number, max: number) {
    return Math.random() * (max - min) + min
  }

  rdColor() {
    const nu = Math.floor(Math.random() * 4228250625) + 1
    return `#${nu.toString(16)}`
  }
}

@ComponentV2
export struct LiqD {
  @Local bs: bool[] = []
  timer = 0
  sc = 1
  of: Position = { x: 0, y: 0 }
  effect: BackgroundEffectOptions = {
    radius: 40,
    saturation: 1.4,
    brightness: 1.3,
    color: "#19ffffff"
  }

  aboutToAppear(): void {
    for (let i = 0; i < 15; i++) {
      this.bs.push(new bool())
    }
    this.timer = setInterval(() => {
      this.bs.forEach((b, index) => {
        setTimeout(() => {
          try {
            const re = this.getUIContext().getComponentUtils().getRectangleById("LiqD").size
            const t: Size = { width: this.getUIContext().px2vp(re.width), height: this.getUIContext().px2vp(re.height) }
            this.getUIContext().animateTo({ duration: 1000 }, () => {
              b.updateE()
            })
            this.getUIContext().animateTo({ duration: 1500 }, () => {
              b.updateP(t)
            })
          } catch (error) {
            salmonLogger.addLog(TAG, error, true)
          }
        }, 100 * index)
      })
    }, 2000)

    try {
      this.sc = display.getDefaultDisplaySync().densityDPI / 300
      this.of.x = (display.getDefaultDisplaySync().densityDPI - 300) / 7
      this.of.y = (display.getDefaultDisplaySync().densityDPI - 300) / 7
    } catch (error) {
      salmonLogger.addLog(TAG, error, true)
    }
  }

  aboutToDisappear(): void {
    clearInterval(this.timer)
  }

  // 点击时更新所有气泡颜色
  updateColors() {
    // 强制触发数组更新以刷新UI
    this.bs = this.bs.map((b) => {
      b.updateE()
      return b
    })
  }

  build() {
    Stack() {
      RelativeContainer() {
        Repeat<bool>(this.bs)
          .each((repeatItem: RepeatItem<bool>) => {
            Row()
              .zIndex(-repeatItem.item.size)
              .backgroundColor(repeatItem.item.color)
              .aspectRatio(1)
              .width(repeatItem.item.size)
              .offset(repeatItem.item.position)
              .clipShape(new CircleShape({ width: repeatItem.item.size, height: repeatItem.item.size }))
              .alignRules({
                top: { anchor: "__container__", align: VerticalAlign.Top },
                left: { anchor: "__container__", align: HorizontalAlign.Start }
              })
          })
          .key((item: bool, index: number) => `${item.color}${item.size}${index}`)
      }
      .layoutWeight(1)
      .foregroundBlurStyle(BlurStyle.Thin)

      Row() {
        Column() {
          Column()
            .backgroundEffect(this.effect)
            .shadow(ShadowStyle.OUTER_DEFAULT_XS)
            .clipShape(new PathShape({ commands: commands }))
            .offset(this.of)
            .size({ width: 80, height: 80 })
            .scale({ x: this.sc, y: this.sc })
        }

        BlurText({
          Text: "LiqD",
          FontSize: 80,
          effect: this.effect
        })
      }
    }
    .id("LiqD")
    .alignContent(Alignment.Center)
    .clip(true)
    .borderRadius(25)
    .size({ width: "100%", height: 130 })
    .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
    .onClick(() => {
      this.getUIContext().animateTo({ duration: 500 }, () => {
        this.updateColors()
      })
    })
  }
}


@ComponentV2
export struct BlurText {
  @Param @Require Text: ResourceStr
  @Param @Require FontSize: number
  @Param MaxLines: number | undefined = 1
  @Param FontWeight: FontWeight | number = FontWeight.Bolder
  @Param TextAlign: TextAlign = TextAlign.Start
  @Param Opacity: number = 1
  @Param effect: BackgroundEffectOptions = {
    radius: 40,
    saturation: 1.3,
    brightness: 1.4,
    color: "#34ffffff"
  }

  build() {
    Stack() {
      Text(this.Text)
        .fontSize(this.FontSize)
        .maxLines(this.MaxLines)
        .fontWeight(this.FontWeight)
        .layoutWeight(1)
        .blendMode(BlendMode.DST_ATOP, BlendApplyType.OFFSCREEN)
        .focusable(true)
        .textAlign(this.TextAlign)
    }
    .opacity(this.Opacity)
    .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
    .backgroundEffect(this.effect)
  }
}