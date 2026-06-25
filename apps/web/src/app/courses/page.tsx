import { BookOpen, FileText } from "lucide-react";

export default function CoursesPage() {
  const courses = [
    { id: "cs101", title: "数据结构", progress: 0.65, docCount: 12, topics: ["数组", "链表", "树", "图", "排序", "动态规划"] },
    { id: "cs102", title: "操作系统", progress: 0.42, docCount: 8, topics: ["进程", "调度", "内存管理", "文件系统"] },
    { id: "cs103", title: "计算机网络", progress: 0.30, docCount: 6, topics: ["TCP/IP", "HTTP", "路由"] },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">我的课程</h1>
        <p className="mt-1 text-sm text-slate-400">课程资料已纳入 RAG 知识库，可被 Retrieval Agent 检索</p>
      </div>

      <div className="grid grid-cols-2 gap-4">
        {courses.map((c) => (
          <div key={c.id} className="card">
            <div className="flex items-start justify-between">
              <div className="flex items-center gap-3">
                <div className="rounded-lg bg-brand-500/20 p-2.5">
                  <BookOpen className="text-brand-100" size={20} />
                </div>
                <div>
                  <h3 className="font-semibold">{c.title}</h3>
                  <p className="text-xs text-slate-400">{c.id}</p>
                </div>
              </div>
              <span className="flex items-center gap-1 text-xs text-slate-400">
                <FileText size={14} /> {c.docCount} 份资料
              </span>
            </div>

            <div className="mt-4">
              <div className="mb-1 flex justify-between text-xs text-slate-400">
                <span>学习进度</span>
                <span>{(c.progress * 100).toFixed(0)}%</span>
              </div>
              <div className="h-2 overflow-hidden rounded-full bg-slate-700/50">
                <div className="h-full rounded-full bg-brand-500" style={{ width: `${c.progress * 100}%` }} />
              </div>
            </div>

            <div className="mt-4 flex flex-wrap gap-1.5">
              {c.topics.map((t) => (
                <span key={t} className="rounded-md bg-slate-700/40 px-2 py-0.5 text-xs text-slate-300">
                  {t}
                </span>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
