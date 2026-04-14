import { Table, Column, PrimaryKey, NotNull, CreatedAt } from '@ibestservices/ibest-orm'

@Table()
export class PrivacyVideoEntity {
  @PrimaryKey()
  uri!: string

  @Column()
  @NotNull()
  title!: string

  @Column()
  originalUri!: string

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
  pointA: number = 0

  @Column()
  pointB: number = 0

  @Column()
  importedAt!: string

  @Column()
  date!: string

  @CreatedAt()
  createdAt?: string

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
