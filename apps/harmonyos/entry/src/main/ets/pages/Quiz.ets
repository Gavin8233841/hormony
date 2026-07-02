/**
 * 课程测验页 - 真实 AI 出题、本地评分与学习记录
 */

import { GradientHeader, ReviewDetailRow, StagedProgress, WorkStep } from '../common/Builders';
import { Constants } from '../common/Constants';
import { HttpClient } from '../common/HttpClient';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  QuizGradingItem,
  QuizPackage,
  QuizQuestionView,
  QuizRequest,
  QuizResult,
  QuizResultDetail,
} from '../model/DataModels';
import { LocalLearningRepository } from '../common/LocalLearningRepository';

interface DifficultyOption {
  value: string;
  label: string;
  description: string;
}

interface QuizValidationResult {
  valid: boolean;
  message: string;
  quizId: string;
  questions: QuizQuestionView[];
  grading: QuizGradingItem[];
}

@Entry
@Component
struct QuizPage {
  private contentScroller: Scroller = new Scroller();
  @State courseId: string = 'cs101';
  @State courseTitle: string = '数据结构';
  @State topic: string = '综合';
  @State quizId: string = '';
  @State questions: QuizQuestionView[] = [];
  @State answers: string[] = [];
  @State currentIndex: number = 0;
  @State loading: boolean = false;
  @State submitting: boolean = false;
  @State difficulty: string = 'medium';
  @State message: string = '';
  @State resultReady: boolean = false;
  @State resultAccuracy: number = 0;
  @State resultCorrectCount: number = 0;
  @State resultTotalQuestions: number = 0;
  @State resultDetails: QuizResultDetail[] = [];
  @State expandedResultId: string = '';
  @State evaluation: string = '';
  @State weakTopics: string[] = [];
  @State progressStep: number = 0;
  @State checkedQuestionIds: string[] = [];
  private grading: QuizGradingItem[] = [];
  private suggestions: string[] = ['二叉树与BST', '图的遍历', '动态规划'];
  private answerLabels: string[] = ['A', 'B', 'C', 'D'];
  private difficultyOptions: DifficultyOption[] = [
    { value: 'easy', label: '基础', description: '概念识别' },
    { value: 'medium', label: '进阶', description: '场景判断' },
    { value: 'hard', label: '挑战', description: '多步推理' }
  ];
  private generationSteps: WorkStep[] = [
    { title: '检索', description: '匹配课程资料' },
    { title: '生成', description: '控制难度与题型' },
    { title: '标注', description: '整理标签与解析' }
  ];
  private scoringSteps: WorkStep[] = [
    { title: '核对', description: '比对 A-D 答案' },
    { title: '归因', description: '统计错因标签' },
    { title: '记录', description: '写入本地画像' }
  ];

  aboutToAppear(): void {
    this.courseId = AppStorage.get<string>('selectedCourseId') ?? 'cs101';
    this.courseTitle = AppStorage.get<string>('selectedCourseTitle') ?? '数据结构';
    const courseTopics = LearningContentRepository.getTopics(this.courseId);
    this.suggestions = courseTopics.slice(0, 3);
    const selectedTopic = AppStorage.get<string>('selectedQuizTopic') ?? '';
    if (selectedTopic.trim().length > 0) {
      const normalizedTopic = selectedTopic.trim();
      if (normalizedTopic === '综合' || courseTopics.includes(normalizedTopic)) {
        this.topic = normalizedTopic;
      } else {
        this.topic = '综合';
        this.message = '检索词不属于课程主题，已切换为综合练习';
      }
      AppStorage.setOrCreate<string>('selectedQuizTopic', '');
    }
    if (this.topic !== '综合' && courseTopics.includes(this.topic) && !this.suggestions.includes(this.topic)) {
      this.suggestions = [this.topic].concat(this.suggestions.filter((value: string): boolean =>
        value !== this.topic).slice(0, 2));
    }
  }

  private currentAnswerText(): string {
    const answer = this.answers[this.currentIndex];
    return typeof answer === 'string' ? answer : '';
  }

  private chooseAnswer(answer: string): void {
    if (this.currentQuestionChecked()) return;
    const nextAnswers = this.answers.slice();
    nextAnswers[this.currentIndex] = answer;
    this.answers = nextAnswers;
  }

