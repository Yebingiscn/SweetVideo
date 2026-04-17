import { pinyin4js } from '@ohos/pinyin4js'

/**
 * 通用排序工具类
 * 提供视频/实体列表的排序功能，支持拼音排序和时长排序
 */
export class SortUtil {
  /**
   * 按拼音对列表进行排序（支持中文自然排序）
   * @param items 待排序的数组
   * @param getTitle 获取标题的回调函数
   * @param order 排序方向：'asc' 升序(A-Z)，'desc' 降序(Z-A)
   * @returns 排序后的数组
   */
  static sortByPinyin<T>(items: T[], getTitle: (item: T) => string, order: 'asc' | 'desc' = 'desc'): T[] {
    if (!items || items.length <= 1) {
      return items || []
    }
    return [...items].sort((a: T, b: T): number => {
      const titleA: string = getTitle(a) || ''
      const titleB: string = getTitle(b) || ''
      const pinyinA: string = pinyin4js.getShortPinyin(titleA)
      const pinyinB: string = pinyin4js.getShortPinyin(titleB)
      const result: number = pinyinA.localeCompare(pinyinB, 'zh-CN', { numeric: true, sensitivity: 'variant' })
      return order === 'asc' ? result : -result
    })
  }

  /**
   * 按时长对列表进行排序
   * @param items 待排序的数组
   * @param getDuration 获取时长的回调函数
   * @param order 排序方向：'asc' 升序(短→长)，'desc' 降序(长→短)
   * @returns 排序后的数组
   */
  static sortByDuration<T>(items: T[], getDuration: (item: T) => number, order: 'asc' | 'desc' = 'desc'): T[] {
    if (!items || items.length <= 1) {
      return items || []
    }
    return [...items].sort((a: T, b: T): number => {
      const durationA: number = Number(getDuration(a)) || 0
      const durationB: number = Number(getDuration(b)) || 0
      return order === 'asc' ? durationA - durationB : durationB - durationA
    })
  }

  /**
   * 按日期对列表进行排序
   * @param items 待排序的数组
   * @param getDate 获取日期的回调函数
   * @param order 排序方向：'asc' 升序(旧→新)，'desc' 降序(新→旧)
   * @returns 排序后的数组
   */
  static sortByDate<T>(items: T[], getDate: (item: T) => string | number, order: 'asc' | 'desc' = 'desc'): T[] {
    if (!items || items.length <= 1) {
      return items || []
    }
    return [...items].sort((a: T, b: T): number => {
      const dateA: number = Number(getDate(a)) || 0
      const dateB: number = Number(getDate(b)) || 0
      return order === 'asc' ? dateA - dateB : dateB - dateA
    })
  }
}
