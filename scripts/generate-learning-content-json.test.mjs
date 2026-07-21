import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import {
  OUTPUT_PATHS,
  buildLearningContent,
  generateLearningContent,
  serializeLearningContent,
} from "./generate-learning-content-json.mjs";

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

function assertCompleteProvenance(item) {
  assert.deepEqual(Object.keys(item.provenance).sort(), PROVENANCE_FIELDS);
  for (const field of PROVENANCE_FIELDS) {
    if (field === "checkedAt" || field === "httpStatus") continue;
    assert.equal(typeof item.provenance[field], "string", `${item.id}.${field}`);
    assert.notEqual(item.provenance[field].trim(), "", `${item.id}.${field}`);
  }
  assert.equal(new URL(item.provenance.sourceUrl).protocol, "https:");
  assert.equal(new URL(item.provenance.rightsUrl).protocol, "https:");
}

test("build is deterministic and preserves the fixed source grain", () => {
  const first = buildLearningContent();
  const second = buildLearningContent();
  assert.deepEqual(second, first);
  assert.deepEqual(serializeLearningContent(second), serializeLearningContent(first));
  assert.equal(first.knowledge.length, 147);
  assert.equal(first.resources.length, 36);
  assert.equal(new Set(first.knowledge.map((item) => item.id)).size, 147);
  assert.equal(new Set(first.resources.map((item) => item.id)).size, 36);
  assert.equal(
    new Set(first.knowledge.map((item) => `${item.courseId}\u0000${item.topic}`)).size,
    33
  );
});

test("all Web records carry complete, non-placeholder provenance", () => {
  const { knowledge, resources } = buildLearningContent();
  for (const chunk of knowledge) {
    assertCompleteProvenance(chunk);
    assert.equal(chunk.provenance.rightsStatus, "reference-only");
    assert.equal(chunk.provenance.accessStatus, "reachable");
    assert.equal(chunk.provenance.httpStatus, 200);
  }
  for (const resource of resources) {
    assertCompleteProvenance(resource);
    assert.equal(resource.provenance.rightsStatus, "external-link-only");
  }
  const blocked = resources.find((resource) => resource.id === "res_01");
  assert.ok(blocked);
  assert.equal(blocked.provenance.accessStatus, "unreachable");
  assert.equal(blocked.provenance.httpStatus, 403);
  assert.equal(
    resources.filter((resource) => resource.provenance.accessStatus === "reachable").length,
    35
  );
  assert.ok(
    resources
      .filter((resource) => resource.provenance.accessStatus === "reachable")
      .every((resource) => resource.provenance.httpStatus === 200)
  );
  assert.equal(
    resources.filter((resource) => resource.courseId === undefined).length,
    10
  );
});

test("HarmonyOS rawfiles exactly match the Web single source", () => {
  const content = buildLearningContent();
  assert.deepEqual(
    JSON.parse(readFileSync(OUTPUT_PATHS.knowledge, "utf8")),
    content.knowledge
  );
  assert.deepEqual(
    JSON.parse(readFileSync(OUTPUT_PATHS.resources, "utf8")),
    content.resources
  );
  assert.doesNotThrow(() => generateLearningContent({ checkOnly: true }));
});

test("corrected protocol facts remain explicit", () => {
  const { knowledge } = buildLearningContent();
  const byId = new Map(knowledge.map((item) => [item.id, item.text]));
  assert.match(byId.get("cs103_k26"), /RFC 9000本身不定义前向纠错/);
  assert.match(byId.get("cs103_k31"), /仍可能受到TCP层队头阻塞/);
  assert.match(byId.get("cs103_k33"), /HPKP.*已被主流浏览器弃用/);
  assert.doesNotMatch(byId.get("cs103_k31"), /彻底解决了队头阻塞问题/);
});
