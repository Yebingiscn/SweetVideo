import type { PlayerControllerInterface } from './PlayerControllerFactory'

interface ViewportSnapshot {
  date: string
  selectedText: string | undefined
  scale: number
  x: number
  y: number
  angle: number
  zoomed: boolean
}

// Background recovery must keep the user's crop, independently of Surface layout.
export class PlayerViewportState {
  private owner: PlayerControllerInterface | undefined = undefined
  private snapshot: ViewportSnapshot | undefined = undefined

  capture(player: PlayerControllerInterface): void {
    this.clear()
    if (!player.nowPlaying) return
    this.owner = player
    this.snapshot = {
      date: player.nowPlaying.date, selectedText: player.selectedText,
      scale: player.scaleFactor, x: player.translateX, y: player.translateY,
      angle: player.angle, zoomed: player.isZoomed
    }
  }

  restore(player: PlayerControllerInterface): boolean {
    const snapshot = this.snapshot
    const matches = this.owner === player && snapshot?.date === player.nowPlaying?.date
    this.clear()
    if (!snapshot || !matches) return false
    player.selectedText = snapshot.selectedText
    if (player.screenWidth > 0 && player.screenHeight > 0) player.setRotation()
    player.scaleFactor = snapshot.scale
    player.translateX = snapshot.x
    player.translateY = snapshot.y
    player.angle = snapshot.angle
    player.isZoomed = snapshot.zoomed
    return true
  }

  clear(): void {
    this.owner = undefined
    this.snapshot = undefined
  }

  static applyAspectRatio(player: PlayerControllerInterface, mode: string): void {
    player.selectedText = mode
    player.scaleFactor = 1
    player.translateX = 0
    player.translateY = 0
    player.isZoomed = false
    // Reuse the initial/resize layout path after committing the new mode.
    player.setRotation()
  }

  static resize(player: PlayerControllerInterface, width: number, height: number): boolean {
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0 ||
      (player.screenWidth === width && player.screenHeight === height)) return false
    player.screenWidth = width
    player.screenHeight = height
    player.setRotation()
    return true
  }
}
