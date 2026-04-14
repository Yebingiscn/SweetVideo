import { Table, Column, PrimaryKey, NotNull, CreatedAt, UpdatedAt, HasMany } from '@ibestservices/ibest-orm'
import { VideoEntity } from './VideoEntity'

@Table()
export class FolderEntity {
  @PrimaryKey()
  id?: number

  @Column()
  @NotNull()
  date!: string

  @Column()
  @NotNull()
  name!: string

  @Column()
  sortOrder: number = 0

  @CreatedAt()
  createdAt?: string

  @UpdatedAt()
  updatedAt?: string

  @HasMany(() => VideoEntity, { foreignKey: 'folderId' })
  videos?: VideoEntity[]
}
