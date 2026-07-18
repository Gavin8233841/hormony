import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import {
  COURSE_IDS,
  EXTERNAL_RESOURCE_TYPES,
  accountingLessonExperiences,
  accountingTopicRelations,
  allKnowledgeChunks,
  allQuizzes,
  cetLessonExperiences,
  cetTopicRelations,
  courseCatalog,
  externalResources,
} from "@/lib/data";
import type { CourseId } from "@/lib/data";
import type {
  CourseCatalogItem,
  ExternalResource,
  KnowledgeChunk,
  LessonExperienceSeed,
} from "@/lib/types";

const MINIMUM_COUNTS: Record<CourseId, {
  chunks: number;
  questions: number;
  choices: number;
}> = {
  cs101: { chunks: 40, questions: 20, choices: 20 },
  cs102: { chunks: 40, questions: 20, choices: 20 },
  cs103: { chunks: 40, questions: 20, choices: 20 },
  acc101: { chunks: 5, questions: 5, choices: 5 },
  cet4: { chunks: 5, questions: 5, choices: 5 },
  cet6: { chunks: 5, questions: 5, choices: 5 },
};

const EXPECTED_TOPICS_BY_COURSE: Record<CourseId, readonly string[]> = {
  cs101: [
    "数组与线性表",
    "链表",
    "栈与队列",
    "二叉树与BST",
    "AVL树与红黑树",
    "图的表示与遍历",
    "最短路径算法",
    "排序算法",
    "动态规划",
    "贪心算法与分治",
    "哈希表",
    "堆与优先队列",
  ],
  cs102: [
    "进程与线程",
    "CPU调度算法",
    "内存管理基础",
    "虚拟内存与分页",
    "分段与段页式",
    "文件系统",
    "I/O系统与磁盘调度",
    "死锁",
    "同步与互斥",
    "进程间通信",
  ],
  cs103: [
    "OSI与TCP/IP模型",
    "物理层与数据链路层",
    "网络层与IP协议",
    "TCP握手与挥手",
    "TCP流量控制与拥塞控制",
    "UDP协议",
    "HTTP协议",
    "HTTPS与TLS",
    "DNS系统",
    "路由算法与协议",
    "网络安全基础",
  ],
  acc101: ["会计要素与会计等式"],
  cet4: ["CET-4连续短语听辨与转写复核"],
  cet6: ["CET-6讲座关键词骨架与延迟复述"],
};

const EXPECTED_RAW_QUIZ_BASE_FIELDS = [
  "answer",
  "courseId",
  "difficulty",
  "explanation",
  "id",
  "options",
  "question",
  "tags",
  "topic",
];

const HARMONY_TOPIC_ENTRY_FILES = [
  "ActivityRecords.ets",
  "CourseDetail.ets",
  "HomeContent.ets",
  "Knowledge.ets",
  "LearningMap.ets",
  "Lesson.ets",
  "MistakeBook.ets",
  "Plan.ets",
  "Practice.ets",
  "Profile.ets",
  "Quiz.ets",
] as const;
const TOPIC_CONTEXT_MARKERS = [
  "selectedQuizTopic",
  "selectedPracticeTopic",
  "@State topic:",
  "this.topic =",
  "topic:",
] as const;
const QUIZ_TOPIC_CONTEXT_MARKERS = ["this.suggestions =", "this.selectTopic("] as const;
const TOPIC_STORAGE_KEYS = new Set([
  "selectedContentTopic",
  "selectedQuizTopic",
  "selectedPracticeTopic",
]);

interface RawQuizQuestion {
  id: string;
  courseId: string;
  topic: string;
  question: string;
  options?: string[];
  answer: string;
  explanation: string;
  difficulty: string;
  tags: string[];
  provenance?: "original_instructional_content";
  sourceResourceIds?: string[];
}

interface TopicRelation {
  courseId: string;
  topic: string;
}

const harmonyResourceUrl = (fileName: string) =>
  new URL(
    `../../../../harmonyos/entry/src/main/resources/rawfile/learning/${fileName}`,
    import.meta.url
  );

const harmonyPageUrl = (fileName: string) =>
  new URL(
    `../../../../harmonyos/entry/src/main/ets/pages/${fileName}`,
    import.meta.url
  );

