import { GradientHeader, ReviewDetailRow } from '../common/Builders';
import { Constants } from '../common/Constants';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { CuratedQuestion, QuizResult, QuizResultDetail } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

const EMPTY_QUESTION: CuratedQuestion = {
  id: '',
  courseId: '',
  topic: '',
  question: '',
  options: [],
  answer: '',
  explanation: ''
};

@Entry
@Component
struct PracticePage {
  private contentScroller: Scroller = new Scroller();
  @State courseId: string = 'cs101';
  @State courseTitle: string = '数据结构';
  @State topic: string = '';
  @State questions: CuratedQuestion[] = [];
  @State activeQuestion: CuratedQuestion = EMPTY_QUESTION;
  @State answers: string[] = [];
  @State activeAnswer: string = '';
  @State checkedQuestionIds: string[] = [];
  @State currentIndex: number = 0;
  @State submitted: boolean = false;
  @State saving: boolean = false;
  @State correctCount: number = 0;
  @State details: QuizResultDetail[] = [];
  @State expandedDetailId: string = '';
  @State message: string = '';

  aboutToAppear(): void {
    this.courseId = AppStorage.get<string>('selectedCourseId') ?? 'cs101';
    this.courseTitle = AppStorage.get<string>('selectedCourseTitle') ?? '数据结构';
    this.topic = AppStorage.get<string>('selectedPracticeTopic') ?? '';
    this.loadQuestions().catch((): void => {
      this.message = '本地练习加载失败，请重新进入';
    });
  }

  private async loadQuestions(): Promise<void> {
    const available = LearningContentRepository.getQuestions(this.courseId, this.topic);
    const reviews = await LocalLearningRepository.getDueReviewItems();
    const results = await LocalLearningRepository.getQuizResults();
    const reviewIds: string[] = [];
    const attemptedIds: string[] = [];
    for (const review of reviews) {
      if (review.courseId === this.courseId && review.topic === this.topic) reviewIds.push(review.questionId);
    }
    for (const result of results) {
      if (result.courseId !== this.courseId || result.topic !== this.topic) continue;
      for (const detail of result.details) {
        if (!attemptedIds.includes(detail.questionId)) attemptedIds.push(detail.questionId);
      }
    }
    const ordered: CuratedQuestion[] = [];
    for (const question of available) {
      if (reviewIds.includes(question.id)) ordered.push(question);
    }
    for (const question of available) {
      if (!reviewIds.includes(question.id) && !attemptedIds.includes(question.id)) ordered.push(question);
    }
    for (const question of available) {
      if (!reviewIds.includes(question.id) && attemptedIds.includes(question.id)) ordered.push(question);
    }
    const selectedQuestions = ordered.slice(0, 5);
    this.answers = new Array<string>(selectedQuestions.length).fill('');
    this.checkedQuestionIds = [];
    this.questions = selectedQuestions;
    this.currentIndex = 0;
    this.activeQuestion = selectedQuestions.length > 0 ? selectedQuestions[0] : EMPTY_QUESTION;
    this.activeAnswer = '';
    this.submitted = false;
    this.details = [];
    this.correctCount = 0;
    this.message = selectedQuestions.length > 0 ? '' : '这个主题还没有精选练习';
  }

  private choose(option: string): void {
    if (this.submitted || this.currentQuestionChecked()) return;
    const next = this.answers.slice();
    next[this.currentIndex] = option;
    this.answers = next;
    this.activeAnswer = option;
  }

