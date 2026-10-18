import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { ItemWithPinyin } from '../interfaces/VideoItemWithPinyinInterface'
import NameSortUtil from './NameSortUtil'

interface CachedPinyinKey {
  name: string
  key: string
}

// 不保存媒体数据；持久化仍由 ToolsUtil.sortBy 在排序完成后统一处理。
export default class MediaSortUtil {
  private static collator: Intl.Collator | undefined = undefined
  private static pinyinKeys: WeakMap<VideoMetadata | FileFolder, CachedPinyinKey> = new WeakMap()

  static sortByNameProcess(list: VideoMetadata[], ascending: boolean = true, pinyinSort: boolean = true): VideoMetadata[] {
    return MediaSortUtil.sortByName(list, item => item.title || '', ascending, pinyinSort)
  }

  static sortFolderByNameProcess(list: FileFolder[], ascending: boolean = true, pinyinSort: boolean = true): FileFolder[] {
    return MediaSortUtil.sortByName(list, item => item.name || '', ascending, pinyinSort)
  }

  static sortByNumericProperty(list: VideoMetadata[], key: 'date' | 'time', ascending: boolean = false): VideoMetadata[] {
    return [...list].sort((a, b) => {
      let aVal: number
      let bVal: number
      if (key === 'date') {
        aVal = Number(a.date)
        bVal = Number(b.date)
      } else {
        aVal = Number(a.time)
        bVal = Number(b.time)
      }
      const cmp = aVal - bVal
      return ascending ? cmp : -cmp
    })
  }

  static sortByDatetimeProcess(list: VideoMetadata[], ascending: boolean = false): VideoMetadata[] {
    return MediaSortUtil.sortByNumericProperty(list, 'date', ascending)
  }

  static sortByTimeProcess(list: VideoMetadata[], ascending: boolean = false): VideoMetadata[] {
    return MediaSortUtil.sortByNumericProperty(list, 'time', ascending)
  }

  static sortByRecentPlayProcess(list: VideoMetadata[], ascending: boolean = false): VideoMetadata[] {
    return [...list].sort((a, b) => {
      const aVal = a.last_played_at ?? 0
      const bVal = b.last_played_at ?? 0
      if (aVal === bVal) {
        return 0
      }
      if (aVal <= 0 || bVal <= 0) {
        return aVal <= 0 ? 1 : -1
      }
      const cmp = aVal - bVal
      return ascending ? cmp : -cmp
    })
  }

  static getMostRecentlyPlayed(list: VideoMetadata[]): VideoMetadata | undefined {
    let latest: VideoMetadata | undefined = undefined
    let latestTime = 0
    for (const item of list) {
      const playedAt = item.last_played_at ?? 0
      if (playedAt > latestTime) {
        latestTime = playedAt
        latest = item
      }
    }
    return latest
  }

  static getFirstLetter(title: string): string {
    if (!title || title.length === 0) {
      return '#'
    }
    const pinyin = NameSortUtil.getSortKey(title, true)
    if (pinyin.length === 0) {
      return '#'
    }
    const first = pinyin[0].toUpperCase()
    if (first >= 'A' && first <= 'Z') {
      return first
    }
    return '#'
  }

  static getFirstLetterForVideo(video: VideoMetadata): string {
    const key = MediaSortUtil.getPinyinKey(video, video.title || '')
    const first = key.length > 0 ? key[0].toUpperCase() : '#'
    return first >= 'A' && first <= 'Z' ? first : '#'
  }

  private static getPinyinKey(item: VideoMetadata | FileFolder, name: string): string {
    const cached = MediaSortUtil.pinyinKeys.get(item)
    if (cached?.name === name) return cached.key
    const key = NameSortUtil.getSortKey(name, true)
    MediaSortUtil.pinyinKeys.set(item, { name: name, key: key })
    return key
  }

  private static sortByName<T extends VideoMetadata | FileFolder>(list: T[], nameExtractor: (item: T) => string, ascending: boolean = true,
    pinyinSort: boolean = true): T[] {
    if (list.length <= 1) {
      return [...list]
    }
    const itemsWithPinyin: ItemWithPinyin<T>[] = list.map(item => {
      const entry: ItemWithPinyin<T> = {
        item: item,
        pinyin: pinyinSort ? MediaSortUtil.getPinyinKey(item, nameExtractor(item)) : nameExtractor(item)
      }
      return entry
    })
    const collator = MediaSortUtil.collator ?? (MediaSortUtil.collator = NameSortUtil.createCollator())
    const sortedItems = itemsWithPinyin.sort((a, b) => {
      const cmp = collator.compare(a.pinyin, b.pinyin)
      return ascending ? cmp : -cmp
    })
    return sortedItems.map(entry => entry.item)
  }

}
