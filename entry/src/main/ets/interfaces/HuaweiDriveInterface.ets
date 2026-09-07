export interface HuaweiDriveTokenResponse {
  accessToken?: string
  expiresIn?: number
  refreshToken?: string
  access_token?: string
  expires_in?: number
  refresh_token?: string
  scope?: string
  token_type?: string
}

export interface HuaweiDriveUser {
  displayName?: string
}

export interface HuaweiDriveStorageQuota {
  usedSpace?: string
  userCapacity?: string
}

export interface HuaweiDriveAbout {
  storageQuota?: HuaweiDriveStorageQuota
  maxFileUploadSize?: string
  needUpdate?: boolean
  user?: HuaweiDriveUser
  domain?: string
}

export interface HuaweiDriveVideoMetadata {
  width?: number
  height?: number
  durationTime?: number
}

export interface HuaweiDriveCapabilities {
  downloadPermission?: boolean
}

export interface HuaweiDriveFile {
  id: string
  fileName: string
  mimeType: string
  size?: number
  editedTime?: string
  parentFolder?: string[]
  recycled?: boolean
  directlyRecycled?: boolean
  contentDownloadLink?: string
  thumbnailDownloadLink?: string
  smallThumbnailDownloadLink?: string
  sha256?: string
  videoMetadata?: HuaweiDriveVideoMetadata
  capabilities?: HuaweiDriveCapabilities
}

export interface HuaweiDriveFileList {
  files?: HuaweiDriveFile[]
  nextCursor?: string
}

export interface HuaweiDriveFolderPath {
  id: string
  name: string
}
