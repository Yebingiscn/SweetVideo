import HuaweiDriveConfig from '../common/HuaweiDriveConfig'
import {
  HuaweiDriveAbout,
  HuaweiDriveFile,
  HuaweiDriveFileList,
  HuaweiDriveTokenResponse
} from '../interfaces/HuaweiDriveInterface'
import HuaweiDriveSessionStore from './HuaweiDriveSessionStore'
import { http } from '@kit.NetworkKit'

export class HuaweiDriveError extends Error {
  statusCode: number = 0

  constructor(message: string, statusCode: number = 0) {
    super(message)
    this.name = 'HuaweiDriveError'
    this.statusCode = statusCode
  }
}

export default class HuaweiDriveUtil {
  static readonly FOLDER_MIME_TYPE: string = 'application/vnd.huawei-apps.folder'
  private static accessToken: string = ''
  private static tokenExpiresAt: number = 0
  private static refreshPromise: Promise<void> | undefined = undefined

  static isAuthorized(): boolean {
    return HuaweiDriveUtil.accessToken.length > 0 && Date.now() + 60_000 < HuaweiDriveUtil.tokenExpiresAt
  }

  static hasSavedSession(): boolean {
    return HuaweiDriveSessionStore.getRefreshToken().length > 0
  }

  static clearAuthorization(): void {
    HuaweiDriveUtil.accessToken = ''
    HuaweiDriveUtil.tokenExpiresAt = 0
  }

  static async logout(): Promise<void> {
    HuaweiDriveUtil.clearAuthorization()
    await HuaweiDriveSessionStore.clear()
  }

  static async restoreAuthorization(): Promise<boolean> {
    if (HuaweiDriveUtil.isAuthorized()) {
      return true
    }
    if (!HuaweiDriveConfig.isOAuthConfigured() || !HuaweiDriveUtil.hasSavedSession()) {
      return false
    }
    await HuaweiDriveUtil.ensureAccessToken(true)
    return HuaweiDriveUtil.isAuthorized()
  }

  static async exchangeAuthorizationCode(authorizationCode: string): Promise<void> {
    if (!HuaweiDriveConfig.isOAuthConfigured()) {
      throw new HuaweiDriveError('尚未配置华为云盘 OAuth 参数')
    }
    const token = await HuaweiDriveUtil.requestToken({
      'grant_type': 'authorization_code',
      'code': authorizationCode,
      'client_id': HuaweiDriveConfig.CLIENT_ID,
      'client_secret': HuaweiDriveConfig.CLIENT_SECRET,
      'redirect_uri': HuaweiDriveConfig.REDIRECT_URI
    })
    await HuaweiDriveUtil.applyToken(token)
  }

  static async getAbout(): Promise<HuaweiDriveAbout> {
    return await HuaweiDriveUtil.requestJson<HuaweiDriveAbout>(
      `${HuaweiDriveConfig.DRIVE_API_BASE_URL}/about?fields=*`)
  }

  static async listFiles(parentId: string = 'root'): Promise<HuaweiDriveFile[]> {
    let cursor = ''
    const files: HuaweiDriveFile[] = []
    do {
      const query = `'${HuaweiDriveUtil.escapeQueryValue(parentId)}' in parentFolder and recycled = false`
      let url = `${HuaweiDriveConfig.DRIVE_API_BASE_URL}/files?fields=*&containers=drive&pageSize=100` +
        `&queryParam=${encodeURIComponent(query)}`
      if (cursor) {
        url += `&cursor=${encodeURIComponent(cursor)}`
      }
      const page = await HuaweiDriveUtil.requestJson<HuaweiDriveFileList>(url)
      if (page.files) {
        files.push(...page.files.filter((item: HuaweiDriveFile) => !item.recycled && !item.directlyRecycled))
      }
      cursor = page.nextCursor ?? ''
    } while (cursor)
    return files.sort((left: HuaweiDriveFile, right: HuaweiDriveFile) => {
      const leftFolder = HuaweiDriveUtil.isFolder(left)
      const rightFolder = HuaweiDriveUtil.isFolder(right)
      if (leftFolder !== rightFolder) {
        return leftFolder ? -1 : 1
      }
      return left.fileName.localeCompare(right.fileName)
    })
  }

  static isFolder(file: HuaweiDriveFile): boolean {
    return file.mimeType === HuaweiDriveUtil.FOLDER_MIME_TYPE
  }

  static isPlayable(file: HuaweiDriveFile): boolean {
    if (HuaweiDriveUtil.isFolder(file) || file.capabilities?.downloadPermission === false) {
      return false
    }
    if (file.mimeType.startsWith('video/') || file.mimeType.startsWith('audio/')) {
      return true
    }
    const extension = HuaweiDriveUtil.getExtension(file.fileName)
    return ['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'ts', 'm2ts', 'mpg', 'mpeg', 'wmv', 'm4v',
      'mp3', 'flac', 'aac', 'm4a', 'wav', 'ogg', 'opus'].includes(extension)
  }

  static getStreamUrl(file: HuaweiDriveFile): string {
    if (!HuaweiDriveUtil.isAuthorized()) {
      throw new HuaweiDriveError('华为云盘登录已失效', 401)
    }
    return file.contentDownloadLink ||
      `${HuaweiDriveConfig.DRIVE_API_BASE_URL}/files/${encodeURIComponent(file.id)}?form=content`
  }

