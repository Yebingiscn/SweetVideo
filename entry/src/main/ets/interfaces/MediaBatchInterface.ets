export interface MediaBatchProgress {
  processedItems: number
  totalItems: number
  currentFileName: string
  failedCount: number
}

export interface MediaBatchResult {
  successDates: string[]
  failedCount: number
  cancelled: boolean
}
