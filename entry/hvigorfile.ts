import { hapTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  system: hapTasks,
  // externalNativeOptions 会一并打包 CMake 链接的 libmpv.so。
  plugins: []
};
