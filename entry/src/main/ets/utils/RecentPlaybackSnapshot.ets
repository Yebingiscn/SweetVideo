import { VideoMetadata } from '../interfaces/VideoMetadataInterface'

// Page-local, bounded by the history limit. Keep signatures separate so in-place
// metadata updates are detected too; do not cache history across privacy/session boundaries.
export class RecentPlaybackSnapshot {
  items: VideoMetadata[] = []
  private signatures: string[] = []

  update(next: VideoMetadata[]): boolean {
    // Legacy snapshots can contain repeated URIs. Match history's first/latest
    // entry semantics for display only; never rewrite or repair storage here.
    const seen = new Set<string>()
    const unique = next.filter((item: VideoMetadata): boolean => {
      const key = RecentPlaybackSnapshot.key(item)
      if (seen.has(key)) {
        return false
      }
      seen.add(key)
      return true
    })
    const signatures = unique.map((item: VideoMetadata): string => JSON.stringify(item))
    if (this.signatures.length === signatures.length &&
      signatures.every((value: string, index: number): boolean => value === this.signatures[index])) {
      return false
    }
    const previous = new Map<string, number>()
    this.items.forEach((item: VideoMetadata, index: number) => previous.set(RecentPlaybackSnapshot.key(item), index))
    this.items = unique.map((item: VideoMetadata, index: number): VideoMetadata => {
      const oldIndex = previous.get(RecentPlaybackSnapshot.key(item))
      return oldIndex !== undefined && this.signatures[oldIndex] === signatures[index] ?
        this.items[oldIndex] : JSON.parse(signatures[index]) as VideoMetadata
    })
    this.signatures = signatures
    return true
  }

  static key(item: VideoMetadata): string {
    return item.uri ? 'uri:' + item.uri : 'date:' + item.date
  }
}
