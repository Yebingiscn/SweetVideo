import { userAuth } from '@kit.UserAuthenticationKit';

// 生物识别工具类
class BiometricAccessUtil {
  // 1.认证类型列表
  authType: userAuth.UserAuthType[] = [
    userAuth.UserAuthType.PIN, // PIN密码（模拟器支持）
    userAuth.UserAuthType.FINGERPRINT, // 指纹
    userAuth.UserAuthType.FACE// 面容ID
  ]
  // 2.认证信任等级
  authTrustLevel: userAuth.AuthTrustLevel = userAuth.AuthTrustLevel.ATL3
  // 4.配置认证界面
  widgetParam: userAuth.WidgetParam = {
    title: '请进行身份认证', // 用户认证界面的标题, 仅在 PIN/指纹 密码时展示
  }
  // 3.设置认证参数
  private authParam: userAuth.AuthParam = {
    challenge: new Uint8Array([49, 49, 49, 49, 49, 49]), // 挑战值，用来防重放攻击。
    authType: this.authType, // 认证类型列表
    authTrustLevel: this.authTrustLevel, // 认证信任等级
  }

  // 5.查询认证能力是否支持
  checkUserAuthSupport() {
    const authTypeRes = this.authType.map((item) => {
      try {
        // 查询认证能力是否支持,注意这里需要用 try catch
        userAuth.getAvailableStatus(item, this.authTrustLevel)
        return true
      } catch {
        return false
      }
    })
    // 有一项支持即可
    return authTypeRes.some(v => v === true)
  }

  // 6.发起原生用户生物认证检测
  startUserAuth(): Promise<boolean> {
    return new Promise((resolve, reject) => {
      try {
        // 1. 获取认证对象
        const userAuthInstance = userAuth.getUserAuthInstance(this.authParam, this.widgetParam)
        // 2. 订阅用户身份认证结果
        userAuthInstance.on('result', {
          // 返回认证结果
          onResult(result) {
            // 如果验证成功/失败
            if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
              resolve(true)
            } else {
              resolve(false)
            }
            // 认证结束，取消订阅认证结果（释放资源）
            userAuthInstance.off('result')
          }
        })
        // 3. 执行用户生物认证检测
        userAuthInstance.start()
      } catch (error) {
        reject(error)
      }
    })
  }
}

export default new BiometricAccessUtil()