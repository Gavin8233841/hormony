import { GradientHeader } from '../common/Builders';
import { Constants } from '../common/Constants';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { CuratedQuestion, QuizResult, QuizResultDetail } from '../model/DataModels';

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
  @State message: string = '';

  aboutToAppear(): void {
    this.courseId = AppStorage.get<string>('selectedCourseId') ?? 'cs101';
    this.courseTitle = AppStorage.get<string>('selectedCourseTitle') ?? '数据结构';
    this.topic = AppStorage.get<string>('selectedPracticeTopic') ?? '';
    const selectedQuestions = LearningContentRepository.getQuestions(this.courseId, this.topic).slice(0, 5);
    this.answers = new Array<string>(selectedQuestions.length).fill('');
    this.questions = selectedQuestions;
    this.activeQuestion = selectedQuestions.length > 0 ? selectedQuestions[0] : EMPTY_QUESTION;
  }

  private choose(option: string): void {
    if (this.submitted) return;
    const next = this.answers.slice();
    next[this.currentIndex] = option;
    this.answers = next;
    this.activeAnswer = option;
  }

  private answerLetter(option: string): string {
    const value = option.trim().toUpperCase();
    return value.length > 0 ? value.substring(0, 1) : '';
  }

  private allAnswered(): boolean {
    return this.answers.length > 0 && this.answers.every((answer: string): boolean => answer.length > 0);
  }

  private async submit(): Promise<void> {
    if (this.saving || !this.allAnswered()) return;
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
      Text(this.activeQuestion.question)
        .width('100%')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
        .lineHeight(27)
      Column({ space: 10 }) {
        ForEach(this.activeQuestion.options, (option: string): void => {
          Button(option)
            .width('100%')
            .height(56)
            .fontSize(14)
            .fontColor(this.activeAnswer === option ? Constants.COLOR_BRAND : Constants.COLOR_TEXT_PRIMARY)
            .backgroundColor(this.activeAnswer === option ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_CARD)
            .border({ width: 1, color: this.activeAnswer === option ? Constants.COLOR_BRAND : Constants.COLOR_BORDER })
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.choose(option); })
        })
      }
      .width('100%')
      Row({ space: 10 }) {
        Button('上一题')
          .layoutWeight(1)
          .height(46)
          .enabled(this.currentIndex > 0)
          .fontColor(this.currentIndex > 0 ? Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_BUTTON_DISABLED_TEXT)
          .backgroundColor(Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => {
            this.currentIndex -= 1;
            this.activeQuestion = this.questions[this.currentIndex];
            this.activeAnswer = this.answers[this.currentIndex] ?? '';
          })
        if (this.currentIndex < this.questions.length - 1) {
          Button('下一题')
            .layoutWeight(1)
            .height(46)
            .enabled(this.activeAnswer.length > 0)
            .fontColor(this.activeAnswer.length > 0 ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
            .backgroundColor(this.activeAnswer.length > 0 ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => {
              this.currentIndex += 1;
              this.activeQuestion = this.questions[this.currentIndex];
              this.activeAnswer = this.answers[this.currentIndex] ?? '';
            })
        } else {
          Button(this.saving ? '保存中...' : '提交评分')
            .layoutWeight(1)
            .height(46)
            .enabled(this.allAnswered() && !this.saving)
            .fontColor(this.allAnswered() ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BUTTON_DISABLED_TEXT)
            .backgroundColor(this.allAnswered() ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
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
      Text(Math.round(this.correctCount / this.questions.length * 100).toString() + '%')
        .fontSize(40)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.correctCount / this.questions.length >= 0.8 ? Constants.COLOR_SUCCESS : Constants.COLOR_WARNING)
      Text(this.correctCount.toString() + ' / ' + this.questions.length.toString() + ' 题正确')
        .fontSize(16)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
      ForEach(this.details, (detail: QuizResultDetail, index: number): void => {
        Column({ space: 7 }) {
          Text((index + 1).toString() + '. ' + detail.stem)
            .width('100%')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text(detail.isCorrect ? '回答正确' : '正确答案：' + detail.correctAnswer)
            .width('100%')
            .fontSize(12)
            .fontColor(detail.isCorrect ? Constants.COLOR_SUCCESS : Constants.COLOR_ERROR)
          Text(detail.explanation)
            .width('100%')
            .fontSize(12)
            .lineHeight(20)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .width('100%')
        .padding(15)
        .backgroundColor(Constants.COLOR_BG_CARD)
        .borderRadius(Constants.RADIUS_MD)
      })
      Button('返回课程')
        .width('100%')
        .height(48)
        .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
        .backgroundColor(Constants.COLOR_BRAND)
        .borderRadius(Constants.RADIUS_MD)
        .onClick((): void => { this.getUIContext().getRouter().back(); })
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
      Scroll() {
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
