import { salmonLogger } from 'salmonlogger'
import { IPTVChannel, IPTVLine, IPTVParseResult, IPTVProgram, IPTVSource, IPTVUrlOptions } from '../interfaces/IPTVInterface'
import ToolsUtil from './ToolsUtil'

const TAG = 'IPTVParser'
interface XMLTVProgram extends IPTVProgram {
  channelKey: string
}
function defaultGroupName(): string {
  return ToolsUtil.getStringResource($r('app.string.iptv_default_group').id)
}

export default class IPTVParser {
  static parsePlaylist(content: string, source: IPTVSource): IPTVParseResult {
    const normalized = content.replace(/^\uFEFF/, '').replace(/\r/g, '')
    const lines = normalized.split('\n')
    const channels: IPTVChannel[] = []
    const seenUrls = new Set<string>()
    const channelIndexes = new Map<string, number>()
    let invalidCount = 0
    let pendingName = ''
    let pendingGroup = ''
    let pendingLogo = ''
    let pendingTvgId = ''
    let pendingTvgName = ''
    let pendingNumber = ''
    let currentTxtGroup = ''

    for (let index = 0; index < lines.length; index++) {
      const line = lines[index].trim()
      if (!line) {
        continue
      }
      if (line.startsWith('#EXTINF')) {
        const comma = line.indexOf(',')
        pendingName = comma >= 0 ? line.substring(comma + 1).trim() : ''
        pendingGroup = IPTVParser.readAttribute(line, 'group-title')
        pendingLogo = IPTVParser.readAttribute(line, 'tvg-logo')
        pendingTvgId = IPTVParser.readAttribute(line, 'tvg-id')
        pendingTvgName = IPTVParser.readAttribute(line, 'tvg-name')
        pendingNumber = IPTVParser.readAttribute(line, 'tvg-chno')
        continue
      }
      if (line.startsWith('#EXTGRP:')) {
        pendingGroup = line.substring('#EXTGRP:'.length).trim()
        continue
      }
      if (line.startsWith('#')) {
        continue
      }

      const txtParts = IPTVParser.splitTxtLine(line)
      if (txtParts.length >= 2 && txtParts[1].toLowerCase() === '#genre#') {
        currentTxtGroup = txtParts[0].trim()
        continue
      }

      let name = pendingName
      let url = line
      if (!pendingName && txtParts.length >= 2) {
        name = txtParts[0].trim()
        url = txtParts.slice(1).join(',').trim()
      }
      const urlInfo = IPTVParser.extractUrlOptions(url)
      url = urlInfo.url
      if (!IPTVParser.isSupportedChannelUrl(url)) {
        invalidCount++
        pendingName = ''
        pendingGroup = ''
        pendingLogo = ''
        pendingTvgId = ''
        pendingTvgName = ''
        pendingNumber = ''
        continue
      }
      if (seenUrls.has(url)) {
        pendingName = ''
        pendingGroup = ''
        pendingLogo = ''
        pendingTvgId = ''
        pendingTvgName = ''
        pendingNumber = ''
        continue
      }
      seenUrls.add(url)
      const finalName = name || pendingTvgName || `${source.name} ${channels.length + 1}`
      const groupName = pendingGroup || currentTxtGroup || defaultGroupName()
      const channelKey = IPTVParser.channelIdentity(finalName, pendingTvgId, url)
      const iptvLine: IPTVLine = {
        url: url,
        userAgent: urlInfo.userAgent || source.userAgent || undefined
      }
      const existingIndex = channelIndexes.get(channelKey)
      if (existingIndex !== undefined) {
        const existing = channels[existingIndex]
        const lines = IPTVParser.channelLines(existing)
        if (!lines.some(item => item.url === iptvLine.url)) {
          lines.push(iptvLine)
          existing.lines = lines
        }
        pendingName = ''
        pendingGroup = ''
        pendingLogo = ''
        pendingTvgId = ''
        pendingTvgName = ''
        pendingNumber = ''
        continue
      }
      channelIndexes.set(channelKey, channels.length)
      channels.push({
        id: `${source.id}_${channels.length}_${IPTVParser.hash(url)}`,
        name: finalName,
        url: url,
        groupName: groupName,
        logoUrl: pendingLogo || undefined,
        tvgId: pendingTvgId || undefined,
        tvgName: pendingTvgName || undefined,
        channelNumber: pendingNumber || undefined,
        userAgent: iptvLine.userAgent,
        lines: [iptvLine],
        selectedLineIndex: 0
      })
      pendingName = ''
      pendingGroup = ''
      pendingLogo = ''
      pendingTvgId = ''
      pendingTvgName = ''
      pendingNumber = ''
    }

    const groups = new Set<string>()
    channels.forEach(channel => groups.add(channel.groupName))
    return {
      channels: channels,
      groupCount: groups.size,
      invalidCount: invalidCount,
      epgMatchedCount: 0
    }
  }

