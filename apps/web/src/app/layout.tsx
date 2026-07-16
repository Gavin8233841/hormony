import type { Metadata } from "next";
import Link from "next/link";
import "./globals.css";
import { Analytics } from "@vercel/analytics/next";
import { SpeedInsights } from "@vercel/speed-insights/next";
import { LayoutDashboard, MessageSquare, BookOpen, CalendarDays, Database, User, Brain } from "lucide-react";

export const metadata: Metadata = {
  title: "鸿学伴 · 智能学习助理",
  description: "C4-AI 鸿蒙高校创新赛 · 智能辅导方向",
};

const navItems = [
  { href: "/", label: "仪表盘", icon: LayoutDashboard },
  { href: "/chat", label: "对话辅导", icon: MessageSquare },
  { href: "/quiz", label: "智能测验", icon: Brain },
  { href: "/courses", label: "课程", icon: BookOpen },
  { href: "/plan", label: "学习计划", icon: CalendarDays },
  { href: "/knowledge", label: "知识库", icon: Database },
  { href: "/profile", label: "个人画像", icon: User },
];

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="zh-CN">
      <body>
        <div className="min-h-screen">
          {/* 侧边栏 */}
          <aside className="fixed left-0 top-0 z-20 hidden h-screen w-56 flex-col border-r border-slate-700/60 bg-slate-900/80 md:flex">
            <div className="px-5 py-5">
              <h1 className="text-lg font-bold text-brand-100">鸿学伴</h1>
              <p className="mt-0.5 text-xs text-slate-400">智能学习助理</p>
            </div>
            <nav className="flex-1 space-y-1 px-3">
              {navItems.map((item) => {
                const Icon = item.icon;
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm text-slate-300 transition hover:bg-slate-700/50 hover:text-white"
                  >
                    <Icon size={18} />
                    {item.label}
                  </Link>
                );
              })}
            </nav>
            <div className="border-t border-slate-700/60 px-5 py-3">
              <p className="text-xs text-slate-500">智能辅导 · 知识检索 · 安全审核</p>
            </div>
          </aside>

          <header className="sticky top-0 z-20 border-b border-slate-700/60 bg-slate-900/95 px-4 py-3 backdrop-blur md:hidden">
            <div className="mb-3 flex items-baseline justify-between gap-3">
              <h1 className="text-base font-bold text-brand-100">鸿学伴</h1>
              <p className="text-xs text-slate-500">智能学习助理</p>
            </div>
            <nav className="flex gap-1 overflow-x-auto pb-1" aria-label="主导航">
              {navItems.map((item) => {
                const Icon = item.icon;
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className="flex shrink-0 items-center gap-1.5 rounded-lg px-2.5 py-2 text-xs text-slate-300 transition hover:bg-slate-700/50 hover:text-white"
                  >
                    <Icon size={15} />
                    {item.label}
                  </Link>
                );
              })}
            </nav>
          </header>

          {/* 主内容 */}
          <main className="p-4 sm:p-6 md:ml-56 md:p-8">{children}</main>
        </div>
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  );
}
