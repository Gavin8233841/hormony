import { AnswerOption, GradientHeader, ReviewDetailRow } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LearningContentRepository } from '../common/LearningContentRepository';
import {
  AnswerDraftClearedError,
  LocalLearningRepository,
  QuizResultConflictError,
  QuizResultVerificationUnavailableError
} from '../common/LocalLearningRepository';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  CuratedPracticeDraft,
  LearningCuratedQuestion as CuratedQuestion,
  LearningQuizResult as QuizResult,
  LearningQuizResultDetail as QuizResultDetail,
  LearningReviewItem as ReviewItem,
  QuizWriteReceipt
} from '../model/LearningMetadataModels';

const EMPTY_QUESTION: CuratedQuestion = {
  id: '',
  courseId: '',
  topic: '',
  question: '',
  options: [],
  answer: '',
  explanation: ''
};

interface PracticeQuestionItem {
  question: CuratedQuestion;
  reviewItemId: string;
}

@Entry
@Component
struct PracticePage {
  @State courseId: string = 'cs101';
  @State courseTitle: string = '数据结构';
  @State topic: string = '';
  @State questions: CuratedQuestion[] = [];
  @State activeQuestion: CuratedQuestion = EMPTY_QUESTION;
  @State answers: string[] = [];
  @State activeAnswer: string = '';
  @State currentIndex: number = 0;
  @State submitted: boolean = false;
  @State saving: boolean = false;
  @State correctCount: number = 0;
  @State details: QuizResultDetail[] = [];
  @State expandedDetailId: string = '';
  @State message: string = '';
  @State hasError: boolean = false;
  @State loading: boolean = false;
  @State loadRetryAvailable: boolean = false;
  @State writeBackTotalQuestions: number = 0;
  @State writeBackActiveReviews: number = 0;
  @State writeBackTopicAccuracy: number = 0;
  @State writeBackActivityCount: number = 0;
  @State writeBackCourseProgress: number = 0;
  @State writeBackBlocked: boolean = false;
  @State draftLoading: boolean = false;
  @State draftSaveFailed: boolean = false;
  @State draftReadFailed: boolean = false;
  @State discardingDraft: boolean = false;
  @State submittedDraftCleanupPending: boolean = false;
  @State cleaningSubmittedDraft: boolean = false;
  private reviewItemIds: string[] = [];
  private selectedReviewItemId: string = '';
  private attemptId: string = '';
  private attemptSubmittedAt: string = '';
  private draftCreated: boolean = false;
  private lifecycleRunId: number = 0;
  private loadRunId: number = 0;
  private draftReadRunId: number = 0;
  private draftSaveRunId: number = 0;
  private pageActive: boolean = false;
  private contextInitialized: boolean = false;

  onPageShow(): void {
    this.lifecycleRunId += 1;
    const lifecycleRunId = this.lifecycleRunId;
    this.pageActive = true;
    if (!this.contextInitialized) {
      this.contextInitialized = true;
      if (!this.initializeContext()) return;
    }
    if (!this.submitted && this.questions.length > 0 && this.attemptId.length > 0 && !this.loading) {
      this.revalidateDraft(lifecycleRunId);
      return;
    }
    if (!this.submitted && this.questions.length === 0 && !this.loading) {
      this.restoreDraft(lifecycleRunId);
    }
  }

  onPageHide(): void {
    this.pageActive = false;
    this.lifecycleRunId += 1;
    this.loadRunId += 1;
    this.draftReadRunId += 1;
    this.loading = false;
    this.draftLoading = false;
    if (!this.submitted && this.draftCreated && this.questions.length > 0 && this.attemptId.length > 0) {
      this.queueDraftSave(false);
    }
  }

  onBackPress(): boolean {
    if (this.discardingDraft) {
      this.message = '正在放弃本轮草稿，请稍候';
      this.hasError = false;
      return true;
    }
    if (this.saving) {
      this.message = '答题结果正在写入本机，请稍候';
      this.hasError = false;
      return true;
    }
    if (this.submitted && this.submittedDraftCleanupPending) {
      this.goBack();
      return true;
    }
    if (!this.submitted && this.draftCreated && this.questions.length > 0 && this.attemptId.length > 0) {
      this.queueDraftSave(false);
    }
    return false;
  }

  private initializeContext(): boolean {
    this.resetPageState();
    this.courseId = AppStorage.get<string>('selectedCourseId') ?? 'cs101';
    this.courseTitle = AppStorage.get<string>('selectedCourseTitle') ?? '数据结构';
    const selectedTopic = (AppStorage.get<string>('selectedPracticeTopic') ?? '').trim();
    this.selectedReviewItemId = (AppStorage.get<string>('selectedReviewItemId') ?? '').trim();
    AppStorage.setOrCreate<string>('selectedReviewItemId', '');
    const courseTopics = LearningContentRepository.getTopics(this.courseId);
    this.topic = courseTopics.includes(selectedTopic) ? selectedTopic : '';
    if (this.topic.length === 0) {
      this.message = selectedTopic.length > 0 ?
        '入口主题不属于当前课程，无法加载精选练习' : '请选择课程中的正式主题后再练习';
      this.hasError = true;
      return false;
    }
    return true;
  }