  static deduplicateChannels(channels: IPTVChannel[]): IPTVChannel[] {
    const result: IPTVChannel[] = []
    const seenUrls = new Set<string>()
    const seenIds = new Set<string>()
    const channelIndexes = new Map<string, number>()
    for (const channel of channels) {
      const lines = IPTVParser.channelLines(channel)
      const uniqueLines: IPTVLine[] = []
      for (const line of lines) {
        const normalizedUrl = line.url.trim()
        if (!normalizedUrl || seenUrls.has(normalizedUrl)) {
          continue
        }
        seenUrls.add(normalizedUrl)
        uniqueLines.push({ url: normalizedUrl, userAgent: line.userAgent })
      }
      if (uniqueLines.length === 0) {
        continue
      }
      const channelKey = IPTVParser.channelIdentity(channel.name, channel.tvgId, uniqueLines[0].url)
      const existingIndex = channelIndexes.get(channelKey)
      if (existingIndex !== undefined) {
        const existing = result[existingIndex]
        existing.lines = [...IPTVParser.channelLines(existing), ...uniqueLines]
        continue
      }
      const selectedUrl = IPTVParser.selectedLine(channel).url
      let selectedLineIndex = uniqueLines.findIndex(line => line.url === selectedUrl)
      selectedLineIndex = selectedLineIndex >= 0 ? selectedLineIndex : 0
      const selectedLine = uniqueLines[selectedLineIndex]
      channel.url = selectedLine.url
      channel.userAgent = selectedLine.userAgent
      channel.lines = uniqueLines
      channel.selectedLineIndex = selectedLineIndex
      if (seenIds.has(channel.id)) {
        channel.id = `${channel.id}_${IPTVParser.hash(uniqueLines[0].url)}`
      }
      while (seenIds.has(channel.id)) {
        channel.id = `${channel.id}_line`
      }
      seenIds.add(channel.id)
      channelIndexes.set(channelKey, result.length)
      result.push(channel)
    }
    return result
  }

  static channelLines(channel: IPTVChannel): IPTVLine[] {
    if (channel.lines && channel.lines.length > 0) {
      return channel.lines.map((line: IPTVLine): IPTVLine => {
        const copiedLine: IPTVLine = { url: line.url, userAgent: line.userAgent }
        return copiedLine
      })
    }
    const primaryLine: IPTVLine = { url: channel.url, userAgent: channel.userAgent }
    return [primaryLine]
  }

  static selectedLine(channel: IPTVChannel): IPTVLine {
    const lines = IPTVParser.channelLines(channel)
    const index = Math.max(0, Math.min(channel.selectedLineIndex ?? 0, lines.length - 1))
    return lines[index]
  }

  static selectLine(channel: IPTVChannel, index: number): void {
    const lines = IPTVParser.channelLines(channel)
    const selectedIndex = Math.max(0, Math.min(index, lines.length - 1))
    channel.lines = lines
    channel.selectedLineIndex = selectedIndex
    channel.url = lines[selectedIndex].url
    channel.userAgent = lines[selectedIndex].userAgent
  }

  static restoreSelectedLines(oldChannels: IPTVChannel[], newChannels: IPTVChannel[]): void {
    for (const channel of newChannels) {
      const channelKey = IPTVParser.channelIdentity(channel.name, channel.tvgId, channel.url)
      const oldChannel = oldChannels.find(item =>
        IPTVParser.channelIdentity(item.name, item.tvgId, item.url) === channelKey)
      if (!oldChannel) {
        continue
      }
      const selectedUrl = IPTVParser.selectedLine(oldChannel).url
      const lineIndex = IPTVParser.channelLines(channel).findIndex(line => line.url === selectedUrl)
      if (lineIndex >= 0) {
        IPTVParser.selectLine(channel, lineIndex)
      }
    }
  }

