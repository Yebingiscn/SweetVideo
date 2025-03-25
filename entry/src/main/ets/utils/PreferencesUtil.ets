import preferences from '@ohos.data.preferences'

export default class PreferencesUtil {
  static async  putPreferencesValue(context: Context, name: string, key: string, value: preferences.ValueType) {
    try {
      let pref = preferences.getPreferencesSync(context, {
        name: name
      })
      pref.putSync(key, value)
      pref.flush()
    } catch {
    }
  }

  static async getPreferencesValue(context: Context, name: string, key: string, defaultValue: preferences.ValueType) {
    try {
      let pref = preferences.getPreferencesSync(context, {
        name: name
      })
      return pref.getSync(key, defaultValue)
    } catch (e) {
      return defaultValue
    }
  }

  static async delPreferencesValue(context: Context, name: string, key: string) {
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