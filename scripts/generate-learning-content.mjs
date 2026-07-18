#!/usr/bin/env node

import { createRequire } from "node:module";
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { runInNewContext } from "node:vm";
import { generateLearningActivities } from "./generate-learning-activities.mjs";

const scriptPath = fileURLToPath(import.meta.url);
const root = resolve(dirname(scriptPath), "..");
const require = createRequire(import.meta.url);
const ts = require("../apps/web/node_modules/typescript");
const rawDirectory = resolve(
  root,
  "apps/harmonyos/entry/src/main/resources/rawfile/learning"
);
const rawFileDirectory = resolve(rawDirectory, "..");

function loadTypeScriptModule(relativePath) {
  const sourcePath = resolve(root, relativePath);
  const source = readFileSync(sourcePath, "utf-8");
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
  return moduleObject.exports;
}

function readJson(relativePath) {
  return JSON.parse(readFileSync(resolve(rawDirectory, relativePath), "utf-8"));
}

function replaceCourseItems(existing, additions, courseId) {
  return [
    ...existing.filter((item) => item.courseId !== courseId),
    ...additions,
  ];
}

function flatChoiceQuestions(quizzes) {
  return quizzes.flatMap((quiz) =>
    quiz.questions
      .filter((question) => question.type === "choice")
      .map((question) => ({
        id: question.id,
        courseId: quiz.courseId,
        topic: quiz.topic,
        question: question.stem,
        options: question.options,
        answer: question.answer,
        explanation: question.explanation,
        difficulty: question.difficulty,
        tags: question.tags,
        ...(question.provenance !== undefined ? { provenance: question.provenance } : {}),
        ...(question.sourceResourceIds !== undefined ? { sourceResourceIds: question.sourceResourceIds } : {}),
      }))
  );
}

function stringifyTopicRelations(relations) {
  const records = relations.map((relation) => [
    "  {",
    `    "id": ${JSON.stringify(relation.id)},`,
    `    "courseId": ${JSON.stringify(relation.courseId)},`,
    `    "topic": ${JSON.stringify(relation.topic)},`,
    `    "prerequisiteIds": [${relation.prerequisiteIds.map((id) => JSON.stringify(id)).join(", ")}],`,
    `    "level": ${JSON.stringify(relation.level)}`,
    "  }",
  ].join("\n"));
  return `[\n${records.join(",\n")}\n]\n`;
}

function writeAndVerify(fileName, value, serialize = null) {
  const outputPath = resolve(rawDirectory, fileName);
  const json = serialize === null ? `${JSON.stringify(value, null, 2)}\n` : serialize(value);
  writeFileSync(outputPath, json, "utf-8");
  const generated = JSON.parse(readFileSync(outputPath, "utf-8"));
  if (JSON.stringify(generated) !== JSON.stringify(value)) {
    throw new Error(`${fileName} verification failed after write`);
  }
  console.log(`[PASS] ${fileName}: ${value.length} records`);
}

function verifyBundledMedia(resources) {
  for (const resource of resources) {
    if (resource.media === undefined) continue;
    const rawFilePath = resource.media.rawFilePath;
    if (!rawFilePath.startsWith("learning/media/") || rawFilePath.includes("..")) {
      throw new Error(`${resource.id} rawFilePath 不在 learning/media`);
    }
    const bytes = readFileSync(resolve(rawFileDirectory, rawFilePath));
    if (bytes.length !== resource.media.byteLength) {
      throw new Error(`${resource.id} 媒体大小不一致`);
    }
    const sha256 = createHash("sha256").update(bytes).digest("hex").toUpperCase();
    if (sha256 !== resource.evidence?.sha256) {
      throw new Error(`${resource.id} 媒体 SHA-256 不一致`);
    }
  }
}

export function generateLearningContent() {
  const catalogModule = loadTypeScriptModule(
    "apps/web/src/lib/data/course-catalog.ts"
  );
  const cs101Module = loadTypeScriptModule(
    "apps/web/src/lib/data/cs101-knowledge.ts"
  );
  const cs102Module = loadTypeScriptModule(
    "apps/web/src/lib/data/cs102-knowledge.ts"
  );
  const cs103Module = loadTypeScriptModule(
    "apps/web/src/lib/data/cs103-knowledge.ts"
  );
  const quizzesModule = loadTypeScriptModule(
    "apps/web/src/lib/data/quizzes.ts"
  );
  const resourcesModule = loadTypeScriptModule(
    "apps/web/src/lib/data/external-resources.ts"
  );
  const accountingModule = loadTypeScriptModule(
    "apps/web/src/lib/data/accounting.ts"
  );
  const cetModule = loadTypeScriptModule(
    "apps/web/src/lib/data/cet.ts"
  );

  const knowledge = [
    ...cs101Module.cs101KnowledgeChunks,
    ...cs102Module.cs102KnowledgeChunks,
    ...cs103Module.cs103KnowledgeChunks,
    ...accountingModule.accountingKnowledgeChunks,
    ...cetModule.cetKnowledgeChunks,
  ];
  const quizzes = [
    ...quizzesModule.cs101Quizzes,
    ...quizzesModule.cs102Quizzes,
    ...quizzesModule.cs103Quizzes,
    ...accountingModule.accountingQuizzes,
    ...cetModule.cetQuizzes,
  ];
  const resources = [
    ...resourcesModule.externalResources,
    ...accountingModule.accountingExternalResources,
    ...cetModule.cetExternalResources,
  ];
  let relations = replaceCourseItems(
    readJson("topic-relations.json"),
    accountingModule.accountingTopicRelations,
    "acc101"
  );
  relations = replaceCourseItems(relations, cetModule.cetTopicRelations.filter(
    (item) => item.courseId === "cet4"
  ), "cet4");
  relations = replaceCourseItems(relations, cetModule.cetTopicRelations.filter(
    (item) => item.courseId === "cet6"
  ), "cet6");
  let experiences = replaceCourseItems(
    readJson("lesson-experiences.json"),
    accountingModule.accountingLessonExperiences,
    "acc101"
  );
  experiences = replaceCourseItems(experiences, cetModule.cetLessonExperiences.filter(
    (item) => item.courseId === "cet4"
  ), "cet4");
  experiences = replaceCourseItems(experiences, cetModule.cetLessonExperiences.filter(
    (item) => item.courseId === "cet6"
  ), "cet6");

  verifyBundledMedia(resources);

  writeAndVerify("course-catalog.json", catalogModule.courseCatalog);
  writeAndVerify("knowledge-chunks.json", knowledge);
  writeAndVerify("quizzes.json", flatChoiceQuestions(quizzes));
  writeAndVerify("external-resources.json", resources);
  writeAndVerify("topic-relations.json", relations, stringifyTopicRelations);
  writeAndVerify("lesson-experiences.json", experiences);
  generateLearningActivities();
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  generateLearningContent();
}
