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

interface QuizLengthOption {
  value: number;
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

interface QuizTagSummary {
  tag: string;
  totalQuestions: number;
  wrongQuestions: number;
  accuracy: number;
  action: string;
}

@Entry
@Component
struct QuizPage {
  @State courseId: string = 'cs101';
  @State courseTitle: string = '数据结构';
  @State topic: string = '综合';
  @State focusTag: string = '';
  @State quizId: string = '';
  @State questions: QuizQuestionView[] = [];
  @State answers: string[] = [];
  @State currentIndex: number = 0;
  @State loading: boolean = false;
  @State submitting: boolean = false;
  @State difficulty: string = 'medium';
  @State questionCount: number = 5;
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
  @State resultCoachTitle: string = '';
  @State resultCoachBody: string = '';
  @State resultTagSummaries: QuizTagSummary[] = [];
  @State progressStep: number = 0;
  @State progressTick: number = 0;
  private grading: QuizGradingItem[] = [];
  private answerLabels: string[] = ['A', 'B', 'C', 'D'];
  private suggestions: string[] = ['二叉树与BST', '图的遍历', '动态规划'];
  private difficultyOptions: DifficultyOption[] = [
    { value: 'easy', label: '基础', description: '概念识别' },
    { value: 'medium', label: '进阶', description: '场景判断' },
    { value: 'hard', label: '挑战', description: '多步推理' }
  ];
  private quizLengthOptions: QuizLengthOption[] = [
    { value: 5, label: '速练', description: '5题 · 快速校准' },
    { value: 10, label: '标准', description: '10题 · 稳定证据' },
    { value: 15, label: '挑战', description: '15题 · 深度检验' }
  ];
  private generationSteps: WorkStep[] = [
    { title: '检索', description: '匹配课程资料' },
    { title: '构题', description: '控制难度与题型' },
    { title: '校验', description: '检查 A-D 与解析' },
    { title: '装配', description: '写入标签与答题卡' }
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
    const selectedFocusTag = AppStorage.get<string>('selectedQuizFocusTag') ?? '';
    if (selectedFocusTag.trim().length > 0) {
      this.focusTag = selectedFocusTag.trim().substring(0, 12);
      AppStorage.setOrCreate<string>('selectedQuizFocusTag', '');
    }
  }

  private currentAnswerText(): string {
    const answer = this.answers[this.currentIndex];
    return typeof answer === 'string' ? answer : '';
  }

  private currentQuestion(): QuizQuestionView | null {
    if (this.currentIndex < 0 || this.currentIndex >= this.questions.length) return null;
    const question = this.questions[this.currentIndex];
    return question === undefined ? null : question;
  }

  private currentQuestionStem(): string {
    const question = this.currentQuestion();
    return question === null ? '题目状态异常，请重新生成' : question.stem;
  }

  private currentQuestionOptions(): string[] {
    const question = this.currentQuestion();
    return question === null ? [] : (question.options ?? []);
  }

  private currentQuestionTags(): string[] {
    const question = this.currentQuestion();
    return question === null ? [] : (question.tags ?? []);
  }

  private currentQuestionDifficulty(): string | undefined {
    const question = this.currentQuestion();
    return question === null ? undefined : question.difficulty;
  }

  private currentQuestionReady(): boolean {
    return this.currentQuestion() !== null;
  }

  private chooseAnswer(answer: string): void {
    if (!this.currentQuestionReady()) return;
    const nextAnswers = this.answers.slice();
    nextAnswers[this.currentIndex] = answer;
    this.answers = nextAnswers;
  }