  static async getStreamHeaders(): Promise<Record<string, string>> {
    await HuaweiDriveUtil.ensureAccessToken()
    return {
      'Authorization': `Bearer ${HuaweiDriveUtil.accessToken}`,
      'Cache-Control': 'no-cache',
      'User-Agent': 'SweetVideo/HiCloudDisk'
    }
  }

  private static async ensureAccessToken(forceRefresh: boolean = false): Promise<void> {
    const threshold = HuaweiDriveConfig.TOKEN_REFRESH_THRESHOLD_MS
    if (!forceRefresh && HuaweiDriveUtil.accessToken && Date.now() + threshold < HuaweiDriveUtil.tokenExpiresAt) {
      return
    }
    const refreshToken = HuaweiDriveSessionStore.getRefreshToken()
    if (!refreshToken) {
      if (HuaweiDriveUtil.isAuthorized()) {
        return
      }
      throw new HuaweiDriveError('请先授权访问华为云盘', 401)
    }
    if (HuaweiDriveUtil.refreshPromise) {
      await HuaweiDriveUtil.refreshPromise
      return
    }
    const task = HuaweiDriveUtil.refreshAccessToken(refreshToken)
    HuaweiDriveUtil.refreshPromise = task
    try {
      await task
    } finally {
      if (HuaweiDriveUtil.refreshPromise === task) {
        HuaweiDriveUtil.refreshPromise = undefined
      }
    }
  }

  private static async refreshAccessToken(refreshToken: string): Promise<void> {
    try {
      const token = await HuaweiDriveUtil.requestToken({
        'grant_type': 'refresh_token',
        'client_id': HuaweiDriveConfig.CLIENT_ID,
        'client_secret': HuaweiDriveConfig.CLIENT_SECRET,
        'refresh_token': refreshToken
      })
      await HuaweiDriveUtil.applyToken(token)
    } catch (error) {
      HuaweiDriveUtil.clearAuthorization()
      await HuaweiDriveSessionStore.clear()
      throw error instanceof Error ? error : new HuaweiDriveError(String(error))
    }
  }

  private static async applyToken(token: HuaweiDriveTokenResponse): Promise<void> {
    const accessToken = token.accessToken ?? token.access_token ?? ''
    const expiresIn = Number(token.expiresIn ?? token.expires_in ?? 3600)
    const refreshToken = token.refreshToken ?? token.refresh_token ?? ''
    if (!accessToken) {
      throw new HuaweiDriveError('华为 OAuth 未返回 Access Token')
    }
    if (token.scope && !token.scope.includes(HuaweiDriveConfig.DRIVE_SCOPE)) {
      throw new HuaweiDriveError('华为帐号授权缺少云盘只读权限')
    }
    HuaweiDriveUtil.accessToken = accessToken
    HuaweiDriveUtil.tokenExpiresAt = Date.now() + Math.max(60, expiresIn) * 1000
    if (refreshToken) {
      await HuaweiDriveSessionStore.saveRefreshToken(refreshToken)
    }
  }

  private static async requestToken(form: Record<string, string>): Promise<HuaweiDriveTokenResponse> {
    const request = http.createHttp()
    const body = Object.keys(form).map((key: string) =>
      `${encodeURIComponent(key)}=${encodeURIComponent(form[key])}`).join('&')
    try {
      const response = await request.request(HuaweiDriveConfig.TOKEN_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        connectTimeout: 30_000,
        readTimeout: 30_000
      })
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new HuaweiDriveError(`华为 OAuth 请求失败（HTTP ${response.responseCode}）`, response.responseCode)
      }
      return JSON.parse(response.result as string) as HuaweiDriveTokenResponse
    } finally {
      request.destroy()
    }
  }

  private static async requestJson<T>(url: string, allowAuthRetry: boolean = true,
    rateLimitRetries: number = 2): Promise<T> {
    await HuaweiDriveUtil.ensureAccessToken()
    const request = http.createHttp()
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: HuaweiDriveUtil.authorizationHeaders(),
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        connectTimeout: 30_000,
        readTimeout: 30_000
      })
      if (response.responseCode === 401 && allowAuthRetry && HuaweiDriveUtil.hasSavedSession()) {
        await HuaweiDriveUtil.ensureAccessToken(true)
        return await HuaweiDriveUtil.requestJson<T>(url, false, rateLimitRetries)
      }
      if (response.responseCode === 429 && rateLimitRetries > 0) {
        await HuaweiDriveUtil.delay((3 - rateLimitRetries) * 750)
        return await HuaweiDriveUtil.requestJson<T>(url, allowAuthRetry, rateLimitRetries - 1)
      }
      if (response.responseCode === 401) {
        HuaweiDriveUtil.clearAuthorization()
        throw new HuaweiDriveError('华为云盘授权已过期，请重新授权', 401)
      }
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new HuaweiDriveError(`华为云盘请求失败（HTTP ${response.responseCode}）`, response.responseCode)
      }
      return JSON.parse(response.result as string) as T
    } finally {
      request.destroy()
    }
  }

  private static authorizationHeaders(): Record<string, string> {
    return {
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
      'Authorization': `Bearer ${HuaweiDriveUtil.accessToken}`,
      'User-Agent': 'SweetVideo/HiCloudDisk'
    }
  }

  private static delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, milliseconds)
    })
  }

  private static escapeQueryValue(value: string): string {
    return value.replace(/'/g, "\\'")
  }

  private static getExtension(fileName: string): string {
    const index = fileName.lastIndexOf('.')
    return index >= 0 ? fileName.substring(index + 1).toLowerCase() : ''
  }
}
