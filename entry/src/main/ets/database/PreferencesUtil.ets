import preferences from '@ohos.data.preferences'
import { salmonLogger } from 'salmonlogger'
import ToolsUtil from '../utils/ToolsUtil'

const TAG = 'PreferencesUtil'

export default class PreferencesUtil {
  private static prefInstance: preferences.Preferences | null = null
  private static flushTimer: number | null = null
  private static readonly FLUSH_DELAY = 500

  static getPreferencesInstance(context: Context, name: string): preferences.Preferences {
    if (!PreferencesUtil.prefInstance) {
      PreferencesUtil.prefInstance = preferences.getPreferencesSync(context, { name: name })
    }
    return PreferencesUtil.prefInstance!
  }

  static putPreferencesValue(context: Context, name: string, key: string, value: preferences.ValueType) {
    try {
      const pref = PreferencesUtil.getPreferencesInstance(context, name)
      pref.putSync(key, value)
      PreferencesUtil.debouncedFlush(pref)
    } catch (e) {
      ToolsUtil.showToast(`数据库异常，保存失败，原因是:${e}，ValueType: ${value}，获取参数为 ${name}}: ${key}`)
    }
  }

  static putPreferencesValueImmediate(context: Context, name: string, key: string, value: preferences.ValueType) {
    try {
      const pref = PreferencesUtil.getPreferencesInstance(context, name)
      pref.putSync(key, value)
      pref.flush()?.catch(() => {
        salmonLogger.addLog(TAG, 'flush error', true)
      })
    } catch (e) {
      ToolsUtil.showToast(`数据库异常，保存失败，原因是:${e}，ValueType: ${value}，获取参数为 ${name}}: ${key}`)
    }
  }

  private static debouncedFlush(pref: preferences.Preferences) {
    if (PreferencesUtil.flushTimer !== null) {
      clearTimeout(PreferencesUtil.flushTimer)
    }
    PreferencesUtil.flushTimer = setTimeout(() => {
      PreferencesUtil.flushTimer = null
      pref.flush()?.catch(() => {
        salmonLogger.addLog(TAG, 'flush error', true)
      })
    }, PreferencesUtil.FLUSH_DELAY)
  }

  static getPreferencesValue(context: Context, name: string, key: string, defaultValue: preferences.ValueType) {
    try {
      const pref = PreferencesUtil.getPreferencesInstance(context, name)
      return pref.getSync(key, defaultValue)
    } catch (e) {
      ToolsUtil.showToast(`数据库异常，读取失败，原因是: ${e}，初始化${defaultValue}时失败，获取参数为 ${name}}: ${key}`)
      return defaultValue
    }
  }

  static batchGetPreferencesValue(context: Context, name: string, keys: string[],
    defaultValues: preferences.ValueType[]): preferences.ValueType[] {
    try {
      const pref = PreferencesUtil.getPreferencesInstance(context, name)
      return keys.map((key, i) => pref.getSync(key, defaultValues[i]))
    } catch (e) {
      salmonLogger.addLog(TAG, `batchGetPreferencesValue error: ${e}`, true)
      return defaultValues
    }
  }

  static delPreferencesValue(context: Context, name: string, key: string) {
    try {
      const pref = PreferencesUtil.getPreferencesInstance(context, name)
      const value = pref.getSync(key, 'DEFAULT_VALUE');
      if (value === 'DEFAULT_VALUE') {
        salmonLogger.addLog(TAG, `Key "${key}" not found, skip deletion`, false)
        return;
      }
      pref.delete(key)?.catch(() => {
        salmonLogger.addLog(TAG, `delete error`, true)
      })
      PreferencesUtil.debouncedFlush(pref)
    } catch (e) {
      ToolsUtil.showToast(`数据库异常，删除失败，原因是 ${e} 删除${key}:${name}失败`)
    }
  }
}