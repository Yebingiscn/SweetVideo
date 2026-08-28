import { fileIo as fs } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { BusinessError, zlib } from '@kit.BasicServicesKit'
import { salmonLogger } from 'salmonlogger'
import {
  IPTVChannel,
  IPTVLine,
  IPTVParseResult,
  IPTVProgram,
  IPTVSource,
  IPTVTestResult,
  IPTVUrlOptions
} from '../interfaces/IPTVInterface'
import { PathUtils } from './PathUtils'
import PermissionUtil from './PermissionUtil'
import ToolsUtil from './ToolsUtil'
import TextEncodingUtil from './TextEncodingUtil'

const TAG = 'IPTVUtil'
const DEFAULT_GROUP = '未分组'
const MAX_SOURCE_SIZE = 20 * 1024 * 1024
const MAX_EPG_SIZE = 40 * 1024 * 1024

interface XMLTVProgram extends IPTVProgram {
  channelKey: string
}

export default class IPTVUtil {
  static editingSource: IPTVSource | undefined = undefined

  static async testSource(source: IPTVSource): Promise<IPTVTestResult> {
    try {
      const result = await IPTVUtil.loadAndParse(source)
      const preparedSource = result.channels.length > 0 ? IPTVUtil.applyParseResult(source, result) : undefined
      return {
        success: result.channels.length > 0,
        message: result.channels.length > 0 ?
          `测试成功：${result.channels.length} 个频道，${result.groupCount} 个分组` : '未解析到可用频道',
        channelCount: result.channels.length,
        groupCount: result.groupCount,
        invalidCount: result.invalidCount,
        epgMatchedCount: result.epgMatchedCount,
        preparedSource: preparedSource
      }
    } catch (error) {
      return {
        success: false,
        message: IPTVUtil.errorMessage(error),
        channelCount: 0,
        groupCount: 0,
        invalidCount: 0,
        epgMatchedCount: 0
      }
    }
  }

  static async refreshSource(source: IPTVSource): Promise<IPTVSource> {
    const refreshing: IPTVSource = IPTVUtil.copySource(source)
    try {
      const result = await IPTVUtil.loadAndParse(refreshing)
      if (result.channels.length === 0) {
        throw new Error('未解析到可用频道')
      }
      return IPTVUtil.applyParseResult(refreshing, result)
    } catch (error) {
      refreshing.lastRefreshTime = Date.now()
      refreshing.lastRefreshStatus = 'failed'
      refreshing.lastError = IPTVUtil.errorMessage(error)
      throw new Error(refreshing.lastError)
    }
  }

  static async refreshEpg(source: IPTVSource): Promise<IPTVSource> {
    const refreshed = IPTVUtil.copySource(source)
    const epgUrl = refreshed.epgUrl?.trim()
    if (!epgUrl || refreshed.channels.length === 0) {
      return refreshed
    }
    const epg = await IPTVUtil.requestText(epgUrl, refreshed.userAgent, MAX_EPG_SIZE)
    refreshed.epgMatchedCount = IPTVUtil.applyXmlTv(refreshed.channels, epg)
    refreshed.lastEpgRefreshTime = Date.now()
    return refreshed
  }

