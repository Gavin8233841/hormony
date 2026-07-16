import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const harmonyPageSource = (fileName: string) =>
  readFileSync(
    fileURLToPath(
      new URL(
        `../../../../harmonyos/entry/src/main/ets/pages/${fileName}`,
        import.meta.url
      )
    ),
    "utf8"
  );

const mistakeBookSource = harmonyPageSource("MistakeBook.ets");
const practiceSource = harmonyPageSource("Practice.ets");

describe("HarmonyOS 错题复习入口契约", () => {
  it("页面重启后应从 ArkData 仓库重建到期优先的复习队列", () => {
    expect(mistakeBookSource).toContain("aboutToAppear(): void");
    expect(mistakeBookSource).toContain("this.loadItems()");

    const dueRead = mistakeBookSource.indexOf(
      "await LocalLearningRepository.getDueReviewItems(now)"
    );
    const activeRead = mistakeBookSource.indexOf(
      "await LocalLearningRepository.getReviewItems()"
    );
    const dueFirstMerge = mistakeBookSource.indexOf(
      "this.items = dueItems.concat(pendingItems)"
    );

    expect(dueRead).toBeGreaterThan(-1);
    expect(activeRead).toBeGreaterThan(dueRead);
    expect(dueFirstMerge).toBeGreaterThan(activeRead);
    expect(mistakeBookSource).toContain(
      "new Date(item.nextReviewAt).getTime() <= this.nowTimestamp"
    );
    expect(mistakeBookSource).toContain(
      "new Date(left.nextReviewAt).getTime() - new Date(right.nextReviewAt).getTime()"
    );
    expect(mistakeBookSource).toContain("'现在复习'");
    expect(mistakeBookSource).toContain("'重新读取'");
  });

  it("未到期项应继续显示但不能写入复习 ID 或进入练习", () => {
    expect(mistakeBookSource).toContain(
      "activeItems.filter((item: ReviewItem): boolean => !dueIds.includes(item.id))"
    );
    expect(mistakeBookSource).toContain(
      "this.items = dueItems.concat(pendingItems)"
    );

    const retryStart = mistakeBookSource.indexOf(
      "private retry(item: ReviewItem): void"
    );
    const buildStart = mistakeBookSource.indexOf("\n  build()", retryStart);
    const retrySource = mistakeBookSource.slice(retryStart, buildStart);
    const dueGuard = retrySource.indexOf("if (!this.isDue(item))");
    const topicGuard = retrySource.indexOf(
      "if (!LearningContentRepository.getTopics(item.courseId).includes(item.topic))"
    );
    const reviewWrite = retrySource.indexOf("'selectedReviewItemId', item.id");
    const notDueBranch = retrySource.slice(dueGuard, topicGuard);

    expect(dueGuard).toBeGreaterThan(-1);
    expect(topicGuard).toBeGreaterThan(dueGuard);
    expect(reviewWrite).toBeGreaterThan(topicGuard);
    expect(notDueBranch).toContain("'这道题尚未到复习时间，请按计划巩固'");
    expect(notDueBranch).toContain("return;");
    expect(notDueBranch).not.toContain("selectedReviewItemId");

    const buttonStart = mistakeBookSource.indexOf("Button(this.isDue(item) ?");
    const buttonEnd = mistakeBookSource.indexOf(
      ".onClick((): void => { this.retry(item); })",
      buttonStart
    );
    const buttonSource = mistakeBookSource.slice(buttonStart, buttonEnd);

    expect(buttonStart).toBeGreaterThan(-1);
    expect(buttonEnd).toBeGreaterThan(buttonStart);
    expect(buttonSource).toContain(": '等待到期'");
    expect(buttonSource).toContain(".enabled(this.isDue(item))");
  });

  it("错题入口应校验精确 Topic 并完整传递课程、Topic 与复习项 ID", () => {
    const retryStart = mistakeBookSource.indexOf(
      "private retry(item: ReviewItem): void"
    );
    const buildStart = mistakeBookSource.indexOf("\n  build()", retryStart);
    const retrySource = mistakeBookSource.slice(retryStart, buildStart);

    expect(retrySource).toContain(
      "LearningContentRepository.getTopics(item.courseId).includes(item.topic)"
    );

    const courseWrite = retrySource.indexOf("'selectedCourseId', item.courseId");
    const topicWrite = retrySource.indexOf("'selectedPracticeTopic', item.topic");
    const reviewWrite = retrySource.indexOf("'selectedReviewItemId', item.id");
    const practiceNavigation = retrySource.indexOf("url: 'pages/Practice'");

    expect(courseWrite).toBeGreaterThan(-1);
    expect(topicWrite).toBeGreaterThan(courseWrite);
    expect(reviewWrite).toBeGreaterThan(topicWrite);
    expect(practiceNavigation).toBeGreaterThan(reviewWrite);
    expect(practiceSource).toContain(
      "AppStorage.get<string>('selectedReviewItemId')"
    );
    expect(practiceSource).toContain(
      "AppStorage.setOrCreate<string>('selectedReviewItemId', '')"
    );
    expect(practiceSource).toContain(
      "item.id === selectedReviewItemId && item.courseId === this.courseId && item.topic === this.topic"
    );
  });

  it("有完整四项选项时重练原题，否则明确降级为同主题精选题", () => {
    expect(mistakeBookSource).toContain("options.length === labels.length");
    expect(mistakeBookSource).toContain(
      "options.every((option: string): boolean => option.trim().length > 0)"
    );
    expect(mistakeBookSource).toContain(
      "option.trim().toUpperCase().startsWith(labels[index] + '.')"
    );
    expect(mistakeBookSource).toContain("'重练原题'");
    expect(mistakeBookSource).toContain("'练同主题精选题'");
    expect(mistakeBookSource).toContain(
      "'此记录未保留完整选项，将使用同主题精选题巩固'"
    );
    expect(practiceSource).toContain("let options = review.options ?? []");
    expect(practiceSource).toContain("if (!this.validReviewOptions(options))");
    expect(practiceSource).toContain(
      "'原错题缺少可重练选项，已切换为同主题精选题'"
    );
    expect(practiceSource).toContain("review.courseId !== this.courseId");
    expect(practiceSource).toContain("review.topic !== this.topic");
    expect(practiceSource).toContain(
      "ordered.push({ question: selectedQuestion, reviewItemId: selectedReview.id })"
    );
  });

  it("原题 ID 应用于题组去重，复习项 ID 应独立用于写回", () => {
    const methodStart = practiceSource.indexOf(
      "private questionFromReview(review: ReviewItem, available: CuratedQuestion[])"
    );
    const methodEnd = practiceSource.indexOf(
      "\n  private validReviewOptions",
      methodStart
    );
    const questionFromReviewSource = practiceSource.slice(methodStart, methodEnd);

    expect(methodStart).toBeGreaterThan(-1);
    expect(methodEnd).toBeGreaterThan(methodStart);
    expect(questionFromReviewSource).toContain("id: review.questionId");
    expect(questionFromReviewSource).not.toContain("id: review.id");
    expect(practiceSource).toContain(
      "ordered.push({ question: selectedQuestion, reviewItemId: selectedReview.id })"
    );
    expect(practiceSource).toContain(
      "usedQuestionIds.push(selectedQuestion.id)"
    );
    expect(practiceSource).toContain(
      "!usedQuestionIds.includes(question.id)"
    );
  });
});
