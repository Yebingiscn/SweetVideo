import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { LengthMetrics } from '@kit.ArkUI'
import { userData, userLoginBuilder } from '../../component/common/UserLoginComponent'
import { iap } from '@kit.IAPKit'
import { PathUtils } from '../../utils/PathUtils'
import ToolsUtil from '../../utils/ToolsUtil'
import { errorMessages, PurchaseOrderPayload } from '../../interfaces/IapDataModel'
import { IapVerifyUtil } from '../../utils/IapVerifyUtil'
import { salmonLogger } from 'salmonlogger'
import { common } from '@kit.AbilityKit'
import Preferences from '../../database/Preferences'

const TAG = 'GetVipPage'

@ComponentV2
export struct GetVipPage {
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local isShowLoginSheet: boolean = false
  @Local purchaseSuccess: boolean = false
  @Local showAgreementSheet: boolean = false
  @Local isAgreed: boolean = false
  private pendingProductType: iap.ProductType | null = null
  private pendingProductId: string = ''
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.purchaseSuccess = Preferences.getUserIsVip(PathUtils.appContext!)
  }

  build() {
    HdsNavDestination() {
      if (this.purchaseSuccess) {
        this.PurchaseSuccessView()
      } else if (!userData.isLogin) {
        this.NotLoginView()
      } else {
        this.VipPurchaseView()
      }
    }
    .titleBar({
      enableComponentSafeArea: true,
      padding: { start: LengthMetrics.vp(5), end: LengthMetrics.vp(5) },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        originalStyle: {
          backgroundStyle: { backgroundColor: $r('sys.color.ohos_id_color_background') },
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary'), subTitleColor: $r('sys.color.font_secondary') },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: { backgroundColor: $r('sys.color.ohos_id_color_background_transparent') },
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary'), subTitleColor: $r('sys.color.font_secondary') },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        }
      },
      content: { title: { mainTitle: '获取VIP' } }
    })
    .backgroundColor($r('app.color.start_window_background'))
    .padding({ top: SafeHeight.topSafeHeight })
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ?
        Setting.backgroundBlurImageSrc : Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .hideBackButton(false)
    .bindToScrollable([this.scroller])
  }

  @Builder
  NotLoginView() {
    Column({ space: 20 }) {
      Column({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.mouse_right_click_move'))
          .fontSize(64)
          .fontColor([$r('sys.color.icon_secondary')])
        Text('请先登录')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_color'))
        Text('登录华为账号后即可购买VIP')
          .fontSize(15)
          .fontColor($r('sys.color.font_secondary'))
      }
      .margin({ top: 80 })

      Button('去登录')
        .width('60%')
        .height(50)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .borderRadius(16)
        .backgroundColor($r('app.color.main_color'))
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.95 })
        .onClick(() => {
          this.isShowLoginSheet = true
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .bindSheet(this.isShowLoginSheet, userLoginBuilder(() => {
      this.isShowLoginSheet = false
    }), {
      detents: [SheetSize.FIT_CONTENT],
      height: SheetSize.MEDIUM,
      preferType: SheetType.CENTER,
      enableOutsideInteractive: false,
      dragBar: true,
      showClose: true,
      title: { title: '账号登录' },
      onWillDismiss: () => {
        this.isShowLoginSheet = false
      }
    })
  }

  @Builder
  VipPurchaseView() {
    Scroll(this.scroller) {
      Column({ space: 20 }) {
        Column({ space: 8 }) {
          Text('Hi ' + (userData.nickName || ''))
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_color'))
          Text('有没有兴趣')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_color'))
          Text('升级 Pro 解锁全部功能')
            .fontSize(28)
            .fontWeight(FontWeight.Bolder)
            .fontColor($r('app.color.text_color'))
        }
        .margin({ top: 30 })

        Column({ space: 12 }) {
          Row({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.diamond'))
              .fontSize(24)
              .fontColor([$r('sys.color.icon_primary')])
            Column() {
              Text('早鸟优惠')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_color'))
              Text('暂时不限制功能，当前属于早鸟优惠')
                .fontSize(13)
                .fontColor($r('sys.color.font_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor($r('app.color.start_window_background_blur'))

          Row({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.vip_rectangle'))
              .fontSize(24)
              .fontColor([$r('sys.color.icon_primary')])
            Column() {
              Text('持续更新')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_color'))
              Text('永久有效，享受未来所有更新')
                .fontSize(13)
                .fontColor($r('sys.color.font_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor($r('app.color.start_window_background_blur'))
        }

        Column({ space: 12 }) {
          Button('¥19.9 / 永久')
            .width('100%')
            .height(50)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .borderRadius(16)
            .backgroundColor($r('app.color.main_color'))
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.95 })
            .onClick(() => {
              this.createPurchase(iap.ProductType.NONCONSUMABLE, 'sweet_vip_forever')
            })

          Button('¥5.9 / 1月')
            .width('100%')
            .height(50)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .borderRadius(16)
            .backgroundColor($r('app.color.start_window_background_blur'))
            .fontColor($r('app.color.text_color'))
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.95 })
            .onClick(() => {
              this.createPurchase(iap.ProductType.AUTORENEWABLE, 'sweet_vip_month')
            })

          Button('恢复购买')
            .width('100%')
            .height(50)
            .fontSize(15)
            .fontWeight(FontWeight.Normal)
            .borderRadius(16)
            .backgroundColor($r('app.color.start_window_background_blur'))
            .fontColor($r('app.color.text_color'))
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.95 })
            .onClick(() => {
              this.restorePurchase()
            })
        }
        .margin({ top: 10 })

        Text('购买后关联华为账号，支持恢复购买')
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))

        Text('会员协议')
          .fontSize(14)
          .fontColor($r('app.color.main_color'))
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.9 })
          .onClick(() => {
            this.showAgreementSheet = true
          })

        Text('订阅详情')
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.9 })
          .onClick(() => {
            const uiWindowParameter: iap.UIWindowParameter = {
              windowScreenMode: iap.WindowScreenMode.DIALOG_BOX
            }
            const groupId = '4E0F8D3546AA4E66A2C0C3E020130B2A'
            iap.showManagedSubscriptions(this.getUIContext().getHostContext() as common.UIAbilityContext,
              uiWindowParameter, groupId).then(() => {
            }).catch((err: BusinessError) => {
              salmonLogger.addLog(
                'Failed to show subscription page. Code is ' + err.code + ', message is ' + err.message)
            })
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: SafeHeight.bottomSafeHeight })
      .alignItems(HorizontalAlign.Center)
    }
    .clip(false)
    .margin({ left: 16, right: 16 })
    .layoutWeight(1)
    .height('100%')
    .align(Alignment.Top)
    .borderRadius(16)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .bindSheet(this.showAgreementSheet, this.AgreementSheetContent(), {
      detents: [SheetSize.FIT_CONTENT],
      height: SheetSize.LARGE,
      preferType: SheetType.CENTER,
      dragBar: false,
      showClose: true,
      title: { title: '会员服务协议' },
      onWillDismiss: () => {
        this.showAgreementSheet = false
      }
    })
  }

  @Builder
  AgreementSheetContent() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          Text(
            '1．会员服务内容：购买"《流心播放器》会员服务"成为会员后，您将享受上述的功能。注意！本应用为视频播放器，您需要自行准备音频及其附属资源的文件，是否为VIP不与能否播放、是否有字幕与封面等不产生任何关联。')
            .fontSize(14)
            .fontColor($r('app.color.text_color'))
            .width('100%')
          Text('2．会员身份绑定：会员身份与设备登录的华为账号绑定。如需登出或切换账号，请在设备的系统设置中操作。')
            .fontSize(14)
            .fontColor($r('app.color.text_color'))
            .width('100%')
          Text('4. 订阅方案变更说明： 若您订阅的方案发生变更，我们将按原方案进行扣费，不会取消您的订阅或更改价格。')
            .fontSize(14)
            .fontColor($r('app.color.text_color'))
            .width('100%')
          Text(
            '5．修改订阅方案：如需更改订阅方案，请至少在扣费前24小时内，通过 "设备系统设置﹣账号中心﹣付款与账单﹣自动扣费／免密支付（或订阅）"选择《流心播放器》进行方案更换。我们将不定期推出新的订阅方案供用户选择。')
            .fontSize(14)
            .fontColor($r('app.color.text_color'))
            .width('100%')
          Text(
            '6．取消续订：如需取消续订，请在扣费前至少24小时关闭自动续订服务。请在"设备系统设置﹣账号中心﹣付款与账单﹣自动扣费／免密支付（或订阅）"中选择《流心播放器》，解除自动扣费服务或取消订阅，即可停止续订。关闭自动续订后，您仍可继续使用会员服务至当前订阅周期结束')
            .fontSize(14)
            .fontColor($r('app.color.text_color'))
            .width('100%')
          Text(
            '7. 退款政策：鉴于数字化商品的特殊性质，《流心播放器》所为您提供的会员服务不包含七天无理由退货服务。会员服务一经购买，即视为已享受服务，因此不予办理退款。请您在购买前仔细阅读服务条款，理性决策。')
            .fontSize(14)
            .fontColor($r('app.color.text_color'))
            .width('100%')
          Text('8．终身会员订阅：购买或兑换终身会员后，用户需手动退订原有订阅方案，否则会继续产生费用。')
            .fontSize(14)
            .fontColor($r('app.color.text_color'))
            .width('100%')
          Text(
            '9．账号注销：注销账号后，您的头像框、VIP 兑换码等个人数据将被永久删除且无法恢复，通过应用内支付所购买的VIP权益因与华为账号关联，故予以保留。开发者不会对已注销账号提供任何形式的资产找回服务。确认注销即示知悉上述后果，此操作不可撤销。')
            .fontSize(14)
            .fontColor($r('app.color.text_color'))
            .width('100%')
          Text('10．会员状态问题：如果会员状态未能正确识别，请尝试在联网状态下重启应用，若无法解决联系开发者。')
            .fontSize(14)
            .fontColor($r('app.color.text_color'))
            .width('100%')
          Text(
            '11．客户支持：如若您认为本文仍无法对您的问题给予有效帮助，请通过"流心播放器﹣设置 - 更多设置﹣关于此应用"中提供的联系方式（QQ群、邮箱）联系我们。')
            .fontSize(14)
            .fontColor($r('app.color.text_color'))
            .width('100%')
        }
        .padding({ left: 20, right: 20, top: 8 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('85%')
      .padding({ left: 16, right: 16 })

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(50)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .borderRadius(16)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .fontColor($r('app.color.text_color'))
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.95 })
          .onClick(() => {
            this.showAgreementSheet = false
          })
        Button('同意并继续')
          .layoutWeight(1)
          .height(50)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .borderRadius(16)
          .backgroundColor($r('app.color.main_color'))
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.95 })
          .onClick(() => {
            this.isAgreed = true
            this.showAgreementSheet = false
            if (this.pendingProductType !== null && this.pendingProductId.length > 0) {
              const type = this.pendingProductType
              const id = this.pendingProductId
              this.pendingProductType = null
              this.pendingProductId = ''
              this.createPurchase(type, id)
            }
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  PurchaseSuccessView() {
    Column({ space: 20 }) {
      Column({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.crown'))
          .fontSize(72)
          .fontColor(['#FFE46D'])
        Text('购买成功')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_color'))
        Text('感谢您的支持，已解锁全部VIP功能')
          .fontSize(15)
          .fontColor($r('sys.color.font_secondary'))
      }
      .margin({ top: 80 })

      Button('返回')
        .width('60%')
        .height(50)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .borderRadius(16)
        .backgroundColor($r('app.color.main_color'))
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.95 })
        .onClick(() => {
          this.pathStack.pop()
        })

      Text('订阅详情')
        .fontSize(12)
        .fontColor($r('sys.color.font_tertiary'))
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.9 })
        .onClick(() => {
          const uiWindowParameter: iap.UIWindowParameter = {
            windowScreenMode: iap.WindowScreenMode.DIALOG_BOX
          }
          const groupId = '4E0F8D3546AA4E66A2C0C3E020130B2A'
          iap.showManagedSubscriptions(this.getUIContext().getHostContext() as common.UIAbilityContext,
            uiWindowParameter, groupId).then(() => {
          }).catch((err: BusinessError) => {
            salmonLogger.addLog(
              'Failed to show subscription page. Code is ' + err.code + ', message is ' + err.message)
          })
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }

  private createPurchase(productType: iap.ProductType, productId: string) {
    if (!this.isAgreed) {
      this.pendingProductType = productType
      this.pendingProductId = productId
      this.showAgreementSheet = true
      return
    }
    const createPurchaseParam: iap.PurchaseParameter = {
      productType: productType,
      productId: productId
    }
    iap.createPurchase(PathUtils.appContext, createPurchaseParam).then((result) => {
      if (productType === iap.ProductType.AUTORENEWABLE) {
        this.dealSubscriptionPurchaseResult(result)
      } else {
        this.onPurchaseSuccess()
      }
    }).catch((err: BusinessError) => {
      salmonLogger.addLog(TAG, 'createPurchase error: ' + JSON.stringify(err), true)
      this.dealPurchaseError(err)
    })
  }

  private restorePurchase() {
    IapVerifyUtil.queryPurchases(this.getUIContext().getHostContext() as common.UIAbilityContext, {
      onHasPurchase: () => {
        this.onPurchaseSuccess()
      },
      onNoPurchase: () => {
        ToolsUtil.showToast('暂无可恢复的购买记录')
      },
      onError: () => {
        ToolsUtil.showToast('恢复购买失败')
      }
    })
  }

  private onPurchaseSuccess() {
    userData.isVip = true
    Preferences.saveUserIsVip(PathUtils.appContext!, true)
    this.purchaseSuccess = true
  }

  private dealSubscriptionPurchaseResult(result: iap.CreatePurchaseResult) {
    const checkResult = IapVerifyUtil.dealSubscriptionPurchaseResult(result.purchaseData)
    if (checkResult.purchaseOrderPayload) {
      this.finishPurchase(checkResult.purchaseOrderPayload)
    }
  }

  private finishPurchase(purchaseOrder: PurchaseOrderPayload) {
    IapVerifyUtil.finishPurchase(purchaseOrder, () => {
      this.onPurchaseSuccess()
    })
  }

  private dealPurchaseError(err: BusinessError) {
    if (err.code === iap.IAPErrorCode.PRODUCT_OWNED || err.code === iap.IAPErrorCode.SYSTEM_ERROR) {
      IapVerifyUtil.queryPurchases(this.getUIContext().getHostContext() as common.UIAbilityContext, {
        onHasPurchase: () => {
          this.onPurchaseSuccess()
        },
        onNoPurchase: () => {
          ToolsUtil.showToast('查询购买记录失败')
        },
        onError: () => {
          ToolsUtil.showToast('查询购买记录失败')
        }
      })
      return
    }
    ToolsUtil.showToast('购买失败，错误码：' + err.code + ', 原因是：' + errorMessages.get(err.code))
    salmonLogger.addLog(TAG, 'Purchase failed. Code is ' + err.code + ', message is ' + err.message, true)
  }
}