  private resetPageState(): void {
    this.questions = [];
    this.activeQuestion = EMPTY_QUESTION;
    this.answers = [];
    this.activeAnswer = '';
    this.currentIndex = 0;
    this.submitted = false;
    this.saving = false;
    this.correctCount = 0;
    this.details = [];
    this.expandedDetailId = '';
    this.message = '';
    this.hasError = false;
    this.loading = false;
    this.loadRetryAvailable = false;
    this.reviewItemIds = [];
    this.selectedReviewItemId = '';
    this.attemptId = '';
    this.attemptSubmittedAt = '';
    this.draftCreated = false;
    this.draftSaveFailed = false;
    this.draftReadFailed = false;
    this.writeBackTotalQuestions = 0;
    this.writeBackActiveReviews = 0;
    this.writeBackTopicAccuracy = 0;
    this.writeBackActivityCount = 0;
    this.writeBackCourseProgress = 0;
    this.writeBackBlocked = false;
    this.submittedDraftCleanupPending = false;
    this.cleaningSubmittedDraft = false;
  }

  private isActiveLifecycle(lifecycleRunId: number): boolean {
    return this.pageActive && this.lifecycleRunId === lifecycleRunId;
  }

  private isActiveLoad(runId: number, lifecycleRunId: number): boolean {
    return this.isActiveLifecycle(lifecycleRunId) && this.loadRunId === runId && this.loading;
  }

  private async revalidateDraft(lifecycleRunId: number): Promise<void> {
    const attemptId = this.attemptId;
    try {
      const draft = await LocalLearningRepository.getCuratedPracticeDraft(
        this.courseId, this.topic, this.selectedReviewItemId);
      if (!this.isActiveLifecycle(lifecycleRunId) || this.attemptId !== attemptId) return;
      if (draft === null || draft.attemptId !== attemptId) this.handleClearedDraft();
    } catch (error) {
      if (!this.isActiveLifecycle(lifecycleRunId) || this.attemptId !== attemptId) return;
      this.message = '本地练习草稿状态校验失败，请重试';
      this.hasError = true;
    }
  }

  private async restoreDraft(lifecycleRunId: number): Promise<void> {
    const runId = this.draftReadRunId + 1;
    this.draftReadRunId = runId;
    this.draftLoading = true;
    try {
      const draft = await LocalLearningRepository.getCuratedPracticeDraft(
        this.courseId, this.topic, this.selectedReviewItemId);
      if (!this.isActiveLifecycle(lifecycleRunId) || this.draftReadRunId !== runId) return;
      this.draftReadFailed = false;
      if (draft === null) {
        this.draftLoading = false;
        this.reloadQuestions();
        return;
      }
      this.courseTitle = draft.courseTitle;
      this.questions = draft.questions;
      this.reviewItemIds = draft.reviewItemIds.slice();
      this.answers = draft.answers.slice();
      this.currentIndex = draft.currentIndex;
      this.activeQuestion = draft.questions[draft.currentIndex];
      this.activeAnswer = draft.answers[draft.currentIndex] ?? '';
      this.attemptId = draft.attemptId;
      this.attemptSubmittedAt = draft.attemptSubmittedAt ?? '';
      this.draftCreated = true;
      this.message = this.attemptSubmittedAt.length > 0 ?
        '已恢复待确认写回的练习草稿，请重试提交，不会重复累计' :
        '已恢复上次未提交草稿，已答 ' + this.answeredCount().toString() + ' / ' +
          this.questions.length.toString() + ' 题';
      this.hasError = false;
    } catch (error) {
      if (!this.isActiveLifecycle(lifecycleRunId) || this.draftReadRunId !== runId) return;
      this.message = '本地练习草稿读取失败，请重试';
      this.hasError = true;
      this.loadRetryAvailable = true;
      this.draftReadFailed = true;
    } finally {
      if (this.isActiveLifecycle(lifecycleRunId) && this.draftReadRunId === runId) {
        this.draftLoading = false;
      }
    }
  }

  private answeredCount(): number {
    return this.answers.filter((answer: string): boolean => answer.length > 0).length;
  }

  private buildDraft(): CuratedPracticeDraft {
    return {
      schemaVersion: 1,
      attemptId: this.attemptId,
      courseId: this.courseId,
      courseTitle: this.courseTitle,
      topic: this.topic,
      selectedReviewItemId: this.selectedReviewItemId,
      questions: this.questions,
      reviewItemIds: this.reviewItemIds,
      answers: this.answers,
      currentIndex: this.currentIndex,
      attemptSubmittedAt: this.attemptSubmittedAt.length > 0 ? this.attemptSubmittedAt : undefined,
      updatedAt: new Date().toISOString()
    };
  }

