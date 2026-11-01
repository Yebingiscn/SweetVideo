export enum DocMarkdownKind {
  PARAGRAPH,
  HEADING,
  LIST,
  QUOTE,
  TABLE
}

export interface DocMarkdownInline {
  key: string
  text: string
  bold: boolean
  code: boolean
  link: string
}

export interface DocMarkdownCell {
  key: string
  spans: DocMarkdownInline[]
}

export interface DocMarkdownRow {
  key: string
  cells: DocMarkdownCell[]
}

export interface DocMarkdownBlock {
  key: string
  kind: DocMarkdownKind
  spans: DocMarkdownInline[]
  level: number
  marker: string
  indent: number
  centered: boolean
  rows: DocMarkdownRow[]
}

// Small, deterministic renderer input for bundled README/Tips documents only.
// It deliberately has no executable HTML, WebView, formula or diagram engine.
export class DocMarkdownParser {
  static parse(source: string): DocMarkdownBlock[] {
    const lines = source.replace(/^\uFEFF/, '').replace(/\r\n?/g, '\n').split('\n')
    const blocks: DocMarkdownBlock[] = []
    let index = 0
    while (index < lines.length) {
      const start = index
      const line = lines[index]
      const trimmed = line.trim()
      if (!trimmed) {
        index++
        continue
      }
      const key = `doc-${start}`
      const heading = /^(#{1,6})\s+(.+)$/.exec(trimmed)
      const centered = /^<p\s+align=["']center["']\s*>([\s\S]*?)<\/p>\s*$/i.exec(trimmed)
      const list = /^(\s*)([-+*]|\d+[.)])\s+(.+)$/.exec(line)
      if (heading) {
        const block = DocMarkdownParser.block(key, DocMarkdownKind.HEADING)
        block.level = heading[1].length
        block.spans = DocMarkdownParser.inline(heading[2].replace(/\s+#+$/, ''), key)
        blocks.push(block)
        index++
      } else if (centered) {
        const block = DocMarkdownParser.block(key, DocMarkdownKind.PARAGRAPH)
        block.centered = true
        block.spans = DocMarkdownParser.inline(centered[1], key)
        blocks.push(block)
        index++
      } else if (index + 1 < lines.length && trimmed.indexOf('|') >= 0 &&
        DocMarkdownParser.tableSeparator(lines[index + 1])) {
        const block = DocMarkdownParser.block(key, DocMarkdownKind.TABLE)
        block.rows.push(DocMarkdownParser.tableRow(line, key + '-r0'))
        index += 2
        while (index < lines.length && lines[index].trim().startsWith('|')) {
          block.rows.push(DocMarkdownParser.tableRow(lines[index], key + '-r' + block.rows.length))
          index++
        }
        blocks.push(block)
      } else if (list) {
        const block = DocMarkdownParser.block(key, DocMarkdownKind.LIST)
        block.indent = Math.min(4, Math.floor(list[1].replace(/\t/g, '    ').length / 2))
        block.marker = /^\d/.test(list[2]) ? list[2] : '•'
        let body = list[3]
        const task = /^\[([ xX])\]\s+(.+)$/.exec(body)
        if (task) {
          block.marker = task[1] === ' ' ? '☐' : '☑'
          body = task[2]
        }
        block.spans = DocMarkdownParser.inline(body, key)
        blocks.push(block)
        index++
      } else if (/^>\s?/.test(trimmed)) {
        const block = DocMarkdownParser.block(key, DocMarkdownKind.QUOTE)
        const content: string[] = []
        while (index < lines.length && /^\s*>/.test(lines[index])) {
          content.push(lines[index].replace(/^\s*>\s?/, '').replace(/\s+\\\s*$/, ''))
          index++
        }
        block.spans = DocMarkdownParser.inline(content.join('\n'), key)
        blocks.push(block)
      } else {
        const block = DocMarkdownParser.block(key, DocMarkdownKind.PARAGRAPH)
        let content = ''
        let hardBreak = false
        while (index < lines.length && lines[index].trim()) {
          if (index > start && DocMarkdownParser.startsBlock(lines, index)) {
            break
          }
          const current = lines[index]
          if (content) {
            content += hardBreak ? '\n' : ' '
          }
          content += current.trim().replace(/\s+\\\s*$/, '')
          hardBreak = /(?:\s\\\s*| {2,})$/.test(current)
          index++
        }
        block.spans = DocMarkdownParser.inline(content, key)
        blocks.push(block)
      }
    }
    return blocks
  }

  private static block(key: string, kind: DocMarkdownKind): DocMarkdownBlock {
    return {
      key: key,
      kind: kind,
      spans: [],
      level: 0,
      marker: '',
      indent: 0,
      centered: false,
      rows: []
    }
  }

  private static startsBlock(lines: string[], index: number): boolean {
    const line = lines[index].trim()
    return /^(?:#{1,6}\s|>\s?|[-+*]\s|\d+[.)]\s|<p\s)/.test(line) ||
      (line.indexOf('|') >= 0 && index + 1 < lines.length && DocMarkdownParser.tableSeparator(lines[index + 1]))
  }

  private static tableSeparator(line: string): boolean {
    const cells = DocMarkdownParser.tableCells(line)
    return cells.length >= 2 && cells.every((cell: string) => /^:?-{3,}:?$/.test(cell))
  }

  private static tableRow(line: string, key: string): DocMarkdownRow {
    const cells = DocMarkdownParser.tableCells(line)
    return {
      key: key,
      cells: cells.map((cell: string, index: number): DocMarkdownCell => {
        const cellKey = `${key}-c${index}`
        return { key: cellKey, spans: DocMarkdownParser.inline(cell, cellKey) }
      })
    }
  }

  private static tableCells(line: string): string[] {
    const cells: string[] = []
    const text = line.trim()
    let cell = ''
    let code = false
    for (let index = 0; index < text.length; index++) {
      const char = text[index]
      if (char === '\\' && text[index + 1] === '|') {
        // Only an adjacent escaped pipe is special: the Tips "\\" key survives.
        cell += '|'
        index++
      } else if (char === '`') {
        code = !code
        cell += char
      } else if (char === '|' && !code) {
        cells.push(cell.trim())
        cell = ''
      } else {
        cell += char
      }
    }
    cells.push(cell.trim())
    if (text.startsWith('|')) {
      cells.shift()
    }
    if (text.endsWith('|')) {
      cells.pop()
    }
    return cells
  }

  private static inline(source: string, key: string, bold: boolean = false, link: string = ''): DocMarkdownInline[] {
    const text = source.replace(/<br\s*\/?>/gi, '\n')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
    const spans: DocMarkdownInline[] = []
    let plain = ''
    let index = 0
    while (index < text.length) {
      if (text[index] === '\\' && /[\\`*\[\]|]/.test(text[index + 1] || '')) {
        plain += text[index + 1]
        index += 2
        continue
      }
      if (text[index] === '`') {
        const end = text.indexOf('`', index + 1)
        if (end > index + 1) {
          DocMarkdownParser.append(spans, plain, key, bold, false, link)
          plain = ''
          DocMarkdownParser.append(spans, text.slice(index + 1, end), key, bold, true, link)
          index = end + 1
          continue
        }
      }
      if (text.slice(index, index + 2) === '**') {
        const end = text.indexOf('**', index + 2)
        if (end > index + 2) {
          DocMarkdownParser.append(spans, plain, key, bold, false, link)
          plain = ''
          spans.push(...DocMarkdownParser.inline(text.slice(index + 2, end), `${key}-b${index}`, true, link))
          index = end + 2
          continue
        }
      }
      if (text[index] === '[') {
        const labelEnd = text.indexOf('](', index + 1)
        if (labelEnd >= 0) {
          let depth = 1
          let end = labelEnd + 2
          while (end < text.length && depth > 0) {
            if (text[end] === '(') {
              depth++
            }
            if (text[end] === ')') {
              depth--
            }
            if (depth > 0) {
              end++
            }
          }
          const url = text.slice(labelEnd + 2, end).trim()
          if (depth === 0 && /^https?:\/\//i.test(url)) {
            DocMarkdownParser.append(spans, plain, key, bold, false, link)
            plain = ''
            spans.push(...DocMarkdownParser.inline(text.slice(index + 1, labelEnd), `${key}-l${index}`, bold, url))
            index = end + 1
            continue
          }
        }
      }
      if (text.slice(index, index + 7) === 'http://' || text.slice(index, index + 8) === 'https://') {
        const match = /^https?:\/\/[^\s<>]+/.exec(text.slice(index))
        if (match) {
          const url = match[0].replace(/[，。；！、,.;!]+$/, '')
          DocMarkdownParser.append(spans, plain, key, bold, false, link)
          plain = ''
          DocMarkdownParser.append(spans, url, key, bold, false, url)
          index += url.length
          continue
        }
      }
      plain += text[index]
      index++
    }
    DocMarkdownParser.append(spans, plain, key, bold, false, link)
    return spans
  }

  private static append(spans: DocMarkdownInline[], text: string, key: string,
    bold: boolean, code: boolean, link: string): void {
    if (text) {
      spans.push({
        key: `${key}-s${spans.length}`,
        text: text,
        bold: bold,
        code: code,
        link: link
      })
    }
  }
}
