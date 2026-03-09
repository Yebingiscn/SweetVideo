import { hapTasks } from '@ohos/hvigor-ohos-plugin';
import * as fs from 'fs';
import * as path from 'path';

// 路径配置
const entryPath = __dirname;
const projectRoot = path.resolve(entryPath, '..');
const libmpvnativePath = path.join(projectRoot, 'libmpvnative');
const entryLibsPath = path.join(entryPath, 'libs/arm64-v8a');

/**
 * 复制 libmpv.so.2 到 entry 模块
 * libmpvnative.so 由 externalNativeOptions 自动构建并打包
 */
function copyLibmpvSo() {
  // libmpv.so.2 源路径（预编译库）
  const libmpvSoSource = path.join(libmpvnativePath, 'libs/arm64-v8a/libmpv.so.2');

  // 确保 entry/libs/arm64-v8a 目录存在
  if (!fs.existsSync(entryLibsPath)) {
    fs.mkdirSync(entryLibsPath, { recursive: true });
    console.log(`[libmpvnative] 创建目录: ${entryLibsPath}`);
  }

  // 复制 libmpv.so.2
  if (fs.existsSync(libmpvSoSource)) {
    const libmpvSoTarget = path.join(entryLibsPath, 'libmpv.so.2');
    fs.copyFileSync(libmpvSoSource, libmpvSoTarget);
    console.log(`[libmpvnative] 已复制 libmpv.so.2 到 entry/libs/arm64-v8a/`);
  } else {
    console.warn(`[libmpvnative] 警告: 未找到 libmpv.so.2`);
    console.warn(`[libmpvnative] 预期路径: ${libmpvSoSource}`);
  }
}

export default {
  system: hapTasks,
  plugins: [
    {
      pluginId: 'libmpvnative-copy-plugin',
      apply: () => {
        return {
          // 在 preBuild 阶段执行复制
          preBuild: () => {
            console.log('[libmpvnative] 开始复制 libmpv.so.2...');
            copyLibmpvSo();
          }
        };
      }
    }
  ]
};
