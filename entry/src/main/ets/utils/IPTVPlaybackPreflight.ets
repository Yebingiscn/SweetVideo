import { url } from '@kit.ArkTS'
import { connection } from '@kit.NetworkKit'
import { salmonLogger } from 'salmonlogger'
import Preferences from '../database/Preferences'
import { IPTVSource } from '../interfaces/IPTVInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import IPTVParser from './IPTVParser'
import { PathUtils } from './PathUtils'
import PrivacySpaceUtil from './PrivacySpaceUtil'

const TAG = 'IPTVPlaybackPreflight'
const RESOLVE_INTERVAL_MS = 15_000

export default class IPTVPlaybackPreflight {
  private static resolving = false
  private static lastHost = ''
  private static lastAttemptTime = 0

  static recordPlayback(video: VideoMetadata | undefined): void {
    const context = PathUtils.appContext
    const key = video?.iptv_channel_key
    if (!video?.is_iptv_live || !key || !context || PrivacySpaceUtil.getPrivacyMode()) {
      return
    }
    try {
      if (Preferences.getLastIPTVChannelKey(context) !== key) {
        Preferences.saveLastIPTVChannelKey(context, key)
      }
    } catch (_) {
      salmonLogger.addLog(TAG, '保存上次播放频道失败', true)
    }
  }

  static async resolveLastChannel(source: IPTVSource | undefined): Promise<void> {
    const context = PathUtils.appContext
    if (!source || !context || IPTVPlaybackPreflight.resolving || PrivacySpaceUtil.getPrivacyMode()) {
      return
    }
    let start = 0
    try {
      const key = Preferences.getLastIPTVChannelKey(context)
      if (!key.startsWith(`${source.id}:`)) {
        return
      }
      const channel = source.channels.find(item => IPTVParser.playbackKey(source.id, item) === key)
      if (!channel) {
        return
      }
      const address = IPTVParser.selectedLine(channel).url.replace(/^hls:\/\/(?=https?:\/\/)/i, '')
      const host = url.URL.parseURL(address).hostname.toLowerCase()
      if (!host || host.includes(':') || /^(?:\d+\.){3}\d+$/.test(host)) {
        return
      }
      const now = Date.now()
      if (host === IPTVPlaybackPreflight.lastHost && now - IPTVPlaybackPreflight.lastAttemptTime < RESOLVE_INTERVAL_MS) {
        return
      }
      start = now
      IPTVPlaybackPreflight.lastHost = host
      IPTVPlaybackPreflight.lastAttemptTime = start
      IPTVPlaybackPreflight.resolving = true
      // 使用系统 DNS，让播放器仍按原地址完成连接、鉴权和直播清单刷新。
      const addresses = await connection.getAddressesByName(host)
      salmonLogger.addLog(TAG, `DNS 预解析耗时 ${Date.now() - start} ms，地址数 ${addresses.length}`, false)
    } catch (_) {
      salmonLogger.addLog(TAG, `DNS 预解析失败${start ? `，耗时 ${Date.now() - start} ms` : ''}`, false)
    } finally {
      IPTVPlaybackPreflight.resolving = false
    }
  }
}
