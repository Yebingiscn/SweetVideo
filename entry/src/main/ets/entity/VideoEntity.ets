import { Table, Column, PrimaryKey, NotNull, BelongsTo } from '@ibestservices/ibest-orm'
import { FolderEntity } from './FolderEntity'

@Table()
export class VideoEntity {
  @PrimaryKey({ autoIncrement: true })
  id?: number

  @Column()
  @NotNull()
  uri!: string

  @Column()
  @NotNull()
  folderId!: number

  @BelongsTo(() => FolderEntity, { foreignKey: 'folderId' })
  folder?: FolderEntity

  @Column()
  @NotNull()
  title!: string

  @Column()
  date!: string

  @Column()
  width: number = 0

  @Column()
  height: number = 0

  @Column()
  duration: number = 0

  @Column()
  lastPosition: number = 0

  @Column()
  format: string = ''

  @Column()
  fileSize: string = ''

  @Column()
  hdrType: number = 0

  @Column()
  startTime: number = 0

  @Column()
  endTime: number = 0

  @Column()
  externalSubtitle: string = ''

  @Column()
  pointA: number = 0

  @Column()
  pointB: number = 0

  @Column()
  sortOrder: number = 0

  @Column()
  subtitle_mode: number = 0

  @Column()
  subtitle_visible: boolean = true

  @Column()
  subtitle_ai_asr_shown: boolean = false

  @Column()
  subtitle_3d_mode: number = 0

  @Column()
  subtitle_offset_millis: number = 0

  @Column()
  subtitle_track_id: number = 0
}
