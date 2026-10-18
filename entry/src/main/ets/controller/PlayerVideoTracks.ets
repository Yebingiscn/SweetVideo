export interface VideoTrack {
  id: number
  title: string
  codec: string
  width: number
  height: number
  fps: number
  selected: boolean
}

// File-local state only. Engine track IDs must never be reused for another media/session.
@ObservedV2
export class PlayerVideoTracks {
  @Trace tracks: VideoTrack[] = []
  @Trace switching: boolean = false
  private revision: number = 0
  private read: () => Promise<VideoTrack[]>
  private choose: (id: number) => Promise<void>
  private mediaKey: () => number

  constructor(read: () => Promise<VideoTrack[]>, choose: (id: number) => Promise<void>, mediaKey: () => number) {
    this.read = read
    this.choose = choose
    this.mediaKey = mediaKey
  }

  reset(): void {
    this.revision++
    this.tracks = []
    this.switching = false
  }

  async refresh(): Promise<void> {
    if (this.switching) return
    const revision = ++this.revision
    const key = this.mediaKey()
    if (key <= 0) return
    try {
      const tracks = await this.read()
      if (revision === this.revision && key === this.mediaKey()) this.tracks = tracks
    } catch (error) {
      if (revision === this.revision && key === this.mediaKey()) throw new Error((error as Error).message)
    }
  }

  async select(id: number): Promise<void> {
    if (this.switching || !this.tracks.some((track: VideoTrack) => track.id === id)) return
    if (this.tracks.some((track: VideoTrack) => track.id === id && track.selected)) return
    const revision = ++this.revision
    const key = this.mediaKey()
    if (key <= 0) return
    this.switching = true
    try {
      await this.choose(id)
      // Accepted is not applied: wait for the engine's actual selection, also while paused.
      for (let attempt = 0; attempt < 20; attempt++) {
        if (revision !== this.revision || key !== this.mediaKey()) return
        const tracks = await this.read()
        if (revision !== this.revision || key !== this.mediaKey()) return
        this.tracks = tracks
        if (tracks.some((track: VideoTrack) => track.id === id && track.selected)) return
        await new Promise<void>((resolve) => setTimeout(resolve, 150))
      }
      throw new Error('Video track selection was not confirmed')
    } catch (error) {
      if (revision === this.revision && key === this.mediaKey()) throw new Error((error as Error).message)
    } finally {
      if (revision === this.revision) this.switching = false
    }
  }
}
