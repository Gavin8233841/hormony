import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { allKnowledgeChunks, courseCatalog } from "@/lib/data";

const harmonySource = (relativePath: string) => readFileSync(fileURLToPath(new URL(
  `../../../../harmonyos/entry/src/main/ets/${relativePath}`,
  import.meta.url
)), "utf8");

const entryAbilitySource = harmonySource("entryability/EntryAbility.ets");
const contentRepositorySource = harmonySource("common/LearningContentRepository.ets");
const planSource = harmonySource("pages/Plan.ets");
const practiceSource = harmonySource("pages/Practice.ets");

describe("非计算机多学科真实学习闭环", () => {
  it("EntryAbility 从生成目录同步 ArkData 并保留仓储合并入口", () => {
    expect(contentRepositorySource).toContain(
      "const COURSE_CATALOG_PATH: string = 'learning/course-catalog.json'"
    );
    expect(contentRepositorySource).toContain(
      "readJson<CourseCatalogItem[]>(COURSE_CATALOG_PATH)"
    );
    expect(entryAbilitySource).toContain(
      "LearningContentRepository.getCourseCatalog()"
    );
    expect(entryAbilitySource).toContain(
      "LocalLearningRepository.syncCourseCatalog(catalog)"
    );
    expect(entryAbilitySource).not.toContain("this.buildCourse('cs101'");
  });

  it("CET-4 与 CET-6 目标应进入同一目录并指向正式基线 Topic", () => {
    for (const expected of [
      {
        id: "cet4",
        title: "大学英语四级（CET-4）",
        baselineTopic: "CET-4连续短语听辨与转写复核",
      },
      {
        id: "cet6",
        title: "大学英语六级（CET-6）",
        baselineTopic: "CET-6讲座关键词骨架与延迟复述",
      },
    ]) {
      const course = courseCatalog.find((item) => item.id === expected.id);
      expect(course).toMatchObject({
        ...expected,
        domain: "language",
        goalType: "language_exam",
        diagnosticFirst: true,
      });
      expect(allKnowledgeChunks.some((chunk) =>
        chunk.courseId === expected.id && chunk.topic === expected.baselineTopic
      )).toBe(true);
    }
    expect(contentRepositorySource).toContain(
      "for (const courseId of item.courseIds ?? [])"
    );
  });

  it("目标选择先校验正式 Topic，再进入基线诊断", () => {
    const methodStart = planSource.indexOf(
      "private selectGoalOption(option: CourseCatalogItem): void"
    );
    const methodEnd = planSource.indexOf("\n  private actionLabel", methodStart);
    const method = planSource.slice(methodStart, methodEnd);
    const topicGuard = method.indexOf(
      "LearningContentRepository.getTopics(option.id).includes(option.baselineTopic)"
    );
    const courseWrite = method.indexOf("'selectedCourseId', option.id");
    const topicWrite = method.indexOf("'selectedPracticeTopic', option.baselineTopic");
    const diagnosticWrite = method.indexOf("'baselineDiagnosticActive', true");
    const navigation = method.indexOf("this.openBaselineDiagnostic()");

    expect(planSource).toContain("@State goalOptions: CourseCatalogItem[] = []");
    expect(planSource).toContain(
      "this.goalOptions = LearningContentRepository.getCourseCatalog()"
    );
    expect(method).toContain("if (!option.diagnosticFirst) return");
    expect(topicGuard).toBeGreaterThan(-1);
    expect(courseWrite).toBeGreaterThan(topicGuard);
    expect(topicWrite).toBeGreaterThan(courseWrite);
    expect(diagnosticWrite).toBeGreaterThan(topicWrite);
    expect(navigation).toBeGreaterThan(diagnosticWrite);

    const navigationStart = planSource.indexOf(
      "private openBaselineDiagnostic(): void"
    );
    const navigationEnd = planSource.indexOf(
      "\n  private actionLabel",
      navigationStart
    );
    const navigationMethod = planSource.slice(navigationStart, navigationEnd);
    expect(navigationMethod).toContain("url: 'pages/Practice'");
    expect(navigationMethod).toContain("'pendingPlanGoal', ''");
    expect(navigationMethod).toContain("'baselineDiagnosticActive', false");
    expect(navigationMethod).toContain("'无法打开基线诊断，请稍后重试'");
  });

  it("诊断提交写回 ArkData，并将证据化画像带回个性计划", () => {
    const appendResult = practiceSource.indexOf(
      "LocalLearningRepository.appendQuizResult(result)"
    );
    const receipt = practiceSource.indexOf("this.applyWriteReceipt(receipt)", appendResult);
    const submitted = practiceSource.indexOf("this.submitted = true", receipt);
    const planMethod = practiceSource.indexOf("private openPersonalPlan(): void");
    const goalWrite = practiceSource.indexOf("'pendingPlanGoal', goal", planMethod);
    const planNavigation = practiceSource.indexOf("url: 'pages/Plan'", goalWrite);

    expect(appendResult).toBeGreaterThan(-1);
    expect(receipt).toBeGreaterThan(appendResult);
    expect(submitted).toBeGreaterThan(receipt);
    expect(practiceSource).toContain("Button('根据诊断生成个性计划')");
    expect(goalWrite).toBeGreaterThan(planMethod);
    expect(planNavigation).toBeGreaterThan(goalWrite);
    expect(planSource).toContain("AppStorage.get<string>('pendingPlanGoal')");
    expect(planSource).toContain("profile: profile ?? undefined");
  });

  it("题后可追问 Agent、进入错题复习并显示掌握与下一步", () => {
    expect(practiceSource).toContain("this.askTutor(detail)");
    expect(practiceSource).toContain("this.openMistakeBook()");
    expect(practiceSource).toContain("本机学习闭环已更新");
    expect(practiceSource).toContain("this.writeBackTopicAccuracy");
    expect(practiceSource).toContain("this.writeBackCourseProgress");
  });
});
