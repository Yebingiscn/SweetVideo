import { Table, Column, PrimaryKey, NotNull, CreatedAt } from '@ibestservices/ibest-orm'

// ORM 实体：隐私空间视频表
// 说明：uri 字段存储的是应用私有目录下的 sandbox 路径（复制后的路径），
//      originalUri 记录的是用户导入时的原始文件 URI，用于去重和导出。
//      所有必填字段均设置默认值，避免实例化时触发类型错误。
@Table()
export class PrivacyVideoEntity {
  @PrimaryKey()
  uri: string = ''

  @Column()
  @NotNull()
  title: string = ''

  @Column()
  originalUri: string = ''

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
  importedAt: string = ''

  @Column()
  date: string = ''

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
