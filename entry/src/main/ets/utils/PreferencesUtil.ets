import preferences from '@ohos.data.preferences'
import ToolsUtil from './ToolsUtil'

// 存储类
export default class PreferencesUtil {
  static putPreferencesValue(context: Context, name: string, key: string, value: preferences.ValueType) {
    try {
      let pref = preferences.getPreferencesSync(context, {
        name: name
      })
      pref.putSync(key, value)
      pref.flush()
    } catch (e) {
      console.error('database error' + JSON.stringify(e))
      ToolsUtil.showToast('数据库异常，保存失败，原因是' + JSON.stringify(e))
    }
  }

  static getPreferencesValue(context: Context, name: string, key: string, defaultValue: preferences.ValueType) {
    try {
      let pref = preferences.getPreferencesSync(context, {
        name: name
      })
      return pref.getSync(key, defaultValue)
    } catch (e) {
      console.error('database error' + JSON.stringify(e))
      ToolsUtil.showToast('数据库异常，读取失败，原因是' + JSON.stringify(e))
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
      console.error('database error' + JSON.stringify(e))
      ToolsUtil.showToast('数据库异常，删除失败，原因是' + JSON.stringify(e))
    }
  }
}