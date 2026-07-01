#!/usr/bin/env node
/**
 * generate-quizzes-json.mjs
 *
 * 从 apps/web/src/lib/data/quizzes.ts 读取题库数据，
 * 生成端侧 apps/harmonyos/.../rawfile/learning/quizzes.json
 *
 * 格式：扁平 JSON 数组，每项包含 id/courseId/topic/question/options/answer/explanation
 * 仅包含 type === "choice" 的题目（简答题不入端侧题库）
 * UTF-8 编码，中文不转义
 *
 * 运行方式：node scripts/generate-quizzes-json.mjs
 */

import { writeFileSync, readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import { runInNewContext } from "node:vm";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, "..");

// ===== 1. 使用仓库现有 TypeScript 编译器读取题库数据 =====
const require = createRequire(import.meta.url);
const ts = require("../apps/web/node_modules/typescript");
const source = readFileSync(resolve(root, "apps/web/src/lib/data/quizzes.ts"), "utf-8");
const javascript = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const moduleObject = { exports: {} };
runInNewContext(javascript, {
  module: moduleObject,
  exports: moduleObject.exports,
  require,
});
const quizzesModule = moduleObject.exports;
const { cs101Quizzes, cs102Quizzes, cs103Quizzes } = quizzesModule;

const allQuizzes = [...cs101Quizzes, ...cs102Quizzes, ...cs103Quizzes];

// ===== 2. 扁平化为选择题列表（映射字段名 stem -> question） =====
const flatQuestions = allQuizzes.flatMap((quiz) =>
  quiz.questions
    .filter((q) => q.type === "choice")
    .map((q) => ({
      id: q.id,
      courseId: quiz.courseId,
      topic: quiz.topic,
      question: q.stem,
      options: q.options,
      answer: q.answer,
      explanation: q.explanation,
    }))
);

// ===== 3. 写入端侧 JSON =====
const outputPath = resolve(
  root,
  "apps/harmonyos/entry/src/main/resources/rawfile/learning/quizzes.json"
);

writeFileSync(outputPath, `${JSON.stringify(flatQuestions, null, 2)}\n`, "utf-8");
console.log(`Generated ${flatQuestions.length} choice questions to:\n  ${outputPath}`);

// ===== 4. 验证：源数据与端侧 JSON 完全一致 =====
const generated = JSON.parse(readFileSync(outputPath, "utf-8"));

if (JSON.stringify(generated) !== JSON.stringify(flatQuestions)) {
  console.error("[FAIL] Generated quizzes.json does not match the Web source.");
  process.exit(1);
}

console.log(
  `[PASS] Verification passed: all ${flatQuestions.length} questions match between source and JSON.`
);
