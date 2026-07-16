#!/usr/bin/env node

import { createRequire } from "node:module";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { runInNewContext } from "node:vm";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(import.meta.url);
const ts = require("../apps/web/node_modules/typescript");

export const OUTPUT_PATHS = {
  knowledge: resolve(
    root,
    "apps/harmonyos/entry/src/main/resources/rawfile/learning/knowledge-chunks.json"
  ),
  resources: resolve(
    root,
    "apps/harmonyos/entry/src/main/resources/rawfile/learning/external-resources.json"
  ),
};

const KNOWLEDGE_SOURCES = [
  ["apps/web/src/lib/data/cs101-knowledge.ts", "cs101KnowledgeChunks"],
  ["apps/web/src/lib/data/cs102-knowledge.ts", "cs102KnowledgeChunks"],
  ["apps/web/src/lib/data/cs103-knowledge.ts", "cs103KnowledgeChunks"],
];
const RESOURCE_SOURCE = [
  "apps/web/src/lib/data/external-resources.ts",
  "externalResources",
];
const PROVENANCE_FIELDS = [
  "accessStatus",
  "checkedAt",
  "httpStatus",
  "rightsName",
  "rightsStatus",
  "rightsUrl",
  "sourceLocator",
  "sourceTitle",
  "sourceUrl",
  "sourceVersion",
];
const RIGHTS_STATUSES = new Set([
  "reference-only",
  "external-link-only",
  "redistributable",
]);
const ACCESS_STATUSES = new Set(["reachable", "unreachable", "not-checked"]);

function loadTypeScriptExport(relativePath, exportName) {
  const source = readFileSync(resolve(root, relativePath), "utf8");
  const javascript = ts.transpileModule(source, {
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2022,
    },
    fileName: relativePath,
  }).outputText;
  const moduleObject = { exports: {} };
  runInNewContext(javascript, {
    module: moduleObject,
    exports: moduleObject.exports,
    require,
  });
  const value = moduleObject.exports[exportName];
  if (!Array.isArray(value)) {
    throw new Error(`${relativePath} 未导出数组 ${exportName}`);
  }
  return JSON.parse(JSON.stringify(value));
}

function validateProvenance(item, label) {
  const provenance = item.provenance;
  if (provenance === null || typeof provenance !== "object" || Array.isArray(provenance)) {
    throw new Error(`${label} 缺少 provenance 对象`);
  }
  const actualFields = Object.keys(provenance).sort();
  if (JSON.stringify(actualFields) !== JSON.stringify(PROVENANCE_FIELDS)) {
    throw new Error(`${label}.provenance 字段不完整: ${actualFields.join(",")}`);
  }
  for (const field of PROVENANCE_FIELDS) {
    if (field === "checkedAt" || field === "httpStatus") continue;
    if (typeof provenance[field] !== "string" || provenance[field].trim().length === 0) {
      throw new Error(`${label}.provenance.${field} 必须为非空字符串`);
    }
  }
  if (!RIGHTS_STATUSES.has(provenance.rightsStatus)) {
    throw new Error(`${label}.provenance.rightsStatus 无效`);
  }
  if (!ACCESS_STATUSES.has(provenance.accessStatus)) {
    throw new Error(`${label}.provenance.accessStatus 无效`);
  }
  if (provenance.accessStatus === "not-checked") {
    if (provenance.checkedAt !== null || provenance.httpStatus !== null) {
      throw new Error(`${label}.provenance 未访问时不得填写检查日期或 HTTP 状态`);
    }
    return;
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(provenance.checkedAt)) {
    throw new Error(`${label}.provenance.checkedAt 必须为 YYYY-MM-DD`);
  }
  if (provenance.accessStatus === "reachable") {
    if (!Number.isInteger(provenance.httpStatus) || provenance.httpStatus < 200 || provenance.httpStatus > 399) {
      throw new Error(`${label}.provenance reachable 必须记录 200-399 HTTP 状态`);
    }
  } else if (
    provenance.httpStatus !== null &&
    (!Number.isInteger(provenance.httpStatus) ||
      provenance.httpStatus < 400 ||
      provenance.httpStatus > 599)
  ) {
    throw new Error(`${label}.provenance unreachable 只能记录 400-599 或 null`);
  }
}

function validateCollection(items, expectedCount, kind) {
  if (items.length !== expectedCount) {
    throw new Error(`${kind} 数量应为 ${expectedCount}，实际 ${items.length}`);
  }
  const ids = new Set();
  for (const item of items) {
    if (typeof item.id !== "string" || item.id.length === 0) {
      throw new Error(`${kind} 存在缺少 id 的记录`);
    }
    if (ids.has(item.id)) throw new Error(`${kind} id 重复: ${item.id}`);
    ids.add(item.id);
    validateProvenance(item, `${kind} ${item.id}`);
  }
}

export function buildLearningContent() {
  const knowledge = KNOWLEDGE_SOURCES.flatMap(([relativePath, exportName]) =>
    loadTypeScriptExport(relativePath, exportName)
  );
  const resources = loadTypeScriptExport(...RESOURCE_SOURCE);
  validateCollection(knowledge, 147, "知识切片");
  validateCollection(resources, 36, "外部资源");
  return { knowledge, resources };
}

export function serializeLearningContent(content) {
  return {
    knowledge: `${JSON.stringify(content.knowledge, null, 2)}\n`,
    resources: `${JSON.stringify(content.resources, null, 2)}\n`,
  };
}

export function generateLearningContent({ checkOnly = false } = {}) {
  const content = buildLearningContent();
  const serialized = serializeLearningContent(content);
  for (const name of Object.keys(OUTPUT_PATHS)) {
    const outputPath = OUTPUT_PATHS[name];
    if (checkOnly) {
      if (readFileSync(outputPath, "utf8") !== serialized[name]) {
        throw new Error(`${outputPath} 与 Web 单一来源不一致，请运行生成器`);
      }
    } else {
      writeFileSync(outputPath, serialized[name], "utf8");
    }
  }
  const action = checkOnly ? "Verified" : "Generated";
  console.log(
    `[PASS] ${action} ${content.knowledge.length} knowledge chunks and ${content.resources.length} external resources from Web sources.`
  );
  return content;
}

const isMain =
  process.argv[1] !== undefined &&
  pathToFileURL(resolve(process.argv[1])).href === import.meta.url;

if (isMain) {
  const args = process.argv.slice(2);
  if (args.some((arg) => arg !== "--check") || args.filter((arg) => arg === "--check").length > 1) {
    console.error("Usage: node scripts/generate-learning-content-json.mjs [--check]");
    process.exitCode = 2;
  } else {
    try {
      generateLearningContent({ checkOnly: args.includes("--check") });
    } catch (error) {
      console.error(`[FAIL] ${error instanceof Error ? error.message : String(error)}`);
      process.exitCode = 1;
    }
  }
}
