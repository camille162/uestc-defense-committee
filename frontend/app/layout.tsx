import './globals.css';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'UESTC 答辩委员会',
  description: '上传论文/PPT，三位 AI 评委语音提问，模拟真实答辩场景',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="zh-CN">
      <body className="bg-gray-50 min-h-screen">
        <header className="bg-white border-b">
          <div className="max-w-5xl mx-auto px-6 py-4 flex items-center justify-between">
            <a href="/" className="text-xl font-bold text-blue-700">UESTC 答辩委员会</a>
            <span className="text-sm text-gray-500">AI 答辩评委 · 语音交互</span>
          </div>
        </header>
        <main className="max-w-5xl mx-auto px-6 py-8">{children}</main>
      </body>
    </html>
  );
}