  static async loadAndParse(source: IPTVSource): Promise<IPTVParseResult> {
    const content = source.sourceType === 'url' ?
      await IPTVUtil.requestText(source.location, source.userAgent, MAX_SOURCE_SIZE) :
      await IPTVUtil.readLocalText(source.location, MAX_SOURCE_SIZE)
    const isHlsManifest = /#EXT-X-(?:STREAM-INF|TARGETDURATION|MEDIA-SEQUENCE)/i.test(content) &&
      !/(?:tvg-id|tvg-name|group-title|#EXTGRP:)/i.test(content)
    const result = isHlsManifest ? {
      channels: [] as IPTVChannel[],
      groupCount: 0,
      invalidCount: 0,
      epgMatchedCount: 0
    } as IPTVParseResult : IPTVUtil.parsePlaylist(content, source)
    if (isHlsManifest) {
      const line: IPTVLine = {
        url: source.location,
        userAgent: source.userAgent || undefined
      }
      result.channels.push({
        id: `${source.id}_0_${IPTVUtil.hash(source.location)}`,
        name: source.name,
        url: source.location,
        groupName: DEFAULT_GROUP,
        userAgent: line.userAgent,
        lines: [line],
        selectedLineIndex: 0
      })
      result.groupCount = 1
    }
    if (source.epgUrl?.trim() && result.channels.length > 0) {
      try {
        const epg = await IPTVUtil.requestText(source.epgUrl.trim(), source.userAgent, MAX_EPG_SIZE)
        result.epgMatchedCount = IPTVUtil.applyXmlTv(result.channels, epg)
        result.epgRefreshTime = Date.now()
      } catch (error) {
        salmonLogger.addLog(TAG, `EPG load failed: ${IPTVUtil.errorMessage(error)}`, true)
      }
    }
    return result
  }

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
        pendingGroup = IPTVUtil.readAttribute(line, 'group-title')
        pendingLogo = IPTVUtil.readAttribute(line, 'tvg-logo')
        pendingTvgId = IPTVUtil.readAttribute(line, 'tvg-id')
        pendingTvgName = IPTVUtil.readAttribute(line, 'tvg-name')
        pendingNumber = IPTVUtil.readAttribute(line, 'tvg-chno')
        continue
      }
      if (line.startsWith('#EXTGRP:')) {
        pendingGroup = line.substring('#EXTGRP:'.length).trim()
        continue
      }
      if (line.startsWith('#')) {
        continue
      }

