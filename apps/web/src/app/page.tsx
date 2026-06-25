import Link from "next/link";
import { MessageSquare, BookOpen, CalendarDays, Target, TrendingUp, ShieldCheck, Database } from "lucide-react";

export default function DashboardPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">学习仪表盘</h1>
        <p className="mt-1 text-sm text-slate-400">多智能体协作的校园学习助理 · 演示数据</p>
      </div>

      {/* 统计卡片 */}
      <div className="grid grid-cols-4 gap-4">
        <StatCard icon={MessageSquare} label="累计提问" value="128" color="text-brand-100" />
        <StatCard icon={Target} label="答题正确率" value="76%" color="text-emerald-400" />
        <StatCard icon={CalendarDays} label="连续学习" value="23 天" color="text-amber-400" />
        <StatCard icon={BookOpen} label="进行中课程" value="3 门" color="text-purple-400" />
      </div>

      {/* 快捷入口 */}
      <div className="grid grid-cols-3 gap-4">
        <Link href="/chat" className="card transition hover:border-brand-500/50">
          <MessageSquare className="mb-2 text-brand-100" size={24} />
          <h3 className="font-semibold">AI 对话辅导</h3>
          <p className="mt-1 text-sm text-slate-400">向 Tutor Agent 提问，获取带引用的讲解</p>
        </Link>
        <Link href="/plan" className="card transition hover:border-brand-500/50">
          <CalendarDays className="mb-2 text-amber-400" size={24} />
          <h3 className="font-semibold">生成学习计划</h3>
          <p className="mt-1 text-sm text-slate-400">Planner Agent 拆解目标为可执行任务</p>
        </Link>
        <Link href="/knowledge" className="card transition hover:border-brand-500/50">
          <Database className="mb-2 text-emerald-400" size={24} />
          <h3 className="font-semibold">知识库检索</h3>
          <p className="mt-1 text-sm text-slate-400">RAG 检索课程资料，输出可解释引用</p>
        </Link>
      </div>

      {/* Agent 架构概览 */}
      <div className="card">
        <div className="mb-4 flex items-center gap-2">
          <TrendingUp size={18} className="text-brand-100" />
          <h2 className="font-semibold">多 Agent 协作架构</h2>
        </div>
        <div className="grid grid-cols-7 gap-2 text-center text-xs">
          {[
            { name: "Profile", desc: "用户画像", color: "bg-blue-500/20 text-blue-300" },
            { name: "Retrieval", desc: "RAG 检索", color: "bg-emerald-500/20 text-emerald-300" },
            { name: "Planner", desc: "计划生成", color: "bg-amber-500/20 text-amber-300" },
            { name: "Tutor", desc: "课程辅导", color: "bg-purple-500/20 text-purple-300" },
            { name: "Quiz", desc: "测验出题", color: "bg-pink-500/20 text-pink-300" },
            { name: "Evaluator", desc: "薄弱分析", color: "bg-cyan-500/20 text-cyan-300" },
            { name: "Safety", desc: "安全审核", color: "bg-red-500/20 text-red-300" },
          ].map((a) => (
            <div key={a.name} className="rounded-lg border border-slate-700/50 p-3">
              <div className={`agent-tag mx-auto mb-1.5 w-fit ${a.color}`}>{a.name}</div>
              <div className="text-slate-400">{a.desc}</div>
            </div>
          ))}
        </div>
      </div>

      {/* 安全机制 */}
      <div className="card flex items-start gap-3">
        <ShieldCheck className="mt-0.5 text-emerald-400" size={20} />
        <div>
          <h3 className="font-semibold">内容安全与反幻觉机制</h3>
          <p className="mt-1 text-sm text-slate-400">
            所有 AI 输出经 Safety Agent 审核：敏感内容过滤、幻觉风险评级、学术诚信检查。
            回答附带资料引用，确保可解释性。
          </p>
        </div>
      </div>
    </div>
  );
}

function StatCard({
  icon: Icon,
  label,
  value,
  color,
}: {
  icon: React.ElementType;
  label: string;
  value: string;
  color: string;
}) {
  return (
    <div className="card">
      <Icon size={20} className={color} />
      <div className="mt-3 text-2xl font-bold">{value}</div>
      <div className="text-sm text-slate-400">{label}</div>
    </div>
  );
}
