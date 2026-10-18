import lazy { pinyin4js } from '@ohos/pinyin4js'

// 视频和文件夹共用自然排序规则，TaskPool 内创建自己的比较器。
export default class NameSortUtil {
  static createCollator(): Intl.Collator {
    return new Intl.Collator('zh-CN', {
      sensitivity: 'accent',
      numeric: true,
      ignorePunctuation: false
    })
  }

  static getSortKey(name: string, pinyinSort: boolean): string {
    return pinyinSort ? pinyin4js.convertToPinyinString(name, '', pinyin4js.WITHOUT_TONE) as string : name
  }
}
