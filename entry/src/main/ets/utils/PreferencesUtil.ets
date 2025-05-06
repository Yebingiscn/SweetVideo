import preferences from '@ohos.data.preferences'

// 存储类
export default class PreferencesUtil {
  static putPreferencesValue(context: Context, name: string, key: string, value: preferences.ValueType) {
    try {
      let pref = preferences.getPreferencesSync(context, {
        name: name
      })
      pref.putSync(key, value)
      pref.flush()
    } catch {
    }
  }

  static getPreferencesValue(context: Context, name: string, key: string, defaultValue: preferences.ValueType) {
    try {
      let pref = preferences.getPreferencesSync(context, {
        name: name
      })
      return pref.getSync(key, defaultValue)
    } catch (e) {
      return defaultValue
    }
  }

  static delPreferencesValue(context: Context, name: string, key: string) {
    try {
      let pref = preferences.getPreferencesSync(context, {
        name: name
      })
      pref.delete(key)
      pref.flush()
    } catch (e) {
    }
  }
}