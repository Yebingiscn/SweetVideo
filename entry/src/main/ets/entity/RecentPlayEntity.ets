import { Table, Column, PrimaryKey, NotNull, CreatedAt } from '@ibestservices/ibest-orm'

@Table()
export class RecentPlayEntity {
  @PrimaryKey()
  uri!: string

  @Column()
  @NotNull()
  title!: string

  @Column()
  folderDate!: string

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
  playedAt!: string

  @CreatedAt()
  createdAt?: string
}
