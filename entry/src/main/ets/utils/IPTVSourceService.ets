import { salmonLogger } from 'salmonlogger'
import { IPTVChannel, IPTVLine, IPTVParseResult, IPTVProgram, IPTVSource, IPTVTestResult } from '../interfaces/IPTVInterface'
import ToolsUtil from './ToolsUtil'
import IPTVParser from './IPTVParser'
import IPTVSourceReader from './IPTVSourceReader'

const TAG = 'IPTVSourceService'
const MAX_SOURCE_SIZE = 20 * 1024 * 1024
const MAX_EPG_SIZE = 40 * 1024 * 1024
function defaultGroupName(): string {
  return ToolsUtil.getStringResource($r('app.string.iptv_default_group').id)
}

export default class IPTVSourceService {
  static editingSource: IPTVSource | undefined = undefined

  static async testSource(source: IPTVSource): Promise<IPTVTestResult> {
    try {
      const result = await IPTVSourceService.loadAndParse(source)
      const preparedSource = result.channels.length > 0 ? IPTVSourceService.applyParseResult(source, result) : undefined
      return {
        success: result.channels.length > 0,
        message: result.channels.length > 0 ?
          ToolsUtil.getStringResourceArgs2($r('app.string.test_success_channels').id, result.channels.length, result.groupCount) : ToolsUtil.getStringResource($r('app.string.iptv_no_channels').id),
        channelCount: result.channels.length,
        groupCount: result.groupCount,
        invalidCount: result.invalidCount,
        epgMatchedCount: result.epgMatchedCount,
        preparedSource: preparedSource
      }
    } catch (error) {
      return {
        success: false,
        message: IPTVSourceService.errorMessage(error),
        channelCount: 0,
        groupCount: 0,
        invalidCount: 0,
        epgMatchedCount: 0
      }
    }
  }

  static async refreshSource(source: IPTVSource): Promise<IPTVSource> {
    const refreshing: IPTVSource = IPTVSourceService.copySource(source)
    try {
      const result = await IPTVSourceService.loadAndParse(refreshing)
      if (result.channels.length === 0) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.iptv_no_channels').id))
      }
      return IPTVSourceService.applyParseResult(refreshing, result)
    } catch (error) {
      refreshing.lastRefreshTime = Date.now()
      refreshing.lastRefreshStatus = 'failed'
      refreshing.lastError = IPTVSourceService.errorMessage(error)
      throw new Error(refreshing.lastError)
    }
  }

  static async refreshEpg(source: IPTVSource): Promise<IPTVSource> {
    const refreshed = IPTVSourceService.copySource(source)
    const epgUrl = refreshed.epgUrl?.trim()
    if (!epgUrl || refreshed.channels.length === 0) {
      return refreshed
    }
    const epg = await IPTVSourceReader.requestText(epgUrl, refreshed.userAgent, MAX_EPG_SIZE)
    refreshed.epgMatchedCount = IPTVParser.applyXmlTv(refreshed.channels, epg)
    refreshed.lastEpgRefreshTime = Date.now()
    return refreshed
  }

  static async loadAndParse(source: IPTVSource): Promise<IPTVParseResult> {
    const content = source.sourceType === 'url' ?
      await IPTVSourceReader.requestText(source.location, source.userAgent, MAX_SOURCE_SIZE) :
      await IPTVSourceReader.readLocalText(source.location, MAX_SOURCE_SIZE)
    const isHlsManifest = /#EXT-X-(?:STREAM-INF|TARGETDURATION|MEDIA-SEQUENCE)/i.test(content) &&
      !/(?:tvg-id|tvg-name|group-title|#EXTGRP:)/i.test(content)
    const result = isHlsManifest ? {
      channels: [] as IPTVChannel[],
      groupCount: 0,
      invalidCount: 0,
      epgMatchedCount: 0
    } as IPTVParseResult : IPTVParser.parsePlaylist(content, source)
    if (isHlsManifest) {
      const line: IPTVLine = {
        url: source.location,
        userAgent: source.userAgent || undefined
      }
      result.channels.push({
        id: `${source.id}_0_${IPTVParser.hash(source.location)}`,
        name: source.name,
        url: source.location,
        groupName: defaultGroupName(),
        userAgent: line.userAgent,
        lines: [line],
        selectedLineIndex: 0
      })
      result.groupCount = 1
    }
    if (source.epgUrl?.trim() && result.channels.length > 0) {
      try {
        const epg = await IPTVSourceReader.requestText(source.epgUrl.trim(), source.userAgent, MAX_EPG_SIZE)
        result.epgMatchedCount = IPTVParser.applyXmlTv(result.channels, epg)
        result.epgRefreshTime = Date.now()
      } catch (error) {
        salmonLogger.addLog(TAG, `EPG load failed: ${IPTVSourceService.errorMessage(error)}`, true)
      }
    }
    return result
  }

  private static applyParseResult(source: IPTVSource, result: IPTVParseResult): IPTVSource {
    const prepared = IPTVSourceService.copySource(source)
    const now = Date.now()
    IPTVParser.restoreSelectedLines(source.channels, result.channels)
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

  private static copySource(source: IPTVSource): IPTVSource {
    return {
      id: source.id,
      name: source.name,
      sourceType: source.sourceType,
      location: source.location,
      userAgent: source.userAgent,
      epgUrl: source.epgUrl,
      channels: source.channels.map(channel => IPTVSourceService.copyChannel(channel)),
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
      lines: channel.lines ? channel.lines.map(line => IPTVSourceService.copyLine(line)) : undefined,
      selectedLineIndex: channel.selectedLineIndex,
      currentProgram: channel.currentProgram ? IPTVSourceService.copyProgram(channel.currentProgram) : undefined,
      nextProgram: channel.nextProgram ? IPTVSourceService.copyProgram(channel.nextProgram) : undefined,
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
