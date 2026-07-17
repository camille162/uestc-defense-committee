'use client';
import { useEffect, useRef, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import {
  startRound, stt, sttStream, submitAnswer, getDetail, endInterview, getQuestion,
  fileUrl, Question, Round, backendLog, SttStreamHandle,
} from '@/lib/api';
import InterviewerAvatar from '@/components/InterviewerAvatar';

type Turn = {
  question: Question;
  answer?: string;
  score?: number;
  comment?: string;
};

type MicState = 'idle' | 'listening' | 'countdown' | 'paused';

// End-of-answer detection thresholds.
const SILENCE_MS = 12000;     // 12s 静音开始倒计时
const COUNTDOWN_MS = 4000;    // 4s 倒计时自动提交
const VOLUME_THRESHOLD = 0.008;

function getSpeechRecognition(): any {
  if (typeof window === 'undefined') return null;
  return (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition || null;
}

export default function InterviewPage() {
  const params = useParams();
  const router = useRouter();
  const interviewId = Number(params.id);

  const [round, setRound] = useState<Round | null>(null);
  const [currentQ, setCurrentQ] = useState<Question | null>(null);
  const [turns, setTurns] = useState<Turn[]>([]);
  const [transcript, setTranscript] = useState('');
  const [interimText, setInterimText] = useState('');
  const [micState, setMicState] = useState<MicState>('idle');
  const [countdownLeft, setCountdownLeft] = useState(0);
  const [volume, setVolume] = useState(0);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [roundEnd, setRoundEnd] = useState<{ passed: boolean; feedback: string; interview_status: string } | null>(null);
  const [audioReady, setAudioReady] = useState(false);
  const [needGesture, setNeedGesture] = useState(false);
  const [ttsFailed, setTtsFailed] = useState(false);
  const [waitingForClick, setWaitingForClick] = useState(true);

  const audioRef = useRef<HTMLAudioElement | null>(null);
  const cameraStreamRef = useRef<MediaStream | null>(null);
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const startedRef = useRef(false);
  const submittingRef = useRef(false);
  const finalAccumRef = useRef<string>(''); // 修复缺失定义

  // 语音识别、录音、流式ASR
  const recognitionRef = useRef<any>(null);
  const mrRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const useWebSpeechRef = useRef<boolean>(false);
  const sttStreamRef = useRef<SttStreamHandle | null>(null);
  const sttReadyRef = useRef<boolean>(false);

  // 音量VAD、音频上下文、定时器、动画帧
  const micStreamRef = useRef<MediaStream | null>(null);
  const audioCtxRef = useRef<AudioContext | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const pcmNodeRef = useRef<ScriptProcessorNode | null>(null);
  const rafRef = useRef<number | null>(null);
  const lastVoiceAtRef = useRef<number>(Date.now());
  const silenceTimerRef = useRef<any>(null);
  const countdownTimerRef = useRef<any>(null);
  const transcriptRef = useRef<string>('');
  const currentQIdRef = useRef<number | null>(null);
  const micStateRef = useRef<MicState>('idle');

  useEffect(() => { transcriptRef.current = transcript; }, [transcript]);
  useEffect(() => { currentQIdRef.current = currentQ?.id ?? null; }, [currentQ?.id]);
  useEffect(() => { micStateRef.current = micState; }, [micState]);

  useEffect(() => {
    useWebSpeechRef.current = !!getSpeechRecognition();
  }, []);

  // 页面初始化 + 完整卸载销毁所有媒体资源（根治卡死内存泄漏）
  useEffect(() => {
    if (startedRef.current) return;
    startedRef.current = true;
    (async () => {
      try {
        setBusy(true);
        const detail = await getDetail(interviewId);
        const runningRound = detail.rounds?.find((r: any) => r.status === 'running');
        if (runningRound) {
          const unanswered = runningRound.questions.find((q: any) => !q.answer);
          if (unanswered) {
            setRound(runningRound);
            setCurrentQ({
              id: unanswered.id, seq: unanswered.seq, topic: unanswered.topic,
              question_text: unanswered.question_text, is_followup: unanswered.is_followup,
              tts_url: unanswered.tts_url,
            });
            setTurns(runningRound.questions
              .filter((qq: any) => qq.answer)
              .map((qq: any) => ({
                question: {
                  id: qq.id, seq: qq.seq, topic: qq.topic, question_text: qq.question_text,
                  is_followup: qq.is_followup, tts_url: qq.tts_url,
                },
                answer: qq.answer || undefined,
                score: qq.score || undefined,
                comment: qq.score_comment || undefined,
              })));
            return;
          }
        }
        const data = await startRound(interviewId);
        setRound(data.round);
        setCurrentQ(data.question);
        setTurns([{ question: data.question }]);
      } catch (e: any) {
        setError(e.message);
      } finally { setBusy(false); }
    })();

    // 页面完全卸载：销毁麦克风、WS、音频、摄像头、定时器、动画帧、音频上下文
    return () => {
      cleanupMic();
      // 销毁摄像头视频流
      if (cameraStreamRef.current) {
        cameraStreamRef.current.getTracks().forEach(t => t.stop());
        cameraStreamRef.current = null;
      }
      // 销毁音频播放器，释放媒体线程
      const audio = audioRef.current;
      if (audio) {
        audio.pause();
        audio.onended = null;
        audio.src = '';
      }
      // 取消音量监控动画帧
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
      // 清空所有定时轮询
      if (silenceTimerRef.current) clearInterval(silenceTimerRef.current);
      if (countdownTimerRef.current) clearInterval(countdownTimerRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [interviewId]);

  // 轮询等待TTS语音合成地址
  useEffect(() => {
    setTtsFailed(false);
    if (!currentQ || currentQ.tts_url) return;
    let stopped = false;
    let attempts = 0;
    const tick = async () => {
      if (stopped) return;
      if (attempts++ > 20) { setTtsFailed(true); return; }
      try {
        const q = await getQuestion(interviewId, currentQ.id);
        if (q.tts_url) {
          setCurrentQ(cur => (cur && cur.id === q.id ? { ...cur, tts_url: q.tts_url } : cur));
          return;
        }
        if (q.tts_failed) { setTtsFailed(true); return; }
      } catch {}
      setTimeout(tick, 1500);
    };
    tick();
    return () => { stopped = true; };
  }, [currentQ?.id, currentQ?.tts_url, interviewId]);

  // 切换题目：先销毁旧音频再加载新语音，防止多音频阻塞主线程
  useEffect(() => {
    if (!currentQ?.tts_url || !audioRef.current) return;
    if (waitingForClick) return;
    setTranscript('');
    setInterimText('');
    finalAccumRef.current = '';
    setMicState('idle');
    cleanupMic();

    const a = audioRef.current;
    // 先清空旧音频资源，避免媒体线程堆积
    a.pause();
    a.onended = null;
    a.src = '';
    a.src = fileUrl(currentQ.tts_url) || '';

    const onEnded = () => {
      if (currentQIdRef.current === currentQ.id && !roundEnd) {
        startListening();
      }
    };
    a.onended = onEnded;

    a.play().catch(() => {
      setNeedGesture(true);
    });

    return () => {
      a.onended = null;
      // 离开当前题目强制释放音频
      a.pause();
      a.src = '';
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentQ?.tts_url, currentQ?.id, waitingForClick]);

  // TTS合成失败，直接开启录音，不卡死等待语音
  useEffect(() => {
    if (!ttsFailed || !currentQ || currentQ.tts_url) return;
    if (waitingForClick) return;
    setTranscript('');
    setInterimText('');
    finalAccumRef.current = '';
    setNeedGesture(false);
    cleanupMic();
    if (currentQIdRef.current === currentQ.id && !roundEnd) {
      startListening();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ttsFailed, currentQ?.tts_url, currentQ?.id, waitingForClick]);

  // 音频播放时暂停麦克风，防止杂音混入录音
  useEffect(() => {
    const a = audioRef.current;
    if (!a) return;
    const onPlay = () => {
      if (micStateRef.current === 'listening' || micStateRef.current === 'countdown') {
        cleanupMic();
      }
    };
    a.addEventListener('play', onPlay);
    return () => { a.removeEventListener('play', onPlay); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [audioReady]);

  // ---------- 麦克风录音、实时转写核心逻辑 ----------
  async function startListening() {
    if (micStateRef.current !== 'idle' && micStateRef.current !== 'paused') return;
    setError(null);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      micStreamRef.current = stream;

      // 初始化音频上下文做音量检测VAD
      const AC = (window as any).AudioContext || (window as any).webkitAudioContext;
      const ctx = new AC();
      audioCtxRef.current = ctx;
      const source = ctx.createMediaStreamSource(stream);
      const analyser = ctx.createAnalyser();
      analyser.fftSize = 512;
      source.connect(analyser);
      analyserRef.current = analyser;

      lastVoiceAtRef.current = Date.now();
      monitorVolume();
      startSilenceWatcher();

      // 本地录音容器
      const mimeType = MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
        ? 'audio/webm;codecs=opus'
        : 'audio/webm';
      const mr = new MediaRecorder(stream, { mimeType });
      chunksRef.current = [];

      // 初始化火山引擎实时流式ASR
      try {
        const streamHandle = sttStream(
          (interim) => { setInterimText(interim); },
          (_err) => { /* 静默降级为POST上传 */ },
        );
        sttStreamRef.current = streamHandle;
        sttReadyRef.current = false;
        setTimeout(() => { sttReadyRef.current = true; }, 200);

        // PCM原始音频下采样发送WebSocket
        const inRate = ctx.sampleRate;
        const targetRate = 16000;
        const node = ctx.createScriptProcessor(4096, 1, 1);
        node.onaudioprocess = (ev: AudioProcessingEvent) => {
          if (!sttStreamRef.current || !sttReadyRef.current) return;
          const input = ev.inputBuffer.getChannelData(0);
          const ratio = inRate / targetRate;
          const outLen = Math.floor(input.length / ratio);
          const pcm = new Int16Array(outLen);
          for (let i = 0; i < outLen; i++) {
            const s = input[Math.floor(i * ratio)];
            const clamped = Math.max(-1, Math.min(1, s));
            pcm[i] = clamped < 0 ? clamped * 0x8000 : clamped * 0x7fff;
          }
          sttStreamRef.current.send(new Blob([pcm.buffer]));
        };
        source.connect(node);
        node.connect(ctx.destination);
        pcmNodeRef.current = node;
      } catch {
        sttStreamRef.current = null;
      }

      mr.ondataavailable = e => {
        if (e.data && e.data.size > 0) {
          chunksRef.current.push(e.data);
        }
      };
      mrRef.current = mr;
      mr.start(1000);

      setMicState('listening');
    } catch (e: any) {
      setError('无法访问麦克风：' + e.message);
      setMicState('idle');
    }
  }

  function stopRecorderAndGetBlob(): Promise<Blob | null> {
    return new Promise(resolve => {
      const mr = mrRef.current;
      if (!mr || mr.state === 'inactive') {
        const blob = chunksRef.current.length ? new Blob(chunksRef.current, { type: 'audio/webm' }) : null;
        resolve(blob);
        return;
      }
      mr.onstop = () => {
        const blob = chunksRef.current.length ? new Blob(chunksRef.current, { type: 'audio/webm' }) : null;
        resolve(blob);
      };
      try { mr.stop(); } catch { resolve(null); }
    });
  }

  function monitorVolume() {
    const analyser = analyserRef.current;
    if (!analyser) return;
    const buf = new Uint8Array(analyser.fftSize);
    const loop = () => {
      analyser.getByteTimeDomainData(buf);
      let sum = 0;
      for (let i = 0; i < buf.length; i++) {
        const v = (buf[i] - 128) / 128;
        sum += v * v;
      }
      const rms = Math.sqrt(sum / buf.length);
      setVolume(rms);
      if (rms > VOLUME_THRESHOLD) {
        lastVoiceAtRef.current = Date.now();
        cancelCountdown();
      }
      rafRef.current = requestAnimationFrame(loop);
    };
    rafRef.current = requestAnimationFrame(loop);
  }

  function startSilenceWatcher() {
    if (silenceTimerRef.current) clearInterval(silenceTimerRef.current);
    silenceTimerRef.current = setInterval(() => {
      if (micStateRef.current !== 'listening') return;
      const idle = Date.now() - lastVoiceAtRef.current;
      const hasAudio = chunksRef.current.length > 1;
      if (idle >= SILENCE_MS && hasAudio) {
        beginCountdown();
      }
    }, 300);
  }

  function beginCountdown() {
    if (micStateRef.current === 'countdown') return;
    setMicState('countdown');
    let left = COUNTDOWN_MS;
    setCountdownLeft(left);
    countdownTimerRef.current = setInterval(() => {
      left -= 100;
      setCountdownLeft(Math.max(left, 0));
      if (left <= 0) {
        clearInterval(countdownTimerRef.current);
        countdownTimerRef.current = null;
        autoSubmit();
      }
    }, 100);
  }

  function cancelCountdown() {
    if (countdownTimerRef.current) {
      clearInterval(countdownTimerRef.current);
      countdownTimerRef.current = null;
    }
    if (micStateRef.current === 'countdown') {
      setMicState('listening');
      setCountdownLeft(0);
    }
  }

  function pauseListening() {
    try { recognitionRef.current?.stop?.(); } catch {}
    try { mrRef.current?.stop?.(); } catch {}
    if (silenceTimerRef.current) clearInterval(silenceTimerRef.current);
    if (countdownTimerRef.current) clearInterval(countdownTimerRef.current);
    if (rafRef.current) cancelAnimationFrame(rafRef.current);
    micStreamRef.current?.getTracks().forEach(t => t.stop());
    audioCtxRef.current?.close().catch(() => {});
    setMicState('paused');
  }

  // 完整销毁麦克风、WS、音频上下文、定时器、动画帧（根治卡死核心函数）
  function cleanupMic() {
    try { recognitionRef.current?.abort?.(); } catch {}
    try { mrRef.current?.stop?.(); } catch {}

    // 断开PCM音频处理节点，释放主线程计算压力
    if (pcmNodeRef.current) {
      try { pcmNodeRef.current.disconnect(); } catch {}
      pcmNodeRef.current.onaudioprocess = null;
      pcmNodeRef.current = null;
    }

    // 关闭实时语音WebSocket流，清空句柄
    if (sttStreamRef.current) {
      try { sttStreamRef.current.close(); } catch {}
      sttStreamRef.current = null;
    }
    sttReadyRef.current = false;
    recognitionRef.current = null;
    mrRef.current = null;

    // 清空所有定时轮询
    if (silenceTimerRef.current) {
      clearInterval(silenceTimerRef.current);
      silenceTimerRef.current = null;
    }
    if (countdownTimerRef.current) {
      clearInterval(countdownTimerRef.current);
      countdownTimerRef.current = null;
    }

    // 取消音量监控动画帧
    if (rafRef.current) {
      cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
    }

    // 关闭麦克风硬件流
    if (micStreamRef.current) {
      micStreamRef.current.getTracks().forEach(t => t.stop());
      micStreamRef.current = null;
    }

    // 彻底销毁音频上下文，释放声卡资源
    if (audioCtxRef.current) {
      audioCtxRef.current.close().catch(() => {});
      audioCtxRef.current = null;
    }
    analyserRef.current = null;

    setInterimText('');
    setCountdownLeft(0);
    setVolume(0);
    setMicState('idle');
  }

  async function autoSubmit() {
    await doSubmit(true);
  }

  // 播放评委回应语音
  function playAcknowledgment(src: string): Promise<void> {
    return new Promise(resolve => {
      const a = audioRef.current;
      if (!a || !src) { resolve(); return; }
      let done = false;
      const finish = () => {
        if (done) return;
        done = true;
        a.removeEventListener('ended', finish);
        a.removeEventListener('error', finish);
        clearTimeout(timer);
        resolve();
      };
      const timer = setTimeout(finish, 6000);
      a.addEventListener('ended', finish);
      a.addEventListener('error', finish);
      a.src = src;
      a.play().catch(() => finish());
    });
  }

  // 提交答案外层锁，防止重复提交并发阻塞页面
  async function doSubmit(auto = false) {
    if (!currentQ) return;
    if (submittingRef.current) return;
    submittingRef.current = true;
    try {
      await _doSubmitInner(auto);
    } finally {
      submittingRef.current = false;
    }
  }

  async function _doSubmitInner(auto = false) {
    if (!currentQ) return;
    const typedText = (transcriptRef.current || '').trim();
    const hasRecording = mrRef.current !== null || chunksRef.current.length > 0;
    if (!typedText && !hasRecording) {
      if (auto) { cancelCountdown(); return; }
      setError('请先录音或输入回答');
      return;
    }

    setBusy(true);
    setError(null);

    let finalText = typedText;
    let answerAudioPath: string | undefined;
    const streamHandle = sttStreamRef.current;
    let usedStream = false;

    // 优先使用WebSocket实时转写结果
    if (streamHandle && streamHandle.isAlive()) {
      try {
        if (pcmNodeRef.current) {
          try { pcmNodeRef.current.disconnect(); } catch {}
          pcmNodeRef.current.onaudioprocess = null;
        }
        await new Promise<void>((resolve) => {
          const mr = mrRef.current;
          if (!mr || mr.state === 'inactive') { resolve(); return; }
          mr.onstop = () => resolve();
          try { mr.stop(); } catch { resolve(); }
        });
        await new Promise(r => setTimeout(r, 100));
        const { text, audio_path } = await streamHandle.finish();
        const streamText = (text || '').trim();
        if (streamText) finalText = streamText;
        if (audio_path) answerAudioPath = audio_path;
        usedStream = true;
      } catch (e: any) {
        console.warn('实时语音流识别失败，降级为文件上传转写', e);
      }
    }

    // 降级：上传录音文件走后端Whisper转写
    if (!usedStream) {
      try {
        const blob = await stopRecorderAndGetBlob();
        if (blob && blob.size > 1000) {
          try {
            const { text, audio_path } = await stt(blob);
            const whisperText = (text || '').trim();
            if (whisperText) finalText = whisperText;
            if (audio_path) answerAudioPath = audio_path;
          } catch (e: any) {
            console.warn('文件语音转写接口失败', e);
            if (!typedText) {
              setBusy(false);
              setError('语音转写失败，请手动输入回答后再次提交。');
              cleanupMic();
              return;
            }
            setError('语音转写失败，已使用手动输入文字提交');
          }
        }
      } finally {
        cleanupMic();
      }
    }

    if (!finalText) {
      setBusy(false);
      setError('未识别到语音内容，请重新录音或手动输入');
      return;
    }
    setTranscript(finalText);

    try {
      const res = await submitAnswer(interviewId, {
        question_id: currentQ.id,
        transcript: finalText,
        audio_path: answerAudioPath,
      });
      setTurns(prev => {
        const arr = [...prev];
        const idx = arr.findIndex(t => t.question.id === currentQ.id);
        if (idx >= 0) {
          arr[idx] = {
            ...arr[idx],
            answer: finalText,
            score: res.score?.total,
            comment: res.score?.comment,
          };
        }
        if (res.next_question) arr.push({ question: res.next_question });
        return arr;
      });
      setTranscript('');
      finalAccumRef.current = '';

      // 播放评委回应语音
      if (res.acknowledgment_audio_url) {
        await playAcknowledgment(fileUrl(res.acknowledgment_audio_url) || '');
      }

      if (res.next_question) {
        setCurrentQ(res.next_question);
      } else if (res.round_finished && res.round) {
        setCurrentQ(null);
        setRound(res.round);
        setRoundEnd({
          passed: res.round.passed,
          feedback: res.round.feedback,
          interview_status: res.interview_status || '',
        });
      }
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  // 开启摄像头
  async function enableCamera() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
      cameraStreamRef.current = stream;
      if (videoRef.current) videoRef.current.srcObject = stream;
    } catch (e: any) {
      setError('摄像头启用失败：' + e.message);
    }
  }

  // 进入下一轮答辩
  async function onNextRound() {
    setRoundEnd(null);
    setTurns([]);
    setBusy(true);
    try {
      const data = await startRound(interviewId);
      setRound(data.round);
      setCurrentQ(data.question);
      setTurns([{ question: data.question }]);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  function onSeeReport() {
    router.push(`/report/${interviewId}`);
  }

  async function onEndInterview() {
    if (!confirm('确定要结束这场答辩吗？系统会立即根据已回答的问题生成评价。')) return;
    cleanupMic();
    // 后台异步生成报告，不阻塞页面跳转
    endInterview(interviewId).catch(e => {
      console.warn('结束答辩后台任务异常', e);
    });
    router.push(`/report/${interviewId}`);
  }

  // ---------- UI渲染辅助函数 ----------
  const combined = transcript + (interimText ? (transcript ? ' ' : '') + interimText : '');
  const volumePct = Math.min(100, Math.round(volume * 300));

  // 解锁自动播放的启动遮罩
  const startOverlay = waitingForClick ? (
    <div className="fixed inset-0 flex flex-col items-center justify-center bg-white z-50 gap-6">
      <div className="text-2xl font-bold text-gray-800">准备好了吗？</div>
      <div className="text-gray-500 text-sm">点击开始，评委将立即向你提问（含语音）</div>
      <button
        className="bg-blue-600 hover:bg-blue-700 text-white px-10 py-4 rounded-xl text-lg font-semibold"
        onClick={async () => {
          setWaitingForClick(false);
          const a = audioRef.current;
          if (a && a.src && a.src !== window.location.href) {
            try { await a.play(); } catch {}
          }
        }}
      >
        开始答辩
      </button>
    </div>
  ) : null;

  return (
    <div className="space-y-4">
      {/* 评委语音播放器 */}
      <div className="bg-blue-50 border border-blue-200 rounded p-3">
        <div className="text-xs text-blue-800 mb-1">评委语音（如果没有自动播放，请点击下方播放按钮）</div>
        <audio
          ref={el => { audioRef.current = el; if (el && !audioReady) setAudioReady(true); }}
          controls
          className="w-full"
        />
      </div>
      {startOverlay}

      {needGesture && (
        <div className="bg-yellow-50 border border-yellow-300 rounded p-3 flex items-center justify-between text-sm">
          <span className="text-yellow-800">浏览器阻止了自动播放。点击按钮播放评委提问语音。</span>
          <button
            className="ml-4 bg-yellow-500 text-white px-3 py-1 rounded"
            onClick={() => { audioRef.current?.play(); setNeedGesture(false); }}
          >播放语音</button>
        </div>
      )}

      {/* 评委+摄像头区域 */}
      <div className="bg-white rounded-lg shadow p-4 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="w-40 h-32 rounded overflow-hidden border border-gray-200">
            <InterviewerAvatar audioEl={audioRef.current} role={round?.role} className="w-full h-full" />
          </div>
          <div>
            <div className="font-semibold">
              第 {round?.round_no ?? '-'} 轮 · {roleLabel(round?.role)}
            </div>
            <div className="text-sm text-gray-500">
              答辩 ID: {interviewId}
              {' · '}
              {useWebSpeechRef.current ? '实时语音识别' : '录音识别（Whisper 兜底）'}
            </div>
          </div>
        </div>
        <div className="flex gap-2 items-center">
          {!roundEnd && (
            <button onClick={onEndInterview} disabled={busy}
              className="text-sm border border-red-300 text-red-600 hover:bg-red-50 px-3 py-1 rounded disabled:opacity-50">
              结束答辩
            </button>
          )}
          {!cameraStreamRef.current && (
            <button onClick={enableCamera} className="text-sm border px-3 py-1 rounded">启用摄像头</button>
          )}
          <video ref={videoRef} autoPlay muted className="w-32 h-24 bg-black rounded" />
        </div>
      </div>

      {/* 历史问答记录 */}
      <div className="bg-white rounded-lg shadow p-4 space-y-3">
        {turns.map((t, i) => (
          <div key={t.question.id} className="border-l-4 border-blue-500 pl-3">
            <div className="text-sm text-gray-500">Q{i + 1} {t.question.is_followup && '· 追问'} · {t.question.topic}</div>
            <div className="font-medium">{t.question.question_text}</div>
            {t.answer && (
              <div className="mt-2 text-sm bg-gray-50 rounded p-2">
                <div className="text-gray-500">你的回答：</div>
                <div>{t.answer}</div>
                {typeof t.score === 'number' && (
                  <div className="mt-2 text-blue-700 text-sm border-t border-blue-100 pt-2">
                    <span className="font-semibold">得分 {t.score}</span>
                    {t.comment && (
                      <div className="mt-1 text-gray-700 whitespace-pre-wrap leading-relaxed">{t.comment}</div>
                    )}
                  </div>
                )}
              </div>
            )}
          </div>
        ))}
      </div>

      {/* 当前答题录音区域 */}
      {currentQ && !roundEnd && (
        <div className="bg-white rounded-lg shadow p-4 space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <MicIndicator state={micState} volumePct={volumePct} />
              <div className="text-sm">
                {micState === 'idle' && (currentQ.tts_url ? '评委讲完后自动开始录音…' : (ttsFailed ? '语音生成失败，请直接阅读上方问题作答…' : '语音合成中…'))}
                {micState === 'listening' && '正在录音，说完停约 12 秒会自动提交；建议答完手动点"立即提交"。'}
                {micState === 'countdown' && (
                  <span className="text-orange-600 font-medium">
                    检测到你已停止说话，{Math.ceil(countdownLeft / 1000)} 秒后自动提交…（继续说可取消）
                  </span>
                )}
                {micState === 'paused' && '已暂停自动提交。'}
              </div>
            </div>
            <div className="flex gap-2">
              {micState === 'listening' && (
                <button onClick={() => doSubmit(false)} disabled={busy}
                  className="bg-blue-600 text-white px-4 py-2 rounded disabled:opacity-50">
                  已答完，立即提交
                </button>
              )}
              {micState === 'countdown' && (
                <>
                  <button onClick={cancelCountdown}
                    className="border px-3 py-2 rounded text-sm">再想想</button>
                  <button onClick={() => doSubmit(false)}
                    className="bg-blue-600 text-white px-4 py-2 rounded">立即提交</button>
                </>
              )}
              {micState === 'paused' && (
                <button onClick={startListening}
                  className="bg-red-600 text-white px-4 py-2 rounded">继续录音</button>
              )}
              {(micState === 'listening' || micState === 'countdown') && (
                <button onClick={pauseListening}
                  className="border px-3 py-2 rounded text-sm">暂停</button>
              )}
              {currentQ.tts_url && (
                <button onClick={() => audioRef.current?.play()}
                  className="border px-3 py-2 rounded text-sm">重放问题</button>
              )}
            </div>
          </div>

          {(micState === 'idle' || micState === 'paused' || transcript) && (
            <textarea className="w-full border rounded px-3 py-2 h-32"
              value={transcript}
              onChange={e => { setTranscript(e.target.value); lastVoiceAtRef.current = Date.now(); cancelCountdown(); }}
              placeholder="录音提交后，转写结果会显示在这里。你也可以在此手动编辑或直接输入。" />
          )}
          {micState === 'listening' && (
            <div className="text-xs text-gray-500 border rounded p-3 bg-gray-50 min-h-[3rem]">
              {interimText
                ? <span className="text-gray-700">{interimText}</span>
                : '录音中… 实时转写显示在这里'}
            </div>
          )}
        </div>
      )}

      {/* 本轮结束评价面板 */}
      {roundEnd && (
        <div className="bg-white rounded-lg shadow p-4 space-y-3">
          <h2 className="text-lg font-bold">
            本轮{roundEnd.passed ? '通过' : '结束'} · 得分 {round?.score}
          </h2>
          <p className="text-gray-700 whitespace-pre-wrap">{roundEnd.feedback}</p>
          <div className="flex gap-2">
            {roundEnd.interview_status === 'round_finished' && (
              <button onClick={onNextRound}
                className="bg-blue-600 text-white px-4 py-2 rounded">进入下一轮</button>
            )}
            {(roundEnd.interview_status === 'completed' || roundEnd.interview_status === 'failed') && (
              <button onClick={onSeeReport}
                className="bg-green-600 text-white px-4 py-2 rounded">查看答辩报告</button>
            )}
          </div>
        </div>
      )}

      {busy && <div className="text-sm text-gray-500">处理中…</div>}
      {error && <div className="text-red-600 text-sm">{error}</div>}
    </div>
  );
}

// 麦克风音量指示器组件
function MicIndicator({ state, volumePct }: { state: MicState; volumePct: number }) {
  const base = 'w-12 h-12 rounded-full flex items-center justify-center transition-colors';
  const color = {
    idle: 'bg-gray-200 text-gray-500',
    listening: 'bg-red-500 text-white animate-pulse',
    countdown: 'bg-orange-500 text-white',
    paused: 'bg-yellow-300 text-yellow-900',
  }[state];
  return (
    <div className="relative">
      <div className={`${base} ${color}`}>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-6 h-6">
          <path d="M12 14a3 3 0 003-3V6a3 3 0 10-6 0v5a3 3 0 003 3z" />
          <path d="M19 11a1 1 0 10-2 0 5 5 0 01-10 0 1 1 0 10-2 0 7 7 0 006 6.92V21h-3a1 1 0 100 2h8a1 1 0 100-2h-3v-3.08A7 7 0 0019 11z" />
        </svg>
      </div>
      {state === 'listening' && (
        <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 h-1 rounded-full bg-red-500"
          style={{ width: `${Math.max(8, volumePct)}%`, minWidth: 8 }} />
      )}
    </div>
  );
}

// 评委角色文字映射
function roleLabel(role?: string) {
  return { peer: '研究方法评委', high_peer: '领域内容评委', manager: '批判性评委' }[role || ''] || role || '-';
}