  private async persistDraft(): Promise<void> {
    if (this.submitted || this.questions.length === 0 || this.attemptId.length === 0) return;
    if (!this.draftCreated) throw new Error('精选练习草稿尚未创建');
    await LocalLearningRepository.saveCuratedPracticeDraft(this.buildDraft());
  }

  private queueDraftSave(showFailure: boolean = true): void {
    if (this.discardingDraft || !this.draftCreated) return;
    const runId = this.draftSaveRunId + 1;
    this.draftSaveRunId = runId;
    this.persistDraft().then((): void => {
      if (this.draftSaveRunId !== runId) return;
      if (this.draftSaveFailed) {
        this.draftSaveFailed = false;
        this.message = '草稿已保存到本机';
        this.hasError = false;
      }
    }).catch((error: Error): void => {
      if (this.draftSaveRunId !== runId) return;
      if (error instanceof AnswerDraftClearedError) {
        this.handleClearedDraft();
        return;
      }
      if (!showFailure) return;
      this.draftSaveFailed = true;
      this.message = '草稿保存失败，当前答案仍保留，请重试保存';
      this.hasError = true;
    });
  }

  private handleClearedDraft(): void {
    const selectedReviewItemId = this.selectedReviewItemId;
    this.resetPageState();
    this.selectedReviewItemId = selectedReviewItemId;
    this.message = '本轮草稿已在其他页面结束，正在同步最新状态';
    this.hasError = false;
    if (this.pageActive) this.restoreDraft(this.lifecycleRunId);
  }

  private async discardCurrentDraft(): Promise<void> {
    if (this.saving || this.discardingDraft || this.attemptId.length === 0) return;
    const attemptId = this.attemptId;
    const selectedReviewItemId = this.selectedReviewItemId;
    const lifecycleRunId = this.lifecycleRunId;
    this.discardingDraft = true;
    this.draftSaveRunId += 1;
    try {
      await LocalLearningRepository.clearCuratedPracticeDraft(attemptId);
      this.resetPageState();
      this.selectedReviewItemId = selectedReviewItemId;
      if (!this.isActiveLifecycle(lifecycleRunId)) return;
      this.message = '已放弃本轮草稿，正在重新加载练习';
      this.discardingDraft = false;
      await this.reloadQuestions();
    } catch (error) {
      this.message = '草稿清除失败，请重试';
      this.hasError = true;
    } finally {
      this.discardingDraft = false;
    }
  }

  private goToPreviousQuestion(): void {
    if (this.discardingDraft || this.currentIndex <= 0) return;
    this.currentIndex -= 1;
    this.activeQuestion = this.questions[this.currentIndex];
    this.activeAnswer = this.answers[this.currentIndex] ?? '';
    this.queueDraftSave();
  }

  private goToNextQuestion(): void {
    if (this.discardingDraft || this.currentIndex >= this.questions.length - 1 ||
      this.activeAnswer.length === 0) return;
    this.currentIndex += 1;
    this.activeQuestion = this.questions[this.currentIndex];
    this.activeAnswer = this.answers[this.currentIndex] ?? '';
    this.queueDraftSave();
  }

  private async goBack(): Promise<void> {
    if (this.discardingDraft) {
      this.message = '正在放弃本轮草稿，请稍候';
      this.hasError = false;
      return;
    }
    if (this.saving) {
      this.message = '答题结果正在写入本机，请稍候';
      this.hasError = false;
      return;
    }
    if (this.submitted && !(await this.ensureSubmittedDraftCleared())) return;
    if (!this.submitted && this.draftCreated && this.questions.length > 0 && this.attemptId.length > 0) {
      this.queueDraftSave(false);
    }
    this.getUIContext().getRouter().back();
  }

  private retryLocalLoad(): void {
    if (this.draftReadFailed) {
      this.restoreDraft(this.lifecycleRunId);
      return;
    }
    this.reloadQuestions();
  }

