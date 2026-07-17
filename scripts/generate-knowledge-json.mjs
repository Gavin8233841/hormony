#!/usr/bin/env node

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import { runInNewContext } from "node:vm";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(import.meta.url);
const ts = require("../apps/web/node_modules/typescript");
const sources = [
  ["cs101", "apps/web/src/lib/data/cs101-knowledge.ts", "cs101KnowledgeChunks"],
  ["cs102", "apps/web/src/lib/data/cs102-knowledge.ts", "cs102KnowledgeChunks"],
  ["cs103", "apps/web/src/lib/data/cs103-knowledge.ts", "cs103KnowledgeChunks"],
];
const outputPath = resolve(
  root,
  "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json",
);

function loadKnowledgeChunks(courseId, relativePath, exportName) {
  const source = readFileSync(resolve(root, relativePath), "utf8");
  const javascript = ts.transpileModule(source, {
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2022,
    },
  }).outputText;
  const moduleObject = { exports: {} };
  runInNewContext(javascript, {
    module: moduleObject,
    exports: moduleObject.exports,
    require,
  });
  const chunks = moduleObject.exports[exportName];
  if (!Array.isArray(chunks)) {
    throw new Error(`${relativePath} 未导出数组 ${exportName}`);
  }
  for (const chunk of chunks) {
    if (
      typeof chunk.id !== "string"
      || typeof chunk.text !== "string"
      || typeof chunk.source !== "string"
      || chunk.courseId !== courseId
      || typeof chunk.topic !== "string"
    ) {
      throw new Error(`${relativePath} 包含字段不完整或 courseId 不一致的知识切片`);
    }
  }
  return chunks;
}

const chunks = sources.flatMap((source) => loadKnowledgeChunks(...source));
const ids = chunks.map((chunk) => chunk.id);
if (chunks.length !== 147) {
  throw new Error(`知识切片总数应为 147，实际 ${chunks.length}`);
}
if (new Set(ids).size !== ids.length) {
  throw new Error("知识切片 id 必须全局唯一");
}

writeFileSync(outputPath, `${JSON.stringify(chunks, null, 2)}\n`, "utf8");
const generated = JSON.parse(readFileSync(outputPath, "utf8"));
if (JSON.stringify(generated) !== JSON.stringify(chunks)) {
  throw new Error("生成后的 knowledge-chunks.json 与 Web 知识源不一致");
}

console.log(`[PASS] 生成 ${chunks.length} 条知识切片，Web 源与端侧 JSON 完全一致`);