const harmonyRawFileUrl = (fileName: string) =>
  new URL(
    `../../../../harmonyos/entry/src/main/resources/rawfile/${fileName}`,
    import.meta.url
  );

const resourceCourseIds = (resource: ExternalResource): string[] =>
  resource.courseId !== undefined ? [resource.courseId] : (resource.courseIds ?? []);

const expectedTopicKeys = COURSE_IDS.flatMap((courseId) =>
  EXPECTED_TOPICS_BY_COURSE[courseId].map((topic) => `${courseId}:${topic}`)
).sort();

const expectedTopicTitles = COURSE_IDS.flatMap(
  (courseId) => EXPECTED_TOPICS_BY_COURSE[courseId]
);

const rawQuizQuestions = JSON.parse(
  readFileSync(fileURLToPath(harmonyResourceUrl("quizzes.json")), "utf8")
) as RawQuizQuestion[];

const rawCourseCatalog = JSON.parse(
  readFileSync(fileURLToPath(harmonyResourceUrl("course-catalog.json")), "utf8")
) as CourseCatalogItem[];

const rawKnowledgeChunks = JSON.parse(
  readFileSync(fileURLToPath(harmonyResourceUrl("knowledge-chunks.json")), "utf8")
) as KnowledgeChunk[];

const rawExternalResources = JSON.parse(
  readFileSync(fileURLToPath(harmonyResourceUrl("external-resources.json")), "utf8")
) as ExternalResource[];

const rawLessonExperiences = JSON.parse(
  readFileSync(fileURLToPath(harmonyResourceUrl("lesson-experiences.json")), "utf8")
) as LessonExperienceSeed[];

const topicRelations = JSON.parse(
  readFileSync(fileURLToPath(harmonyResourceUrl("topic-relations.json")), "utf8")
) as TopicRelation[];

