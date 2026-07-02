/**
 * 课程测验页 - 真实 AI 出题、本地评分与学习记录
 */

import { AnswerOption, GradientHeader, ReviewDetailRow } from '../common/Builders';
import { Constants } from '../common/Constants';
import { HttpClient } from '../common/HttpClient';
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
  @State resultReady: boolean = false;
  @State resultAccuracy: number = 0;
  @State resultCorrectCount: number = 0;
  @State resultTotalQuestions: number = 0;
  @State resultDetails: QuizResultDetail[] = [];
  @State expandedResultId: string = '';
  @State evaluation: string = '';
  @State weakTopics: string[] = [];
  private grading: QuizGradingItem[] = [];
  private suggestions: string[] = ['二叉树与BST', '图的遍历', '动态规划'];
  private difficultyOptions: DifficultyOption[] = [
    { value: 'easy', label: '基础', description: '概念识别' },
    { value: 'medium', label: '进阶', description: '场景判断' },
    { value: 'hard', label: '挑战', description: '多步推理' }
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
      if (!Array.isArray(response.questions) || !Array.isArray(response.grading) ||
        response.questions.length === 0 || response.questions.length !== response.grading.length) {
        throw new Error('Invalid quiz response');
      }
      const nextAnswers = new Array<string>(response.questions.length).fill('');
      this.quizId = response.quizId;
      this.grading = response.grading;
      // 先提交答案槽位，最后提交题目，避免 ArkUI 在两次状态更新之间读取未初始化答案。
      this.answers = nextAnswers;
      this.questions = response.questions;
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
    this.submitting = true;
    this.message = '';
    const details: QuizResultDetail[] = [];
    let correctCount = 0;
    for (let i = 0; i < this.questions.length; i++) {
      const question = this.questions[i];
      const grading = this.findGrading(question.id);
      const userAnswer = this.answers[i] ?? '';
      const isCorrect = this.answerLetter(userAnswer) === grading.answer.trim().toUpperCase();
      if (isCorrect) correctCount += 1;
      const detail: QuizResultDetail = {
        questionId: question.id,
        stem: question.stem,
        userAnswer: userAnswer,
        correctAnswer: this.correctOption(question, grading.answer),
        isCorrect: isCorrect,
        explanation: grading.explanation
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

  private findGrading(questionId: string): QuizGradingItem {
    for (const item of this.grading) {
      if (item.questionId === questionId) return item;
    }
    return { questionId: questionId, answer: '', explanation: '暂无解析' };
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
      Column().width('36%').height(18).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(6)
      Column().width('100%').height(86).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(14)
      Column().width('100%').height(52).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
      Column().width('100%').height(52).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
      Column().width('100%').height(52).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
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
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
    .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
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
        Text(this.message)
          .width('100%')
          .fontSize(12)
          .fontColor(Constants.COLOR_ERROR)
          .padding({ left: 18, right: 18, bottom: 10 })
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