  private selectTopic(nextTopic: string): void {
    this.topic = nextTopic;
    this.focusTag = '';
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
    this.resultCoachTitle = '';
    this.resultCoachBody = '';
    this.resultTagSummaries = [];
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
      count: this.questionCount,
      difficulty: this.difficulty,
      focusTag: this.focusTag.length > 0 ? this.focusTag : undefined,
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

    const wrongCount = this.questions.length - correctCount;
    const weakTopics: string[] = wrongCount > 0 ? [this.topic] : [];
    const accuracy = this.questions.length > 0 ? correctCount / this.questions.length : 0;
    const result: QuizResult = {
      quizId: this.quizId,
      userId: Constants.DEMO_USER_ID,
      courseId: this.courseId,
      topic: this.topic,
      source: 'ai',
      difficulty: this.difficulty,
      totalQuestions: this.questions.length,
      correctCount: correctCount,
      accuracy: accuracy,
      details: details,
      evaluation: this.learningEvaluation(correctCount, this.questions.length),
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
      this.resultCoachTitle = this.coachTitle(result.accuracy, wrongCount);
      this.resultCoachBody = this.coachBody(result.accuracy, wrongCount);
      this.resultTagSummaries = this.buildTagSummaries(result.details);
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

  private learningEvaluation(correctCount: number, totalQuestions: number): string {
    if (totalQuestions === 0) return '本轮暂无可评分题目。';
    if (correctCount === totalQuestions) {
      return '本组题目全部答对，已形成一次高质量掌握证据。';
    }
    const wrongCount = totalQuestions - correctCount;
    if (correctCount / totalQuestions >= 0.8) {
      return '整体掌握稳定，建议只复盘 ' + wrongCount.toString() + ' 道失误题。';
    }
    return '已记录本次答题结果，建议先按错因标签复盘，再做同标签短练。';
  }

  private coachTitle(accuracy: number, wrongCount: number): string {
    if (wrongCount === 0) return '掌握判定：可以前进';
    if (accuracy >= 0.8) return '掌握判定：接近掌握';
    if (accuracy >= 0.6) return '掌握判定：需要巩固';
    return '掌握判定：先补基础';
  }

  private coachBody(accuracy: number, wrongCount: number): string {
    if (wrongCount === 0) {
      return '这轮题已经写入本地画像。你可以挑战更高难度，或去学习星图解锁下一个主题。';
    }
    if (accuracy >= 0.8) {
      return '错题会进入错题本和间隔复习队列。建议先看解析，再用最弱标签加练一组。';
    }
    if (accuracy >= 0.6) {
      return '当前不是简单刷题问题，更像概念条件没有稳定提取。先复习资料，再练同标签题。';
    }
    return '先降低难度复盘核心定义，确认关键词和边界条件后，再回到本主题进阶题。';
  }

  private buildTagSummaries(details: QuizResultDetail[]): QuizTagSummary[] {
    const summaries: QuizTagSummary[] = [];
    for (const detail of details) {
      const sourceTags = (detail.tags ?? []).length > 0 ? (detail.tags ?? []) : [this.topic];
      for (const tag of sourceTags) {
        const normalized = tag.trim();
        if (normalized.length === 0) continue;
        let item = summaries.find((value: QuizTagSummary): boolean => value.tag === normalized);
        if (item === undefined) {
          item = {
            tag: normalized,
            totalQuestions: 0,
            wrongQuestions: 0,
            accuracy: 0,
            action: ''
          };
          summaries.push(item);
        }
        item.totalQuestions += 1;
        if (!detail.isCorrect) item.wrongQuestions += 1;
        item.accuracy = item.totalQuestions > 0 ?
          (item.totalQuestions - item.wrongQuestions) / item.totalQuestions : 0;
        item.action = this.tagAction(item);
      }
    }
    summaries.sort((left: QuizTagSummary, right: QuizTagSummary): number => {
      const wrongDelta = right.wrongQuestions - left.wrongQuestions;
      if (wrongDelta !== 0) return wrongDelta;
      const totalDelta = right.totalQuestions - left.totalQuestions;
      if (totalDelta !== 0) return totalDelta;
      return left.accuracy - right.accuracy;
    });
    return summaries.slice(0, 4);
  }

  private tagAction(item: QuizTagSummary): string {
    if (item.wrongQuestions === 0) return '保持节奏，挑战高难度';
    if (item.accuracy < 0.6) return '先看资料，再练基础题';
    if (item.wrongQuestions >= 2) return '集中复盘错因';
    return '短练一组巩固';
  }

  private tagProgressColor(item: QuizTagSummary): string {
    if (item.wrongQuestions === 0) return Constants.COLOR_SUCCESS;
    if (item.accuracy >= 0.6) return Constants.COLOR_WARNING;
    return Constants.COLOR_ERROR;
  }

  private askTutorForResult(): void {
    const weakTags = this.resultTagSummaries
      .filter((item: QuizTagSummary): boolean => item.wrongQuestions > 0)
      .map((item: QuizTagSummary): string => item.tag)
      .join('、');
    const question = '请帮我复盘这次《' + this.courseTitle + '》' + this.topic +
      '测验：正确率 ' + Math.round(this.resultAccuracy * 100).toString() + '%，' +
      '错题 ' + (this.resultTotalQuestions - this.resultCorrectCount).toString() + ' 道。' +
      (weakTags.length > 0 ? '薄弱标签是：' + weakTags + '。' : '') +
      '请给我一个三步复习方案，并说明下一组题应该怎么练。';
    AppStorage.setOrCreate<string>('pendingChatQuestion', question);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Chat' }).catch((): void => {
      this.message = '无法打开学伴，请重试';
    });
  }

