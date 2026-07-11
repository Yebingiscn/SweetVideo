import { common } from '@kit.AbilityKit'
import { userData } from '../component/common/UserLoginComponent'
import Preferences from '../database/Preferences'
import { PathUtils } from './PathUtils'
import { salmonLogger } from 'salmonlogger'
import ToolsUtil from './ToolsUtil'
import { FinishStatus, PurchaseData, PurchaseOrderPayload, SubGroupStatusPayload } from '../interfaces/IapDataModel'

import { iap } from '@kit.IAPKit'
import { JSON } from '@kit.ArkTS'

export interface SubscriptionCheckResult {
  isActive: boolean
  purchaseOrderPayload: PurchaseOrderPayload | null
}

export interface QueryPurchasesCallback {
  onHasPurchase: () => void
  onNoPurchase: () => void
  onError: () => void
}

const TAG = 'IapVerifyUtil'

export class IapVerifyUtil {
  static queryEnvironmentStatus(): Promise<boolean> {
    return iap.queryEnvironmentStatus(PathUtils.appContext)
      .then(() => {
        return true
      })
      .catch((err: BusinessError) => {
        salmonLogger.addLog(
          TAG,
          `Failed to query environment status. Code is ${err.code}, message is ${err.message}`,
          true
        )
        // 如果返回错误码 1001860054，说明当前服务地不在 IAP 支持范围内，需隐藏入口
        if (err.code === 1001860054) {
          return false
        }
        // 其他错误暂视为环境可用
        return true
      })
  }

  static verifyPurchaseStatus(context: common.UIAbilityContext) {
    const localIsVip = Preferences.getUserIsVip(context)
    IapVerifyUtil.queryPurchases(context, {
      onHasPurchase: () => {
        IapVerifyUtil.updateVipStatus(true)
      },
      onNoPurchase: () => {
        IapVerifyUtil.updateVipStatus(false)
      },
      onError: () => {
        userData.isVip = localIsVip
      }
    })
  }

  static queryPurchases(context: common.UIAbilityContext, callback: QueryPurchasesCallback) {
    const parameter: iap.QueryPurchasesParameter = {
      productType: iap.ProductType.NONCONSUMABLE,
      queryType: iap.PurchaseQueryType.CURRENT_ENTITLEMENT
    }
    iap.queryPurchases(context, parameter)
      .then((data: iap.QueryPurchaseResult) => {
        if (data.purchaseDataList && data.purchaseDataList.length > 0) {
          callback.onHasPurchase()
        } else {
          IapVerifyUtil.queryAutoRenewable(context, callback)
        }
      })
      .catch((err: BusinessError) => {
        salmonLogger.addLog(TAG, `Failed to query purchases. Code is ${err.code}, message is ${err.message}`, true)
        callback.onError()
      })
  }

  static dealSubscriptionPurchaseResult(purchaseData: string): SubscriptionCheckResult {
    const purchaseDataObj = JSON.parse(purchaseData) as PurchaseData
    const jwsSubscriptionStatus: string | undefined = purchaseDataObj.jwsSubscriptionStatus
    if (!jwsSubscriptionStatus) {
      return { isActive: false, purchaseOrderPayload: null }
    }
    const subscriptionStatus: string = ToolsUtil.decodeJwsObj(jwsSubscriptionStatus)
    if (!subscriptionStatus) {
      return { isActive: false, purchaseOrderPayload: null }
    }
    const subGroupStatusPayload = JSON.parse(subscriptionStatus) as SubGroupStatusPayload
    const lastSubscriptionStatus = subGroupStatusPayload.lastSubscriptionStatus
    if (!lastSubscriptionStatus || lastSubscriptionStatus.status !== FinishStatus.FINISHED) {
      return { isActive: false, purchaseOrderPayload: null }
    }
    const purchaseOrderPayload = lastSubscriptionStatus.lastPurchaseOrder ?? null
    return { isActive: true, purchaseOrderPayload }
  }

  static finishPurchase(purchaseOrder: PurchaseOrderPayload, onSuccess?: () => void) {
    const finishPurchaseParam: iap.FinishPurchaseParameter = {
      productType: Number(purchaseOrder.productType),
      purchaseToken: purchaseOrder.purchaseToken,
      purchaseOrderId: purchaseOrder.purchaseOrderId
    }
    iap.finishPurchase(PathUtils.appContext, finishPurchaseParam).then(() => {
      salmonLogger.addLog(TAG, 'Succeeded in finishing purchase.', false)
      if (onSuccess) {
        onSuccess()
      }
    }).catch((err: BusinessError) => {
      salmonLogger.addLog(TAG, 'Failed to finish purchase. Code is ' + err.code + ', message is ' + err.message, true)
    })
  }

  private static queryAutoRenewable(context: common.UIAbilityContext, callback: QueryPurchasesCallback) {
    const parameter: iap.QueryPurchasesParameter = {
      productType: iap.ProductType.AUTORENEWABLE,
      queryType: iap.PurchaseQueryType.CURRENT_ENTITLEMENT
    }
    iap.queryPurchases(context, parameter)
      .then((data: iap.QueryPurchaseResult) => {
        if (data.purchaseDataList && data.purchaseDataList.length > 0) {
          let hasActiveSubscription = false
          for (let i = 0; i < data.purchaseDataList.length; i++) {
            const result = IapVerifyUtil.dealSubscriptionPurchaseResult(data.purchaseDataList[i])
            if (result.isActive) {
              hasActiveSubscription = true
              if (result.purchaseOrderPayload && result.purchaseOrderPayload.finishStatus !== FinishStatus.FINISHED) {
                IapVerifyUtil.finishPurchase(result.purchaseOrderPayload)
              }
            }
          }
          if (hasActiveSubscription) {
            callback.onHasPurchase()
          } else {
            callback.onNoPurchase()
          }
        } else {
          callback.onNoPurchase()
        }
      })
      .catch((err: BusinessError) => {
        salmonLogger.addLog(TAG, `Failed to query purchases. Code is ${err.code}, message is ${err.message}`, true)
        callback.onError()
      })
  }

  private static updateVipStatus(isVip: boolean) {
    if (userData.isVip !== isVip) {
      userData.isVip = isVip
      Preferences.saveUserIsVip(PathUtils.appContext!, isVip)
    }
  }
}
