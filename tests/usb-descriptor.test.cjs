const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.env.TYPESCRIPT_MODULE);
const source = fs.readFileSync('entry/src/main/ets/utils/UsbAudioSession.ets', 'utf8');
const code = ts.transpileModule(source, { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020
} }).outputText;
function fixture(fd = 42, errno = 0) {
  const calls = [];
  const logs = [];
  const exports = {};
  const usb = {
    getDevices: () => [{ name: '2-2', vendorId: 1, productId: 2,
      configs: [{ interfaces: [{ clazz: 1 }] }] }],
    hasRight: () => true, connectDevice: () => ({}),
    getFileDescriptor: () => fd, closePipe: () => calls.push('closePipe')
  };
  vm.runInNewContext(code, { exports, canIUse: () => true, $r: id => ({ id }),
    require: name => {
      if (name === '@kit.BasicServicesKit') return { usbManager: usb };
      if (name === '@kit.CoreFileKit') return { fileIo: {
        statSync: () => { throw Error('stat must not be called on USB fd'); },
        closeSync: fd => calls.push(['closeFd', fd])
      } };
      if (name === 'libmpvnative.so') return { checkUsbFileDescriptor: value => {
        assert.equal(value, fd); calls.push('check'); return errno;
      } };
      if (name === 'salmonlogger') return { salmonLogger: { addLog: (_, message) => logs.push(message) } };
      return { default: { getStringResource: id => id } };
    } });
  return { session: new exports.UsbAudioSession(), calls, logs, usb };
}
(async () => {
  let f = fixture();
  assert.equal(await f.session.open(''), 42);
  assert.equal(await f.session.open(''), 42);
  f.session.close(); f.session.close();
  assert.deepEqual(f.calls, ['check', ['closeFd', 42], 'closePipe']);
  for (const fd of [-1, 88080488]) {
    f = fixture(fd, 9);
    await assert.rejects(f.session.open(''), /usb_native_permission_failed/);
    assert.deepEqual(f.calls, ['check', 'closePipe']);
    assert.equal(f.session.descriptor, -1);
    assert.ok(f.logs.some(log => log.includes('errno=9')));
  }
  f = fixture();
  let authorize;
  f.usb.hasRight = () => false;
  f.usb.requestRight = () => new Promise(resolve => { authorize = resolve; });
  const pending = f.session.open('');
  f.session.close(); authorize(true);
  await assert.rejects(pending, /usb_connection_cancelled/);
  assert.deepEqual(f.calls, []);
  console.log('PASS USB descriptor: metadata denied, invalid fd, cleanup, cancellation');
})().catch(error => { console.error(error); process.exitCode = 1; });