  private startFocusedTagDrill(tag: string): void {
    const normalized = tag.trim().substring(0, 12);
    if (normalized.length === 0) return;
    this.focusTag = normalized;
    this.generateQuiz();
  }

  private runGenerationProgress(): void {
    this.progressStep = 0;
    this.progressTick = 0;
    setTimeout((): void => {
      if (this.loading) {
        this.progressStep = 1;
        this.progressTick = 1;
      }
    }, 700);
    setTimeout((): void => {
      if (this.loading) {
        this.progressStep = 2;
        this.progressTick = 2;
      }
    }, 2200);
    setTimeout((): void => {
      if (this.loading) {
        this.progressStep = 3;
        this.progressTick = 3;
      }
    }, 5200);
    setTimeout((): void => {
      if (this.loading) {
        this.progressTick = 4;
      }
    }, 9800);
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

  private questionCountLabel(): string {
    return this.questionCount.toString() + ' 题';
  }

  private generationTitle(): string {
    if (this.progressStep >= 3) return '正在装配题组';
    if (this.progressStep === 2) return '正在校验题目结构';
    if (this.progressStep === 1) return '正在控制难度与题型';
    return '正在检索课程依据';
  }

  private generationSubtitle(): string {
    if (this.progressStep >= 3) return '把题干、选项、解析和标签整理成可答题卡';
    if (this.progressStep === 2) return '检查 A-D 选项、答案、解析和标签是否完整';
    if (this.progressStep === 1) {
      return '围绕“' + this.topic + '”生成 ' + this.difficultyLabel() + ' · ' + this.questionCountLabel();
    }
    if (this.focusTag.length > 0) return '先查课程资料，再聚焦“' + this.focusTag + '”出题';
    return '先查课程资料，再让 AI 出题，避免凭空编题';
  }

  private generationWaitHint(): string {
    if (this.progressTick >= 4) return '长题组仍在云端生成中：页面没有卡住，返回后会自动进入答题。';
    if (this.questionCount >= 10) return '题量越长，云端会分批生成并校验，等待时间会更久。';
    return '保持在当前页，题组生成后会直接展示第一题。';
  }

  private generationRequestSummary(): string {
    const focus = this.focusTag.length > 0 ? ' · 标签 ' + this.focusTag : '';
    return this.courseTitle + ' · ' + this.topic + ' · ' + this.difficultyLabel() + ' · ' +
      this.questionCountLabel() + focus;
  }

  @Builder
  LoadingState() {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.rays'))
          .width(42)
          .height(42)
          .fontSize(22)
          .fontColor([Constants.COLOR_TEXT_ON_GRADIENT])
          .backgroundColor(Constants.COLOR_BRAND)
          .borderRadius(21)
        Column({ space: 4 }) {
          Text('AI 正在生成题组')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text(this.generationRequestSummary())
            .fontSize(12)
            .lineHeight(18)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.GenerationProgress()

      Column({ space: 9 }) {
        this.GenerationCheckpoint('课程依据', '检索课程资料和最近薄弱标签', this.progressStep >= 0)
        this.GenerationCheckpoint('题目生成', '按难度分层组织题干和选项', this.progressStep >= 1)
        this.GenerationCheckpoint('结构校验', '检查 A-D、答案、解析和标签', this.progressStep >= 2)
        this.GenerationCheckpoint('答题卡装配', '准备首题、进度条和本地记录字段', this.progressStep >= 3)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(Constants.COLOR_SURFACE_TINT)
      .borderRadius(Constants.RADIUS_MD)

      Row({ space: 8 }) {
        LoadingProgress()
          .width(18)
          .height(18)
          .color(Constants.COLOR_BRAND)
        Text(this.generationWaitHint())
          .layoutWeight(1)
          .fontSize(12)
          .lineHeight(18)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(Constants.COLOR_BRAND_LIGHT)
      .borderRadius(Constants.RADIUS_MD)

      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Column().layoutWeight(2).height(14).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(7)
          Column().layoutWeight(1).height(14).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(7)
        }
        .width('100%')
        Column().width('100%').height(54).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
        Column().width('100%').height(42).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
        Column().width('92%').height(42).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
        Column().width('86%').height(42).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(Constants.COLOR_BG_CARD)
      .borderRadius(Constants.RADIUS_MD)
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
  }

  @Builder
  GenerationCheckpoint(title: string, detail: string, active: boolean) {
    Row({ space: 9 }) {
      Text(active ? '✓' : '·')
        .width(22)
        .height(22)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(active ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_PLACEHOLDER)
        .textAlign(TextAlign.Center)
        .backgroundColor(active ? Constants.COLOR_BRAND : Constants.COLOR_BG_PROGRESS_TRACK)
        .borderRadius(11)
      Column({ space: 2 }) {
        Text(title)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(active ? Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_TEXT_PLACEHOLDER)
        Text(detail)
          .fontSize(10)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
  }

  @Builder
  SetupState() {
    Column({ space: 18 }) {
      Column({ space: 6 }) {
        Text('选择本次练习主题')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text('按题量、难度和标签生成真实 AI 题组，完成后立即查看解析')
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
          .onClick(() => { this.selectTopic('综合'); })
        ForEach(this.suggestions, (suggestion: string): void => {
          Button(suggestion)
            .width('100%')
            .height(48)
            .fontSize(14)
            .fontColor(this.topic === suggestion ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_PRIMARY)
            .backgroundColor(this.topic === suggestion ? Constants.COLOR_BRAND : Constants.COLOR_BG_TAG)
            .borderRadius(Constants.RADIUS_MD)
            .onClick(() => { this.selectTopic(suggestion); })
        })
      }
      .width('100%')

      if (this.focusTag.length > 0) {
        Row({ space: 9 }) {
          SymbolGlyph($r('sys.symbol.rays'))
            .fontSize(18)
            .fontColor([Constants.COLOR_BRAND])
          Column({ space: 3 }) {
            Text('本轮重点标签：' + this.focusTag)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
            Text('AI 会围绕这个薄弱标签出题，完成后继续写入标签画像')
              .fontSize(11)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Button('取消')
            .height(30)
            .fontSize(11)
            .fontColor(Constants.COLOR_BRAND)
            .backgroundColor(Constants.COLOR_BRAND_LIGHT)
            .borderRadius(Constants.RADIUS_SM)
            .onClick((): void => { this.focusTag = ''; })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(Constants.COLOR_SURFACE_TINT)
        .borderRadius(Constants.RADIUS_MD)
      }

      Column({ space: 8 }) {
        Text('挑战长度')
          .width('100%')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Row({ space: 8 }) {
          ForEach(this.quizLengthOptions, (option: QuizLengthOption): void => {
            Button({ type: ButtonType.Normal }) {
              Column({ space: 3 }) {
                Text(option.label)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.questionCount === option.value ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_PRIMARY)
                Text(option.description)
                  .fontSize(10)
                  .fontColor(this.questionCount === option.value ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_SECONDARY)
              }
            }
            .layoutWeight(1)
            .height(58)
            .backgroundColor(this.questionCount === option.value ? Constants.COLOR_BRAND : Constants.COLOR_BG_TAG)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.questionCount = option.value; })
          })
        }
        .width('100%')
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
      this.generationTitle(),
      this.generationSubtitle(),
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
      if (!this.currentQuestionReady()) {
        Text('题目状态异常，请重新生成')
          .width('100%')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text('本轮题组没有可展示的当前题，已保护页面不再崩溃。')
          .width('100%')
          .fontSize(13)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .lineHeight(20)
        Button('重新生成')
          .width('100%')
          .height(48)
          .fontSize(14)
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
          .backgroundColor(Constants.COLOR_BRAND)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.generateQuiz(); })
      } else {
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

        Text(this.currentQuestionStem())
          .width('100%')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
          .lineHeight(27)

        if (this.currentQuestionTags().length > 0 ||
          this.currentQuestionDifficulty() !== undefined) {
          Flex({ wrap: FlexWrap.Wrap }) {
            Text(this.questionDifficultyLabel(this.currentQuestionDifficulty()))
              .fontSize(10)
              .fontColor(Constants.COLOR_TEXT_TERTIARY)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(Constants.COLOR_BG_TAG)
              .borderRadius(9)
              .margin({ right: 6, bottom: 6 })
            ForEach(this.currentQuestionTags(), (tag: string): void => {
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
          ForEach(this.currentQuestionOptions(), (option: string): void => {
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
          if (this.focusTag.length > 0) {
            Text('重点标签：' + this.focusTag)
              .fontSize(11)
              .fontColor(Constants.COLOR_BRAND)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 18 })
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Constants.COLOR_BG_CARD)
      .borderRadius(Constants.RADIUS_LG)

      if (this.resultCoachTitle.length > 0) {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            SymbolGlyph($r(this.resultAccuracy >= 0.8 ? 'sys.symbol.sparkles' : 'sys.symbol.lightbulb_fill'))
              .fontSize(18)
              .fontColor([this.resultAccuracy >= 0.8 ? Constants.COLOR_SUCCESS : Constants.COLOR_WARNING])
            Text(this.resultCoachTitle)
              .layoutWeight(1)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
          }
          .width('100%')
          Text(this.resultCoachBody)
            .width('100%')
            .fontSize(13)
            .lineHeight(21)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
          Text(this.evaluation)
            .width('100%')
            .fontSize(12)
            .lineHeight(19)
            .fontColor(Constants.COLOR_TEXT_TERTIARY)
          Row({ space: 10 }) {
            Button('问学伴复盘')
              .layoutWeight(1)
              .height(42)
              .fontSize(12)
              .fontColor(Constants.COLOR_BRAND)
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.askTutorForResult(); })
            Button('复习资料')
              .layoutWeight(1)
              .height(42)
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.reviewTopic(this.topic); })
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Constants.COLOR_SURFACE_TINT)
        .borderRadius(Constants.RADIUS_MD)
      }

      if (this.resultTagSummaries.length > 0) {
        Column({ space: 12 }) {
          Text('错因标签')
            .width('100%')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          ForEach(this.resultTagSummaries, (item: QuizTagSummary): void => {
            Column({ space: 8 }) {
              Row() {
                Text(item.tag)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
                Text('错 ' + item.wrongQuestions.toString() + ' / ' + item.totalQuestions.toString())
                  .fontSize(11)
                  .fontColor(item.wrongQuestions > 0 ? Constants.COLOR_ERROR : Constants.COLOR_SUCCESS)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              Progress({ value: Math.round(item.accuracy * 100), total: 100, type: ProgressType.Linear })
                .width('100%')
                .color(this.tagProgressColor(item))
                .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
                .borderRadius(4)
              Row({ space: 8 }) {
                Text(item.action)
                  .layoutWeight(1)
                  .fontSize(11)
                  .fontColor(Constants.COLOR_TEXT_TERTIARY)
                Button('练这个标签')
                  .height(30)
                  .fontSize(11)
                  .fontColor(Constants.COLOR_BRAND)
                  .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                  .borderRadius(Constants.RADIUS_SM)
                  .onClick((): void => { this.startFocusedTagDrill(item.tag); })
              }
              .width('100%')
            }
            .width('100%')
            .padding(12)
            .backgroundColor(Constants.COLOR_BG_CARD)
            .borderRadius(Constants.RADIUS_MD)
          })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Constants.COLOR_BG_CARD)
        .borderRadius(Constants.RADIUS_LG)
      }

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
