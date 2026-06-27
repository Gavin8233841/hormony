#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Loop Engineering Gate v2 — TRAE Stop Hook 决策引擎
=====================================================
修复点:
  1. 不覆盖 AI 维护的 progress.json，改用 hook_log.json 记录 Hook 自身日志
  2. 完成关键词不再单独放行——必须验证命令全通过 AND 验收清单全完成
  3. 阻断时注入更强的"不要停下来"指令
"""

import sys
import os
import json
import subprocess
import datetime
from pathlib import Path


def now_iso():
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def read_stdin():
    try:
        raw = sys.stdin.read()
        return json.loads(raw) if raw.strip() else {}
    except Exception as e:
        return {"_error": f"stdin parse error: {e}"}


def load_config(trae_dir):
    config_path = trae_dir / "loop_config.json"
    if not config_path.exists():
        return None
    try:
        return json.loads(config_path.read_text(encoding="utf-8"))
    except Exception as e:
        return {"_error": f"config load error: {e}"}


def load_progress(trae_dir):
    """读取 AI 维护的 progress.json（只读，不覆盖）"""
    progress_path = trae_dir / "progress.json"
    if not progress_path.exists():
        return {}
    try:
        return json.loads(progress_path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def load_hook_log(trae_dir):
    """读取 Hook 自己的日志（独立于 progress.json）"""
    log_path = trae_dir / "hook_log.json"
    if not log_path.exists():
        return {"created_at": now_iso(), "cycles": []}
    try:
        return json.loads(log_path.read_text(encoding="utf-8"))
    except Exception:
        return {"created_at": now_iso(), "cycles": []}


def check_keywords(message, keywords):
    msg_lower = message.lower()
    return any(kw.lower() in msg_lower for kw in keywords)


def _decode_output(data):
    if data is None:
        return ""
    if isinstance(data, str):
        return data
    for enc in ("utf-8", "gbk", "gb2312", "cp936", "latin-1"):
        try:
            return data.decode(enc)
        except (UnicodeDecodeError, AttributeError):
            continue
    return data.decode("utf-8", errors="replace")


def run_verification(cmd, cwd, timeout=180):
    kwargs = {
        "shell": True,
        "cwd": str(cwd),
        "capture_output": True,
        "timeout": timeout,
    }
    if sys.platform == "win32":
        kwargs["creationflags"] = 0x08000000

    try:
        result = subprocess.run(cmd, **kwargs)
        stdout_text = _decode_output(result.stdout)
        stderr_text = _decode_output(result.stderr)
        stdout_tail = "\n".join(stdout_text.strip().split("\n")[-10:]) if stdout_text.strip() else ""
        stderr_tail = "\n".join(stderr_text.strip().split("\n")[-10:]) if stderr_text.strip() else ""
        return {
            "command": cmd,
            "passed": result.returncode == 0,
            "exit_code": result.returncode,
            "stdout_tail": stdout_tail,
            "stderr_tail": stderr_tail,
        }
    except subprocess.TimeoutExpired:
        return {
            "command": cmd,
            "passed": False,
            "exit_code": -1,
            "stdout_tail": "",
            "stderr_tail": f"[TIMEOUT] 命令执行超时（{timeout}秒）",
        }
    except FileNotFoundError:
        return {
            "command": cmd,
            "passed": False,
            "exit_code": -3,
            "stdout_tail": "",
            "stderr_tail": "[NOTFOUND] 命令未找到",
        }
    except Exception as e:
        return {
            "command": cmd,
            "passed": False,
            "exit_code": -2,
            "stdout_tail": "",
            "stderr_tail": f"[ERROR] {e}",
        }


def run_all_verifications(config, cwd):
    commands = config.get("verify_commands", [])
    if not commands:
        return []
    return [run_verification(cmd, cwd) for cmd in commands]


def check_acceptance_from_progress(progress):
    """从 AI 维护的 progress.json 中读取验收清单完成状态。
    如果没有 acceptance_status 字段，返回 None（无法判断，视为未完成）。
    """
    acceptance = progress.get("acceptance_status")
    if not acceptance or not isinstance(acceptance, list):
        return None
    all_done = all(item.get("done", False) for item in acceptance)
    done_count = sum(1 for item in acceptance if item.get("done", False))
    total_count = len(acceptance)
    return {
        "all_done": all_done,
        "done_count": done_count,
        "total_count": total_count
    }


def generate_next_step(config, progress, verify_results, loop_count, acceptance_info):
    parts = []
    parts.append(f"=== Loop Engineering 自评估报告（第 {loop_count + 1} 轮）===")
    parts.append("")

    # 验证结果
    if verify_results:
        passed_count = sum(1 for r in verify_results if r["passed"])
        total_count = len(verify_results)
        parts.append(f"[验证结果] {passed_count}/{total_count} 通过")
        parts.append("")
        for r in verify_results:
            status = "PASS" if r["passed"] else "FAIL"
            parts.append(f"  [{status}] {r['command']}")
            if not r["passed"]:
                if r.get("stderr_tail"):
                    parts.append("    错误输出（最后10行）：")
                    for line in r["stderr_tail"].split("\n"):
                        parts.append(f"    {line}")
                if r.get("stdout_tail"):
                    parts.append("    标准输出（最后10行）：")
                    for line in r["stdout_tail"].split("\n"):
                        parts.append(f"    {line}")
        parts.append("")

    # 验收清单（从 AI 的 progress.json 读取已有状态）
    criteria = config.get("acceptance_criteria", [])
    if criteria:
        parts.append("[验收清单当前状态]")
        acceptance = progress.get("acceptance_status", [])
        for i, item in enumerate(criteria):
            done = False
            note = ""
            if i < len(acceptance):
                done = acceptance[i].get("done", False)
                note = acceptance[i].get("note", "")
            mark = "[x]" if done else "[ ]"
            parts.append(f"  {i+1}. {mark} {item}")
            if note:
                parts.append(f"       备注: {note}")
        parts.append("")

    # 验收完成度
    if acceptance_info:
        parts.append(f"[验收完成度] {acceptance_info['done_count']}/{acceptance_info['total_count']}")
        parts.append("")

    # 北极星目标
    goal = config.get("goal", "")
    if goal:
        parts.append(f"[北极星目标] {goal}")
        parts.append("")

    # AI 自己的进度记录
    ai_cycles = progress.get("cycles", [])
    if ai_cycles:
        parts.append("[AI 循环历史]")
        recent = ai_cycles[-3:]
        for c in recent:
            parts.append(f"  轮次 {c.get('loop', '?')}: {c.get('actions', '')[:100]}")
            next_step = c.get("next_step", "")
            if next_step:
                parts.append(f"    → 下一步: {next_step}")
        parts.append("")

    # 下一步指令
    parts.append("[下一步指令]")
    failed_cmds = [r for r in verify_results if not r["passed"]]
    if failed_cmds:
        parts.append("请优先修复以下失败的验证项：")
        for r in failed_cmds:
            parts.append(f"  - {r['command']}")
        parts.append("修复后重新运行验证命令确认通过。")
    elif acceptance_info and not acceptance_info["all_done"]:
        parts.append("验证命令已通过，但验收清单未全部完成。")
        parts.append(f"还需完成 {acceptance_info['total_count'] - acceptance_info['done_count']} 项验收标准。")
        parts.append("请继续推进未完成的验收项。")
    else:
        parts.append("请继续推进未完成的验收项，直到全部满足。")

    parts.append("")
    parts.append(">>> 重要：不要停下来等待确认。直接继续执行下一步工作。")
    parts.append('>>> 不要以问句结尾。不要说请确认是否继续。')
    parts.append('>>> 不要声明完成或仅差提交，除非验收清单 7 项全部 [x] 标记为完成。')

    return "\n".join(parts)


def save_hook_log(trae_dir, hook_log):
    """保存 Hook 自己的日志到 hook_log.json（不碰 progress.json）"""
    log_path = trae_dir / "hook_log.json"
    log_path.write_text(
        json.dumps(hook_log, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )


def main():
    input_data = read_stdin()
    last_message = input_data.get("last_assistant_message", "")
    loop_count = input_data.get("loop_count", 0)
    cwd = input_data.get("cwd", os.getcwd())

    trae_dir = Path(cwd) / ".trae"

    # 加载配置
    config = load_config(trae_dir)
    if config is None:
        print(json.dumps({"decision": ""}))
        return
    if "_error" in config:
        print(json.dumps({
            "decision": "block",
            "reason": f"loop_config.json 加载失败: {config['_error']}\n请检查配置文件格式。"
        }, ensure_ascii=False))
        return

    # 读取 AI 维护的 progress.json（只读）
    progress = load_progress(trae_dir)

    # 读取 Hook 自己的日志
    hook_log = load_hook_log(trae_dir)

    # 运行验证命令
    verify_results = run_all_verifications(config, cwd)
    all_passed = all(r["passed"] for r in verify_results) if verify_results else True

    # 关键词检测
    complete_kw = config.get("complete_keywords", [])
    block_kw = config.get("block_keywords", [])
    has_complete_signal = check_keywords(last_message, complete_kw) if complete_kw else False
    has_block_signal = check_keywords(last_message, block_kw) if block_kw else False

    # 从 AI 的 progress.json 读取验收清单状态
    acceptance_info = check_acceptance_from_progress(progress)

    max_loops = config.get("max_loops", 20)

    # 决策逻辑（v2 修复版）
    if loop_count >= max_loops - 1:
        # 防死循环：到达上限 → 放行
        decision = ""
        reason = ""
        status = "max_loops_reached"
    elif has_block_signal:
        # 阻断关键词 → 放行（需要用户介入）
        decision = ""
        reason = ""
        status = "blocked_by_keyword"
    elif all_passed and acceptance_info and acceptance_info["all_done"] and has_complete_signal:
        # 验证全通过 AND 验收清单全完成 AND 声明完成 → 放行
        decision = ""
        reason = ""
        status = "completed"
    else:
        # 其他所有情况 → 阻断，注入下一步指令
        # 包括：
        #   - 验证失败 → 阻断修复
        #   - 验证通过但验收清单未完成 → 阻断继续
        #   - 验证通过且声明完成但验收清单未全完成 → 阻断（虚假完成）
        decision = "block"
        reason = generate_next_step(config, progress, verify_results, loop_count, acceptance_info)
        if not all_passed:
            status = "fixing"
        elif acceptance_info and not acceptance_info["all_done"]:
            status = "acceptance_incomplete"
        else:
            status = "continuing"

    # 记录 Hook 日志（独立文件，不碰 progress.json）
    cycle = {
        "loop_count": loop_count,
        "timestamp": now_iso(),
        "status": status,
        "verify_passed": sum(1 for r in verify_results if r["passed"]),
        "verify_total": len(verify_results),
        "has_complete_signal": has_complete_signal,
        "has_block_signal": has_block_signal,
        "acceptance_done": acceptance_info["done_count"] if acceptance_info else 0,
        "acceptance_total": acceptance_info["total_count"] if acceptance_info else 0,
        "decision": decision,
        "message_length": len(last_message)
    }
    hook_log["cycles"].append(cycle)
    hook_log["updated_at"] = now_iso()
    save_hook_log(trae_dir, hook_log)

    # 输出
    if decision == "block":
        output = {"decision": "block", "reason": reason}
    else:
        output = {"decision": ""}
    print(json.dumps(output, ensure_ascii=False))


if __name__ == "__main__":
    main()