  private async reloadQuestions(): Promise<void> {
    if (this.loading) return;
    const runId = this.loadRunId + 1;
    this.loadRunId = runId;
    const lifecycleRunId = this.lifecycleRunId;
    this.loading = true;
    this.loadRetryAvailable = false;
    this.message = '';
    this.hasError = false;
    try {
      await this.loadQuestions(this.selectedReviewItemId, runId, lifecycleRunId);
      if (!this.isActiveLoad(runId, lifecycleRunId)) return;
      const attemptId = this.attemptId;
      try {
        const draft = this.buildDraft();
        const created = await LocalLearningRepository.createCuratedPracticeDraft(draft, (): boolean =>
          this.isActiveLoad(runId, lifecycleRunId) && this.attemptId === attemptId);
        if (!created || !this.isActiveLoad(runId, lifecycleRunId)) return;
        this.draftCreated = true;
      } catch (error) {
        if (!this.isActiveLoad(runId, lifecycleRunId)) return;
        if (error instanceof AnswerDraftClearedError) {
          this.handleClearedDraft();
          return;
        }
        const selectedReviewItemId = this.selectedReviewItemId;
        this.resetPageState();
        this.selectedReviewItemId = selectedReviewItemId;
        this.loadRetryAvailable = true;
        this.message = '练习草稿创建失败，请重新加载';
        this.hasError = true;
        return;
      }
    } catch (error) {
      if (!this.isActiveLoad(runId, lifecycleRunId)) return;
      this.questions = [];
      this.activeQuestion = EMPTY_QUESTION;
      this.answers = [];
      this.activeAnswer = '';
      this.reviewItemIds = [];
      this.message = '本地练习加载失败，请重试';
      this.hasError = true;
      this.loadRetryAvailable = true;
    } finally {
      if (this.loadRunId === runId) this.loading = false;
    }
  }

  private async loadQuestions(selectedReviewItemId: string, runId: number,
    lifecycleRunId: number): Promise<void> {
    const available = LearningContentRepository.getQuestions(this.courseId, this.topic);
    const reviewQueue = await LocalLearningRepository.getReviewQueue();
    if (!this.isActiveLoad(runId, lifecycleRunId)) return;
    const reviews = reviewQueue.dueItems;
    const activeReviews = reviewQueue.activeItems;
    const results = await LocalLearningRepository.getQuizResults();
    if (!this.isActiveLoad(runId, lifecycleRunId)) return;
    const attemptedIds: string[] = [];
    for (const result of results) {
      if (result.courseId !== this.courseId || result.topic !== this.topic) continue;
      for (const detail of result.details) {
        if (!attemptedIds.includes(detail.questionId)) attemptedIds.push(detail.questionId);
      }
    }

    const ordered: PracticeQuestionItem[] = [];
    const usedQuestionIds: string[] = [];
    let notice = '';
    if (selectedReviewItemId.length > 0) {
      const selectedReview = activeReviews.find((item: ReviewItem): boolean =>
        item.id === selectedReviewItemId && item.courseId === this.courseId && item.topic === this.topic);
      if (selectedReview !== undefined) {
        const selectedQuestion = this.questionFromReview(selectedReview, available);
        if (selectedQuestion !== null) {
          ordered.push({ question: selectedQuestion, reviewItemId: selectedReview.id });
          usedQuestionIds.push(selectedQuestion.id);
        } else {
          const fallbackQuestion = available.find((question: CuratedQuestion): boolean =>
            question.courseId === this.courseId && question.topic === this.topic &&
            !usedQuestionIds.includes(question.id));
          if (fallbackQuestion === undefined) {
            this.message = '原错题缺少可重练选项，且同主题暂无精选题';
            this.hasError = true;
            return;
          }
          ordered.push({ question: fallbackQuestion, reviewItemId: selectedReview.id });
          usedQuestionIds.push(fallbackQuestion.id);
          notice = '原错题缺少可重练选项，已切换为同主题精选题';
        }
      } else {
        notice = '指定错题已失效，已加载同主题精选题';
      }
    }

    for (const review of reviews) {
      if (review.courseId !== this.courseId || review.topic !== this.topic ||
        review.id === selectedReviewItemId) continue;
      const reviewQuestion = this.questionFromReview(review, available);
      if (reviewQuestion === null || usedQuestionIds.includes(reviewQuestion.id)) continue;
      ordered.push({ question: reviewQuestion, reviewItemId: review.id });
      usedQuestionIds.push(reviewQuestion.id);
    }

    for (const question of available) {
      if (!usedQuestionIds.includes(question.id) && !attemptedIds.includes(question.id)) {
        ordered.push({ question: question, reviewItemId: '' });
        usedQuestionIds.push(question.id);
      }
    }
    for (const question of available) {
      if (!usedQuestionIds.includes(question.id) && attemptedIds.includes(question.id)) {
        ordered.push({ question: question, reviewItemId: '' });
        usedQuestionIds.push(question.id);
      }
    }
    const selectedItems = ordered.slice(0, 5);
    const selectedQuestions = selectedItems.map((item: PracticeQuestionItem): CuratedQuestion => item.question);
    this.reviewItemIds = selectedItems.map((item: PracticeQuestionItem): string => item.reviewItemId);
    this.answers = new Array<string>(selectedQuestions.length).fill('');
    this.questions = selectedQuestions;
    this.activeQuestion = selectedQuestions.length > 0 ? selectedQuestions[0] : EMPTY_QUESTION;
    this.attemptId = selectedQuestions.length > 0 ?
      LocalLearningRepository.createAnswerDraftAttemptId('curated-' + this.courseId) : '';
    this.message = selectedQuestions.length > 0 ? notice : '这个主题还没有精选练习';
    this.hasError = selectedQuestions.length === 0;
  }

