/**
 * 课程测验页 - 原生答题、服务端评分与错题解析
 */

import { GradientHeader } from '../common/Builders';
import { Constants } from '../common/Constants';
import { HttpClient } from '../common/HttpClient';
import {
  QuizAnswer,
  QuizQuestionView,
  QuizRequest,
  QuizResult,
  QuizResultDetail,
  QuizSubmission,
  QuizView,
} from '../model/DataModels';

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
  @State message: string = '';
  @State resultReady: boolean = false;
  @State resultAccuracy: number = 0;
  @State resultCorrectCount: number = 0;
  @State resultTotalQuestions: number = 0;
  @State resultDetails: QuizResultDetail[] = [];
  @State evaluation: string = '';
  @State weakTopics: string[] = [];
  private suggestions: string[] = ['二叉树与BST', '图的遍历', '动态规划'];

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
  }

  private get currentAnswer(): string {
    return this.answers[this.currentIndex] ?? '';
  }

  private chooseAnswer(answer: string): void {
    const nextAnswers = this.answers.slice();
    nextAnswers[this.currentIndex] = answer;
    this.answers = nextAnswers;
  }

  private resetQuiz(): void {
    this.quizId = '';
    this.questions = [];
    this.answers = [];
    this.currentIndex = 0;
    this.message = '';
    this.resultReady = false;
    this.resultDetails = [];
    this.evaluation = '';
    this.weakTopics = [];
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
      difficulty: 'medium',
    };
    try {
      const response = await HttpClient.post<QuizView>(
        Constants.API_QUIZ,
        JSON.stringify(request)
      );
      this.quizId = response.quizId;
      this.questions = response.questions;
      this.answers = new Array<string>(response.questions.length).fill('');
      if (this.questions.length === 0) {
        this.message = '当前主题暂时没有可用题目';
      }
    } catch (e) {
      this.message = '题目加载失败，请确认学习服务已启动';
    } finally {
      this.loading = false;
    }
  }

  async submitQuiz(): Promise<void> {
    if (this.submitting || this.quizId.length === 0) return;
    this.submitting = true;
    this.message = '';
    const answerList: QuizAnswer[] = [];
    for (let i = 0; i < this.questions.length; i++) {
      const answer: QuizAnswer = {
        questionId: this.questions[i].id,
        userAnswer: this.answers[i] ?? '',
      };
      answerList.push(answer);
    }
    const request: QuizSubmission = {
      quizId: this.quizId,
      userId: Constants.DEMO_USER_ID,
      answers: answerList,
    };
    try {
      const response = await HttpClient.post<QuizResult>(
        Constants.API_QUIZ_SUBMIT,
        JSON.stringify(request)
      );
      this.resultAccuracy = response.accuracy;
      this.resultCorrectCount = response.correctCount;
      this.resultTotalQuestions = response.totalQuestions;
      this.resultDetails = response.details;
      this.evaluation = response.evaluation;
      this.weakTopics = response.weakTopics;
      this.resultReady = true;
    } catch (e) {
      this.message = '提交失败，请稍后重试';
    } finally {
      this.submitting = false;
    }
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
        Text('每组 5 道选择题，提交后立即查看解析')
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
          Button(option)
            .width('100%')
            .height(54)
            .fontSize(14)
            .fontColor(this.currentAnswer === option ? Constants.COLOR_BRAND : Constants.COLOR_TEXT_PRIMARY)
            .backgroundColor(this.currentAnswer === option ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_TAG)
            .border({
              width: this.currentAnswer === option ? 1 : 0,
              color: Constants.COLOR_BRAND,
            })
            .borderRadius(Constants.RADIUS_MD)
            .onClick(() => { this.chooseAnswer(option); })
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
            .fontColor(this.currentAnswer.length > 0 ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
            .backgroundColor(this.currentAnswer.length > 0 ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
            .borderRadius(Constants.RADIUS_MD)
            .enabled(this.currentAnswer.length > 0)
            .onClick(() => { this.currentIndex += 1; })
        } else {
          Button(this.submitting ? '评分中...' : '提交评分')
            .layoutWeight(1)
            .height(48)
            .fontSize(14)
            .fontColor(this.currentAnswer.length > 0 && !this.submitting ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
            .backgroundColor(this.currentAnswer.length > 0 && !this.submitting ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
            .borderRadius(Constants.RADIUS_MD)
            .enabled(this.currentAnswer.length > 0 && !this.submitting)
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
              Text(topic)
                .fontSize(12)
                .fontColor(Constants.COLOR_WARNING)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .backgroundColor(Constants.COLOR_BG_CARD)
                .borderRadius(Constants.RADIUS_SM)
                .margin({ right: 8, bottom: 8 })
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

      ForEach(this.resultDetails, (detail: QuizResultDetail, index: number): void => {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            SymbolGlyph($r(detail.isCorrect ? 'sys.symbol.checkmark_circle_fill' : 'sys.symbol.xmark_circle_fill'))
              .fontSize(18)
              .fontColor([detail.isCorrect ? Constants.COLOR_SUCCESS : Constants.COLOR_ERROR])
            Text((index + 1).toString() + '. ' + detail.stem)
              .layoutWeight(1)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
          }
          .width('100%')
          Text('你的答案：' + (detail.userAnswer.length > 0 ? detail.userAnswer : '未作答'))
            .width('100%')
            .fontSize(12)
            .fontColor(detail.isCorrect ? Constants.COLOR_SUCCESS : Constants.COLOR_ERROR)
          if (!detail.isCorrect) {
            Text('正确答案：' + detail.correctAnswer)
              .width('100%')
              .fontSize(12)
              .fontColor(Constants.COLOR_SUCCESS)
          }
          Text(detail.explanation)
            .width('100%')
            .fontSize(12)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
            .lineHeight(20)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Constants.COLOR_BG_CARD)
        .borderRadius(Constants.RADIUS_MD)
      })

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
