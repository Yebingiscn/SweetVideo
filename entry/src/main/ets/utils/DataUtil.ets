import { VideoMetadata } from "./VideoInfoUtil";

export default class DataUtil<T> implements IDataSource {
  private sources: T[] = []
  //数据源
  private listeners: DataChangeListener[] = []

  //数据监听
  // 数据源构造器
  constructor(sources: T[]) {
    this.sources = sources;
  }

  totalCount(): number { //数据源中数据个数
    return this.sources.length
  }

  getData(index: number) { //获取下标对应的数据
    return this.sources[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void { //注册监听器
    if (this.listeners.indexOf(listener) < 0) { //当前监听器数组中没有数据
      this.listeners.push(listener) //增加该监听
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    let pos = this.listeners.indexOf(listener)
    if (pos > 0) //当前监听器数组中有数据
    {
      this.listeners.splice(pos, 1) //移除该监听
    }
  }

  //_______________________________数据源操作方法 新增数据、插入数据、删除数据、更新数据________________________

  addData(item: T) { //尾部增加元素
    this.sources.push(item)
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataAdd(this.sources.length - 1)
    })
  }

  addData1(index: number, item: T) { //某个位置添加元素
    this.sources.splice(index, 0, item)
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataAdd(index)
    })
  }

  delData() { //末尾移除元素
    this.sources.pop()
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataDelete(this.sources.length - 1)
    })
  }

  clearData() { //末尾移除元素
    this.sources.pop()
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataDelete(0)
    })
  }

  delData1(index: number) { //移除某个下标对应的元素
    this.sources.splice(index, 1)
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataDelete(index)

    })
  }

  updData(index: number, Data: T) { //更新某个下标的元素
    this.sources.splice(index, 1, Data)
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataChange(index)
    })
  }
}

export class VideoDataSource implements IDataSource {
  private listeners: DataChangeListener[] = []; // 存储监听器
  private data: VideoMetadata[] = [];

  constructor(data: VideoMetadata[]) {
    this.data = data;
  }

  // 必须实现的方法：注册数据变化监听
  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener);
  }

  // 必须实现的方法：取消注册
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  // 数据更新时需要触发的逻辑
  updateData(newData: VideoMetadata[]) {
    this.data = newData;
    this.listeners.forEach(listener => {
      listener.onDataReloaded(); // 通知所有监听器数据已更新
    });
  }

  totalCount(): number {
    return this.data.length;
  }

  getData(index: number): VideoMetadata {
    return this.data[index];
  }

  getKey(index: number): string {
    return this.data[index].date; // 确保date是唯一标识
  }
}