  private questionFromReview(review: ReviewItem, available: CuratedQuestion[]): CuratedQuestion | null {
    let options = review.options ?? [];
    let answer = this.answerLetter(review.correctAnswer);
    let difficulty = review.difficulty;
    let tags = review.tags ?? [];
    if (!this.validReviewOptions(options)) {
      const stored = available.find((question: CuratedQuestion): boolean =>
        question.id === review.questionId && question.question === review.stem);
      if (stored === undefined) return null;
      options = stored.options;
      answer = stored.answer;
      difficulty = stored.difficulty;
      tags = stored.tags ?? [];
    }
    if (!this.validReviewOptions(options) || answer.length === 0) return null;
    return {
      id: review.questionId,
      courseId: review.courseId,
      topic: review.topic,
      question: review.stem,
      options: options,
      answer: answer,
      explanation: review.explanation,
      difficulty: difficulty,
      tags: tags
    };
  }

  private validReviewOptions(options: string[]): boolean {
    const labels: string[] = ['A', 'B', 'C', 'D'];
    if (options.length !== labels.length) return false;
    for (let index = 0; index < options.length; index += 1) {
      const option = options[index].trim().toUpperCase();
      if (option.length === 0 || !option.startsWith(labels[index] + '.')) return false;
    }
    return true;
  }

  private choose(option: string): void {
    if (this.discardingDraft || this.submitted || this.attemptSubmittedAt.length > 0) return;
    const next = this.answers.slice();
    next[this.currentIndex] = option;
    this.answers = next;
    this.activeAnswer = option;
    this.queueDraftSave();
  }

