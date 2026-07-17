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
    expect(mistakeBookSource).toContain("onPageShow(): void");
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

  it("从练习返回或跨日再次显示时应刷新当前时间与 ArkData 队列", () => {
    const pageShowStart = mistakeBookSource.indexOf("onPageShow(): void");
    const loadItemsStart = mistakeBookSource.indexOf(
      "\n  private async loadItems(): Promise<void>",
      pageShowStart
    );
    const pageShowSource = mistakeBookSource.slice(pageShowStart, loadItemsStart);

    expect(pageShowStart).toBeGreaterThan(-1);
    expect(loadItemsStart).toBeGreaterThan(pageShowStart);
    expect(pageShowSource).toContain("this.loadItems()");

    const loadItemsEnd = mistakeBookSource.indexOf(
      "\n  private courseTitle",
      loadItemsStart
    );
    const loadItemsSource = mistakeBookSource.slice(loadItemsStart, loadItemsEnd);
    const refreshNow = loadItemsSource.indexOf("const now = new Date()");
    const captureTimestamp = loadItemsSource.indexOf(
      "const nowTimestamp = now.getTime()",
      refreshNow
    );
    const dueRead = loadItemsSource.indexOf(
      "await LocalLearningRepository.getDueReviewItems(now)",
      captureTimestamp
    );
    const activeRead = loadItemsSource.indexOf(
      "await LocalLearningRepository.getReviewItems()",
      dueRead
    );
    const staleGuard = loadItemsSource.indexOf(
      "if (this.loadRunId !== runId) return",
      activeRead
    );
    const publishTimestamp = loadItemsSource.indexOf(
      "this.nowTimestamp = nowTimestamp",
      staleGuard
    );

    expect(loadItemsEnd).toBeGreaterThan(loadItemsStart);
    expect(refreshNow).toBeGreaterThan(-1);
    expect(captureTimestamp).toBeGreaterThan(refreshNow);
    expect(dueRead).toBeGreaterThan(captureTimestamp);
    expect(activeRead).toBeGreaterThan(dueRead);
    expect(staleGuard).toBeGreaterThan(activeRead);
    expect(publishTimestamp).toBeGreaterThan(staleGuard);
  });

  it("连续显示触发的旧读取不得覆盖较新的复习快照", () => {
    const loadItemsStart = mistakeBookSource.indexOf(
      "private async loadItems(): Promise<void>"
    );
    const loadItemsEnd = mistakeBookSource.indexOf(
      "\n  private courseTitle",
      loadItemsStart
    );
    const loadItemsSource = mistakeBookSource.slice(loadItemsStart, loadItemsEnd);
    expect(loadItemsStart).toBeGreaterThan(-1);
    expect(loadItemsEnd).toBeGreaterThan(loadItemsStart);
    const nextRun = loadItemsSource.indexOf(
      "const runId = this.loadRunId + 1"
    );
    const activateRun = loadItemsSource.indexOf(
      "this.loadRunId = runId",
      nextRun
    );
    const activeRead = loadItemsSource.indexOf(
      "await LocalLearningRepository.getReviewItems()"
    );
    const catchStart = loadItemsSource.indexOf("} catch (error)", activeRead);
    const finallyStart = loadItemsSource.indexOf("} finally {", catchStart);
    const successSource = loadItemsSource.slice(activeRead, catchStart);
    const catchSource = loadItemsSource.slice(catchStart, finallyStart);
    const finallySource = loadItemsSource.slice(finallyStart);

    expect(nextRun).toBeGreaterThan(-1);
    expect(activateRun).toBeGreaterThan(nextRun);
    expect(activeRead).toBeGreaterThan(-1);
    expect(catchStart).toBeGreaterThan(activeRead);
    expect(finallyStart).toBeGreaterThan(catchStart);
    expect(successSource.indexOf("if (this.loadRunId !== runId) return"))
      .toBeLessThan(successSource.indexOf("this.items ="));
    expect(catchSource.indexOf("if (this.loadRunId !== runId) return"))
      .toBeLessThan(catchSource.indexOf("this.items = []"));
    expect(finallySource).toContain(
      "if (this.loadRunId === runId) this.loading = false"
    );
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

  it("旧 AI 错题缺少选项时替代题仍应推进原复习项且不在题组重复", () => {
    const loadStart = practiceSource.indexOf(
      "private async loadQuestions(selectedReviewItemId: string)"
    );
    const loadEnd = practiceSource.indexOf(
      "\n  private questionFromReview",
      loadStart
    );
    const loadSource = practiceSource.slice(loadStart, loadEnd);
    const missingOriginal = loadSource.indexOf("if (selectedQuestion !== null)");
    const fallbackLookup = loadSource.indexOf(
      "const fallbackQuestion = available.find",
      missingOriginal
    );
    const exactCourse = loadSource.indexOf(
      "question.courseId === this.courseId",
      fallbackLookup
    );
    const exactTopic = loadSource.indexOf(
      "question.topic === this.topic",
      exactCourse
    );
    const unavailable = loadSource.indexOf(
      "if (fallbackQuestion === undefined)",
      exactTopic
    );
    const bindOriginalReview = loadSource.indexOf(
      "ordered.push({ question: fallbackQuestion, reviewItemId: selectedReview.id })",
      unavailable
    );
    const reserveQuestionId = loadSource.indexOf(
      "usedQuestionIds.push(fallbackQuestion.id)",
      bindOriginalReview
    );
    const remainingQuestions = loadSource.indexOf(
      "for (const question of available)",
      reserveQuestionId
    );

    expect(loadStart).toBeGreaterThan(-1);
    expect(loadEnd).toBeGreaterThan(loadStart);
    expect(fallbackLookup).toBeGreaterThan(missingOriginal);
    expect(exactCourse).toBeGreaterThan(fallbackLookup);
    expect(exactTopic).toBeGreaterThan(exactCourse);
    expect(unavailable).toBeGreaterThan(exactTopic);
    const unavailableBranch = loadSource.slice(unavailable, bindOriginalReview);
    expect(unavailableBranch).toContain("原错题缺少可重练选项，且同主题暂无精选题");
    expect(unavailableBranch).toContain("this.hasError = true");
    expect(unavailableBranch).toContain("return;");
    expect(bindOriginalReview).toBeGreaterThan(unavailable);
    expect(reserveQuestionId).toBeGreaterThan(bindOriginalReview);
    expect(remainingQuestions).toBeGreaterThan(reserveQuestionId);
    expect(loadSource).toContain(
      "this.reviewItemIds = selectedItems.map((item: PracticeQuestionItem): string => item.reviewItemId)"
    );
  });

  it("练习加载失败后应保留精确错题 ID 并在空题错误态原地重试", () => {
    const appearStart = practiceSource.indexOf("aboutToAppear(): void");
    const resetStart = practiceSource.indexOf(
      "\n  private resetPageState(): void",
      appearStart
    );
    const appearSource = practiceSource.slice(appearStart, resetStart);
    expect(appearStart).toBeGreaterThan(-1);
    expect(resetStart).toBeGreaterThan(appearStart);
    const retainAt = appearSource.indexOf(
      "this.selectedReviewItemId = (AppStorage.get<string>('selectedReviewItemId') ?? '').trim()"
    );
    const clearAt = appearSource.indexOf(
      "AppStorage.setOrCreate<string>('selectedReviewItemId', '')"
    );

    expect(retainAt).toBeGreaterThan(-1);
    expect(clearAt).toBeGreaterThan(retainAt);
    expect(practiceSource).toContain(
      "private selectedReviewItemId: string = ''"
    );
    expect(appearSource).toContain("this.reloadQuestions()");

    const reloadStart = practiceSource.indexOf(
      "private async reloadQuestions(): Promise<void>"
    );
    const reloadEnd = practiceSource.indexOf(
      "\n  private async loadQuestions",
      reloadStart
    );
    const reloadSource = practiceSource.slice(reloadStart, reloadEnd);
    expect(reloadStart).toBeGreaterThan(-1);
    expect(reloadEnd).toBeGreaterThan(reloadStart);
    expect(reloadSource).toContain(
      "await this.loadQuestions(this.selectedReviewItemId)"
    );
    expect(reloadSource).toContain(
      "this.message = '本地练习加载失败，请重试'"
    );
    expect(reloadSource).toContain("this.loadRetryAvailable = true");
    expect(reloadSource).not.toContain("请重新进入");

    const retryButtonStart = practiceSource.indexOf("Button('重新加载')");
    const retryButtonEnd = practiceSource.indexOf(
      ".onClick((): void => { this.reloadQuestions(); })",
      retryButtonStart
    );
    expect(retryButtonStart).toBeGreaterThan(-1);
    expect(retryButtonEnd).toBeGreaterThan(retryButtonStart);
    expect(practiceSource.slice(retryButtonStart - 500, retryButtonStart))
      .toContain("this.loadRetryAvailable");
  });
});
