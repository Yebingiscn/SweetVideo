import { Table, Column, PrimaryKey, NotNull, BelongsTo } from '@ibestservices/ibest-orm'
import { FolderEntity } from './FolderEntity'

// ORM 实体：普通视频表
// 说明：通过 folderId 外键关联 FolderEntity，构成“一个文件夹包含多个视频”的一对多关系。
//      字段命名采用 ArkTS 驼峰风格，ibest-orm 会自动映射到数据库下划线命名（如 lastPosition -> last_position）。
//      所有必填字段均设置默认值，避免 new VideoEntity() 时触发类型错误。
@Table()
export class VideoEntity {
  @PrimaryKey({ autoIncrement: true })
  id?: number

  @Column()
  @NotNull()
  uri: string = ''

  @Column()
  @NotNull()
  folderId: number = 0

  @BelongsTo(() => FolderEntity, { foreignKey: 'folderId' })
  folder?: FolderEntity

  @Column()
  @NotNull()
  title: string = ''

  @Column()
  date: string = ''

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
