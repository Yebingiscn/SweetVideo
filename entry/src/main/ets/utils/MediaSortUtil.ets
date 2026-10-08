import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { ItemWithPinyin } from '../interfaces/VideoItemWithPinyinInterface'
import { pinyin4js } from '@ohos/pinyin4js'

// 不保存媒体数据；持久化仍由 ToolsUtil.sortBy 在排序完成后统一处理。
export default class MediaSortUtil {
  private static splitRegex = /(\d+)/g
  private static readonly COLLATOR = new Intl.Collator("zh-CN", {
    sensitivity: "variant",
    numeric: true,
    ignorePunctuation: false,
    caseFirst: "upper"
  })

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
    const pinyin = pinyin4js.getShortPinyin(title) as string
    if (pinyin.length === 0) {
      return '#'
    }
    const first = pinyin[0].toUpperCase()
    if (first >= 'A' && first <= 'Z') {
      return first
    }
    return '#'
  }

  private static sortByName<T>(list: T[], nameExtractor: (item: T) => string, ascending: boolean = true,
    pinyinSort: boolean = true): T[] {
    if (list.length <= 1) {
      return [...list]
    }
    if (pinyinSort) {
      const itemsWithPinyin: ItemWithPinyin<T>[] = list.map(item => {
        const entry: ItemWithPinyin<T> = {
          item: item,
          pinyin: pinyin4js.getShortPinyin(nameExtractor(item))
        }
        return entry
      })
      const sortedItems = [...itemsWithPinyin].sort((a, b) => {
        const cmp = MediaSortUtil.naturalCompare(a.pinyin, b.pinyin)
        return ascending ? cmp : -cmp
      })
      return sortedItems.map(entry => entry.item)
    } else {
      return [...list].sort((a, b) => {
        const cmp = MediaSortUtil.COLLATOR.compare(nameExtractor(a), nameExtractor(b))
        return ascending ? cmp : -cmp
      })
    }
  }

  private static naturalCompare(a: string, b: string): number {
    const aParts = a.split(MediaSortUtil.splitRegex).filter(Boolean)
    const bParts = b.split(MediaSortUtil.splitRegex).filter(Boolean)

    for (let i = 0; i < Math.min(aParts.length, bParts.length); i++) {
      const aVal = aParts[i]
      const bVal = bParts[i]
      const aIsNum = /^\d+$/.test(aVal)
      const bIsNum = /^\d+$/.test(bVal)

      if (aIsNum && bIsNum) {
        const numA = parseInt(aVal, 10)
        const numB = parseInt(bVal, 10)
        if (numA !== numB) {
          return numA - numB
        }
      } else {
        const cmp = MediaSortUtil.COLLATOR.compare(aVal, bVal)
        if (cmp !== 0) {
          return cmp
        }
      }
    }
    return aParts.length - bParts.length
  }

}
