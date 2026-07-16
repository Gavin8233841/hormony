<!-- competition-source-manifest:v1 -->
```json
{
  "include": [
    "AGENTS.md",
    "DESIGN.md",
    "PRODUCT.md",
    "README.md",
    "apps/harmonyos",
    "apps/web",
    "docs/ACTIVE-LEARNING-SPEC-CS101.md",
    "docs/ACTIVE-LEARNING-SPEC-CS102.md",
    "docs/ACTIVE-LEARNING-SPEC-CS103.md",
    "docs/COMPETITION-NOTICE.md",
    "docs/COMPETITION-SCORE-FIRST-PLAN.md",
    "docs/DEPLOYMENT-GUIDE.md",
    "docs/MODEL-ROLLOUT-STRATEGY.md",
    "docs/SUBMISSION-SOURCE-MANIFEST.md",
    "docs/architecture.md",
    "docs/workstreams/06-competition-release-result.md",
    "scripts/generate-learning-activities.mjs",
    "scripts/generate-learning-content-json.mjs",
    "scripts/generate-learning-content-json.test.mjs",
    "scripts/generate-quizzes-json.mjs",
    "scripts/harmonyos-app-smoke.ps1",
    "scripts/simulator-api-gateway.mjs",
    "scripts/start-simulator-gateway.ps1",
    "scripts/test-chat.mjs",
    "scripts/test_validate_competition_content.py",
    "scripts/validate-competition-content.py",
    "scripts/validate-topic-relations.py"
  ],
  "exclude": [
    "apps/harmonyos/screenshot",
    "apps/web/BACKEND_P1_FIX_DEVLOG.md",
    "apps/web/BACKEND_P2_CLEANUP_DEVLOG.md"
  ]
}
```

默认门禁通过 `git ls-files` 展开本清单。最终核验前，必须先精确暂存或提交
清单内的新增文件，再运行 `python scripts/validate-competition-content.py`；未跟踪文件
不会被目录项隐式纳入，也不得据此宣称最终 Demo ZIP 已通过。
