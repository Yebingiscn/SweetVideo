import { BaseListener } from './BaseEventUtil'

export interface CoverUpdateEvent {
  date: string
}

export const coverEventBus = new BaseListener<CoverUpdateEvent>()
