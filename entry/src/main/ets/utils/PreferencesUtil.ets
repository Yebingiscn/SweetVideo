import preferences from '@ohos.data.preferences'
import { Context } from '@kit.AbilityKit'

class PreferencesUtil {
  // 创建一个Map类型用来存储pref的name,和pref
  prefMap: Map<string, preferences.Preferences> = new Map()

  // 加载Preferences
  async localPreferences(context: Context, name: string) {
    // 获取pref，返回的是一个Promise
    let pref = await preferences.getPreferences(context, name)
    // 将Pref填入PrefMap中
    this.prefMap.set(name, pref)
  }

  // 放Preferences数据
  async putPreferencesValue(name: string, key: string, value: preferences.ValueType) {
    // 从Map中获取pref
    let pref = this.prefMap.get(name)
    // 在pref中添加
    await pref?.put(key, value)
    // 将pref输入磁盘中
    await pref?.flush()
  }

  // 读Preferences数据
  async getPreferencesValue(name: string, key: string, defaultValue: preferences.ValueType) {
    let pref = this.prefMap.get(name)
    return await pref?.get(key, defaultValue)
  }
}

export default new PreferencesUtil()