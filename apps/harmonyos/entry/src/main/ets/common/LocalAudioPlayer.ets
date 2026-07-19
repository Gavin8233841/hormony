import { media } from '@kit.MediaKit';
import { resourceManager } from '@kit.LocalizationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Constants } from './Constants';

export type LocalAudioPlaybackState =
  'idle' | 'loading' | 'ready' | 'playing' | 'paused' | 'completed' | 'failed' | 'released';

export type LocalAudioFailurePoint = 'none' | 'open' | 'create' | 'prepare' | 'play' | 'pause';

export interface LocalAudioSnapshot {
  state: LocalAudioPlaybackState;
  message: string;
  currentTimeMs: number;
  durationMs: number;
}

export type LocalAudioSnapshotCallback = (snapshot: LocalAudioSnapshot) => void;

export interface LocalAudioPlayerOptions {
  failurePoint: LocalAudioFailurePoint;
}

const DEFAULT_OPTIONS: LocalAudioPlayerOptions = {
  failurePoint: 'none'
};

export class LocalAudioPlayer {
  private manager: resourceManager.ResourceManager;
  private onSnapshot: LocalAudioSnapshotCallback;
  private options: LocalAudioPlayerOptions;
  private player: media.AVPlayer | null = null;
  private rawFilePath: string = '';
  private rawFdOpen: boolean = false;
  private generation: number = 0;
  private operationPending: boolean = false;
  private playbackState: LocalAudioPlaybackState = 'idle';
  private statusMessage: string = '本地音频已就绪，播放不需要网络';
  private currentTimeMs: number = 0;
  private durationMs: number = 0;
  private initializedResolve: (() => void) | null = null;
  private initializedReject: ((reason: Error) => void) | null = null;
  private initializedTimeoutId: number = -1;
  private stateChangeCallback: ((state: media.AVPlayerState, reason: media.StateChangeReason) => void) | null = null;
  private errorCallback: ((error: Error) => void) | null = null;
  private timeUpdateCallback: ((timeMs: number) => void) | null = null;

  constructor(manager: resourceManager.ResourceManager, onSnapshot: LocalAudioSnapshotCallback,
    options: LocalAudioPlayerOptions = DEFAULT_OPTIONS) {
    this.manager = manager;
    this.onSnapshot = onSnapshot;
    this.options = options;
    this.publish();
  }

  getState(): LocalAudioPlaybackState {
    return this.playbackState;
  }

  async toggle(rawFilePath: string): Promise<void> {
    if (this.operationPending || this.playbackState === 'released') return;
    if (this.player === null || this.playbackState === 'idle' || this.playbackState === 'failed') {
      await this.start(rawFilePath);
      return;
    }
    if (this.playbackState === 'playing') {
      await this.pause();
      return;
    }
    if (this.playbackState === 'ready' || this.playbackState === 'paused' ||
      this.playbackState === 'completed') {
      await this.play();
    }
  }

  async retry(rawFilePath: string): Promise<void> {
    if (this.operationPending || this.playbackState === 'released') return;
    this.operationPending = true;
    await this.releaseResources();
    this.playbackState = 'idle';
    this.statusMessage = '正在重新打开本地音频';
    this.currentTimeMs = 0;
    this.durationMs = 0;
    this.publish();
    this.operationPending = false;
    await this.start(rawFilePath);
  }

  async release(): Promise<void> {
    if (this.playbackState === 'released') return;
    this.generation += 1;
    this.operationPending = true;
    this.playbackState = 'released';
    this.statusMessage = '本地音频播放器已释放';
    this.currentTimeMs = 0;
    this.durationMs = 0;
    this.publish();
    this.rejectInitialized(new Error('本地音频已离开'));
    await this.releaseResources();
    this.operationPending = false;
    hilog.info(Constants.HILOG_DOMAIN, Constants.HILOG_TAG, 'LocalAudio released');
  }

