export type EngineReleaseHook = () => void

export interface PlayerEngineAdapter {
  isCreated(): boolean

  release(beforeNativeRelease?: EngineReleaseHook): Promise<void>
}
