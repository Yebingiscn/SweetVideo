export default class DataUtil<T> implements IDataSource {
  private datas: T[] = []
  //数据源
  private listeners: DataChangeListener[] = []

  //数据监听
  // 数据源构造器
  constructor(datas: T[]) {
    this.datas = datas;
  }

  totalCount(): number { //数据源中数据个数
    return this.datas.length
  }

  getData(index: number) { //获取下标对应的数据
    return this.datas[index]
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
    this.datas.push(item)
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataAdd(this.datas.length - 1)
    })
  }

  addData1(index: number, item: T) { //某个位置添加元素
    this.datas.splice(index, 0, item)
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataAdd(index)
    })
  }

  delData() { //末尾移除元素
    this.datas.pop()
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataDelete(this.datas.length - 1)
    })
  }

  clearData() { //末尾移除元素
    this.datas.pop()
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataDelete(0)
    })
  }

  delData1(index: number) { //移除某个下标对应的元素
    this.datas.splice(index, 1)
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataDelete(index)

    })
  }

  updData(index: number, Data: T) { //更新某个下标的元素
    this.datas.splice(index, 1, Data)
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataChange(index)
    })
  }
}