  private async start(rawFilePath: string): Promise<void> {
    if (rawFilePath.length === 0) {
      await this.fail(new Error('本地音频路径为空'), this.generation);
      return;
    }
    this.operationPending = true;
    const token = this.generation + 1;
    this.generation = token;
    this.playbackState = 'loading';
    this.statusMessage = '正在准备本地音频';
    this.currentTimeMs = 0;
    this.durationMs = 0;
    this.publish();
    try {
      this.throwIfInjected('open');
      const rawFile = await this.manager.getRawFd(rawFilePath);
      if (token !== this.generation) {
        await this.manager.closeRawFd(rawFilePath);
        return;
      }
      this.rawFilePath = rawFilePath;
      this.rawFdOpen = true;

      this.throwIfInjected('create');
      const player = await media.createAVPlayer();
      if (token !== this.generation) {
        await player.release();
        await this.closeRawFd();
        return;
      }
      this.player = player;
      this.registerCallbacks(player, token);
      const initialized = this.waitForInitialized(token);
      const source: media.AVFileDescriptor = {
        fd: rawFile.fd,
        offset: rawFile.offset,
        length: rawFile.length
      };
      player.fdSrc = source;
      await initialized;
      if (token !== this.generation) return;

      this.throwIfInjected('prepare');
      await player.prepare();
      if (token !== this.generation) return;
      this.durationMs = Math.max(0, player.duration);
      this.playbackState = 'ready';
      this.statusMessage = '本地音频已准备';
      this.publish();
      this.operationPending = false;
      await this.play();
    } catch (error) {
      if (token === this.generation) {
        const normalized = error instanceof Error ? error : new Error(String(error));
        await this.fail(normalized, token);
      }
    } finally {
      if (token === this.generation) this.operationPending = false;
    }
  }

  private async play(): Promise<void> {
    if (this.player === null || this.operationPending) return;
    const token = this.generation;
    this.operationPending = true;
    try {
      this.throwIfInjected('play');
      await this.player.play();
    } catch (error) {
      if (token === this.generation) {
        const normalized = error instanceof Error ? error : new Error(String(error));
        await this.fail(normalized, token);
      }
    } finally {
      if (token === this.generation) this.operationPending = false;
    }
  }

  private async pause(): Promise<void> {
    if (this.player === null || this.operationPending || this.playbackState !== 'playing') return;
    const token = this.generation;
    this.operationPending = true;
    try {
      this.throwIfInjected('pause');
      await this.player.pause();
    } catch (error) {
      if (token === this.generation) {
        const normalized = error instanceof Error ? error : new Error(String(error));
        await this.fail(normalized, token);
      }
    } finally {
      if (token === this.generation) this.operationPending = false;
    }
  }

