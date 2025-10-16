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
      pref.flush()?.catch(() => {
        console.error('flush error')
      })
    } catch (e) {
      console.error(`数据库异常，保存失败，原因是:${JSON.stringify(e)}，ValueType: ${value}，获取参数为 ${name}}: ${key}`)
      ToolsUtil.showToast(`数据库异常，保存失败，原因是:${JSON.stringify(e)}，ValueType: ${value}，获取参数为 ${name}}: ${key}`)
    }
  }

  static getPreferencesValue(context: Context, name: string, key: string, defaultValue: preferences.ValueType) {
    try {
      let pref = preferences.getPreferencesSync(context, {
        name: name
      })
      return pref.getSync(key, defaultValue)
    } catch (e) {
      console.error(`数据库异常，读取失败，原因是: ${JSON.stringify(e)}，初始化${defaultValue}时失败，获取参数为 ${name}}: ${key}`)
      ToolsUtil.showToast(`数据库异常，读取失败，原因是: ${JSON.stringify(e)}，初始化${defaultValue}时失败，获取参数为 ${name}}: ${key}`)
      return defaultValue
    }
  }

  static delPreferencesValue(context: Context, name: string, key: string) {
    try {
      let pref = preferences.getPreferencesSync(context, {
        name: name
      })
      const value = pref.getSync(key, 'DEFAULT_VALUE');
      if (value === 'DEFAULT_VALUE') {
        console.log(`Key "${key}" not found, skip deletion`);
        return; // 键不存在时提前返回
      }
      pref.delete(key)?.catch(() => {
        console.error('delete error')
      })
      pref.flush()?.catch(() => {
        console.error('flush error')
      })
    } catch (e) {
      console.error(`数据库异常，删除失败，原因是 ${JSON.stringify(e)} 删除${key}:${name}失败`)
      ToolsUtil.showToast(`数据库异常，删除失败，原因是 ${JSON.stringify(e)} 删除${key}:${name}失败`)
    }
  }
}