'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { uploadResume, createInterview, startRound } from '@/lib/api';

type Stage = 'idle' | 'creating' | 'planning' | 'synth' | 'ready';

const STAGE_LABEL: Record<Stage, string> = {
  idle: '',
  creating: '创建答辩记录中…',
  planning: '评委正在阅读你的论文和PPT…',
  synth: '合成评委语音中…',
  ready: '准备就绪，进入答辩…',
};

function StepLine({ label, active, done }: { label: string; active: boolean; done: boolean }) {
  return (
    <div className={`flex items-center gap-2 ${active ? 'text-blue-600 font-medium' : done ? 'text-green-600' : 'text-gray-400'}`}>
      <span className="w-4 h-4 inline-flex items-center justify-center">
        {done ? '✓' : active ? '●' : '○'}
      </span>
      {label}
    </div>
  );
}

export default function HomePage() {
  const router = useRouter();
  const [position, setPosition] = useState('');
  const [jd, setJd] = useState('');
  const [resumeText, setResumeText] = useState('');
  const [plan, setPlan] = useState('1');
  const [loading, setLoading] = useState(false);
  const [stage, setStage] = useState<Stage>('idle');
  const [error, setError] = useState<string | null>(null);

  async function onFile(f: File | null) {
    if (!f) return;
    setLoading(true); setError(null);
    try {
      const { text } = await uploadResume(f);
      setResumeText(text);
    } catch (e: any) {
      setError(e.message);
    } finally { setLoading(false); }
  }

  async function onStart() {
    if (!position || !jd || !resumeText) {
      setError('请填写论文题目、方向并上传论文/PPT');
      return;
    }
    setLoading(true); setError(null); setStage('creating');
    try {
      const isOnly3 = plan === 'only3';
      const { id } = await createInterview({
        position_title: position, jd_text: jd, resume_text: resumeText,
        rounds_planned: isOnly3 ? 3 : parseInt(plan),
        start_round: isOnly3 ? 3 : 1,
      });
      setStage('planning');
      setStage('synth');
      await startRound(id);
      setStage('ready');
      setTimeout(() => router.push(`/interview/${id}`), 300);
    } catch (e: any) {
      setError(e.message);
      setStage('idle');
      setLoading(false);
    }
  }

  if (loading && stage !== 'idle') {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="bg-white rounded-lg shadow-lg px-10 py-8 flex flex-col items-center space-y-6 max-w-md">
          <div className="relative w-16 h-16">
            <div className="absolute inset-0 rounded-full border-4 border-blue-200"></div>
            <div className="absolute inset-0 rounded-full border-4 border-blue-600 border-t-transparent animate-spin"></div>
          </div>
          <div className="text-center space-y-2">
            <h2 className="text-lg font-semibold">答辩即将开始</h2>
            <p className="text-gray-600 text-sm">{STAGE_LABEL[stage]}</p>
          </div>
          <div className="w-full space-y-1 text-xs text-gray-500">
            <StepLine label="创建答辩记录" active={stage === 'creating'} done={['planning','synth','ready'].includes(stage)} />
            <StepLine label="阅读论文/PPT，规划问题" active={stage === 'planning'} done={['synth','ready'].includes(stage)} />
            <StepLine label="合成评委语音" active={stage === 'synth'} done={stage === 'ready'} />
            <StepLine label="进入答辩" active={stage === 'ready'} done={false} />
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-lg shadow p-6">
        <h1 className="text-2xl font-bold mb-2">开始一场模拟答辩</h1>
        <p className="text-gray-500 text-sm">上传你的简历，粘贴目标岗位 JD，选择答辩轮次，Agent 评委陪你模拟论文答辩。</p>
      </div>
      <div className="bg-white rounded-lg shadow p-6 space-y-4">
        <div>
          <label className="block font-medium mb-1">论文题目</label>
          <input
            className="w-full border rounded px-3 py-2"
            value={position}
            onChange={e => setPosition(e.target.value)}
            placeholder="论文题目：例如'基于深度学习的网络入侵检测研究'"
          />
          <p className="text-xs text-gray-400 mt-1">只填职位名称，JD 全文贴到下面那栏</p>
        </div>
        <div>
          <label className="block font-medium mb-1">论文方向简述</label>
          <textarea
            className="w-full border rounded px-3 py-2 h-32"
            value={jd}
            onChange={e => setJd(e.target.value)}
            placeholder="粘贴论文摘要或研究方向简述…"
          />
        </div>
        <div>
          <label className="block font-medium mb-1">论文/PPT（PDF / PPTX / DOCX / TXT）</label>
          <input
            type="file"
            accept=".pdf,.pptx,.docx,.txt"
            onChange={e => onFile(e.target.files?.[0] || null)}
          />
          {resumeText && (
            <p className="text-sm text-green-700 mt-1">已解析 {resumeText.length} 字符</p>
          )}
        </div>
        <div>
          <label className="block font-medium mb-1">答辩轮次</label>
          <select
            className="border rounded px-3 py-2"
            value={plan}
            onChange={e => setPlan(e.target.value)}
          >
            <option value="1">1 位评委（研究方法）</option>
            <option value="2">2 位评委（研究方法 + 领域内容）</option>
            <option value="3">3 位评委（研究方法 + 领域内容 + 批判性）</option>
            <option value="only3">仅批判性评委</option>
          </select>
          <p className="text-sm text-gray-500 mt-1">每轮 5-8 道主题问题 + 动态追问，单轮约 30-60 分钟</p>
        </div>
        {error && <div className="text-red-600 text-sm">{error}</div>}
        <button
          disabled={loading}
          onClick={onStart}
          className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded disabled:opacity-50"
        >
          {loading ? '处理中…' : '开始答辩'}
        </button>
      </div>
    </div>
  );
}