  private askTutor(detail: QuizResultDetail): void {
    const question = '请结合课程资料讲解这道题：' + detail.stem +
      '。我的答案是“' + (detail.userAnswer.length > 0 ? detail.userAnswer : '未作答') +
      '”，正确答案是“' + detail.correctAnswer + '”。请指出关键概念和判断步骤。';
    AppStorage.setOrCreate<string>('selectedCourseId', this.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle);
    AppStorage.setOrCreate<string>('pendingChatQuestion', question);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Chat' }).catch((): void => {
      this.message = '无法打开学伴，请重试';
    });
  }

  private openQuiz(): void {
    AppStorage.setOrCreate<string>('selectedCourseId', this.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.courseTitle);
    AppStorage.setOrCreate<string>('selectedQuizTopic', this.topic.length > 0 ? this.topic : '综合');
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Quiz' }).catch((err: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'PracticePage Quiz navigation failed: %{public}s', err.message);
    });
  }

  private answerLetter(option: string): string {
    const value = option.trim().toUpperCase();
    return value.length > 0 ? value.substring(0, 1) : '';
  }

  private allAnswered(): boolean {
    return this.answers.length > 0 && this.answers.every((answer: string): boolean => answer.length > 0);
  }

  private currentAnswerText(): string {
    const answer = this.answers[this.currentIndex];
    return typeof answer === 'string' ? answer : '';
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

  private allFeedbackChecked(): boolean {
    if (this.questions.length === 0) return false;
    for (const question of this.questions) {
      if (!this.checkedQuestionIds.includes(question.id)) return false;
    }
    return true;
  }

  private readyToSubmit(): boolean {
    return this.allAnswered() && this.allFeedbackChecked() && !this.saving;
  }

  private checkCurrentQuestion(): void {
    if (this.currentAnswerText().length === 0) {
      this.message = '请先选择一个答案';
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
    this.activeQuestion = this.questions[this.currentIndex];
    this.activeAnswer = this.answers[this.currentIndex] ?? '';
    this.message = '';
    this.contentScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
  }

  private currentQuestionCorrect(): boolean {
    return this.answerLetter(this.currentAnswerText()) === this.activeQuestion.answer.trim().toUpperCase();
  }

  private currentCorrectAnswerText(): string {
    return this.findCorrectOption(this.activeQuestion);
  }

  private currentExplanation(): string {
    return this.activeQuestion.explanation;
  }

  private optionIsCorrect(option: string): boolean {
    return this.answerLetter(option) === this.activeQuestion.answer.trim().toUpperCase();
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

  private feedbackActionLabel(): string {
    if (this.currentIndex < this.questions.length - 1) return '进入下一题';
    return this.saving ? '保存中...' : '提交本组总结';
  }

  private feedbackActionEnabled(): boolean {
    if (this.saving) return false;
    if (this.currentIndex < this.questions.length - 1) return true;
    return this.readyToSubmit();
  }

  private handleFeedbackAction(): void {
    if (!this.feedbackActionEnabled()) return;
    if (this.currentIndex < this.questions.length - 1) {
      this.goToQuestion(this.currentIndex + 1);
      return;
    }
    this.submit();
  }

  private async submit(): Promise<void> {
    if (!this.readyToSubmit()) {
      this.message = '请先完成全部题目并查看每题反馈';
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
        userAnswer: userAnswer,
        correctAnswer: this.findCorrectOption(question),
        isCorrect: correct,
        explanation: question.explanation
      });
    }
    const result: QuizResult = {
      quizId: 'curated-' + Date.now().toString(),
      userId: Constants.DEMO_USER_ID,
      courseId: this.courseId,
      topic: this.topic.length > 0 ? this.topic : '综合',
      source: 'curated',
      totalQuestions: this.questions.length,
      correctCount: totalCorrect,
      accuracy: totalCorrect / this.questions.length,
      details: nextDetails,
      evaluation: totalCorrect === this.questions.length ? '本组精选练习全部答对。' : '已记录错题，可根据解析继续巩固。',
      weakTopics: totalCorrect < this.questions.length ? [this.topic] : [],
      submittedAt: new Date().toISOString()
    };
    try {
      await LocalLearningRepository.appendQuizResult(result);
      this.correctCount = totalCorrect;
      this.details = nextDetails;
      this.expandedDetailId = nextDetails.find((detail: QuizResultDetail): boolean => !detail.isCorrect)?.questionId ?? '';
      this.submitted = true;
    } catch (error) {
      this.message = '答题记录保存失败，请重试';
    } finally {
      this.saving = false;
    }
  }

  private findCorrectOption(question: CuratedQuestion): string {
    for (const option of question.options) {
      if (this.answerLetter(option) === question.answer.trim().toUpperCase()) return option;
    }
    return question.answer;
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
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      Progress({ value: this.currentIndex + 1, total: this.questions.length, type: ProgressType.Linear })
        .width('100%')
        .color(Constants.COLOR_BRAND)
        .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)

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

      Text(this.activeQuestion.question)
        .width('100%')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
        .lineHeight(27)
      Column({ space: 10 }) {
        ForEach(this.activeQuestion.options, (option: string): void => {
          this.PracticeAnswerOption(option)
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
          .height(46)
          .enabled(this.currentIndex > 0)
          .fontColor(this.currentIndex > 0 ? Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_BUTTON_DISABLED_TEXT)
          .backgroundColor(Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.goToQuestion(this.currentIndex - 1); })
        if (this.currentIndex < this.questions.length - 1) {
          Button('下一题')
            .layoutWeight(1)
            .height(46)
            .enabled(this.currentQuestionChecked())
            .fontColor(this.currentQuestionChecked() ? Constants.COLOR_TEXT_ON_GRADIENT :
              Constants.COLOR_BUTTON_DISABLED_TEXT)
            .backgroundColor(this.currentQuestionChecked() ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.goToQuestion(this.currentIndex + 1); })
        } else {
          Button(this.saving ? '保存中...' : '提交评分')
            .layoutWeight(1)
            .height(46)
            .enabled(this.readyToSubmit())
            .fontColor(this.readyToSubmit() ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
            .backgroundColor(this.readyToSubmit() ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
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
  PracticeAnswerOption(option: string) {
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
    .onClick((): void => { this.choose(option); })
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
        '先看正确选项和关键理由，本题会在提交后进入错题复盘。')
        .width('100%')
        .fontSize(13)
        .lineHeight(21)
        .fontColor(Constants.COLOR_TEXT_TERTIARY)

      Button(this.feedbackActionLabel())
        .width('100%')
        .height(42)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.feedbackActionEnabled() ? Constants.COLOR_TEXT_ON_GRADIENT :
          Constants.COLOR_BUTTON_DISABLED_TEXT)
        .backgroundColor(this.feedbackActionEnabled() ? Constants.COLOR_BRAND :
          Constants.COLOR_BUTTON_DISABLED_BG)
        .borderRadius(Constants.RADIUS_MD)
        .enabled(this.feedbackActionEnabled())
        .onClick((): void => { this.handleFeedbackAction(); })

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
          Text(this.correctCount === this.questions.length ? '已全部掌握，可以继续新主题' : '先复盘错题，再进入下一组')
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
        Button('返回课程')
          .layoutWeight(1)
          .height(48)
          .fontColor(Constants.COLOR_BRAND)
          .backgroundColor(Constants.COLOR_BRAND_LIGHT)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.getUIContext().getRouter().back(); })
        Button('进入 AI 测验')
          .layoutWeight(1)
          .height(48)
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
          .backgroundColor(Constants.COLOR_BRAND)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.openQuiz(); })
      }
      .width('100%')
    }
    .width('100%')
  }

  build() {
    Column() {
      GradientHeader('精选练习', this.courseTitle + (this.topic.length > 0 ? ' · ' + this.topic : ''),
        () => this.getUIContext().getRouter().back())
      if (this.message.length > 0) {
        Text(this.message).fontSize(12).fontColor(Constants.COLOR_ERROR).padding({ bottom: 8 })
      }
      Scroll(this.contentScroller) {
        Column() {
          if (this.questions.length === 0) {
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
        .padding({ left: 16, right: 16, bottom: 28 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
