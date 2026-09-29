import { DanmakuSession } from '../../utils/DanmakuSession'

@ComponentV2
export struct DanmakuMenuComponent {
  @Param session: DanmakuSession = new DanmakuSession()
  @Event onImport: () => void = () => {
  }

  build() {
    Menu() {
      MenuItem({ content: '显示弹幕' })
        .enabled(this.session.items.length > 0)
        .contentFontColor(this.session.enabled && this.session.items.length > 0 ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .onClick(() => {
          this.session.enabled = !this.session.enabled
        })
        .height(40)
        .backgroundColor(this.session.enabled && this.session.items.length > 0 ? $r('app.color.main_color') :
          Color.Transparent)
        .borderRadius(16)
        .width('100%')
      MenuItem({ content: this.session.loading ? '正在导入…' : '导入本地弹幕（XML）' })
        .enabled(!this.session.loading)
        .onClick(() => this.onImport())
      if (this.session.items.length > 0) {
        MenuItem({ content: `${this.session.items.length} 条 · ${this.session.name}` })
          .enabled(false)
        MenuItem({ content: '字号', builder: this.DanmakuFontMenu })
        MenuItem({ content: '透明度', builder: this.DanmakuOpacityMenu })
        MenuItem({ content: '显示区域', builder: this.DanmakuAreaMenu })
        MenuItem({
          content: `时间偏移：${(this.session.offsetMs / 1000).toFixed(1)} 秒`,
          builder: this.DanmakuOffsetMenu
        })
      }
      MenuItem({ content: '弹幕保存在沙箱，再次播放自动加载' }).enabled(false)
    }.width(270)
  }

  @Builder
  DanmakuFontMenu() {
    Menu() {
      MenuItem({ content: '小' }).onClick(() => {
        this.session.fontSize = 18
      })
      MenuItem({ content: '中' }).onClick(() => {
        this.session.fontSize = 22
      })
      MenuItem({ content: '大' }).onClick(() => {
        this.session.fontSize = 28
      })
    }
  }

  @Builder
  DanmakuOpacityMenu() {
    Menu() {
      MenuItem({ content: '50%' }).onClick(() => {
        this.session.opacity = 0.5
      })
      MenuItem({ content: '80%' }).onClick(() => {
        this.session.opacity = 0.8
      })
      MenuItem({ content: '100%' }).onClick(() => {
        this.session.opacity = 1
      })
    }
  }

  @Builder
  DanmakuAreaMenu() {
    Menu() {
      MenuItem({ content: '上方 1/4' }).onClick(() => {
        this.session.area = 0.25
      })
      MenuItem({ content: '上半屏（默认）' }).onClick(() => {
        this.session.area = 0.5
      })
      MenuItem({ content: '上方 3/4' }).onClick(() => {
        this.session.area = 0.75
      })
    }
  }

  @Builder
  DanmakuOffsetMenu() {
    Menu() {
      MenuItem({ content: '提前 0.5 秒' })
        .onClick(() => {
          this.session.offsetMs = Math.max(-600000, this.session.offsetMs - 500)
        })
      MenuItem({ content: '延后 0.5 秒' })
        .onClick(() => {
          this.session.offsetMs = Math.min(600000, this.session.offsetMs + 500)
        })
      MenuItem({ content: '重置偏移' }).onClick(() => {
        this.session.offsetMs = 0
      })
    }
  }
}
