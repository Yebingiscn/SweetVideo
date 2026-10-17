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
  return { audio, calls, notices, state, setHardware: v => { hardware = v; } };
}
let f = audioFixture(0);
assert.equal(f.audio.changeUsbVolume(-5), true);
assert.deepEqual(f.calls, [['set', 'ao-volume', '50'], ['set', 'volume', '45']]);
assert.equal(f.state.usbVolume, 45);
f.calls.length = 0;
f.audio.setUsbVolume(31);
assert.deepEqual(f.calls, [['set', 'volume', '31']]); // no hardware retry for each slider tick
assert.equal(f.state.usbVolume, 31);
f = audioFixture(0); f.setHardware(true); f.audio.setUsbVolume(20);
assert.deepEqual(f.calls, [['set', 'ao-volume', '50'], ['set', 'volume', '100'], ['set', 'ao-volume', '20']]);
assert.equal(f.state.usbVolume, 20);
f = audioFixture(0, 0, true);
f.audio.changeUsbVolume(5);
assert.deepEqual(f.calls, [['set', 'ao-volume', '55']]);
f = audioFixture(2, 0, true);
f.audio.changeUsbVolume(-5);
assert.deepEqual(f.calls, [['set', 'volume', '45']]);
for (const [mode, dsd] of [[3, 0], [1, 0], [0, 1], [2, 2]]) {
  f = audioFixture(mode, dsd);
  assert.equal(f.audio.changeUsbVolume(-5), false);
  assert.deepEqual(f.calls, mode === 3 ? [] : [['set', 'ao-volume', '50']]);
}
f = audioFixture(2); f.audio.changeUsbVolume(-1000); f.audio.changeUsbVolume(1000);
assert.deepEqual(f.calls, [['set', 'volume', '0'], ['set', 'volume', '100']]);
f.calls.length = 0;
assert.equal(f.audio.setUsbVolume(NaN), false);
assert.deepEqual(f.calls, []);

const source = fs.readFileSync('entry/src/main/ets/controller/MpvController/MpvController.ets', 'utf8');
const ast = ts.createSourceFile('controller.ts', source, ts.ScriptTarget.Latest, true);
const cls = ast.statements.find(n => ts.isClassDeclaration(n) && n.members.some(m => m.name?.getText(ast) === 'recoverUsbPlayback'));
const method = cls.members.find(m => m.name?.getText(ast) === 'recoverUsbPlayback').getText(ast);
function interruptFixture(usb = true) {
  const exports = {}, handlers = {}, calls = [];
  const session = {
    on: (name, callback) => { handlers[name] = callback; },
    isAudioSessionActivated: () => false,
    activateAudioSession: async () => { calls.push('activate'); }
  };
  const methods = ['registerAudioInterruptListener', 'reactivateAudioSessionIfNeeded'].map(name =>
    cls.members.find(m => m.name?.getText(ast) === name).getText(ast)).join('\n');
  const hints = Object.fromEntries(['RESUME', 'PAUSE', 'STOP', 'TIME_OUT_STOP', 'DUCK', 'UNDUCK'].map(x =>
    ['AUDIO_SESSION_STATE_CHANGE_HINT_' + x, x]));
  vm.runInNewContext(compile(`class Subject { ${methods} }; exports.Subject = Subject`), {
    exports, TAG: 'test', salmonLogger: { addLog() {} }, canIUse: () => false,
    Setting: { allowConcurrentPlay: false },
    MpvPlayerState: { RELEASING: 'releasing', IDLE: 'idle', PAUSED: 'paused' },
    audio: { getAudioManager: () => ({ getSessionManager: () => session }),
      AudioSessionDeactivatedReason: { DEACTIVATED_TIMEOUT: 1 },
      AudioSessionStateChangeHint: hints, AudioConcurrencyMode: { CONCURRENCY_DEFAULT: 0 } }
  });
  const s = new exports.Subject();
  Object.assign(s, { usbExclusiveActive: usb, playing: true, isInState: state => s.status === state,
    pause: () => calls.push('pause'), pausePlayback: () => calls.push('pausePlayback'),
    audioPauseGuard: { interrupt: () => calls.push('interrupt') },
    decodingRecovery: { getPlaybackIntentForModeSwitch: () => true } });
  s.registerAudioInterruptListener();
  return { s, calls, handlers };
}
for (const usb of [true, false]) {
  const t = interruptFixture(usb);
  t.handlers.audioSessionDeactivated({ reason: 1 });
  assert.deepEqual(t.calls, [usb ? 'activate' : 'pause']);
  t.calls.length = 0;
  t.handlers.audioSessionStateChanged({ stateChangeHint: 'TIME_OUT_STOP' });
  assert.deepEqual(t.calls, [usb ? 'activate' : 'pause']);
  t.calls.length = 0;
  t.handlers.audioSessionDeactivated({ reason: 0 });
  t.handlers.audioSessionStateChanged({ stateChangeHint: 'STOP' });
  t.handlers.audioSessionStateChanged({ stateChangeHint: 'PAUSE' });
  assert.deepEqual(t.calls, ['pause', 'pause', 'interrupt', 'pausePlayback']);
  t.calls.length = 0; t.s.status = 'releasing';
  t.handlers.audioSessionDeactivated({ reason: 1 });
  assert.deepEqual(t.calls, []);
}
const pausedUsb = interruptFixture(); pausedUsb.s.playing = false;
pausedUsb.handlers.audioSessionDeactivated({ reason: 1 });
assert.deepEqual(pausedUsb.calls, []);
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