  private static channelIdentity(name: string, tvgId: string | undefined, url: string): string {
    const normalizedName = name.trim()
      .toLowerCase()
      .replace(/[\s\-_—·|｜]+/g, '')
      .replace(
        /[（(【\[](?:高清|超清|蓝光|标清|hd|fhd|uhd|4k|8k|ipv4|ipv6|备用(?:线路|源)?\d*|线路\d+|源\d+|组播|单播)[）)】\]]/gi,
        '')
      .replace(
        /(?:高清|超清|蓝光|标清|fhd|uhd|hd|4k|8k|ipv4|ipv6|备用(?:线路|源)?\d*|线路\d+|源\d+|主线路?|主源|组播|单播)+$/gi,
        '')
      .replace(/^cctv0*1(?:综合频道?|频道)$/, 'cctv1')
    if (normalizedName) {
      return `name:${normalizedName}`
    }
    if (tvgId?.trim()) {
      return `tvg:${IPTVParser.normalizeKey(tvgId)}`
    }
    return `url:${url}`
  }

  private static splitTxtLine(line: string): string[] {
    if (line.includes(',')) {
      return line.split(',')
    }
    if (line.includes('|') && !line.match(/^https?:\/\//i)) {
      return line.split('|')
    }
    const match = line.match(/^(.+?)\s+((?:https?|rtmp|rtsp|udp|rtp|srt):\/\/.*)$/i)
    return match ? [match[1], match[2]] : [line]
  }

  private static readAttribute(line: string, key: string): string {
    const expression = new RegExp(`${key}=(?:"([^"]*)"|'([^']*)'|([^\\s,]+))`, 'i')
    const match = line.match(expression)
    return match ? (match[1] || match[2] || match[3] || '').trim() : ''
  }

  private static extractUrlOptions(value: string): IPTVUrlOptions {
    const parts = value.split('|')
    let userAgent = ''
    for (let index = 1; index < parts.length; index++) {
      const item = parts[index]
      const separator = item.indexOf('=')
      if (separator < 0) {
        continue
      }
      const key = item.substring(0, separator).trim().toLowerCase()
      if (key === 'user-agent' || key === 'user_agent' || key === 'ua') {
        userAgent = ToolsUtil.safeDecodeURIComponent(item.substring(separator + 1).trim())
      }
    }
    const result: IPTVUrlOptions = { url: parts[0].trim(), userAgent: userAgent }
    return result
  }

  private static isSupportedChannelUrl(url: string): boolean {
    return /^(https?|rtmp|rtmps|rtsp|rtp|udp|srt|hls):\/\//i.test(url)
  }

  static applyXmlTv(channels: IPTVChannel[], xml: string): number {
    const programs: XMLTVProgram[] = []
    const channelAliases = IPTVParser.readXmlTvChannelAliases(xml)
    const programsByChannel = new Map<string, XMLTVProgram[]>()
    const expression = /<programme\b([^>]*)>([\s\S]*?)<\/programme>/gi
    let match: RegExpExecArray | null = expression.exec(xml)
    const now = Date.now()
    while (match) {
      const attributes = match[1]
      const channelKey = IPTVParser.readXmlAttribute(attributes, 'channel')
      const startTime = IPTVParser.parseXmlTvTime(IPTVParser.readXmlAttribute(attributes, 'start'))
      const endTime = IPTVParser.parseXmlTvTime(IPTVParser.readXmlAttribute(attributes, 'stop'))
      if (channelKey && endTime >= now && startTime <= now + 24 * 60 * 60 * 1000) {
        const titleMatch = match[2].match(/<title(?:\s[^>]*)?>([\s\S]*?)<\/title>/i)
        const program: XMLTVProgram = {
          channelKey: channelKey,
          title: IPTVParser.decodeXml(IPTVParser.unwrapCdata(titleMatch ? titleMatch[1].trim() : ToolsUtil.getStringResource($r('app.string.unknown_program').id))),
          startTime: startTime,
          endTime: endTime
        }
        programs.push(program)
        const normalizedChannelKey = IPTVParser.normalizeEpgKey(channelKey)
        const channelPrograms = programsByChannel.get(normalizedChannelKey) ?? []
        channelPrograms.push(program)
        programsByChannel.set(normalizedChannelKey, channelPrograms)
      }
      match = expression.exec(xml)
    }
    let matched = 0
    const unmatchedChannels: string[] = []
    channels.forEach(channel => {
      channel.currentProgram = undefined
      channel.nextProgram = undefined
      const keys = [channel.tvgId, channel.tvgName, channel.name]
        .filter(key => !!key)
        .map(key => IPTVParser.normalizeEpgKey(key!))
      const xmlChannelKeys = new Set<string>()
      keys.forEach(key => {
        xmlChannelKeys.add(key)
        const aliases = channelAliases.get(key)
        aliases?.forEach(alias => xmlChannelKeys.add(alias))
      })
      const channelPrograms: XMLTVProgram[] = []
      xmlChannelKeys.forEach(key => {
        programsByChannel.get(key)?.forEach(program => channelPrograms.push(program))
      })
      channelPrograms.sort((a, b) => a.startTime - b.startTime)
      const current = channelPrograms.find(program => program.startTime <= now && program.endTime > now)
      const next = channelPrograms.find(program => program.startTime > now)
      if (current) {
        channel.currentProgram = { title: current.title, startTime: current.startTime, endTime: current.endTime }
      }
      if (next) {
        channel.nextProgram = { title: next.title, startTime: next.startTime, endTime: next.endTime }
      }
      if (current || next) {
        matched++
      } else if (unmatchedChannels.length < 5) {
        unmatchedChannels.push(`${channel.name}[tvg-id=${channel.tvgId ?? ''}]`)
      }
    })
    salmonLogger.addLog(TAG,
      `EPG parsed: programmes=${programs.length}, aliases=${channelAliases.size}, matched=${matched}/${channels.length}`,
      false)
    if (unmatchedChannels.length > 0) {
      salmonLogger.addLog(TAG, `EPG unmatched samples: ${unmatchedChannels.join(', ')}`, false)
    }
    return matched
  }

  private static readXmlTvChannelAliases(xml: string): Map<string, string[]> {
    const aliases = new Map<string, string[]>()
    const expression = /<channel\b([^>]*)>([\s\S]*?)<\/channel>/gi
    let match: RegExpExecArray | null = expression.exec(xml)
    while (match) {
      const channelId = IPTVParser.readXmlAttribute(match[1], 'id')
      const normalizedId = IPTVParser.normalizeEpgKey(channelId)
      if (normalizedId) {
        IPTVParser.addXmlTvAlias(aliases, normalizedId, normalizedId)
        const displayNameExpression = /<display-name(?:\s[^>]*)?>([\s\S]*?)<\/display-name>/gi
        let displayNameMatch: RegExpExecArray | null = displayNameExpression.exec(match[2])
        while (displayNameMatch) {
          const displayName = IPTVParser.decodeXml(IPTVParser.unwrapCdata(displayNameMatch[1].trim()))
          const normalizedDisplayName = IPTVParser.normalizeEpgKey(displayName)
          if (normalizedDisplayName) {
            IPTVParser.addXmlTvAlias(aliases, normalizedDisplayName, normalizedId)
          }
          displayNameMatch = displayNameExpression.exec(match[2])
        }
      }
      match = expression.exec(xml)
    }
    return aliases
  }

  private static addXmlTvAlias(aliases: Map<string, string[]>, alias: string, channelId: string): void {
    const channelIds = aliases.get(alias) ?? []
    if (!channelIds.includes(channelId)) {
      channelIds.push(channelId)
      aliases.set(alias, channelIds)
    }
  }

  private static readXmlAttribute(attributes: string, key: string): string {
    const match = attributes.match(new RegExp(`${key}="([^"]*)"`, 'i'))
    return match ? IPTVParser.decodeXml(match[1]) : ''
  }

  private static parseXmlTvTime(value: string): number {
    const match = value.match(/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(?:\s*([+-])(\d{2})(\d{2}))?/)
    if (!match) {
      return 0
    }
    let result = Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]), Number(match[4]),
      Number(match[5]), Number(match[6]))
    if (match[7]) {
      const offset = (Number(match[8]) * 60 + Number(match[9])) * 60 * 1000
      result += match[7] === '+' ? -offset : offset
    }
    return result
  }

  private static normalizeKey(value: string): string {
    return value.trim().toLowerCase().replace(/[\s_-]+/g, '')
  }

  private static normalizeEpgKey(value: string): string {
    return IPTVParser.normalizeKey(IPTVParser.decodeXml(IPTVParser.unwrapCdata(value)))
      .replace(/[\uff08\uff09()\u3010\u3011\[\]\u00b7|\uff5c]/g, '')
      .replace(
        /(?:\u9ad8\u6e05|\u8d85\u6e05|\u6807\u6e05|\u84dd\u5149|fhd|uhd|hd|4k|8k|\u9891\u9053|\u7535\u89c6\u53f0)+$/gi,
        '')
      .replace(/^cctv0*1(?:\u7efc\u5408)?$/i, 'cctv1')
  }

  private static unwrapCdata(value: string): string {
    const match = value.match(/^<!\[CDATA\[([\s\S]*?)\]\]>$/i)
    return match ? match[1] : value
  }

  private static decodeXml(value: string): string {
    return value.replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
  }

  static hash(value: string): string {
    let hash = 0
    for (let index = 0; index < value.length; index++) {
      hash = ((hash << 5) - hash + value.charCodeAt(index)) | 0
    }
    return Math.abs(hash).toString(36)
  }
}
