/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2024. All rights reserved.
 */

export interface PurchaseData {
  type: number;
  jwsPurchaseOrder?: string;
  jwsSubscriptionStatus?: string;
}

export interface PurchaseOrderPayload {
  productId: string;
  productType: string;
  purchaseOrderId: string;
  purchaseToken: string;
  finishStatus?: FinishStatus;
}

export enum FinishStatus {
  FINISHED = '1',
  UNFINISHED = '2'
}

export interface SubGroupStatusPayload {
  environment: string;
  applicationId: string;
  packageName: string;
  subGroupId: string;
  lastSubscriptionStatus?: SubscriptionStatus;
  historySubscriptionStatusList?: SubscriptionStatus[];
}

export interface SubscriptionStatus {
  subGroupGenerationId: string;
  subscriptionId: string;
  purchaseToken: string;
  status: string;
  expiresTime: number;
  lastPurchaseOrder?: PurchaseOrderPayload;
  renewalInfo?: SubRenewalInfo;
}

interface SubRenewalInfo {
  productId: string;
}

export enum SubStatus {
  ACTIVE = '1',
  EXPIRED = '2',
  CHARGE_ATTEMPT = '3',
  REVOKED = '5'
}

// 错误码与中文描述的映射
export const errorMessages: Map<number, string> = new Map([
  [1001860000, '用户取消当前操作。'],
  [1001860001, '通用失败错误码。'],
  [1001860002, '应用未被授权访问接口。'],
  [1001860003, '无效的商品信息。'],
  [1001860004, '接口访问过频。'],
  [1001860005, '网络连接异常。'],
  [1001860007, '商品所属的应用未在指定国家/地区上架。'],
  [1001860050, '未登录华为账号。'],
  [1001860051, '由于已经拥有该商品，购买失败。'],
  [1001860052, '由于未拥有该商品，发货失败。'],
  [1001860053, '此次购买已经完成发货，无需重复发货。'],
  [1001860054, '用户账号所在服务地暂不支持IAP。'],
  [1001860056, '用户交易被拒绝。'],
  [1001860057, '当前应用不是debug签名的应用。'],
  [1001860058, '华为账号不是沙盒测试账号。'],
  [1001860059, '无效的优惠信息。'],
  [1001860060, '无效的签名信息。'],
  [1001860061, '商品已退款或退款中。'],
  [1001860062, '不允许退款。'],
  [1001860064, '在登录的华为账号上找不到该笔订单。'],
  [1001860065, '不支持开票操作。']
])