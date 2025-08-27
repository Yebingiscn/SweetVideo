import { FileFolder } from './FileFolderInterface';

// 定义处理结果的接口
export interface FolderProcessResult {
  folder: FileFolder; // 根据您的实际文件夹类型替换 any
  processed: number;
}

export type ProcessFunction<T, R> = (item: T) => Promise<R>;
