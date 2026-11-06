import { Context } from '@kit.AbilityKit'
import Preferences from '../database/Preferences'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { PathUtils } from './PathUtils'
import { salmonLogger } from 'salmonlogger'

const TAG = 'RecentPlayUtil'

// 最近播放类
export default class RecentPlayUtil {
  public static deque: VideoMetadata[] = []
  private static readonly MAX_SIZE = 30
  private static videoIdMap: Map<string, number> = new Map()

  static addPlayback(context: Context, item: VideoMetadata, requireSuccess: boolean = false): boolean {
    try {
      if (item?.uri == null) throw new Error('Playback URI is unavailable')
      // 默认容错只控制如何报告失败，不能把读取失败的空数组用作写回基线。
      const latest = Preferences.getRecentPlay(context, true)
      const seen = new Set<string>()
      const updated = [item, ...latest].filter(video => {
        if (seen.has(video.uri)) return false
        seen.add(video.uri)
        return true
      }).slice(0, RecentPlayUtil.MAX_SIZE)
      Preferences.saveRecentPlay(context, updated, true)
      RecentPlayUtil.publishData(updated)
      return true
    } catch (_error) {
      salmonLogger.addLog(TAG, '更新播放历史失败，保留原有数据', true)
      if (requireSuccess) throw new Error('Playback history could not be saved')
      return false
    }
  }

  static getRecentPlaybacks(): VideoMetadata[] {
    try {
      const latest = Preferences.getRecentPlay(PathUtils.appContext!, true)
      RecentPlayUtil.publishData([...latest])
      return [...latest]
    } catch (_error) {
      // 仅用于展示的回退，不替换最后一次成功快照；写操作始终另行严格读取。
      salmonLogger.addLog(TAG, '读取播放历史失败，保留最近一次成功快照', true)
      return [...RecentPlayUtil.deque]
    }
  }

  public static delData(context: Context, uri: string, requireSuccess: boolean = false): boolean {
    try {
      const latest = Preferences.getRecentPlay(context, true)
      const retained = latest.filter(item => item.uri !== uri)
      if (retained.length !== latest.length) {
        Preferences.saveRecentPlay(context, retained, true)
      }
      RecentPlayUtil.publishData(retained)
      return true
    } catch (_error) {
      salmonLogger.addLog(TAG, '删除播放历史失败，保留原有数据', true)
      if (requireSuccess) throw new Error('Playback history could not be deleted')
      return false
    }
  }

  static clearData(context: Context): boolean {
    try {
      // 用户确认清空全部历史，无需用界面快照逐条读改写。
      const empty: VideoMetadata[] = []
      Preferences.saveRecentPlay(context, empty, true)
      RecentPlayUtil.publishData(empty)
      return true
    } catch (_error) {
      salmonLogger.addLog(TAG, '清空播放历史失败，保留原有数据', true)
      return false
    }
  }

  private static publishData(items: VideoMetadata[]): void {
    RecentPlayUtil.deque = items
    RecentPlayUtil.updateMapIndices()
  }

  private static updateMapIndices() {
    RecentPlayUtil.videoIdMap.clear()
    RecentPlayUtil.deque.forEach((item, index) => {
      RecentPlayUtil.videoIdMap.set(item.uri, index)
    })
  }
}