describe("课程数据资产完整性", () => {
  it("课程目录与生成资产应保持单一来源", () => {
    expect(rawCourseCatalog).toEqual(courseCatalog);
    expect(rawKnowledgeChunks).toEqual(allKnowledgeChunks);
    expect(rawExternalResources).toEqual(externalResources);
    expect(
      topicRelations.filter((relation) => relation.courseId === "acc101")
    ).toEqual(accountingTopicRelations);
    expect(
      rawLessonExperiences.filter((experience) => experience.courseId === "acc101")
    ).toEqual(accountingLessonExperiences);
    expect(
      topicRelations.filter((relation) => relation.courseId === "cet4" || relation.courseId === "cet6")
    ).toEqual(cetTopicRelations);
    expect(
      rawLessonExperiences.filter((experience) =>
        experience.courseId === "cet4" || experience.courseId === "cet6"
      )
    ).toEqual(cetLessonExperiences);
  });

  it("CET-4 与 CET-6 原创内容应完整关联同课程官方或开放媒体资源", () => {
    const resourcesById = new Map(
      externalResources.map((resource) => [resource.id, resource])
    );
    for (const courseId of ["cet4", "cet6"]) {
      const chunks = allKnowledgeChunks.filter((chunk) => chunk.courseId === courseId);
      const questions = allQuizzes
        .filter((quiz) => quiz.courseId === courseId)
        .flatMap((quiz) => quiz.questions);
      const experiences = cetLessonExperiences.filter(
        (experience) => experience.courseId === courseId
      );
      const activities = experiences.flatMap((experience) => experience.activities);
      expect(chunks).toHaveLength(5);
      expect(questions).toHaveLength(5);
      expect(experiences).toHaveLength(1);
      expect(activities).toHaveLength(2);

      for (const item of [...chunks, ...questions, ...activities]) {
        expect(item.provenance).toBe("original_instructional_content");
        expect(item.sourceResourceIds?.length).toBeGreaterThan(0);
        expect(new Set(item.sourceResourceIds).size).toBe(item.sourceResourceIds?.length);
        for (const resourceId of item.sourceResourceIds ?? []) {
          const resource = resourcesById.get(resourceId);
          expect(resource, `${courseId} 引用了未知资源 ${resourceId}`).toBeDefined();
          if (resource === undefined) {
            throw new Error(`${courseId} 引用了未知资源 ${resourceId}`);
          }
          expect(resourceCourseIds(resource)).toContain(courseId);
        }
      }

      const mediaResourceIds = experiences[0].mediaResourceIds ?? [];
      expect(mediaResourceIds).toHaveLength(1);
      const mediaResource = resourcesById.get(mediaResourceIds[0]);
      expect(mediaResource?.type).toBe("audio");
      expect(mediaResource?.media).toBeDefined();
      if (mediaResource === undefined) {
        throw new Error(`${courseId} 缺少媒体资源 ${mediaResourceIds[0]}`);
      }
      expect(resourceCourseIds(mediaResource)).toContain(courseId);
    }
  });

  it("acc101 原创内容应通过同课程资源 ID 形成可校验证据链", () => {
    const expectedResourceIds = [
      "acc101_outline_pdf_2026",
      "acc101_basic_accounting_standard",
    ];
    const resourcesById = new Map(
      externalResources.map((resource) => [resource.id, resource])
    );
    const expectEvidenceChain = (
      courseId: string,
      provenance: string | undefined,
      sourceResourceIds: string[] | undefined
    ) => {
      expect(provenance).toBe("original_instructional_content");
      expect(sourceResourceIds).toEqual(expectedResourceIds);
      expect(new Set(sourceResourceIds).size).toBe(sourceResourceIds?.length);
      for (const resourceId of sourceResourceIds ?? []) {
        const resource = resourcesById.get(resourceId);
        expect(resource).toBeDefined();
        expect(resource?.courseId).toBe(courseId);
      }
    };

    const accountingChunks = allKnowledgeChunks.filter(
      (chunk) => chunk.courseId === "acc101"
    );
    expect(accountingChunks).toHaveLength(5);
    for (const chunk of accountingChunks) {
      expectEvidenceChain(
        chunk.courseId,
        chunk.provenance,
        chunk.sourceResourceIds
      );
    }

    const accountingQuestions = allQuizzes
      .filter((quiz) => quiz.courseId === "acc101")
      .flatMap((quiz) => quiz.questions);
    expect(accountingQuestions).toHaveLength(5);
    for (const question of accountingQuestions) {
      expectEvidenceChain(
        "acc101",
        question.provenance,
        question.sourceResourceIds
      );
    }

    const accountingActivities = accountingLessonExperiences.flatMap(
      (experience) => experience.activities
    );
    expect(accountingActivities).toHaveLength(2);
    for (const activity of accountingActivities) {
      expectEvidenceChain(
        "acc101",
        activity.provenance,
        activity.sourceResourceIds
      );
    }
  });

  it("进程间通信案例应精确区分 System V 与 POSIX 消息选择语义", () => {
    const experience = rawLessonExperiences.find(
      (item) => item.courseId === "cs102" && item.topic === "进程间通信"
    );
    expect(experience?.caseBody).toContain(
      "System V 以 mtype/msgtyp 做类型选择"
    );
    expect(experience?.caseBody).toContain(
      "POSIX 以 msg_prio 选择最高优先级、同优先级最早消息"
    );
    expect(experience?.caseBody).toContain("两者均保留消息边界");
    expect(experience?.caseBody).toContain(
      "能否使用取决于是否持有描述符，而不是亲缘关系本身"
    );
    expect(experience?.caseBody).not.toContain("收件人可按类型筛选");
    expect(experience?.caseBody).not.toContain("只能用于关系密切的同事");

    const messageQueueKnowledge = rawKnowledgeChunks.find(
      (item) => item.id === "cs102_k45"
    );
    expect(messageQueueKnowledge?.text).toContain(
      "System V 消息携带 mtype，接收方用 msgtyp 做类型选择"
    );
    expect(messageQueueKnowledge?.text).toContain(
      "POSIX 消息携带 msg_prio，接收方优先取得最高优先级消息，同优先级取最早消息"
    );
    expect(messageQueueKnowledge?.text).toContain("两种接口都保留消息边界");
    expect(messageQueueKnowledge?.text).not.toContain("每个消息有类型");
  });

  it("匿名管道知识与活动应保留精确描述符、容量和 EOF 语义", () => {
    const chunk = rawKnowledgeChunks.find((item) => item.id === "cs102_k44");
    const experience = rawLessonExperiences.find(
      (item) => item.courseId === "cs102" && item.topic === "进程间通信"
    );
    const activity = experience?.activities.find(
      (item) => item.id === "cs102-进程间通信-1"
    );
    const knowledgeAndFeedback = `${chunk?.text ?? ""}\n${activity?.feedback ?? ""}`;

    expect(knowledgeAndFeedback).toContain("单向、无消息边界");
    expect(knowledgeAndFeedback).toContain("SCM_RIGHTS");
    expect(knowledgeAndFeedback).toContain("F_GETPIPE_SZ");
    expect(knowledgeAndFeedback).toContain("F_SETPIPE_SZ");
    expect(activity?.feedback).toContain("read 先返回已到达的数据");
    expect(activity?.feedback).toContain("读空且仍有写端打开时");
    expect(activity?.feedback).toContain("read 返回 0（EOF）");
    expect(activity?.content).toContain("#include <stdio.h>");
    expect(knowledgeAndFeedback).not.toContain("仅用于有亲缘关系");
    expect(knowledgeAndFeedback).not.toMatch(/通常\s*64KB/i);
    expect(activity?.feedback).not.toContain("父进程的 read 会一直阻塞");
  });

  it("知识切片应满足课程覆盖、长度和唯一性约束", () => {
    const ids = new Set<string>();

    for (const chunk of allKnowledgeChunks) {
      expect(ids.has(chunk.id)).toBe(false);
      ids.add(chunk.id);
      expect(COURSE_IDS).toContain(chunk.courseId);
      expect(chunk.topic?.trim().length).toBeGreaterThan(0);
      expect(chunk.source.trim().length).toBeGreaterThan(0);
      expect(chunk.text.trim().length).toBeGreaterThanOrEqual(100);
    }

    for (const courseId of COURSE_IDS) {
      const count = allKnowledgeChunks.filter(
        (chunk) => chunk.courseId === courseId
      ).length;
      expect(count).toBeGreaterThanOrEqual(MINIMUM_COUNTS[courseId].chunks);
    }
  });

  it("题库应满足课程题量、题目唯一性和答案约束", () => {
    const quizIds = new Set<string>();
    const questionIds = new Set<string>();
    const stems = new Set<string>();

    for (const quiz of allQuizzes) {
      expect(quizIds.has(quiz.quizId)).toBe(false);
      quizIds.add(quiz.quizId);
      expect(COURSE_IDS).toContain(quiz.courseId);
      expect(quiz.topic.trim().length).toBeGreaterThan(0);

      for (const question of quiz.questions) {
        expect(questionIds.has(question.id)).toBe(false);
        questionIds.add(question.id);
        expect(question.stem.trim().length).toBeGreaterThan(0);
        // 题干全局唯一
        const stemKey = question.stem.trim();
        expect(stems.has(stemKey)).toBe(false);
        stems.add(stemKey);
        expect(question.answer.trim().length).toBeGreaterThan(0);
        expect(question.explanation.trim().length).toBeGreaterThan(0);
        expect(["easy", "medium", "hard"]).toContain(question.difficulty);
        expect(question.tags?.length ?? 0).toBeGreaterThan(0);
        question.tags?.forEach((tag) => {
          expect(tag.trim().length).toBeGreaterThan(0);
          expect(tag.length).toBeLessThanOrEqual(12);
        });

        if (question.type === "choice") {
          expect(question.options).toHaveLength(4);
          expect(["A", "B", "C", "D"]).toContain(question.answer);
          const answerIndex = question.answer.charCodeAt(0) - "A".charCodeAt(0);
          expect(question.options?.[answerIndex]).toMatch(
            new RegExp(`^${question.answer}\\.`)
          );
        }
      }
    }

    for (const courseId of COURSE_IDS) {
      const count = allQuizzes
        .filter((quiz) => quiz.courseId === courseId)
        .reduce((sum, quiz) => sum + quiz.questions.length, 0);
      expect(count).toBeGreaterThanOrEqual(MINIMUM_COUNTS[courseId].questions);
    }
  });

  it("每门课程选择题数量应达到目录约束", () => {
    for (const courseId of COURSE_IDS) {
      const choiceCount = allQuizzes
        .filter((quiz) => quiz.courseId === courseId)
        .flatMap((quiz) => quiz.questions)
        .filter((question) => question.type === "choice").length;
      expect(choiceCount).toBeGreaterThanOrEqual(MINIMUM_COUNTS[courseId].choices);
    }
  });

  it("Web 与 HarmonyOS 题库应同源并完整覆盖正式 Topic", () => {
    const webQuestions: RawQuizQuestion[] = allQuizzes.flatMap((quiz) =>
      quiz.questions
        .filter((q) => q.type === "choice")
        .map((question) => ({
          id: question.id,
          courseId: quiz.courseId,
          topic: quiz.topic,
          question: question.stem,
          ...(question.options ? { options: question.options } : {}),
          answer: question.answer,
          explanation: question.explanation,
          difficulty: question.difficulty ?? "",
          tags: question.tags ?? [],
          ...(question.provenance !== undefined ?
            { provenance: question.provenance } : {}),
          ...(question.sourceResourceIds !== undefined ?
            { sourceResourceIds: question.sourceResourceIds } : {}),
        }))
    );

    expect(rawQuizQuestions).toEqual(webQuestions);

    const relationTopics = topicRelations.map(
      (relation) => `${relation.courseId}:${relation.topic}`
    ).sort();
    const rawTopics = Array.from(new Set(rawQuizQuestions.map(
      (question) => `${question.courseId}:${question.topic}`
    ))).sort();
    const webTopics = Array.from(new Set(webQuestions.map(
      (question) => `${question.courseId}:${question.topic}`
    ))).sort();

    const webQuizTopics = allQuizzes.map(
      (quiz) => `${quiz.courseId}:${quiz.topic}`
    ).sort();

    const knowledgeTopics = Array.from(new Set(allKnowledgeChunks.map(
      (chunk) => `${chunk.courseId}:${chunk.topic}`
    ))).sort();

    const computerScienceTopicKeys = expectedTopicKeys.filter(
      (key) => key.startsWith("cs")
    );
    expect(computerScienceTopicKeys).toHaveLength(33);
    expect(expectedTopicKeys).toHaveLength(36);
    expect(new Set(expectedTopicTitles).size).toBe(36);
    expect(relationTopics).toEqual(expectedTopicKeys);
    expect(rawTopics).toEqual(expectedTopicKeys);
    expect(webTopics).toEqual(expectedTopicKeys);
    expect(webQuizTopics).toEqual(expectedTopicKeys);
    expect(knowledgeTopics).toEqual(expectedTopicKeys);

    for (const question of rawQuizQuestions) {
      const expectedFields = EXPECTED_RAW_QUIZ_BASE_FIELDS.slice();
      if (question.provenance !== undefined) expectedFields.push("provenance");
      if (question.sourceResourceIds !== undefined) {
        expectedFields.push("sourceResourceIds");
      }
      expect(Object.keys(question).sort()).toEqual(expectedFields.sort());
    }

    for (const relation of topicRelations) {
      const topicQuestions = webQuestions.filter(
        (question) =>
          question.courseId === relation.courseId &&
          question.topic === relation.topic
      );
      const choiceQuestions = topicQuestions.filter(
        (question) => question.options?.length === 4
      );
      expect(choiceQuestions.length).toBe(5);

      for (const question of choiceQuestions) {
        expect(question.options).toHaveLength(4);
        question.options?.forEach((option, index) => {
          expect(option).toMatch(new RegExp(`^${String.fromCharCode(65 + index)}\\.`));
        });
        expect(["A", "B", "C", "D"]).toContain(question.answer);
        expect(["easy", "medium", "hard"]).toContain(question.difficulty);
        expect(question.tags.length).toBeGreaterThan(0);
        expect(question.explanation.match(/[^。！？.!?]+[。！？.!?]/g)?.length ?? 0)
          .toBeGreaterThanOrEqual(2);
      }
    }
  });

  it("HarmonyOS 测验与练习入口只能写入目录中的正式 Topic", () => {
    for (const fileName of HARMONY_TOPIC_ENTRY_FILES) {
      const source = readFileSync(fileURLToPath(harmonyPageUrl(fileName)), "utf8");
      const lines = source.split(/\r?\n/);
      let contextLineCount = 0;
      const contextMarkers = fileName === "Quiz.ets" ?
        [...TOPIC_CONTEXT_MARKERS, ...QUIZ_TOPIC_CONTEXT_MARKERS] : TOPIC_CONTEXT_MARKERS;

      for (let index = 0; index < lines.length; index += 1) {
        const line = lines[index];
        if (!contextMarkers.some((marker) => line.includes(marker))) continue;
        contextLineCount += 1;

        const literals = Array.from(line.matchAll(/(['"])(.*?)\1/g), (match) => match[2]);
        for (const literal of literals) {
          if (literal.length === 0 || TOPIC_STORAGE_KEYS.has(literal)) continue;
          expect(
            expectedTopicTitles,
            `${fileName}:${index + 1} 写入了非正式 Topic：${literal}`
          ).toContain(literal);
        }
      }

      expect(contextLineCount, `${fileName} 未匹配到 Topic 入口`).toBeGreaterThan(0);
    }
  });

  it("外部资源应使用受支持类型、HTTPS 地址和有效课程关联", () => {
    const ids = new Set<string>();
    const titles = new Set<string>();
    const urls = new Set<string>();

    for (const resource of externalResources) {
      expect(ids.has(resource.id)).toBe(false);
      ids.add(resource.id);
      // 标题全局唯一
      const titleKey = resource.title.trim();
      expect(titles.has(titleKey)).toBe(false);
      titles.add(titleKey);
      // URL 全局唯一
      const urlKey = resource.url.trim();
      expect(urls.has(urlKey)).toBe(false);
      urls.add(urlKey);
      expect(EXTERNAL_RESOURCE_TYPES).toContain(resource.type);
      expect(new URL(resource.url).protocol).toBe("https:");
      expect(resource.description.trim().length).toBeGreaterThanOrEqual(30);
      expect(resource.tags.length).toBeGreaterThan(0);
      if (resource.courseId) {
        expect(COURSE_IDS).toContain(resource.courseId);
      }
      if (resource.courseIds !== undefined) {
        expect(resource.courseId).toBeUndefined();
        expect(resource.courseIds.length).toBeGreaterThan(1);
        expect(new Set(resource.courseIds).size).toBe(resource.courseIds.length);
        for (const courseId of resource.courseIds) {
          expect(COURSE_IDS).toContain(courseId);
        }
      }
      if (resource.courseId === "acc101") {
        expect(resource.evidence).toBeDefined();
        expect(resource.evidence?.rightsStatus).toBe("link_only");
        expect(resource.evidence?.allowModification).toBe(false);
        expect(resource.evidence?.allowRedistribution).toBe(false);
        expect(resource.evidence?.sha256).toMatch(/^[A-F0-9]{64}$/);
        expect(resource.evidence?.accessibility.trim().length).toBeGreaterThan(0);
        expect(resource.evidence?.packagePolicy).toContain("HAP");
        expect(resource.evidence?.api12Rendering).toContain("API 12");
      }
      if (resource.type === "audio") {
        expect(resource.courseId === "cet4" || resource.courseId === "cet6").toBe(true);
        expect(resource.evidence?.rightsStatus).toBe("open_licensed");
        expect(resource.evidence?.allowModification).toBe(true);
        expect(resource.evidence?.allowRedistribution).toBe(true);
        expect(resource.evidence?.sha256).toMatch(/^[A-F0-9]{64}$/);
        expect(resource.media).toBeDefined();
        expect(new URL(resource.media?.mediaUrl ?? "").protocol).toBe("https:");
        expect(resource.media?.mimeType).toBe("audio/ogg");
        expect(resource.media?.byteLength).toBeGreaterThan(0);
        expect(resource.media?.durationMs).toBeGreaterThan(0);
        expect(resource.media?.transcript.trim().length).toBeGreaterThan(0);
        expect(resource.media?.transcriptTimed).toBe(false);
        expect(resource.media?.attribution.trim().length).toBeGreaterThan(0);
        expect(new URL(resource.media?.licenseUrl ?? "").protocol).toBe("https:");
        const rawBytes = readFileSync(fileURLToPath(
          harmonyRawFileUrl(resource.media?.rawFilePath ?? "")
        ));
        expect(rawBytes.byteLength).toBe(resource.media?.byteLength);
        expect(createHash("sha256").update(rawBytes).digest("hex").toUpperCase())
          .toBe(resource.evidence?.sha256);
      } else {
        expect(resource.media).toBeUndefined();
      }
    }

    for (const type of EXTERNAL_RESOURCE_TYPES) {
      expect(externalResources.some((resource) => resource.type === type)).toBe(true);
    }
  });

});