      const txtParts = IPTVUtil.splitTxtLine(line)
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
      const urlInfo = IPTVUtil.extractUrlOptions(url)
      url = urlInfo.url
      if (!IPTVUtil.isSupportedChannelUrl(url)) {
        invalidCount++
        IPTVUtil.clearPendingValues(() => {
          pendingName = ''
          pendingGroup = ''
          pendingLogo = ''
          pendingTvgId = ''
          pendingTvgName = ''
          pendingNumber = ''
        })
        continue
      }
      if (seenUrls.has(url)) {
        IPTVUtil.clearPendingValues(() => {
          pendingName = ''
          pendingGroup = ''
          pendingLogo = ''
          pendingTvgId = ''
          pendingTvgName = ''
          pendingNumber = ''
        })
        continue
      }
      seenUrls.add(url)
      const finalName = name || pendingTvgName || `${source.name} ${channels.length + 1}`
      const groupName = pendingGroup || currentTxtGroup || DEFAULT_GROUP
      const channelKey = IPTVUtil.channelIdentity(finalName, pendingTvgId, url)
      const iptvLine: IPTVLine = {
        url: url,
        userAgent: urlInfo.userAgent || source.userAgent || undefined
      }
      const existingIndex = channelIndexes.get(channelKey)
      if (existingIndex !== undefined) {
        const existing = channels[existingIndex]
        const lines = IPTVUtil.channelLines(existing)
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
        id: `${source.id}_${channels.length}_${IPTVUtil.hash(url)}`,
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
      const lines = IPTVUtil.channelLines(channel)
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
      const channelKey = IPTVUtil.channelIdentity(channel.name, channel.tvgId, uniqueLines[0].url)
      const existingIndex = channelIndexes.get(channelKey)
      if (existingIndex !== undefined) {
        const existing = result[existingIndex]
        existing.lines = [...IPTVUtil.channelLines(existing), ...uniqueLines]
        continue
      }
      const selectedUrl = IPTVUtil.selectedLine(channel).url
      let selectedLineIndex = uniqueLines.findIndex(line => line.url === selectedUrl)
      selectedLineIndex = selectedLineIndex >= 0 ? selectedLineIndex : 0
      const selectedLine = uniqueLines[selectedLineIndex]
      channel.url = selectedLine.url
      channel.userAgent = selectedLine.userAgent
      channel.lines = uniqueLines
      channel.selectedLineIndex = selectedLineIndex
      if (seenIds.has(channel.id)) {
        channel.id = `${channel.id}_${IPTVUtil.hash(uniqueLines[0].url)}`
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
    const lines = IPTVUtil.channelLines(channel)
    const index = Math.max(0, Math.min(channel.selectedLineIndex ?? 0, lines.length - 1))
    return lines[index]
  }

  static selectLine(channel: IPTVChannel, index: number): void {
    const lines = IPTVUtil.channelLines(channel)
    const selectedIndex = Math.max(0, Math.min(index, lines.length - 1))
    channel.lines = lines
    channel.selectedLineIndex = selectedIndex
    channel.url = lines[selectedIndex].url
    channel.userAgent = lines[selectedIndex].userAgent
  }

  private static applyParseResult(source: IPTVSource, result: IPTVParseResult): IPTVSource {
    const prepared = IPTVUtil.copySource(source)
    const now = Date.now()
    IPTVUtil.restoreSelectedLines(source.channels, result.channels)
    prepared.channels = result.channels
    prepared.channelCount = result.channels.length
    prepared.groupCount = result.groupCount
    prepared.epgMatchedCount = result.epgMatchedCount
    prepared.lastEpgRefreshTime = source.epgUrl?.trim() ? result.epgRefreshTime : undefined
    prepared.lastRefreshTime = now
    prepared.updatedTime = now
    prepared.lastRefreshStatus = 'success'
    prepared.lastError = ''
    return prepared
  }

  private static restoreSelectedLines(oldChannels: IPTVChannel[], newChannels: IPTVChannel[]): void {
    for (const channel of newChannels) {
      const channelKey = IPTVUtil.channelIdentity(channel.name, channel.tvgId, channel.url)
      const oldChannel = oldChannels.find(item =>
      IPTVUtil.channelIdentity(item.name, item.tvgId, item.url) === channelKey)
      if (!oldChannel) {
        continue
      }
      const selectedUrl = IPTVUtil.selectedLine(oldChannel).url
      const lineIndex = IPTVUtil.channelLines(channel).findIndex(line => line.url === selectedUrl)
      if (lineIndex >= 0) {
        IPTVUtil.selectLine(channel, lineIndex)
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
      return `tvg:${IPTVUtil.normalizeKey(tvgId)}`
    }
    return `url:${url}`
  }

  private static clearPendingValues(clear: () => void): void {
    clear()
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

  private static applyXmlTv(channels: IPTVChannel[], xml: string): number {
    const programs: XMLTVProgram[] = []
    const channelAliases = IPTVUtil.readXmlTvChannelAliases(xml)
    const programsByChannel = new Map<string, XMLTVProgram[]>()
    const expression = /<programme\b([^>]*)>([\s\S]*?)<\/programme>/gi
    let match: RegExpExecArray | null = expression.exec(xml)
    const now = Date.now()
    while (match) {
      const attributes = match[1]
      const channelKey = IPTVUtil.readXmlAttribute(attributes, 'channel')
      const startTime = IPTVUtil.parseXmlTvTime(IPTVUtil.readXmlAttribute(attributes, 'start'))
      const endTime = IPTVUtil.parseXmlTvTime(IPTVUtil.readXmlAttribute(attributes, 'stop'))
      if (channelKey && endTime >= now && startTime <= now + 24 * 60 * 60 * 1000) {
        const titleMatch = match[2].match(/<title(?:\s[^>]*)?>([\s\S]*?)<\/title>/i)
        const program: XMLTVProgram = {
          channelKey: channelKey,
          title: IPTVUtil.decodeXml(IPTVUtil.unwrapCdata(titleMatch ? titleMatch[1].trim() : '未知节目')),
          startTime: startTime,
          endTime: endTime
        }
        programs.push(program)
        const normalizedChannelKey = IPTVUtil.normalizeEpgKey(channelKey)
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
        .map(key => IPTVUtil.normalizeEpgKey(key!))
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
      const channelId = IPTVUtil.readXmlAttribute(match[1], 'id')
      const normalizedId = IPTVUtil.normalizeEpgKey(channelId)
      if (normalizedId) {
        IPTVUtil.addXmlTvAlias(aliases, normalizedId, normalizedId)
        const displayNameExpression = /<display-name(?:\s[^>]*)?>([\s\S]*?)<\/display-name>/gi
        let displayNameMatch: RegExpExecArray | null = displayNameExpression.exec(match[2])
        while (displayNameMatch) {
          const displayName = IPTVUtil.decodeXml(IPTVUtil.unwrapCdata(displayNameMatch[1].trim()))
          const normalizedDisplayName = IPTVUtil.normalizeEpgKey(displayName)
          if (normalizedDisplayName) {
            IPTVUtil.addXmlTvAlias(aliases, normalizedDisplayName, normalizedId)
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
    return match ? IPTVUtil.decodeXml(match[1]) : ''
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
    return IPTVUtil.normalizeKey(IPTVUtil.decodeXml(IPTVUtil.unwrapCdata(value)))
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

  private static async requestText(url: string, userAgent: string | undefined, maxSize: number): Promise<string> {
    if (!/^https?:\/\//i.test(url.trim())) {
      throw new Error('仅支持 HTTP/HTTPS/远程TXT 节目源和 EPG 地址')
    }
    return new Promise((resolve, reject) => {
      const request = http.createHttp()
      const headers: Record<string, string> = {}
      if (userAgent?.trim()) {
        headers['User-Agent'] = userAgent.trim()
      }
      request.request(url.trim(), {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 10000,
        readTimeout: 15000
      }, (error: BusinessError, response: http.HttpResponse) => {
        if (error) {
          request.destroy()
          reject(new Error(`请求失败：${error.message || error.code}`))
          return
        }
        const code = response.responseCode
        if (code < 200 || code >= 300) {
          request.destroy()
          reject(new Error(`HTTP ${code}`))
          return
        }
        const buffer = response.result as ArrayBuffer
        if (buffer.byteLength > maxSize) {
          request.destroy()
          reject(new Error('文件过大，已停止读取'))
          return
        }
        IPTVUtil.decodeBuffer(buffer, maxSize).then((text: string) => {
          resolve(text)
        }).catch((decodeError: Error) => {
          reject(decodeError)
        }).finally(() => {
          request.destroy()
        })
      })
    })
  }

  private static async readLocalText(uri: string, maxSize: number): Promise<string> {
    await PermissionUtil.activatePermission(uri)
    let file: fs.File | undefined = undefined
    try {
      file = await fs.open(uri, fs.OpenMode.READ_ONLY)
      const stat = await fs.stat(file.fd)
      const size = stat.size
      if (size > maxSize) {
        throw new Error('文件过大，已停止读取')
      }
      const buffer = new ArrayBuffer(size)
      await fs.read(file.fd, buffer)
      return await IPTVUtil.decodeBuffer(buffer, maxSize)
    } catch (error) {
      salmonLogger.addLog(TAG, `readLocalText failed: ${IPTVUtil.errorMessage(error)}`, true)
      return ''
    } finally {
      if (file) {
        try {
          await fs.close(file)
        } catch (error) {
          salmonLogger.addLog(TAG, `Close local file failed: ${IPTVUtil.errorMessage(error)}`, true)
        }
      }
    }
  }

  private static async decodeBuffer(buffer: ArrayBuffer, maxSize: number): Promise<string> {
    const decodedBuffer = IPTVUtil.isGzipBuffer(buffer) ? await IPTVUtil.gunzipBuffer(buffer, maxSize) : buffer
    if (decodedBuffer.byteLength > maxSize) {
      throw new Error('解压后文件过大，已停止读取')
    }
    const bytes = new Uint8Array(decodedBuffer)
    const detectedEncoding = TextEncodingUtil.detectBufferEncoding(decodedBuffer)
    const encoding = detectedEncoding || 'UTF-8'
    try {
      const decoder = util.TextDecoder.create(encoding, { ignoreBOM: true })
      return decoder.decodeToString(bytes, { stream: false })
    } catch (error) {
      salmonLogger.addLog(TAG, `Decode ${encoding} text failed, fallback to UTF-8: ${IPTVUtil.errorMessage(error)}`, true)
      const fallbackDecoder = util.TextDecoder.create('UTF-8', { ignoreBOM: true })
      return fallbackDecoder.decodeToString(bytes, { stream: false })
    }
  }

  private static isGzipBuffer(buffer: ArrayBuffer): boolean {
    const bytes = new Uint8Array(buffer)
    return bytes.length >= 2 && bytes[0] === 0x1F && bytes[1] === 0x8B
  }

  private static async gunzipBuffer(buffer: ArrayBuffer, maxSize: number): Promise<ArrayBuffer> {
    if (!PathUtils.tempPath) {
      throw new Error('无法创建 EPG 解压缓存')
    }
    const tempPath = `${PathUtils.tempPath}/iptv_epg_${Date.now()}_${Math.floor(Math.random() * 1000000)}.gz`
    let gzip: zlib.GZip | undefined = undefined
    let opened = false
    try {
      const file = await fs.open(tempPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      try {
        await fs.write(file.fd, buffer)
      } finally {
        try {
          await fs.close(file)
        } catch (error) {
          salmonLogger.addLog(TAG, `Close temp gzip file failed: ${IPTVUtil.errorMessage(error)}`, true)
        }
      }

      gzip = await zlib.createGZip()
      await gzip.gzopen(tempPath, 'rb')
      opened = true
      const chunks: ArrayBuffer[] = []
      let totalSize = 0
      const chunkSize = 64 * 1024
      while (true) {
        const chunk = new ArrayBuffer(chunkSize)
        const readSize = await gzip.gzfread(chunk, 1, chunkSize)
        if (readSize > 0) {
          totalSize += readSize
          if (totalSize > maxSize) {
            throw new Error('解压后文件过大，已停止读取')
          }
          chunks.push(chunk.slice(0, readSize))
        }
        if (readSize < chunkSize) {
          if (await gzip.gzeof() !== 0) {
            break
          }
          const gzipError = await gzip.gzerror()
          throw new Error(`Gzip 解压失败：${gzipError.statusMsg || gzipError.status}`)
        }
      }

      const result = new ArrayBuffer(totalSize)
      const resultBytes = new Uint8Array(result)
      let offset = 0
      chunks.forEach(chunk => {
        const chunkBytes = new Uint8Array(chunk)
        resultBytes.set(chunkBytes, offset)
        offset += chunkBytes.length
      })
      salmonLogger.addLog(TAG, `Gzip decompressed: ${buffer.byteLength} -> ${result.byteLength} bytes`, false)
      return result
    } catch (error) {
      const message = IPTVUtil.errorMessage(error)
      salmonLogger.addLog(TAG, `Gzip decompressed error: ${message}`, true)
      throw new Error(message)
    } finally {
      if (opened && gzip) {
        try {
          await gzip.gzcloser()
        } catch (error) {
          salmonLogger.addLog(TAG, `Close gzip failed: ${IPTVUtil.errorMessage(error)}`, true)
        }
      }
      try {
        await fs.access(tempPath)
        await fs.unlink(tempPath)
      } catch (error) {
        salmonLogger.addLog(TAG, `Remove temp gzip file failed: ${IPTVUtil.errorMessage(error)}`, true)
      }
    }
  }

  private static hash(value: string): string {
    let hash = 0
    for (let index = 0; index < value.length; index++) {
      hash = ((hash << 5) - hash + value.charCodeAt(index)) | 0
    }
    return Math.abs(hash).toString(36)
  }

  private static copySource(source: IPTVSource): IPTVSource {
    return {
      id: source.id,
      name: source.name,
      sourceType: source.sourceType,
      location: source.location,
      userAgent: source.userAgent,
      epgUrl: source.epgUrl,
      channels: source.channels.map(channel => IPTVUtil.copyChannel(channel)),
      channelCount: source.channelCount,
      groupCount: source.groupCount,
      createdTime: source.createdTime,
      updatedTime: source.updatedTime,
      lastRefreshTime: source.lastRefreshTime,
      lastEpgRefreshTime: source.lastEpgRefreshTime,
      lastRefreshStatus: source.lastRefreshStatus,
      lastError: source.lastError,
      epgMatchedCount: source.epgMatchedCount,
    }
  }

  private static copyChannel(channel: IPTVChannel): IPTVChannel {
    return {
      id: channel.id,
      name: channel.name,
      url: channel.url,
      groupName: channel.groupName,
      logoUrl: channel.logoUrl,
      tvgId: channel.tvgId,
      tvgName: channel.tvgName,
      channelNumber: channel.channelNumber,
      userAgent: channel.userAgent,
      lines: channel.lines ? channel.lines.map(line => IPTVUtil.copyLine(line)) : undefined,
      selectedLineIndex: channel.selectedLineIndex,
      currentProgram: channel.currentProgram ? IPTVUtil.copyProgram(channel.currentProgram) : undefined,
      nextProgram: channel.nextProgram ? IPTVUtil.copyProgram(channel.nextProgram) : undefined,
    }
  }

  private static copyLine(line: IPTVLine): IPTVLine {
    return { url: line.url, userAgent: line.userAgent }
  }

  private static copyProgram(program: IPTVProgram): IPTVProgram {
    return { title: program.title, startTime: program.startTime, endTime: program.endTime }
  }

  private static errorMessage(error: Object): string {
    if (error instanceof Error) {
      return error.message
    }
    return String(error)
  }
}
