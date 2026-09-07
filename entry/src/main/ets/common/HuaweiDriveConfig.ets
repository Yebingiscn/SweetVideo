/**
 * 华为云盘鉴权配置。
 *
 * 纯客户端 OAuth 配置。请填写华为开发者联盟中的 OAuth 应用信息。
 * 注意：客户端内置的 Client Secret 可以被逆向提取，仅适用于已确认接受该风险的场景。
 */
export default class HuaweiDriveConfig {
  static readonly CLIENT_ID: string = '6917561535749426059'
  static readonly CLIENT_SECRET: string = ''
  static readonly REDIRECT_URI: string = ''
  static readonly AUTH_URL: string = 'https://oauth-login.cloud.huawei.com/oauth2/v3/authorize'
  static readonly TOKEN_URL: string = 'https://oauth-login.cloud.huawei.com/oauth2/v3/token'
  static readonly DRIVE_SCOPE: string = 'https://www.huawei.com/auth/drive.readonly'
  static readonly DRIVE_API_BASE_URL: string = 'https://driveapis.cloud.huawei.com.cn/drive/v1'
  static readonly TOKEN_REFRESH_THRESHOLD_MS: number = 10 * 60 * 1000

  static isOAuthConfigured(): boolean {
    return HuaweiDriveConfig.CLIENT_ID.trim().length > 0 &&
      HuaweiDriveConfig.CLIENT_SECRET.trim().length > 0 &&
      /^[a-z][a-z0-9+.-]*:\/\//i.test(HuaweiDriveConfig.REDIRECT_URI.trim())
  }

  static buildAuthorizeUrl(state: string): string {
    const params = [
      'response_type=code',
      'access_type=offline',
      `state=${encodeURIComponent(state)}`,
      `client_id=${encodeURIComponent(HuaweiDriveConfig.CLIENT_ID)}`,
      `redirect_uri=${encodeURIComponent(HuaweiDriveConfig.REDIRECT_URI)}`,
      `scope=${encodeURIComponent(`openid profile ${HuaweiDriveConfig.DRIVE_SCOPE}`)}`
    ]
    return `${HuaweiDriveConfig.AUTH_URL}?${params.join('&')}`
  }
}
