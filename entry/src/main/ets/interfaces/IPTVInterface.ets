export type IPTVSourceType = 'url' | 'file'

export interface IPTVProgram {
  title: string
  startTime: number
  endTime: number
}

export interface IPTVLine {
  url: string
  userAgent?: string
}

export interface IPTVChannel {
  id: string
  name: string
  url: string
  groupName: string
  logoUrl?: string
  tvgId?: string
  tvgName?: string
  channelNumber?: string
  userAgent?: string
  lines?: IPTVLine[]
  selectedLineIndex?: number
  currentProgram?: IPTVProgram
  nextProgram?: IPTVProgram
}

export interface IPTVSource {
  id: string
  name: string
  sourceType: IPTVSourceType
  location: string
  userAgent?: string
  epgUrl?: string
  channels: IPTVChannel[]
  channelCount: number
  groupCount: number
  createdTime: number
  updatedTime: number
  lastRefreshTime?: number
  lastRefreshStatus: 'idle' | 'success' | 'failed'
  lastError?: string
  epgMatchedCount?: number
}

export interface IPTVParseResult {
  channels: IPTVChannel[]
  groupCount: number
  invalidCount: number
  epgMatchedCount: number
}

export interface IPTVTestResult {
  success: boolean
  message: string
  channelCount: number
  groupCount: number
  invalidCount: number
  epgMatchedCount: number
  preparedSource?: IPTVSource
}