  private registerCallbacks(player: media.AVPlayer, token: number): void {
    this.stateChangeCallback = (state: media.AVPlayerState, _reason: media.StateChangeReason): void => {
      this.handleStateChange(token, state);
    };
    this.errorCallback = (error: Error): void => {
      this.fail(error, token).catch((cleanupError: Error): void => {
        hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
          'LocalAudio error cleanup failed: %{public}s', cleanupError.message);
      });
    };
    this.timeUpdateCallback = (timeMs: number): void => {
      if (token !== this.generation || this.playbackState === 'released') return;
      this.currentTimeMs = Math.max(0, timeMs);
      this.publish();
    };
    player.on('stateChange', this.stateChangeCallback);
    player.on('error', this.errorCallback);
    player.on('timeUpdate', this.timeUpdateCallback);
  }

  private handleStateChange(token: number, state: media.AVPlayerState): void {
    if (token !== this.generation || this.playbackState === 'released') return;
    if (state === 'initialized') {
      this.resolveInitialized();
      return;
    }
    if (state === 'prepared') {
      this.durationMs = this.player === null ? 0 : Math.max(0, this.player.duration);
      this.playbackState = 'ready';
      this.statusMessage = '本地音频已准备';
    } else if (state === 'playing') {
      this.playbackState = 'playing';
      this.statusMessage = '正在播放本地音频';
    } else if (state === 'paused') {
      this.playbackState = 'paused';
      this.statusMessage = '已暂停，可继续播放';
    } else if (state === 'completed') {
      this.playbackState = 'completed';
      this.statusMessage = '播放完成，可重播或显示静态文本';
      this.currentTimeMs = this.durationMs;
    } else if (state === 'error') {
      this.fail(new Error('AVPlayer 进入 error 状态'), token).catch((cleanupError: Error): void => {
        hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
          'LocalAudio state cleanup failed: %{public}s', cleanupError.message);
      });
      return;
    } else {
      return;
    }
    this.publish();
    hilog.info(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
      'LocalAudio state %{public}s', this.playbackState);
  }

  private waitForInitialized(token: number): Promise<void> {
    return new Promise<void>((resolve: () => void, reject: (reason: Error) => void): void => {
      this.initializedResolve = resolve;
      this.initializedReject = reject;
      this.initializedTimeoutId = setTimeout((): void => {
        if (token !== this.generation || this.initializedReject === null) return;
        const timeoutReject = this.initializedReject;
        this.clearInitializedWaiter();
        timeoutReject(new Error('本地音频初始化超时'));
      }, 5000);
    });
  }

  private resolveInitialized(): void {
    if (this.initializedResolve === null) return;
    const resolve = this.initializedResolve;
    this.clearInitializedWaiter();
    resolve();
  }

  private rejectInitialized(error: Error): void {
    if (this.initializedReject === null) return;
    const reject = this.initializedReject;
    this.clearInitializedWaiter();
    reject(error);
  }

  private clearInitializedWaiter(): void {
    if (this.initializedTimeoutId >= 0) clearTimeout(this.initializedTimeoutId);
    this.initializedTimeoutId = -1;
    this.initializedResolve = null;
    this.initializedReject = null;
  }

  private async fail(error: Error, token: number): Promise<void> {
    if (token !== this.generation || this.playbackState === 'released') return;
    this.generation += 1;
    this.operationPending = true;
    this.rejectInitialized(error);
    await this.releaseResources();
    this.operationPending = false;
    this.playbackState = 'failed';
    this.statusMessage = '本地音频加载失败，请重试';
    this.currentTimeMs = 0;
    this.durationMs = 0;
    this.publish();
    hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
      'LocalAudio failed: %{public}s', error.message);
  }

  private async releaseResources(): Promise<void> {
    const player = this.player;
    this.player = null;
    if (player !== null) {
      try {
        if (this.stateChangeCallback !== null) player.off('stateChange', this.stateChangeCallback);
        if (this.errorCallback !== null) player.off('error', this.errorCallback);
        if (this.timeUpdateCallback !== null) player.off('timeUpdate', this.timeUpdateCallback);
      } catch (error) {
        hilog.warn(Constants.HILOG_DOMAIN, Constants.HILOG_TAG, 'LocalAudio listener cleanup failed');
      }
      try {
        if (player.state !== 'released') await player.release();
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        hilog.warn(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
          'LocalAudio player release failed: %{public}s', message);
      }
    }
    this.stateChangeCallback = null;
    this.errorCallback = null;
    this.timeUpdateCallback = null;
    await this.closeRawFd();
  }

  private async closeRawFd(): Promise<void> {
    if (!this.rawFdOpen || this.rawFilePath.length === 0) return;
    const path = this.rawFilePath;
    try {
      await this.manager.closeRawFd(path);
      this.rawFdOpen = false;
      this.rawFilePath = '';
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      hilog.warn(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'LocalAudio raw fd close failed: %{public}s', message);
    }
  }

  private throwIfInjected(point: LocalAudioFailurePoint): void {
    if (this.options.failurePoint === point) {
      throw new Error('注入本地音频失败点: ' + point);
    }
  }

  private publish(): void {
    const snapshot: LocalAudioSnapshot = {
      state: this.playbackState,
      message: this.statusMessage,
      currentTimeMs: this.currentTimeMs,
      durationMs: this.durationMs
    };
    this.onSnapshot(snapshot);
  }
}
