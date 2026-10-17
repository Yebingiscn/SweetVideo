const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.env.TYPESCRIPT_MODULE);
const compile = s => ts.transpileModule(s, { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020
} }).outputText;
function audioFixture(mode, dsd = 0, hardware = false) {
  const calls = [], notices = [];
  const Setting = { mpvUsbExclusive: true, mpvUsbVolumeMode: mode, mpvUsbDsdMode: dsd, mpvUsbDevice: 'dac' };
  const state = { usbExclusiveActive: false };
  const exports = {};
  class Session { close() {} }
  vm.runInNewContext(compile(fs.readFileSync('entry/src/main/ets/controller/MpvController/MpvAudioController.ets', 'utf8')), {
    exports, $r: id => ({ id }), require: name => {
      if (name === 'libmpvnative.so') return { command: (_, args) => {
        calls.push(Array.from(args)); return { success: args[1] !== 'ao-volume' || hardware };
      } };
      if (name.endsWith('/ObservedUtil')) return { Setting };
      if (name.endsWith('/UsbAudioSession')) return { UsbAudioSession: Session };
      if (name.endsWith('/AudioEffectInterface')) return { AudioEffectConfig: class {} };
      if (name === 'salmonlogger') return { salmonLogger: { addLog() {} } };
      return { default: { showToast: s => notices.push(s), getStringResource: id => id } };
    }
  });
  const audio = new exports.MpvAudioController(state, { handle: null }, () => 1, () => 1);
  audio.updatePreferences(() => {});
  audio.engine.handle = 1;
  audio.configureUsbOutput(42);
  audio.initializeUsbVolume();
  calls.length = 0;
  return { audio, calls, notices };
}
let f = audioFixture(0);
assert.equal(f.audio.changeUsbVolume(-5), true);
assert.deepEqual(f.calls, [['set', 'volume', '45']]);
f = audioFixture(0, 0, true);
f.audio.changeUsbVolume(5);
assert.deepEqual(f.calls, [['set', 'ao-volume', '55']]);
f = audioFixture(2, 0, true);
f.audio.changeUsbVolume(-5);
assert.deepEqual(f.calls, [['set', 'volume', '45']]);
for (const [mode, dsd] of [[3, 0], [1, 0], [0, 1], [2, 2]]) {
  f = audioFixture(mode, dsd);
  assert.equal(f.audio.changeUsbVolume(-5), false);
  assert.deepEqual(f.calls, []);
}
f = audioFixture(2); f.audio.changeUsbVolume(-1000); f.audio.changeUsbVolume(1000);
assert.deepEqual(f.calls, [['set', 'volume', '0'], ['set', 'volume', '100']]);

const source = fs.readFileSync('entry/src/main/ets/controller/MpvController/MpvController.ets', 'utf8');
const ast = ts.createSourceFile('controller.ts', source, ts.ScriptTarget.Latest, true);
const cls = ast.statements.find(n => ts.isClassDeclaration(n) && n.members.some(m => m.name?.getText(ast) === 'recoverUsbPlayback'));
const method = cls.members.find(m => m.name?.getText(ast) === 'recoverUsbPlayback').getText(ast);
async function recovery(stale = false, pause = false) {
  const exports = {}, calls = [];
  vm.runInNewContext(compile(`class Subject { ${method} }; exports.Subject = Subject`), {
    exports, TAG: 'test', salmonLogger: { addLog() {} }, MpvPlayerState: { PAUSED: 'pause', LOADING: 'load' }
  });
  const s = new exports.Subject();
  Object.assign(s, { playRequestGeneration: 3, usbExclusiveActive: true, playTime: 39000,
    nowPlaying: { uri: 'video' }, isInState: () => pause,
    engineAdapter: { invalidateLoad() {}, load: (...args) => calls.push(args) },
    restoreOrdinaryAudioOutput: () => { s.usbExclusiveActive = false; },
    cancelDecodingModeTimers() {}, transitionTo() {}, configureNetworkStateSubscription() {},
    getData: async () => { if (stale) s.playRequestGeneration++; },
    applyAutoDeinterlace() {}, applyDecoderVrrPolicy() {},
    audioEffectConfig: { effect: 'off' },
    audioController: { applyAudioPassthrough: () => true, applyAudioCoverMode() {} },
    preparePlayUrl: uri => uri, getInitialSubtitleTrackId: () => 2,
    smbPlayback: { headers: () => undefined }, subtitleController: { applySubtitleStyle() {} },
    handleLoadFailure: () => { throw Error('unexpected load failure'); }
  });
  await s.recoverUsbPlayback(); await s.recoverUsbPlayback();
  assert.equal(calls.length, stale ? 0 : 1);
  if (!stale) assert.deepEqual(calls[0], ['video', 39, 2, undefined, undefined]);
  assert.equal(s.initialPlaying, !pause);
}
Promise.all([recovery(), recovery(true), recovery(false, true)]).then(() => {
  console.log('PASS USB volume modes, DSD protection, limits, one-shot recovery, resume position/pause and cancellation');
}).catch(e => { console.error(e); process.exitCode = 1; });
