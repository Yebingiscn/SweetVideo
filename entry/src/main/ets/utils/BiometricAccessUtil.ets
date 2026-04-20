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
          // 查询认证能力是否支持,注意这里需要用 try catch
          userAuth.getAvailableStatus(item, BiometricAccessUtil.authTrustLevel)
          return true
        } catch (error) {
          salmonLogger.addLog(TAG, `BiometricAccessUtil: Auth type ${item} not supported: ` + error)
          return false
        }
      })
      // 有一项支持即可
      return authTypeRes.some(v => v === true)
    }
    return false
  }

  // 6.发起原生用户生物认证检测
  static startUserAuth(): Promise<boolean> {
    return new Promise((resolve) => {
      if (canIUse('SystemCapability.UserIAM.UserAuth.Core')) {
        let userAuthInstance: userAuth.UserAuthInstance | null = null
        try {
          // 生成随机挑战值，增强安全性
          const challenge = new Uint8Array(16)
          for (let i = 0; i < 16; i++) {
            challenge[i] = Math.floor(Math.random() * 256)
          }

          // 1. 获取认证对象
          userAuthInstance =
            userAuth.getUserAuthInstance({
              challenge: challenge, // 挑战值，用来防重放攻击。
              authType: BiometricAccessUtil.authType, // 认证类型列表
              authTrustLevel: userAuth.AuthTrustLevel.ATL3, // 认证信任等级
            }, BiometricAccessUtil.widgetParam)
          // 2. 订阅用户身份认证结果
          userAuthInstance.on('result', {
            // 返回认证结果
            onResult(result) {
              try {
                // 如果验证成功/失败
                if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
                  resolve(true)
                } else {
                  resolve(false)
                }
              } finally {
                // 认证结束，取消订阅认证结果（释放资源）
                if (userAuthInstance) {
                  try {
                    userAuthInstance.off('result')
                  } catch {
                    // 忽略取消订阅时的错误
                  }
                }
              }
            }
          })
          // 3. 执行用户生物认证检测
          userAuthInstance.start()
        } catch (error) {
          // 发生错误时确保释放资源
          if (userAuthInstance) {
            try {
              userAuthInstance.off('result')
            } catch {
              // 忽略取消订阅时的错误
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
