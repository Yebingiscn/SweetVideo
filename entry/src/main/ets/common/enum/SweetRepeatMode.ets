export const enum SweetRepeatMode {
  LIST = 0,
  SINGLE = 1,
  RANDOM = 2,
  SEQUENCE = 3,
  // Legacy persisted value for the old end-current timer; never use as a playback mode.
  ONCE = 4
}

export function normalizeRepeatMode(mode: number): SweetRepeatMode {
  switch (mode) {
    case SweetRepeatMode.LIST:
    case SweetRepeatMode.SINGLE:
    case SweetRepeatMode.RANDOM:
    case SweetRepeatMode.SEQUENCE:
      return mode
    default:
      return SweetRepeatMode.LIST
  }
}