import preferences from '@ohos.data.preferences'
import { PathUtils } from './PathUtils'
import { salmonLogger } from 'salmonlogger'

const TAG = 'HuaweiDriveSessionStore'
const STORE_NAME = 'huawei_drive_session'
const KEY_REFRESH_TOKEN = 'refresh_token'

/**
 * 只持久化用于免登录续期的 Refresh Token；Access Token 始终只保存在内存中。
 */
export default class HuaweiDriveSessionStore {
  static getRefreshToken(): string {
    try {
      const store = preferences.getPreferencesSync(PathUtils.appContext!, { name: STORE_NAME })
      return store.getSync(KEY_REFRESH_TOKEN, '') as string
    } catch (error) {
      salmonLogger.addLog(TAG, `读取华为云盘会话失败: ${error}`, true)
      return ''
    }
  }

  static async saveRefreshToken(token: string): Promise<void> {
    if (!token) {
      return
    }
    try {
      const store = preferences.getPreferencesSync(PathUtils.appContext!, { name: STORE_NAME })
      store.putSync(KEY_REFRESH_TOKEN, token)
      await store.flush()
    } catch (error) {
      salmonLogger.addLog(TAG, 'saveRefreshToken error', true)
    }
  }

  static async clear(): Promise<void> {
    try {
      const store = preferences.getPreferencesSync(PathUtils.appContext!, { name: STORE_NAME })
      store.deleteSync(KEY_REFRESH_TOKEN)
      await store.flush()
    } catch (error) {
      salmonLogger.addLog(TAG, `清理华为云盘会话失败: ${error}`, true)
    }
  }
}
