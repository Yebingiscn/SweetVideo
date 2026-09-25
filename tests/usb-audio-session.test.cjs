const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.env.TYPESCRIPT_MODULE || 'typescript');
const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/utils/UsbAudioSession.ets'), 'utf8');
const code = ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
function fixture() {
  const calls = [];
  const device = { name: '1-2', vendorId: 12, productId: 34, configs: [{ interfaces: [{ clazz: 1 }] }] };
  let devices = [device];
  const usb = {
    getDevices: () => devices,
    hasRight: () => false,
    requestRight: async () => true,
    connectDevice: () => { calls.push('connect'); return { busNum: 1, devAddress: 2 }; },
    getFileDescriptor: () => 42,
    closePipe: () => calls.push('pipe-close'),
  };
  const file = {
    statSync: fd => { if (fd !== 42) throw Error('not an fd'); },
    closeSync: fd => { assert.equal(fd, 42); calls.push('fd-close'); }
  };
  const exports = {};
  vm.runInNewContext(code, {
    exports, canIUse: () => true,
    require: name => name === '@kit.BasicServicesKit' ? { usbManager: usb } :
      name === '@kit.CoreFileKit' ? { fileIo: file } : { salmonLogger: { addLog() {} } }
  });
  return { C: exports.UsbAudioSession, usb, calls, device, setDevices: d => { devices = d; } };
}
(async () => {
  let f = fixture();
  let s = new f.C();
  assert.equal(await s.open(''), 42);
  assert.equal(await s.open(''), 42);
  s.close(); s.close();
  assert.deepEqual(f.calls, ['connect', 'fd-close', 'pipe-close']);
  assert.equal(s.descriptor, -1);

  f = fixture(); s = new f.C(); f.usb.requestRight = async () => false;
  await assert.rejects(s.open(''), /授权/);
  assert.deepEqual(f.calls, []);

  f = fixture(); s = new f.C();
  f.setDevices([f.device, { ...f.device, name: '1-3' }]);
  await assert.rejects(s.open(''), /选择/);
  assert.equal(await s.open(f.C.deviceKey(f.device)), 42); s.close();

  f = fixture(); s = new f.C();
  await assert.rejects(s.open('999:999:1-2'), /未找到/);
  assert.deepEqual(f.calls, []);

  f = fixture(); s = new f.C();
  let permit;
  f.usb.requestRight = () => new Promise(resolve => { permit = resolve; });
  const pending = s.open(''); s.close(); permit(true);
  await assert.rejects(pending, /取消/);
  assert.deepEqual(f.calls, []);

  f = fixture(); s = new f.C(); f.usb.getFileDescriptor = () => 88080488;
  await assert.rejects(s.open(''), /原生传输权限/);
  assert.deepEqual(f.calls, ['connect', 'pipe-close']);

  f = fixture(); s = new f.C(); f.usb.hasRight = () => true;
  f.usb.requestRight = () => { throw Error('must reuse authorization'); };
  assert.equal(await s.open(''), 42); s.close();
  console.log('USB session: authorization, selection, cancellation, fd validation and idempotent cleanup passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
