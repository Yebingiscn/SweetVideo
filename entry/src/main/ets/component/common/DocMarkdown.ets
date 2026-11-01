import { util } from '@kit.ArkTS'
import { salmonLogger } from 'salmonlogger'
import { PathUtils } from '../../utils/PathUtils'
import WantProcessUtil from '../../utils/WantProcessUtil'
import {
  DocMarkdownBlock,
  DocMarkdownCell,
  DocMarkdownInline,
  DocMarkdownKind,
  DocMarkdownParser,
  DocMarkdownRow
} from '../../utils/DocMarkdownParser'

// Native text only. The parent page owns vertical scrolling.
@ComponentV2
export struct DocMarkdown {
  @Param rawfilePath: string = ''
  @Local private blocks: DocMarkdownBlock[] = []
  @Local private documentWidth: number = 320
  private requestVersion: number = 0

  aboutToAppear(): void {
    this.loadDocument()
  }

  aboutToDisappear(): void {
    this.requestVersion++
  }

  @Monitor('rawfilePath')
  onPathChanged(): void {
    this.loadDocument()
  }

  private async loadDocument(): Promise<void> {
    const version = ++this.requestVersion
    const path = this.rawfilePath
    this.blocks = []
    const context = PathUtils.appContext
    if (!context || !path) {
      return
    }
    try {
      const bytes = await context.resourceManager.getRawFileContent(path)
      if (version !== this.requestVersion || path !== this.rawfilePath) {
        return
      }
      const text = util.TextDecoder.create('utf-8', { ignoreBOM: true }).decodeToString(bytes)
      this.blocks = DocMarkdownParser.parse(text)
    } catch (error) {
      if (version !== this.requestVersion) {
        return
      }
      salmonLogger.addLog('DocMarkdown', 'Bundled document load failed: ' + path, true)
    }
  }

  private openLink(link: string): void {
    const context = PathUtils.appContext
    if (context && /^https?:\/\//i.test(link)) {
      WantProcessUtil.linkToWeb(context, link)
    }
  }

  private headingSize(level: number): number {
    return level < 3 ? 21 : (level === 3 ? 18 : 16)
  }

  private cellWidth(index: number, columns: number): number {
    if (columns === 2) {
      const first = Math.max(120, Math.min(200, this.documentWidth * 0.32))
      return index === 0 ? first : Math.max(240, this.documentWidth - first)
    }
    return Math.max(160, this.documentWidth / columns)
  }

  @Builder
  private inlineText(spans: DocMarkdownInline[], size: number = 15, weight: FontWeight = FontWeight.Normal,
    align: TextAlign = TextAlign.Start) {
    Text() {
      Repeat<DocMarkdownInline>(spans)
        .each((ri: RepeatItem<DocMarkdownInline>) => {
          Span(ri.item.text)
            .fontWeight(ri.item.bold ? FontWeight.Bold : weight)
            .fontFamily(ri.item.code ? 'monospace' : 'HarmonyOS Sans')
            .fontColor(ri.item.link ? $r('sys.color.font_emphasize') : $r('app.color.text_color'))
            .decoration({ type: ri.item.link ? TextDecorationType.Underline : TextDecorationType.None })
            .onClick(() => this.openLink(ri.item.link))
        })
        .key((span: DocMarkdownInline) => span.key)
    }
    .fontSize(size)
    .fontColor($r('app.color.text_color'))
    .lineHeight(size * 1.55)
    .textAlign(align)
    .copyOption(CopyOptions.LocalDevice)
    .width('100%')
  }

  @Builder
  private table(block: DocMarkdownBlock) {
    Scroll() {
      Column() {
        Repeat<DocMarkdownRow>(block.rows)
          .each((row: RepeatItem<DocMarkdownRow>) => {
            Row() {
              Repeat<DocMarkdownCell>(row.item.cells)
                .each((cell: RepeatItem<DocMarkdownCell>) => {
                  Column() {
                    this.inlineText(cell.item.spans, 14,
                      row.index === 0 ? FontWeight.Medium : FontWeight.Normal)
                  }
                  .width(this.cellWidth(cell.index, row.item.cells.length))
                  .padding(10)
                })
                .key((cell: DocMarkdownCell) => cell.key)
            }
            .alignItems(VerticalAlign.Top)
            .backgroundColor(row.index === 0 ? $r('app.color.start_window_background_blur') : Color.Transparent)
            .border({ width: { bottom: 0.5 }, color: '#40808080' })
          })
          .key((row: DocMarkdownRow) => row.key)
      }
      .border({ width: 0.5, color: '#40808080' })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Auto)
    .width('100%')
  }

  @Builder
  private block(block: DocMarkdownBlock) {
    if (block.kind === DocMarkdownKind.HEADING) {
      this.inlineText(block.spans, this.headingSize(block.level), FontWeight.Bold)
    } else if (block.kind === DocMarkdownKind.TABLE) {
      this.table(block)
    } else if (block.kind === DocMarkdownKind.LIST) {
      Row({ space: 8 }) {
        Text(block.marker)
          .fontSize(15)
          .lineHeight(23)
          .fontColor($r('app.color.text_color'))
          .width(24)
        Column() {
          this.inlineText(block.spans)
        }.layoutWeight(1)
      }
      .alignItems(VerticalAlign.Top)
      .padding({ left: block.indent * 16 })
      .width('100%')
    } else if (block.kind === DocMarkdownKind.QUOTE) {
      Column() {
        this.inlineText(block.spans)
      }
      .padding({ left: 12, top: 4, bottom: 4 })
      .border({ width: { left: 3 }, color: '#60808080' })
      .width('100%')
    } else {
      this.inlineText(block.spans, 15, FontWeight.Normal,
        block.centered ? TextAlign.Center : TextAlign.Start)
    }
  }

  build() {
    Column({ space: 12 }) {
      Repeat<DocMarkdownBlock>(this.blocks)
        .each((ri: RepeatItem<DocMarkdownBlock>) => {
          this.block(ri.item)
        })
        .key((block: DocMarkdownBlock) => block.key)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .onAreaChange((_oldArea: Area, area: Area) => {
      const width = Number(area.width)
      if (width > 0 && width !== this.documentWidth) {
        this.documentWidth = width
      }
    })
  }
}