  private askTutor(detail: QuizResultDetail): void {
    const question = '请结合课程资料讲解这道题：' + detail.stem +
      '。我的答案是“' + (detail.userAnswer.length > 0 ? detail.userAnswer : '未作答') +
      '”，正确答案是“' + detail.correctAnswer + '”。请指出关键概念和判断步骤。';
    AppStorage.setOrCreate<string>('pendingChatQuestion', question);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Chat' }).catch((): void => {
      this.message = '无法打开学伴，请重试';
    });
  }

  private resetQuiz(): void {
    this.quizId = '';
    this.questions = [];
    this.answers = [];
    this.currentIndex = 0;
    this.message = '';
    this.resultReady = false;
    this.resultDetails = [];
    this.expandedResultId = '';
    this.evaluation = '';
    this.weakTopics = [];
    this.grading = [];
    this.progressStep = 0;
    this.checkedQuestionIds = [];
  }

  private reviewTopic(topic: string): void {
    AppStorage.setOrCreate<string>('selectedCourseId', this.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle);
    AppStorage.setOrCreate<string>('knowledgePrefillQuery', topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Knowledge' }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'QuizPage knowledge router.pushUrl failed: %{public}s', err.message);
    });
  }

  private incorrectDetails(): QuizResultDetail[] {
    return this.resultDetails.filter((detail: QuizResultDetail): boolean => !detail.isCorrect);
  }

  private firstIncorrectDetail(): QuizResultDetail | null {
    const items = this.incorrectDetails();
    return items.length > 0 ? items[0] : null;
  }

  private primaryReviewKeyword(): string {
    const items = this.incorrectDetails();
    const tags: string[] = [];
    for (const detail of items) {
      for (const tag of detail.tags ?? []) {
        const normalized = tag.trim();
        if (normalized.length > 0 && !tags.includes(normalized)) tags.push(normalized);
      }
    }
    if (tags.length > 0) return tags[0];
    return this.topic;
  }

  private reviewPrimaryWeakPoint(): void {
    this.reviewTopic(this.primaryReviewKeyword());
  }

  private askFirstIncorrect(): void {
    const detail = this.firstIncorrectDetail();
    if (detail !== null) this.askTutor(detail);
  }

  private restartHardQuiz(): void {
    this.resetQuiz();
    this.difficulty = 'hard';
  }

  async generateQuiz(): Promise<void> {
    if (this.loading) return;
    this.resetQuiz();
    this.loading = true;
    this.progressStep = 1;
    const request: QuizRequest = {
      userId: Constants.DEMO_USER_ID,
      courseId: this.courseId,
      topic: this.topic,
      count: 5,
      difficulty: this.difficulty,
    };
    try {
      const response = await HttpClient.post<QuizPackage>(
        Constants.API_QUIZ,
        JSON.stringify(request)
      );
      this.progressStep = 2;
      const validation = this.validateQuizPackage(response);
      if (!validation.valid) {
        this.message = validation.message;
        return;
      }
      const nextAnswers = new Array<string>(validation.questions.length).fill('');
      this.quizId = validation.quizId;
      this.grading = validation.grading;
      // 先提交答案槽位，最后提交题目，避免 ArkUI 在两次状态更新之间读取未初始化答案。
      this.answers = nextAnswers;
      this.questions = validation.questions;
      if (this.questions.length === 0) {
        this.message = '当前主题暂时没有可用题目';
      }
    } catch (e) {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'QuizPage API failed: %{public}s', (e as Error).message);
      this.message = '云端学伴暂不可用，请检查网络后重试';
    } finally {
      this.loading = false;
    }
  }

  async submitQuiz(): Promise<void> {
    if (this.submitting || this.quizId.length === 0) return;
    if (!this.allQuestionsAnswered()) {
      this.message = '请先完成全部题目';
      return;
    }
    if (!this.allFeedbackChecked()) {
      this.message = '请先查看每道题反馈';
      return;
    }
    if (!this.quizCanBeScored()) {
      this.message = '题目评分数据不完整，请重新生成题组';
      return;
    }
    this.submitting = true;
    this.progressStep = 1;
    this.message = '';
    const details: QuizResultDetail[] = [];
    let correctCount = 0;
    for (let i = 0; i < this.questions.length; i++) {
      const question = this.questions[i];
      const grading = this.gradingForQuestion(question.id);
      if (grading === null) {
        this.message = '题目评分数据不完整，请重新生成题组';
        this.submitting = false;
        return;
      }
      const userAnswer = this.answers[i] ?? '';
      const isCorrect = this.answerLetter(userAnswer) === grading.answer.trim().toUpperCase();
      if (isCorrect) correctCount += 1;
      const detail: QuizResultDetail = {
        questionId: question.id,
        stem: question.stem,
        userAnswer: userAnswer,
        correctAnswer: this.correctOption(question, grading.answer),
        isCorrect: isCorrect,
        explanation: grading.explanation,
        tags: grading.tags ?? question.tags ?? []
      };
      details.push(detail);
    }

    const weakTopics: string[] = correctCount < this.questions.length ? [this.topic] : [];
    const result: QuizResult = {
      quizId: this.quizId,
      userId: Constants.DEMO_USER_ID,
      courseId: this.courseId,
      topic: this.topic,
      source: 'ai',
      totalQuestions: this.questions.length,
      correctCount: correctCount,
      accuracy: this.questions.length > 0 ? correctCount / this.questions.length : 0,
      details: details,
      evaluation: correctCount === this.questions.length ? '本组题目全部答对，继续保持。' :
        '已记录本次答题结果，可从薄弱知识点进入课程资料复习。',
      weakTopics: weakTopics,
      submittedAt: new Date().toISOString()
    };
    try {
      await LocalLearningRepository.appendQuizResult(result);
      this.progressStep = 2;
      this.resultAccuracy = result.accuracy;
      this.resultCorrectCount = result.correctCount;
      this.resultTotalQuestions = result.totalQuestions;
      this.resultDetails = result.details;
      this.expandedResultId = result.details.find((detail: QuizResultDetail): boolean => !detail.isCorrect)?.questionId ?? '';
      this.evaluation = result.evaluation;
      this.weakTopics = result.weakTopics;
      this.resultReady = true;
    } catch (e) {
      this.message = '答题结果保存失败，请稍后重试';
    } finally {
      this.submitting = false;
    }
  }

  private validateQuizPackage(response: QuizPackage | null): QuizValidationResult {
    const invalidMessage = '云端返回的题组不完整，请重新生成';
    const invalid: QuizValidationResult = {
      valid: false,
      message: invalidMessage,
      quizId: '',
      questions: [],
      grading: []
    };
    if (response === null) return invalid;
    const quizId = this.cleanText(response.quizId);
    if (quizId.length === 0 || !Array.isArray(response.questions) || !Array.isArray(response.grading) ||
      response.questions.length === 0 || response.questions.length !== response.grading.length) {
      return invalid;
    }

    const questionIds: string[] = [];
    const questions: QuizQuestionView[] = [];
    for (const source of response.questions) {
      const id = this.cleanText(source.id);
      const type = this.cleanText(source.type);
      const stem = this.cleanText(source.stem);
      const options = this.validatedOptions(source.options);
      if (id.length === 0 || questionIds.includes(id) || type !== 'choice' || stem.length === 0 ||
        options.length !== this.answerLabels.length) {
        return invalid;
      }
      questionIds.push(id);
      questions.push({
        id: id,
        type: type,
        stem: stem,
        options: options,
        tags: this.quizTags(source.tags)
      });
    }

    const gradingIds: string[] = [];
    const grading: QuizGradingItem[] = [];
    for (const source of response.grading) {
      const questionId = this.cleanText(source.questionId);
      const answer = this.cleanText(source.answer).toUpperCase();
      const explanation = this.cleanText(source.explanation);
      if (questionId.length === 0 || !questionIds.includes(questionId) || gradingIds.includes(questionId) ||
        !this.answerIsValid(answer) || explanation.length === 0) {
        return invalid;
      }
      gradingIds.push(questionId);
      grading.push({
        questionId: questionId,
        answer: answer,
        explanation: explanation,
        tags: this.quizTags(source.tags)
      });
    }

    if (gradingIds.length !== questionIds.length) return invalid;
    return {
      valid: true,
      message: '',
      quizId: quizId,
      questions: questions,
      grading: grading
    };
  }

  private cleanText(value?: string): string {
    return typeof value === 'string' ? value.trim() : '';
  }

  private quizTags(tags?: string[]): string[] {
    const nextTags: string[] = [];
    const source = Array.isArray(tags) ? tags : [];
    for (const tag of source) {
      if (typeof tag !== 'string') continue;
      const normalized = tag.trim();
      if (normalized.length > 0 && normalized.length <= 12 && !nextTags.includes(normalized)) {
        nextTags.push(normalized);
      }
    }
    if (nextTags.length > 0) return nextTags.slice(0, 3);
    const topicTag = this.topic.trim().substring(0, 12);
    return [topicTag.length > 0 ? topicTag : '综合'];
  }

  private validatedOptions(options?: string[]): string[] {
    if (!Array.isArray(options) || options.length !== this.answerLabels.length) return [];
    const normalizedOptions: string[] = [];
    for (let index = 0; index < options.length; index++) {
      const option = options[index];
      if (typeof option !== 'string') return [];
      const normalized = option.trim();
      if (normalized.length === 0 ||
        !normalized.toUpperCase().startsWith(this.answerLabels[index] + '.')) {
        return [];
      }
      normalizedOptions.push(normalized);
    }
    return normalizedOptions;
  }

  private answerIsValid(answer: string): boolean {
    return this.answerLabels.includes(answer.trim().toUpperCase());
  }

  private allQuestionsAnswered(): boolean {
    if (this.questions.length === 0 || this.answers.length !== this.questions.length) return false;
    for (const answer of this.answers) {
      if (!this.answerIsValid(this.answerLetter(answer))) return false;
    }
    return true;
  }

  private quizCanBeScored(): boolean {
    if (this.quizId.trim().length === 0 || this.questions.length === 0 ||
      this.grading.length !== this.questions.length) {
      return false;
    }
    const questionIds: string[] = [];
    for (const question of this.questions) {
      const id = this.cleanText(question.id);
      if (id.length === 0 || questionIds.includes(id) ||
        this.validatedOptions(question.options).length !== this.answerLabels.length ||
        this.gradingForQuestion(id) === null) {
        return false;
      }
      questionIds.push(id);
    }
    return true;
  }

  private gradingForQuestion(questionId: string): QuizGradingItem | null {
    for (const item of this.grading) {
      if (item.questionId === questionId && this.answerIsValid(item.answer) &&
        item.explanation.trim().length > 0) {
        return item;
      }
    }
    return null;
  }

  private currentQuestionId(): string {
    if (this.currentIndex < 0 || this.currentIndex >= this.questions.length) return '';
    return this.questions[this.currentIndex].id;
  }

  private currentQuestionChecked(): boolean {
    const questionId = this.currentQuestionId();
    return questionId.length > 0 && this.checkedQuestionIds.includes(questionId);
  }

  private checkedCount(): number {
    let count = 0;
    for (const question of this.questions) {
      if (this.checkedQuestionIds.includes(question.id)) count += 1;
    }
    return count;
  }

  private checkCurrentQuestion(): void {
    if (this.currentAnswerText().length === 0) {
      this.message = '请先选择一个答案';
      return;
    }
    if (!this.quizCanBeScored()) {
      this.message = '题目评分数据不完整，请重新生成题组';
      return;
    }
    const questionId = this.currentQuestionId();
    if (questionId.length === 0 || this.checkedQuestionIds.includes(questionId)) return;
    const nextIds = this.checkedQuestionIds.slice();
    nextIds.push(questionId);
    this.checkedQuestionIds = nextIds;
    this.message = '';
  }

  private goToQuestion(index: number): void {
    if (index < 0 || index >= this.questions.length) return;
    this.currentIndex = index;
    this.message = '';
    this.contentScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
  }

  private allFeedbackChecked(): boolean {
    if (this.questions.length === 0) return false;
    for (const question of this.questions) {
      if (!this.checkedQuestionIds.includes(question.id)) return false;
    }
    return true;
  }

  private currentQuestionCorrect(): boolean {
    const grading = this.gradingForQuestion(this.currentQuestionId());
    if (grading === null) return false;
    return this.answerLetter(this.currentAnswerText()) === grading.answer.trim().toUpperCase();
  }

  private currentCorrectAnswerText(): string {
    const grading = this.gradingForQuestion(this.currentQuestionId());
    if (grading === null || this.currentIndex < 0 || this.currentIndex >= this.questions.length) return '';
    return this.correctOption(this.questions[this.currentIndex], grading.answer);
  }

  private currentExplanation(): string {
    const grading = this.gradingForQuestion(this.currentQuestionId());
    return grading !== null ? grading.explanation : '';
  }

  private optionIsCorrect(option: string): boolean {
    const grading = this.gradingForQuestion(this.currentQuestionId());
    return grading !== null && this.answerLetter(option) === grading.answer.trim().toUpperCase();
  }

  private optionIsWrongSelection(option: string): boolean {
    return this.currentQuestionChecked() && this.currentAnswerText() === option && !this.optionIsCorrect(option);
  }

  private optionBackgroundColor(option: string): string {
    if (!this.currentQuestionChecked()) {
      return this.currentAnswerText() === option ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_CARD;
    }
    if (this.optionIsCorrect(option)) return Constants.COLOR_SUCCESS_LIGHT;
    if (this.optionIsWrongSelection(option)) return Constants.COLOR_ERROR_LIGHT;
    return Constants.COLOR_BG_CARD;
  }

  private optionBorderColor(option: string): string {
    if (!this.currentQuestionChecked()) {
      return this.currentAnswerText() === option ? Constants.COLOR_BRAND : Constants.COLOR_BORDER;
    }
    if (this.optionIsCorrect(option)) return Constants.COLOR_SUCCESS;
    if (this.optionIsWrongSelection(option)) return Constants.COLOR_ERROR;
    return Constants.COLOR_BORDER;
  }

  private optionLetterBackground(option: string): string {
    if (!this.currentQuestionChecked()) {
      return this.currentAnswerText() === option ? Constants.COLOR_BRAND : Constants.COLOR_BG_TAG;
    }
    if (this.optionIsCorrect(option)) return Constants.COLOR_SUCCESS;
    if (this.optionIsWrongSelection(option)) return Constants.COLOR_ERROR;
    return Constants.COLOR_BG_TAG;
  }

  private optionLetterColor(option: string): string {
    if (!this.currentQuestionChecked() && this.currentAnswerText() !== option) return Constants.COLOR_TEXT_TERTIARY;
    if (this.currentQuestionChecked() && !this.optionIsCorrect(option) && !this.optionIsWrongSelection(option)) {
      return Constants.COLOR_TEXT_TERTIARY;
    }
    return Constants.COLOR_TEXT_ON_GRADIENT;
  }

  private optionIconColor(option: string): string {
    if (this.optionIsCorrect(option)) return Constants.COLOR_SUCCESS;
    if (this.optionIsWrongSelection(option)) return Constants.COLOR_ERROR;
    return Constants.COLOR_BRAND;
  }

  private answerLetter(answer: string): string {
    const trimmed = answer.trim().toUpperCase();
    if (trimmed.length === 0) return '';
    return trimmed.substring(0, 1);
  }

  private correctOption(question: QuizQuestionView, answer: string): string {
    const options = question.options ?? [];
    const index = answer.trim().toUpperCase().charCodeAt(0) - 'A'.charCodeAt(0);
    if (index >= 0 && index < options.length) return options[index];
    return answer;
  }

  private difficultyLabel(): string {
    for (const option of this.difficultyOptions) {
      if (option.value === this.difficulty) return option.label;
    }
    return '进阶';
  }

  @Builder
  LoadingState() {
    Column({ space: 14 }) {
      this.GenerationProgress()
      Column().width('100%').height(72).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(14)
      Column().width('100%').height(48).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
      Column().width('100%').height(48).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
      Column().width('100%').height(48).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
  }

  @Builder
  SetupState() {
    Column({ space: 18 }) {
      Column({ space: 6 }) {
        Text('选择本次练习主题')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text('每组 5 道选择题，按难度生成并立即查看解析')
          .fontSize(13)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 10 }) {
        Button('综合练习')
          .width('100%')
          .height(48)
          .fontSize(14)
          .fontColor(this.topic === '综合' ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_PRIMARY)
          .backgroundColor(this.topic === '综合' ? Constants.COLOR_BRAND : Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_MD)
          .onClick(() => { this.topic = '综合'; })
        ForEach(this.suggestions, (suggestion: string): void => {
          Button(suggestion)
            .width('100%')
            .height(48)
            .fontSize(14)
            .fontColor(this.topic === suggestion ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_PRIMARY)
            .backgroundColor(this.topic === suggestion ? Constants.COLOR_BRAND : Constants.COLOR_BG_TAG)
            .borderRadius(Constants.RADIUS_MD)
            .onClick(() => { this.topic = suggestion; })
        })
      }
      .width('100%')

      Column({ space: 8 }) {
        Text('难度分层')
          .width('100%')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Row({ space: 8 }) {
          ForEach(this.difficultyOptions, (option: DifficultyOption): void => {
            Button({ type: ButtonType.Normal }) {
              Column({ space: 3 }) {
                Text(option.label)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.difficulty === option.value ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_PRIMARY)
                Text(option.description)
                  .fontSize(10)
                  .fontColor(this.difficulty === option.value ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_SECONDARY)
              }
            }
            .layoutWeight(1)
            .height(54)
            .backgroundColor(this.difficulty === option.value ? Constants.COLOR_BRAND : Constants.COLOR_BG_TAG)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.difficulty = option.value; })
          })
        }
        .width('100%')
      }
      .width('100%')

      Button('开始答题')
        .width('100%')
        .height(50)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
        .backgroundColor(Constants.COLOR_BRAND)
        .borderRadius(Constants.RADIUS_MD)
        .onClick(() => { this.generateQuiz(); })

      if (this.loading) {
        this.GenerationProgress()
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
    .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
  }

  @Builder
  GenerationProgress() {
    StagedProgress(
      this.progressStep >= 2 ? '正在整理题目标签' : 'AI 正在生成题目',
      this.progressStep >= 2 ? '校验 A-D 选项、解析和能力标签' : '检索课程资料、匹配难度、生成可评分题组',
      this.progressStep,
      this.generationSteps
    )
  }

  @Builder
  ScoringProgress() {
    StagedProgress('正在生成学习反馈', '评分、错因标签和本地画像同步中', this.progressStep, this.scoringSteps)
  }

  @Builder
  QuestionState() {
    Column({ space: 16 }) {
      Row() {
        Text('第 ' + (this.currentIndex + 1).toString() + ' 题')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_BRAND)
        Text((this.currentIndex + 1).toString() + ' / ' + this.questions.length.toString())
          .fontSize(13)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row() {
        Text('即时反馈')
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)
        Text(this.checkedCount().toString() + ' / ' + this.questions.length.toString() + ' 已查看')
          .fontSize(12)
          .fontColor(this.allFeedbackChecked() ? Constants.COLOR_SUCCESS : Constants.COLOR_TEXT_TERTIARY)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Progress({ value: this.currentIndex + 1, total: this.questions.length, type: ProgressType.Linear })
        .width('100%')
        .color(Constants.COLOR_BRAND)
        .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
        .borderRadius(4)

      Text(this.questions[this.currentIndex].stem)
        .width('100%')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
        .lineHeight(27)

      if ((this.questions[this.currentIndex].tags ?? []).length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.questions[this.currentIndex].tags ?? [], (tag: string): void => {
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
        ForEach(this.questions[this.currentIndex].options ?? [], (option: string): void => {
          this.QuizAnswerOption(option)
        })
      }
      .width('100%')

      if (this.currentQuestionChecked()) {
        this.QuestionFeedbackCard()
      } else {
        Button('查看本题反馈')
          .width('100%')
          .height(46)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.currentAnswerText().length > 0 ? Constants.COLOR_TEXT_ON_GRADIENT :
            Constants.COLOR_BUTTON_DISABLED_TEXT)
          .backgroundColor(this.currentAnswerText().length > 0 ? Constants.COLOR_BRAND :
            Constants.COLOR_BUTTON_DISABLED_BG)
          .borderRadius(Constants.RADIUS_MD)
          .enabled(this.currentAnswerText().length > 0)
          .onClick((): void => { this.checkCurrentQuestion(); })
      }

      Row({ space: 10 }) {
        Button('上一题')
          .layoutWeight(1)
          .height(48)
          .fontSize(14)
          .fontColor(this.currentIndex > 0 ? Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_BUTTON_DISABLED_TEXT)
          .backgroundColor(Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_MD)
          .enabled(this.currentIndex > 0)
          .onClick(() => { this.goToQuestion(this.currentIndex - 1); })

        if (this.currentIndex < this.questions.length - 1) {
          Button('下一题')
            .layoutWeight(1)
            .height(48)
            .fontSize(14)
            .fontColor(this.currentQuestionChecked() ? Constants.COLOR_TEXT_ON_GRADIENT :
              Constants.COLOR_BUTTON_DISABLED_TEXT)
            .backgroundColor(this.currentQuestionChecked() ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
            .borderRadius(Constants.RADIUS_MD)
            .enabled(this.currentQuestionChecked())
            .onClick(() => { this.goToQuestion(this.currentIndex + 1); })
        } else {
          Button(this.submitting ? '评分中...' : '提交评分')
            .layoutWeight(1)
            .height(48)
            .fontSize(14)
            .fontColor(this.allQuestionsAnswered() && this.allFeedbackChecked() && !this.submitting ?
              Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
            .backgroundColor(this.allQuestionsAnswered() && this.allFeedbackChecked() && !this.submitting ?
              Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
            .borderRadius(Constants.RADIUS_MD)
            .enabled(this.allQuestionsAnswered() && this.allFeedbackChecked() && !this.submitting)
            .onClick(() => { this.submitQuiz(); })
        }
      }
      .width('100%')
      if (this.submitting) {
        this.ScoringProgress()
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
    .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
  }

  @Builder
  QuizAnswerOption(option: string) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Text(option.substring(0, 1))
          .width(30)
          .height(30)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.optionLetterColor(option))
          .textAlign(TextAlign.Center)
          .backgroundColor(this.optionLetterBackground(option))
          .borderRadius(15)
        Text(option.length > 2 ? option.substring(2).trim() : option)
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
          .textAlign(TextAlign.Start)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.currentQuestionChecked() && (this.optionIsCorrect(option) || this.optionIsWrongSelection(option))) {
          SymbolGlyph($r(this.optionIsCorrect(option) ? 'sys.symbol.checkmark_circle_fill' :
            'sys.symbol.xmark_circle_fill'))
            .fontSize(19)
            .fontColor([this.optionIconColor(option)])
        } else if (this.currentAnswerText() === option) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(19)
            .fontColor([Constants.COLOR_BRAND])
        }
      }
      .width('100%')
      .padding({ left: 13, right: 13 })
    }
    .width('100%')
    .constraintSize({ minHeight: 58 })
    .backgroundColor(this.optionBackgroundColor(option))
    .border({ width: 1, color: this.optionBorderColor(option) })
    .borderRadius(Constants.RADIUS_MD)
    .onClick((): void => { this.chooseAnswer(option); })
  }

  @Builder
  QuestionFeedbackCard() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r(this.currentQuestionCorrect() ? 'sys.symbol.checkmark_circle_fill' :
          'sys.symbol.exclamationmark_circle_fill'))
          .fontSize(20)
          .fontColor([this.currentQuestionCorrect() ? Constants.COLOR_SUCCESS : Constants.COLOR_WARNING])
        Text(this.currentQuestionCorrect() ? '判断正确' : '先标记这个薄弱点')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.currentQuestionCorrect() ? Constants.COLOR_SUCCESS : Constants.COLOR_WARNING)
        Blank()
        Text('答案已锁定')
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)
      }
      .width('100%')

      Text(this.currentQuestionCorrect() ? '这题已经掌握，下一题继续保持判断节奏。' :
        '没关系，先看正确选项和关键理由，提交成功后会进入复盘链路。')
        .width('100%')
        .fontSize(13)
        .lineHeight(21)
        .fontColor(Constants.COLOR_TEXT_TERTIARY)

      Text('你的答案：' + this.currentAnswerText())
        .width('100%')
        .fontSize(12)
        .fontColor(this.currentQuestionCorrect() ? Constants.COLOR_SUCCESS : Constants.COLOR_WARNING)

      if (!this.currentQuestionCorrect()) {
        Text('正确答案：' + this.currentCorrectAnswerText())
          .width('100%')
          .fontSize(12)
          .fontColor(Constants.COLOR_SUCCESS)
      }

      Text(this.currentExplanation())
        .width('100%')
        .fontSize(13)
        .lineHeight(21)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.currentQuestionCorrect() ? Constants.COLOR_SUCCESS_LIGHT : Constants.COLOR_SURFACE_TINT)
    .border({
      width: 1,
      color: this.currentQuestionCorrect() ? Constants.COLOR_SUCCESS : Constants.COLOR_BG_PROGRESS_TRACK
    })
    .borderRadius(Constants.RADIUS_MD)
  }

  @Builder
  ResultState() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 3 }) {
          Text(Math.round(this.resultAccuracy * 100).toString() + '%')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.resultAccuracy >= 0.6 ? Constants.COLOR_SUCCESS : Constants.COLOR_WARNING)
          Text('正确率')
            .fontSize(12)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        Column({ space: 4 }) {
          Text(this.resultCorrectCount.toString() + ' / ' + this.resultTotalQuestions.toString() + ' 题正确')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text(this.resultAccuracy >= 0.8 ? '掌握得很好，可以进入下一主题' : '查看解析后，再练一组巩固薄弱点')
            .fontSize(12)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
          Text('本次难度：' + this.difficultyLabel())
            .fontSize(11)
            .fontColor(Constants.COLOR_TEXT_TERTIARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 18 })
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Constants.COLOR_BG_CARD)
      .borderRadius(Constants.RADIUS_LG)

      Column({ space: 12 }) {
        Row() {
          Text('下一步闭环')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text(this.incorrectDetails().length > 0 ?
            this.incorrectDetails().length.toString() + ' 题待复盘' : '可以加难度')
            .fontSize(11)
            .fontColor(this.incorrectDetails().length > 0 ? Constants.COLOR_WARNING : Constants.COLOR_SUCCESS)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)

        Text(this.incorrectDetails().length > 0 ?
          '先回看薄弱标签，再让学伴讲第一道错题的判断步骤。' : '本轮表现稳定，下一组可直接切到挑战难度。')
          .width('100%')
          .fontSize(13)
          .lineHeight(21)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)

        if (this.incorrectDetails().length > 0) {
          Row({ space: 10 }) {
            Button('复习 ' + this.primaryReviewKeyword())
              .layoutWeight(1)
              .height(44)
              .fontSize(12)
              .fontColor(Constants.COLOR_BRAND)
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.reviewPrimaryWeakPoint(); })
            Button('问学伴')
              .layoutWeight(1)
              .height(44)
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.askFirstIncorrect(); })
          }
          .width('100%')
        } else {
          Button('下一组用挑战难度')
            .width('100%')
            .height(44)
            .fontSize(13)
            .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
            .backgroundColor(Constants.COLOR_BRAND)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.restartHardQuiz(); })
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Constants.COLOR_SURFACE_TINT)
      .borderRadius(Constants.RADIUS_MD)

      if (this.weakTopics.length > 0) {
        Column({ space: 10 }) {
          Text('建议复习')
            .width('100%')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.weakTopics, (topic: string): void => {
              Button(topic)
                .height(38)
                .fontSize(12)
                .fontColor(Constants.COLOR_WARNING)
                .padding({ left: 12, right: 12 })
                .backgroundColor(Constants.COLOR_BG_CARD)
                .borderRadius(Constants.RADIUS_SM)
                .margin({ right: 8, bottom: 8 })
                .onClick(() => { this.reviewTopic(topic); })
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Constants.COLOR_SURFACE_TINT)
        .borderRadius(Constants.RADIUS_MD)
      }

      Text('逐题解析')
        .width('100%')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)

      Column() {
        ForEach(this.resultDetails, (detail: QuizResultDetail, index: number): void => {
          ReviewDetailRow(detail, index, this.expandedResultId === detail.questionId, (): void => {
            this.expandedResultId = this.expandedResultId === detail.questionId ? '' : detail.questionId;
          }, (): void => { this.askTutor(detail); })
          if (index < this.resultDetails.length - 1) {
            Divider().color(Constants.COLOR_BORDER).margin({ left: 44 })
          }
        })
      }
      .width('100%')
      .backgroundColor(Constants.COLOR_BG_CARD)
      .borderRadius(Constants.RADIUS_LG)

      Button('再练一组')
        .width('100%')
        .height(50)
        .fontSize(15)
        .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
        .backgroundColor(Constants.COLOR_BRAND)
        .borderRadius(Constants.RADIUS_MD)
        .onClick(() => { this.resetQuiz(); })
    }
    .width('100%')
  }

  build() {
    Column() {
      GradientHeader('课程测验', this.courseTitle + ' · 即时评分', () => this.getUIContext().getRouter().back())

      if (this.message.length > 0) {
        Text(this.message)
          .width('100%')
          .fontSize(12)
          .fontColor(Constants.COLOR_ERROR)
          .padding({ left: 18, right: 18, bottom: 10 })
      }

      Scroll(this.contentScroller) {
        Column() {
          if (this.loading) {
            this.LoadingState()
          } else if (this.resultReady) {
            this.ResultState()
          } else if (this.questions.length > 0) {
            this.QuestionState()
          } else {
            this.SetupState()
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 28 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }

  pageTransition() {
    PageTransitionEnter({ duration: Constants.ANIM_NORMAL, curve: Curve.EaseOut })
      .slide(SlideEffect.Left)
    PageTransitionExit({ duration: Constants.ANIM_NORMAL, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
  }
}