  private async askTutor(detail: QuizResultDetail): Promise<void> {
    if (!(await this.ensureSubmittedDraftCleared())) return;
    const question = '请结合课程资料讲解这道题：' + detail.stem +
      '。我的答案是“' + (detail.userAnswer.length > 0 ? detail.userAnswer : '未作答') +
      '”，正确答案是“' + detail.correctAnswer + '”。请指出关键概念和判断步骤。';
    AppStorage.setOrCreate<string>('pendingChatQuestion', question);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Chat' }).catch((): void => {
      this.message = '无法打开学伴，请重试';
    });
  }

  private async ensureSubmittedDraftCleared(): Promise<boolean> {
    if (!this.submittedDraftCleanupPending) return true;
    if (this.cleaningSubmittedDraft || this.attemptId.length === 0) return false;
    const attemptId = this.attemptId;
    this.cleaningSubmittedDraft = true;
    try {
      await LocalLearningRepository.clearCuratedPracticeDraft(attemptId);
      if (this.attemptId !== attemptId || !this.submitted) return false;
      this.submittedDraftCleanupPending = false;
      this.message = '答题已写回本机，草稿已清除';
      this.hasError = false;
      return true;
    } catch (error) {
      this.submittedDraftCleanupPending = true;
      this.message = '答题已写回本机，但草稿仍未清除，请重试清理';
      this.hasError = false;
      return false;
    } finally {
      this.cleaningSubmittedDraft = false;
    }
  }

  private async openQuiz(): Promise<void> {
    if (!(await this.ensureSubmittedDraftCleared())) return;
    if (!LearningContentRepository.getTopics(this.courseId).includes(this.topic)) {
      this.message = '当前主题无效，无法进入 AI 测验';
      return;
    }
    AppStorage.setOrCreate<string>('selectedCourseId', this.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle);
    AppStorage.setOrCreate<string>('selectedQuizTopic', this.topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Quiz' }).catch((err: Error): void => {
      this.message = '无法打开 AI 测验，请重试';
      this.hasError = true;
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'PracticePage Quiz navigation failed: %{public}s', err.message);
    });
  }

  private async openMistakeBook(): Promise<void> {
    if (!(await this.ensureSubmittedDraftCleared())) return;
    this.getUIContext().getRouter().pushUrl({ url: 'pages/MistakeBook' }).catch((err: Error): void => {
      this.message = '无法打开错题本，请重试';
      this.hasError = true;
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'PracticePage mistake book navigation failed: %{public}s', err.message);
    });
  }

  private answerLetter(option: string): string {
    const value = option.trim().toUpperCase();
    return value.length > 0 ? value.substring(0, 1) : '';
  }

  private allAnswered(): boolean {
    return this.answers.length > 0 && this.answers.every((answer: string): boolean => answer.length > 0);
  }

  private async submit(): Promise<void> {
    if (this.saving || this.discardingDraft || this.writeBackBlocked || !this.allAnswered()) return;
    if (!LearningContentRepository.getTopics(this.courseId).includes(this.topic)) {
      this.message = '当前主题无效，答题记录未保存';
      this.hasError = true;
      return;
    }
    this.saving = true;
    const nextDetails: QuizResultDetail[] = [];
    let totalCorrect = 0;
    for (let index = 0; index < this.questions.length; index++) {
      const question = this.questions[index];
      const userAnswer = this.answers[index] ?? '';
      const correct = this.answerLetter(userAnswer) === question.answer.trim().toUpperCase();
      if (correct) totalCorrect += 1;
      nextDetails.push({
        questionId: question.id,
        stem: question.question,
        options: question.options,
        userAnswer: userAnswer,
        correctAnswer: this.findCorrectOption(question),
        isCorrect: correct,
        explanation: question.explanation,
        difficulty: question.difficulty,
        tags: question.tags ?? [],
        reviewItemId: this.reviewItemIds[index] ?? ''
      });
    }
    if (this.attemptSubmittedAt.length === 0) this.attemptSubmittedAt = new Date().toISOString();
    const result: QuizResult = {
      quizId: this.attemptId,
      userId: Constants.DEMO_USER_ID,
      courseId: this.courseId,
      topic: this.topic,
      source: 'curated',
      difficulty: this.dominantDifficulty(),
      totalQuestions: this.questions.length,
      correctCount: totalCorrect,
      accuracy: totalCorrect / this.questions.length,
      details: nextDetails,
      evaluation: totalCorrect === this.questions.length ? '本组精选练习全部答对。' : '已记录错题，可根据解析继续巩固。',
      weakTopics: totalCorrect < this.questions.length ? [this.topic] : [],
      submittedAt: this.attemptSubmittedAt
    };
    let draftPersisted = false;
    try {
      this.draftSaveRunId += 1;
      await this.persistDraft();
      draftPersisted = true;
      const receipt = await LocalLearningRepository.appendQuizResult(result);
      this.correctCount = totalCorrect;
      this.details = nextDetails;
      this.expandedDetailId = nextDetails.find((detail: QuizResultDetail): boolean => !detail.isCorrect)?.questionId ?? '';
      this.applyWriteReceipt(receipt);
      this.message = '';
      this.hasError = false;
      this.submitted = true;
      this.draftSaveFailed = false;
      try {
        await LocalLearningRepository.clearCuratedPracticeDraft(this.attemptId);
      } catch (error) {
        this.submittedDraftCleanupPending = true;
        this.message = '答题已写回本机，但草稿清理失败；请重试清理草稿后继续';
        this.hasError = false;
      }
    } catch (error) {
      if (error instanceof AnswerDraftClearedError) {
        this.handleClearedDraft();
        return;
      }
      if (error instanceof QuizResultConflictError) {
        this.draftSaveFailed = false;
        this.writeBackBlocked = true;
        this.message = '当前答题记录与本机摘要不一致，已阻止重复写回；请放弃草稿后重新开始';
        this.hasError = true;
        return;
      }
      if (error instanceof QuizResultVerificationUnavailableError) {
        this.draftSaveFailed = false;
        this.writeBackBlocked = true;
        this.message = '历史答题已写入但缺少可验证摘要，已阻止重复累计；请放弃草稿后重新开始';
        this.hasError = true;
        return;
      }
      this.draftSaveFailed = !draftPersisted;
      this.message = draftPersisted ? '答题结果写回未确认，答案已冻结并保存，请重试提交' :
        '提交前草稿保存失败，本次尚未写回；答案已冻结，请重试保存并提交';
      this.hasError = true;
    } finally {
      this.saving = false;
    }
  }

  private applyWriteReceipt(receipt: QuizWriteReceipt): void {
    this.writeBackTotalQuestions = receipt.totalQuestions;
    this.writeBackActiveReviews = receipt.activeReviewCount;
    this.writeBackTopicAccuracy = receipt.topicAccuracy;
    this.writeBackActivityCount = receipt.activityCount;
    this.writeBackCourseProgress = receipt.courseProgress;
  }

  private findCorrectOption(question: CuratedQuestion): string {
    for (const option of question.options) {
      if (this.answerLetter(option) === question.answer.trim().toUpperCase()) return option;
    }
    return question.answer;
  }

  private dominantDifficulty(): string {
    let easy = 0;
    let medium = 0;
    let hard = 0;
    for (const question of this.questions) {
      if (question.difficulty === 'easy') easy += 1;
      else if (question.difficulty === 'hard') hard += 1;
      else medium += 1;
    }
    if (hard > easy && hard >= medium) return 'hard';
    if (easy > hard && easy >= medium) return 'easy';
    return 'medium';
  }

  private difficultyLabel(value?: string): string {
    if (value === 'easy') return '基础';
    if (value === 'hard') return '挑战';
    return '进阶';
  }

  @Builder
  DraftLoadingState() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color(Constants.COLOR_BRAND)
        Text('正在恢复本机练习草稿')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
      }
      .width('100%')
      Column().width('100%').height(54).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
      Column().width('100%').height(44).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
      Column().width('92%').height(44).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
      Column().width('86%').height(44).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
    .accessibilityText('正在恢复本机练习草稿')
  }

  @Builder
  QuestionView() {
    Column({ space: 16 }) {
      Row() {
        Text('离线精选题库')
          .fontSize(11)
          .fontColor(Constants.COLOR_SUCCESS)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(Constants.COLOR_SUCCESS_LIGHT)
          .borderRadius(Constants.RADIUS_SM)
        Text((this.currentIndex + 1).toString() + ' / ' + this.questions.length.toString())
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
        Button(this.discardingDraft ? '正在放弃...' : '放弃草稿')
          .height(48)
          .fontSize(11)
          .fontColor(Constants.COLOR_ERROR)
          .backgroundColor(Constants.COLOR_ERROR_LIGHT)
          .borderRadius(Constants.RADIUS_SM)
          .enabled(!this.discardingDraft)
          .onClick((): void => { this.discardCurrentDraft(); })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      if (this.attemptSubmittedAt.length > 0) {
        Text(this.writeBackBlocked ? '本机完整性校验已阻止写回；请放弃草稿后重新开始。' :
          '上次写回未确认，答案已冻结；重试只会确认同一次答题。')
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor(Constants.COLOR_WARNING)
          .padding(10)
          .backgroundColor(Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_SM)
      }
      Progress({ value: this.currentIndex + 1, total: this.questions.length, type: ProgressType.Linear })
        .width('100%')
        .color(Constants.COLOR_BRAND)
        .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
      Text(this.activeQuestion.question)
        .width('100%')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
        .lineHeight(27)
      if ((this.activeQuestion.tags ?? []).length > 0 || this.activeQuestion.difficulty !== undefined) {
        Flex({ wrap: FlexWrap.Wrap }) {
          Text(this.difficultyLabel(this.activeQuestion.difficulty))
            .fontSize(10)
            .fontColor(Constants.COLOR_TEXT_TERTIARY)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(Constants.COLOR_BG_TAG)
            .borderRadius(9)
            .margin({ right: 6, bottom: 6 })
          ForEach(this.activeQuestion.tags ?? [], (tag: string): void => {
            Text(tag)
              .fontSize(10)
              .fontColor(Constants.COLOR_BRAND)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(9)
              .margin({ right: 6, bottom: 6 })
          })
        }
        .width('100%')
      }
      Column({ space: 10 }) {
        ForEach(this.activeQuestion.options, (option: string): void => {
          AnswerOption(option, this.activeAnswer === option,
            this.attemptSubmittedAt.length === 0 && !this.discardingDraft,
            (): void => { this.choose(option); })
        })
      }
      .width('100%')
      Row({ space: 10 }) {
        Button('上一题')
          .layoutWeight(1)
          .height(46)
          .enabled(this.currentIndex > 0 && !this.discardingDraft)
          .fontColor(this.currentIndex > 0 && !this.discardingDraft ?
            Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_BUTTON_DISABLED_TEXT)
          .backgroundColor(Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.goToPreviousQuestion(); })
        if (this.currentIndex < this.questions.length - 1) {
          Button('下一题')
            .layoutWeight(1)
            .height(46)
            .enabled(this.activeAnswer.length > 0 && !this.discardingDraft)
            .fontColor(this.activeAnswer.length > 0 && !this.discardingDraft ?
              Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
            .backgroundColor(this.activeAnswer.length > 0 && !this.discardingDraft ?
              Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.goToNextQuestion(); })
        } else {
          Button(this.discardingDraft ? '正在放弃...' : (this.saving ? '写入中...' :
            (this.writeBackBlocked ? '写回已阻止' :
            (this.attemptSubmittedAt.length > 0 ? '重试写回' : '提交评分'))))
            .layoutWeight(1)
            .height(46)
            .enabled(this.allAnswered() && !this.saving && !this.discardingDraft && !this.writeBackBlocked)
            .fontColor(this.allAnswered() && !this.discardingDraft && !this.writeBackBlocked ?
              Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
            .backgroundColor(this.allAnswered() && !this.discardingDraft && !this.writeBackBlocked ?
              Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.submit(); })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
  }

  @Builder
  ResultView() {
    Column({ space: 16 }) {
      Row({ space: 18 }) {
        Stack({ alignContent: Alignment.Center }) {
          Progress({ value: this.correctCount, total: this.questions.length, type: ProgressType.Ring })
            .width(86)
            .height(86)
            .color(this.correctCount / this.questions.length >= 0.8 ? Constants.COLOR_SUCCESS : Constants.COLOR_WARNING)
          Text(Math.round(this.correctCount / this.questions.length * 100).toString() + '%')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
        }
        Column({ space: 5 }) {
          Text('本轮已完成')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text(this.correctCount.toString() + ' / ' + this.questions.length.toString() + ' 题正确')
            .fontSize(14)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
          Text(this.correctCount === this.questions.length ?
            '本组已全部答对，可以进入同主题 AI 测验' : '先复盘错题，再进入下一组')
            .fontSize(12)
            .fontColor(Constants.COLOR_TEXT_TERTIARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Constants.COLOR_BG_CARD)
      .borderRadius(Constants.RADIUS_LG)

      if (this.writeBackTotalQuestions > 0) {
        Column({ space: 9 }) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(18)
              .fontColor([Constants.COLOR_SUCCESS])
            Text('本机学习闭环已更新')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
          }
          .width('100%')
          Text('画像累计 ' + this.writeBackTotalQuestions.toString() + ' 题 · 当前错题 ' +
            this.writeBackActiveReviews.toString() + ' 道')
            .width('100%')
            .fontSize(12)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
          Text(this.topic + ' 掌握度 ' + Math.round(this.writeBackTopicAccuracy * 100).toString() +
            '% · 学习活动累计 ' + this.writeBackActivityCount.toString() + ' 次')
            .width('100%')
            .fontSize(12)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
          Text('课程进度 ' + Math.round(this.writeBackCourseProgress * 100).toString() + '%')
            .width('100%')
            .fontSize(12)
            .fontColor(Constants.COLOR_BRAND)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Constants.COLOR_SUCCESS_LIGHT)
        .borderRadius(Constants.RADIUS_MD)
      }

      Text('逐题复盘')
        .width('100%')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)

      Column() {
        ForEach(this.details, (detail: QuizResultDetail, index: number): void => {
          ReviewDetailRow(detail, index, this.expandedDetailId === detail.questionId, (): void => {
            this.expandedDetailId = this.expandedDetailId === detail.questionId ? '' : detail.questionId;
          }, (): void => { this.askTutor(detail); })
          if (index < this.details.length - 1) {
            Divider().color(Constants.COLOR_BORDER).margin({ left: 44 })
          }
        })
      }
      .width('100%')
      .backgroundColor(Constants.COLOR_BG_CARD)
      .borderRadius(Constants.RADIUS_LG)
      Row({ space: 10 }) {
        Button('返回上页')
          .layoutWeight(1)
          .height(48)
          .fontColor(Constants.COLOR_BRAND)
          .backgroundColor(Constants.COLOR_BRAND_LIGHT)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.goBack(); })
        Button(this.correctCount < this.questions.length ? '查看错题本' : '进入 AI 测验')
          .layoutWeight(1)
          .height(48)
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
          .backgroundColor(this.correctCount < this.questions.length ? Constants.COLOR_WARNING : Constants.COLOR_BRAND)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => {
            if (this.correctCount < this.questions.length) this.openMistakeBook();
            else this.openQuiz();
          })
      }
        .width('100%')
    }
    .width('100%')
  }

  build() {
    Column() {
      GradientHeader('精选练习', this.courseTitle + (this.topic.length > 0 ? ' · ' + this.topic : ''),
        () => this.goBack())
      if (this.message.length > 0) {
        Row({ space: 8 }) {
          Text(this.message)
            .layoutWeight(1)
            .fontSize(12)
            .fontColor(this.hasError ? Constants.COLOR_ERROR : Constants.COLOR_WARNING)
          if (this.submittedDraftCleanupPending) {
            Button(this.cleaningSubmittedDraft ? '正在清理...' : '重试清理草稿')
              .height(48)
              .fontSize(12)
              .fontColor(Constants.COLOR_BRAND)
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(Constants.RADIUS_SM)
              .enabled(!this.cleaningSubmittedDraft)
              .onClick((): void => { this.ensureSubmittedDraftCleared(); })
          } else if (this.draftSaveFailed) {
            Button('保存草稿')
              .height(48)
              .fontSize(12)
              .fontColor(Constants.COLOR_BRAND)
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(Constants.RADIUS_SM)
              .onClick((): void => { this.queueDraftSave(); })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })
      }
      Scroll() {
        Column() {
          if (this.draftLoading) {
            this.DraftLoadingState()
          } else if (this.loading) {
            Column()
              .width('100%')
              .height(200)
              .backgroundColor(Constants.COLOR_BG_SKELETON)
              .borderRadius(Constants.RADIUS_LG)
              .margin({ top: 24 })
          } else if (this.questions.length === 0 && this.loadRetryAvailable) {
            Column({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
                .fontSize(40)
                .fontColor([Constants.COLOR_ERROR])
              Button('重新加载')
                .height(48)
                .fontSize(13)
                .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                .backgroundColor(Constants.COLOR_BRAND)
                .borderRadius(Constants.RADIUS_MD)
                .accessibilityText('重新加载本地练习')
                .accessibilityDescription('再次读取原错题与同主题精选题')
                .onClick((): void => { this.retryLocalLoad(); })
            }
            .width('100%')
            .height(220)
            .justifyContent(FlexAlign.Center)
          } else if (this.questions.length === 0) {
            Text('该主题暂无精选练习题')
              .fontSize(15)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
              .margin({ top: 120 })
          } else if (this.submitted) {
            this.ResultView()
          } else {
            this.QuestionView()
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 28 + SafeAreaInsets.bottomVp() })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
