import { Table, Column, PrimaryKey, NotNull, CreatedAt } from '@ibestservices/ibest-orm'

// ORM 实体：最近播放记录表
// 说明：uri 作为主键，保证同一视频不会重复插入；folderDate 对应 VideoMetadata.date，
//      用于回查原文件夹信息。playedAt 记录最近一次播放的时间戳。
@Table()
export class RecentPlayEntity {
  @PrimaryKey()
  uri: string = ''

  @Column()
  @NotNull()
  title: string = ''

  @Column()
  folderDate: string = ''

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
  playedAt: string = ''

  @CreatedAt()
  createdAt?: string
}
