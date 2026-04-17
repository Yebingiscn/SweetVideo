import { Table, Column, PrimaryKey, NotNull, CreatedAt, UpdatedAt, HasMany } from '@ibestservices/ibest-orm'
import { VideoEntity } from './VideoEntity'

// ORM 实体：文件夹表
// 说明：ibest-orm 要求实体字段在 new 实例化时即可访问，因此将原 `date!: string` 等非空断言改为 `date: string = ''` 默认值。
//      主键 id 为自增，通常由 ORM 在 insert 时自动填充。
@Table()
export class FolderEntity {
  @PrimaryKey()
  id?: number

  @Column()
  @NotNull()
  date: string = ''

  @Column()
  @NotNull()
  name: string = ''

  @Column()
  sortOrder: number = 0

  @CreatedAt()
  createdAt?: string

  @UpdatedAt()
  updatedAt?: string

  @HasMany(() => VideoEntity, { foreignKey: 'folderId' })
  videos?: VideoEntity[]
}
