/**
 * 课程测验页 - 真实 AI 出题、本地评分与学习记录
 */

import { AnswerOption, GradientHeader, ReviewDetailRow, StagedProgress, WorkStep } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { HttpClient } from '../common/HttpClient';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  QuizPackage,
  QuizRequest,
} from '../model/DataModels';
import {
  LearningQuizGradingItem as QuizGradingItem,
  LearningQuizQuestionView as QuizQuestionView,
  LearningQuizResult as QuizResult,
  LearningQuizResultDetail as QuizResultDetail
} from '../model/LearningMetadataModels';
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
  @State hasError: boolean = false;
  @State resultReady: boolean = false;
  @State resultAccuracy: number = 0;
  @State resultCorrectCount: number = 0;
  @State resultTotalQuestions: number = 0;
  @State resultDetails: QuizResultDetail[] = [];
  @State expandedResultId: string = '';
  @State evaluation: string = '';
  @State weakTopics: string[] = [];
  @State progressStep: number = 0;
  private grading: QuizGradingItem[] = [];
  private answerLabels: string[] = ['A', 'B', 'C', 'D'];
  private suggestions: string[] = ['二叉树与BST', '图的遍历', '动态规划'];
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
    if (this.courseId === 'cs102') {
      this.suggestions = ['进程与线程', 'CPU调度', '虚拟内存与分页'];
    } else if (this.courseId === 'cs103') {
      this.suggestions = ['TCP握手与流量控制', 'HTTP协议', 'DNS系统'];
    } else {
      this.suggestions = ['二叉树与BST', '图的遍历', '动态规划'];
    }
    const selectedTopic = AppStorage.get<string>('selectedQuizTopic') ?? '';
    if (selectedTopic.trim().length > 0) {
      this.topic = selectedTopic.trim();
      AppStorage.setOrCreate<string>('selectedQuizTopic', '');
    }
  }

  private currentAnswerText(): string {
    const answer = this.answers[this.currentIndex];
    return typeof answer === 'string' ? answer : '';
  }

  private chooseAnswer(answer: string): void {
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
    this.hasError = false;
    this.resultReady = false;
    this.resultDetails = [];
    this.expandedResultId = '';
    this.evaluation = '';
    this.weakTopics = [];
    this.grading = [];
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

  async generateQuiz(): Promise<void> {
    if (this.loading) return;
    this.resetQuiz();
    this.loading = true;
    this.runGenerationProgress();
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
        this.hasError = true;
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
        this.hasError = true;
      } else {
        this.message = '题目已生成，完成后会按标签记录到本机';
        this.hasError = false;
      }
    } catch (e) {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'QuizPage API failed: %{public}s', (e as Error).message);
      this.message = this.quizErrorMessage(e as Error);
      this.hasError = true;
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
        difficulty: grading.difficulty ?? question.difficulty ?? this.difficulty,
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
      difficulty: this.difficulty,
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
        difficulty: this.quizDifficulty(source.difficulty) ?? this.difficulty,
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
        difficulty: this.quizDifficulty(source.difficulty) ?? this.difficulty,
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

  private quizDifficulty(value?: string): string | undefined {
    const normalized = this.cleanText(value);
    if (normalized === 'easy' || normalized === 'medium' || normalized === 'hard') return normalized;
    return undefined;
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

  private answerLetter(answer: string): string {
    const trimmed = answer.trim().toUpperCase();
    if (trimmed.length === 0) return '';
    return trimmed.substring(0, 1);
  }

  private runGenerationProgress(): void {
    this.progressStep = 0;
    setTimeout((): void => {
      if (this.loading) this.progressStep = 1;
    }, 700);
    setTimeout((): void => {
      if (this.loading) this.progressStep = 2;
    }, 2200);
  }

  private quizErrorMessage(error: Error): string {
    const message = error.message;
    if (message.includes('MODEL_INVALID_RESPONSE')) {
      return '这组 AI 题目格式没过校验，答案不会保存。请点重试重新生成。';
    }
    if (message.includes('MODEL_TIMEOUT')) {
      return 'AI 出题超时了，当前主题和难度已保留，请稍后重试。';
    }
    if (message.includes('KNOWLEDGE_UNAVAILABLE')) {
      return '当前主题缺少课程资料，请换一个主题或先学习相关课程。';
    }
    if (message.includes('SAFETY_BLOCKED')) {
      return '这组题目没有通过安全审核，请重新生成一组。';
    }
    if (message.startsWith('HTTP ')) {
      return '云端出题暂时失败，未保存题组。请检查网络后重试。';
    }
    return '云端学伴暂不可用，请检查网络后重试';
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

  private questionDifficultyLabel(value?: string): string {
    if (value === 'easy') return '基础';
    if (value === 'hard') return '挑战';
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
      this.progressStep >= 2 ? '正在整理题目标签' :
        (this.progressStep === 1 ? '正在控制难度与题型' : '正在检索课程依据'),
      this.progressStep >= 2 ? '校验 A-D 选项、解析和能力标签' :
        (this.progressStep === 1 ? '围绕“' + this.topic + '”生成 ' + this.difficultyLabel() + '题组' :
          '先查课程资料，再让 AI 出题，避免凭空编题'),
      this.progressStep,
      this.generationSteps
    )
  }

  @Builder
  MessageBanner() {
    Row({ space: 8 }) {
      SymbolGlyph($r(this.hasError ? 'sys.symbol.exclamationmark_triangle_fill' : 'sys.symbol.checkmark_circle_fill'))
        .fontSize(16)
        .fontColor([this.hasError ? Constants.COLOR_ERROR : Constants.COLOR_SUCCESS])
      Text(this.message)
        .layoutWeight(1)
        .fontSize(12)
        .lineHeight(18)
        .fontColor(this.hasError ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
      if (this.hasError && !this.loading && this.questions.length === 0) {
        Button('重试')
          .height(32)
          .fontSize(12)
          .fontColor(Constants.COLOR_BRAND)
          .backgroundColor(Constants.COLOR_BRAND_LIGHT)
          .borderRadius(Constants.RADIUS_SM)
          .onClick((): void => { this.generateQuiz(); })
      }
    }
    .width('100%')
    .padding({ left: 18, right: 18, bottom: 10 })
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

      if ((this.questions[this.currentIndex].tags ?? []).length > 0 ||
        this.questions[this.currentIndex].difficulty !== undefined) {
        Flex({ wrap: FlexWrap.Wrap }) {
          Text(this.questionDifficultyLabel(this.questions[this.currentIndex].difficulty))
            .fontSize(10)
            .fontColor(Constants.COLOR_TEXT_TERTIARY)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(Constants.COLOR_BG_TAG)
            .borderRadius(9)
            .margin({ right: 6, bottom: 6 })
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
          AnswerOption(option, this.currentAnswerText() === option, (): void => { this.chooseAnswer(option); })
        })
      }
      .width('100%')

      Row({ space: 10 }) {
        Button('上一题')
          .layoutWeight(1)
          .height(48)
          .fontSize(14)
          .fontColor(this.currentIndex > 0 ? Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_BUTTON_DISABLED_TEXT)
          .backgroundColor(Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_MD)
          .enabled(this.currentIndex > 0)
          .onClick(() => { this.currentIndex -= 1; })

        if (this.currentIndex < this.questions.length - 1) {
          Button('下一题')
            .layoutWeight(1)
            .height(48)
            .fontSize(14)
            .fontColor(this.currentAnswerText().length > 0 ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
            .backgroundColor(this.currentAnswerText().length > 0 ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
            .borderRadius(Constants.RADIUS_MD)
            .enabled(this.currentAnswerText().length > 0)
            .onClick(() => { this.currentIndex += 1; })
        } else {
          Button(this.submitting ? '评分中...' : '提交评分')
            .layoutWeight(1)
            .height(48)
            .fontSize(14)
            .fontColor(this.currentAnswerText().length > 0 && !this.submitting ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
            .backgroundColor(this.currentAnswerText().length > 0 && !this.submitting ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
            .borderRadius(Constants.RADIUS_MD)
            .enabled(this.currentAnswerText().length > 0 && !this.submitting)
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
        this.MessageBanner()
      }

      Scroll() {
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
        .padding({ left: 16, right: 16, bottom: 28 + SafeAreaInsets.bottomVp() })
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
