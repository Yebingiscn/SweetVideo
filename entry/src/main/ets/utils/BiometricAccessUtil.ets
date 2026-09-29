import { userAuth } from '@kit.UserAuthenticationKit'
import { salmonLogger } from 'salmonlogger'

const TAG = 'BiometricAccessUtil'

// 生物识别工具类
export default class BiometricAccessUtil {
  // 1.认证类型列表
  static authType: userAuth.UserAuthType[] = []
  // 2.认证信任等级
  static authTrustLevel: userAuth.AuthTrustLevel | undefined = undefined
  // 4.配置认证界面
  static widgetParam: userAuth.WidgetParam = {
    title: '进入隐私空间前请进行身份认证', // 用户认证界面的标题, 仅在 PIN/指纹 密码时展示
  }

  // 5.查询认证能力是否支持
  static checkUserAuthSupport() {
    if (canIUse('SystemCapability.UserIAM.UserAuth.Core')) {
      BiometricAccessUtil.authType = [userAuth.UserAuthType.PIN, // PIN密码（模拟器支持）
        userAuth.UserAuthType.FINGERPRINT, // 指纹
        userAuth.UserAuthType.FACE// 面容ID
      ]
      BiometricAccessUtil.authTrustLevel = userAuth.AuthTrustLevel.ATL3
      const authTypeRes = BiometricAccessUtil.authType.map((item) => {
        try {
          userAuth.getAvailableStatus(item, BiometricAccessUtil.authTrustLevel)
          return true
        } catch (error) {
          salmonLogger.addLog(TAG, `BiometricAccessUtil: Auth type ${item} not supported: ` + error)
          return false
        }
      })
      return authTypeRes.some(v => v === true)
    }
    return false
  }

  // 查询指定认证类型是否支持
  static checkAuthTypeSupported(authType: userAuth.UserAuthType): boolean {
    if (canIUse('SystemCapability.UserIAM.UserAuth.Core')) {
      try {
        userAuth.getAvailableStatus(authType, userAuth.AuthTrustLevel.ATL3)
        return true
      } catch (error) {
        salmonLogger.addLog(TAG, `BiometricAccessUtil: Auth type ${authType} not supported: ` + error)
        return false
      }
    }
    return false
  }

  // 发起认证，优先使用 preferredAuthType，不支持则回退到另一种生物认证，都不支持返回 false
  static startUserAuthWithFallback(preferredAuthType: userAuth.UserAuthType): Promise<boolean> {
    if (canIUse('SystemCapability.UserIAM.UserAuth.Core')) {
      const fallbackType = preferredAuthType === userAuth.UserAuthType.FACE ?
        userAuth.UserAuthType.FINGERPRINT : userAuth.UserAuthType.FACE
      if (BiometricAccessUtil.checkAuthTypeSupported(preferredAuthType)) {
        return BiometricAccessUtil.startUserAuth([preferredAuthType])
      }
      if (BiometricAccessUtil.checkAuthTypeSupported(fallbackType)) {
        return BiometricAccessUtil.startUserAuth([fallbackType])
      }
      return Promise.resolve(false)
    }
    return Promise.resolve(false)
  }

  // 6.发起原生用户生物认证检测
  static startUserAuth(authTypes?: userAuth.UserAuthType[]): Promise<boolean> {
    return new Promise((resolve) => {
      if (canIUse('SystemCapability.UserIAM.UserAuth.Core')) {
        let userAuthInstance: userAuth.UserAuthInstance | null = null
        try {
          const challenge = new Uint8Array(16)
          for (let i = 0; i < 16; i++) {
            challenge[i] = Math.floor(Math.random() * 256)
          }

          const useAuthType = authTypes ?? BiometricAccessUtil.authType
          userAuthInstance =
            userAuth.getUserAuthInstance({
              challenge: challenge,
              authType: useAuthType,
              authTrustLevel: userAuth.AuthTrustLevel.ATL3,
            }, BiometricAccessUtil.widgetParam)
          userAuthInstance.on('result', {
            onResult(result) {
              try {
                if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
                  resolve(true)
                } else {
                  resolve(false)
                }
              } finally {
                if (userAuthInstance) {
                  try {
                    userAuthInstance.off('result')
                  } catch {
                  }
                }
              }
            }
          })
          userAuthInstance.start()
        } catch (error) {
          if (userAuthInstance) {
            try {
              userAuthInstance.off('result')
            } catch {
            }
          }
          salmonLogger.addLog(TAG, 'BiometricAccessUtil.startUserAuth error:' + error, true)
          resolve(false)
        }
      } else {
        resolve(false)
      }
    })
  }
}
