import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { CuratedKnowledgeChunk, LearningActivity, LessonExperience, LessonProgress } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

const EMPTY_CHUNK: CuratedKnowledgeChunk = {
  id: '',
  text: '',
  source: '',
  courseId: '',
  topic: ''
};

@Entry
@Component
struct LessonPage {
  private contentScroller: Scroller = new Scroller();
  @State courseId: string = 'cs101';
  @State courseTitle: string = '数据结构';
  @State topic: string = '';
  @State chunks: CuratedKnowledgeChunk[] = [];
  @State activeChunk: CuratedKnowledgeChunk = EMPTY_CHUNK;
  @State completedChunkIds: string[] = [];
  @State currentIndex: number = 0;
  @State saving: boolean = false;
  @State message: string = '';
  @State experience: LessonExperience | null = null;
  @State activeActivityIndex: number = 0;
  @State selectedIndexes: number[] = [];
  @State responseText: string = '';
  @State feedbackVisible: boolean = false;
  @State attemptedActivityIds: string[] = [];
  @State codeRunStepIndex: number = -1;

  aboutToAppear(): void {
    this.courseId = AppStorage.get<string>('selectedCourseId') ?? 'cs101';
    this.courseTitle = AppStorage.get<string>('selectedCourseTitle') ?? '数据结构';
    this.topic = AppStorage.get<string>('selectedContentTopic') ?? '';
    const content = LearningContentRepository.getKnowledge(this.courseId, this.topic);
    this.experience = LearningContentRepository.getLessonExperience(this.courseId, this.topic);
    this.chunks = content;
    this.activeChunk = content.length > 0 ? content[0] : EMPTY_CHUNK;
    this.loadProgress();
  }

  private async loadProgress(): Promise<void> {
    try {
      const progress = await LocalLearningRepository.getLessonProgress(this.courseId);
      const item = progress.find((value: LessonProgress): boolean => value.topic === this.topic);
      this.completedChunkIds = item?.completedChunkIds ?? [];
      if (this.chunks.length > 0) {
        const nextIndex = this.chunks.findIndex((chunk: CuratedKnowledgeChunk): boolean =>
          !this.completedChunkIds.includes(chunk.id));
        this.currentIndex = nextIndex >= 0 ? nextIndex : 0;
        this.activeChunk = this.chunks[this.currentIndex];
      }
    } catch (error) {
      this.message = '学习进度读取失败，但课程内容仍可查看';
    }
  }

  private moveTo(index: number): void {
    if (index < 0 || index >= this.chunks.length) return;
    this.currentIndex = index;
    this.activeChunk = this.chunks[index];
    this.message = '';
    this.contentScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
  }

  private activeActivity(): LearningActivity | null {
    if (this.experience === null || this.experience.activities.length === 0) return null;
    return this.experience.activities[this.activeActivityIndex] ?? null;
  }

  private resetActivityInput(): void {
    this.selectedIndexes = [];
    this.responseText = '';
    this.feedbackVisible = false;
    this.codeRunStepIndex = -1;
  }

  private experienceStepCount(): number {
    return this.experience === null ? 0 : this.experience.visualSteps.length;
  }

  private chooseSingle(index: number): void {
    const activity = this.activeActivity();
    if (activity === null || this.feedbackVisible) return;
    this.selectedIndexes = [index];
    this.feedbackVisible = true;
    this.markActivityAttempted(activity.id);
  }

  private chooseOrderStep(index: number): void {
    if (this.feedbackVisible || this.selectedIndexes.includes(index)) return;
    this.selectedIndexes = this.selectedIndexes.concat([index]);
  }

  private submitOrder(): void {
    const activity = this.activeActivity();
    if (activity === null || this.selectedIndexes.length !== activity.options.length) return;
    this.feedbackVisible = true;
    this.markActivityAttempted(activity.id);
  }

  private revealFreeResponse(): void {
    if (this.responseText.trim().length === 0) {
      this.message = '请先写下你的推演或填空答案';
      return;
    }
    this.message = '';
    this.feedbackVisible = true;
  }

  private selfAssess(activityId: string): void {
    this.markActivityAttempted(activityId);
  }

  private markActivityAttempted(activityId: string): void {
    if (!this.attemptedActivityIds.includes(activityId)) {
      this.attemptedActivityIds = this.attemptedActivityIds.concat([activityId]);
    }
  }

  private activityIsCorrect(): boolean {
    const activity = this.activeActivity();
    if (activity === null || activity.answerIndexes.length !== this.selectedIndexes.length) return false;
    return activity.answerIndexes.every((answer: number, index: number): boolean =>
      answer === this.selectedIndexes[index]);
  }

  private allActivitiesAttempted(): boolean {
    if (this.experience === null) return true;
    return this.experience.activities.every((activity: LearningActivity): boolean =>
      this.attemptedActivityIds.includes(activity.id));
  }

  private showIntroExperience(): boolean {
    return this.experience !== null && this.currentIndex === 0;
  }

  private showPracticeExperience(): boolean {
    return this.experience !== null && this.currentIndex === this.chunks.length - 1;
  }

  private goToActivity(index: number): void {
    if (this.experience === null || index < 0 || index >= this.experience.activities.length) return;
    this.activeActivityIndex = index;
    this.resetActivityInput();
    this.message = '';
    this.contentScroller.scrollPage({ next: false });
  }

  private finalActionLabel(): string {
    if (this.saving) return '保存中...';
    if (this.currentIndex < this.chunks.length - 1) return '学完本节，继续';
    if (!this.allActivitiesAttempted()) return '完成互动练习后继续';
    return '完成主题并练习';
  }

  private contentBeats(): string[] {
    return this.activeChunk.text
      .replace(/；/g, '。')
      .split('。')
      .map((sentence: string): string => sentence.trim())
      .filter((sentence: string): boolean => sentence.length > 0)
      .map((sentence: string): string => sentence + '。');
  }

  private masteryGoal(): string {
    if (this.experience !== null && this.experience.visualSteps.length > 0) {
      const first = this.experience.visualSteps[0];
      const last = this.experience.visualSteps[this.experience.visualSteps.length - 1];
      return '学完后能把「' + first + ' → ' + last + '」讲清楚，并完成一次主动练习。';
    }
    return '学完后能用自己的话解释本节核心点，并进入练习验证。';
  }

  private currentLearningFocus(): string {
    if (this.showIntroExperience()) return '先建立概念图，再用现实案例落地。';
    if (this.showPracticeExperience()) return '看一遍分步示例，再亲手做题验证。';
    return '把正文拆成判断点，逐条确认自己是否能复述。';
  }

  private activityProgressText(): string {
    if (this.experience === null || this.experience.activities.length === 0) return '无互动练习';
    return this.attemptedActivityIds.length.toString() + '/' + this.experience.activities.length.toString() + ' 已练';
  }

  private codeRunSteps(activity: LearningActivity): string[] {
    const contentLines = activity.content
      .split('\n')
      .map((line: string): string => line.trim())
      .filter((line: string): boolean => line.length > 0 && line !== '代码：');
    const firstLine = contentLines.length > 0 ? contentLines[0] : '题干';
    const lastLine = contentLines.length > 1 ? contentLines[contentLines.length - 1] : firstLine;
    const answer = activity.answer.length > 36 ? activity.answer.substring(0, 36) + '…' : activity.answer;
    return [
      '入口：从「' + firstLine + '」开始，圈出输入、状态变量和输出位置。',
      '状态：逐行更新变量或指针，遇到空缺先写下自己的预测，不急着看答案。',
      '出口：走到「' + lastLine + '」，代入答案「' + answer + '」并检查是否满足题意。'
    ];
  }

  private codeRunProgressValue(activity: LearningActivity): number {
    if (this.codeRunStepIndex < 0) return 0;
    return Math.min(this.codeRunStepIndex + 1, this.codeRunSteps(activity).length);
  }

  private codeRunButtonLabel(activity: LearningActivity): string {
    if (this.codeRunStepIndex < 0) return '运行推演';
    if (this.codeRunStepIndex < this.codeRunSteps(activity).length - 1) return '下一步';
    return '已完成推演';
  }

  private advanceCodeRun(activity: LearningActivity): void {
    const total = this.codeRunSteps(activity).length;
    if (this.codeRunStepIndex < total - 1) {
      this.codeRunStepIndex += 1;
    }
  }

  private async completeCurrent(): Promise<void> {
    if (this.saving || this.activeChunk.id.length === 0) return;
    if (this.currentIndex === this.chunks.length - 1 && !this.allActivitiesAttempted() &&
      !this.completedChunkIds.includes(this.activeChunk.id)) {
      this.message = '请先完成本主题的全部互动练习';
      return;
    }
    this.saving = true;
    this.message = '';
    try {
      await LocalLearningRepository.completeLessonChunk(
        this.courseId,
        this.topic,
        this.activeChunk.id,
        this.chunks.length
      );
      if (!this.completedChunkIds.includes(this.activeChunk.id)) {
        this.completedChunkIds = this.completedChunkIds.concat([this.activeChunk.id]);
      }
      if (this.currentIndex < this.chunks.length - 1) {
        this.moveTo(this.currentIndex + 1);
      } else {
        this.openPractice();
      }
    } catch (error) {
      this.message = '学习进度保存失败，请重试';
    } finally {
      this.saving = false;
    }
  }

  private openPractice(): void {
    AppStorage.setOrCreate<string>('selectedPracticeTopic', this.topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Practice' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'LessonPage Practice navigation failed: %{public}s', error.message);
    });
  }

  @Builder
  private MasteryBrief() {
    Column({ space: 12 }) {
      Row() {
        Text('本节掌握标准')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_BRAND)
        Text(this.activityProgressText())
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Text(this.masteryGoal())
        .width('100%')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .lineHeight(28)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)

      Row({ space: 8 }) {
        this.MasterySignal('目标', this.topic.length > 0 ? this.topic : this.courseTitle)
        this.MasterySignal('方法', this.currentLearningFocus())
        this.MasterySignal('反馈', this.showPracticeExperience() ? '做完练习后进题组' : '完成本节后继续')
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
  }

  @Builder
  private MasterySignal(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(10)
        .fontColor(Constants.COLOR_TEXT_SECONDARY)
      Text(value)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
        .lineHeight(18)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: 62 })
    .padding({ left: 10, right: 10, top: 9, bottom: 9 })
    .backgroundColor(Constants.COLOR_SURFACE_TINT)
    .borderRadius(Constants.RADIUS_SM)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private CodeBlock(activity: LearningActivity) {
    Column({ space: 8 }) {
      Row() {
        Text(activity.language.length > 0 ? activity.language : 'code')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
        Text('阅读后再作答')
          .fontSize(11)
          .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      Scroll() {
        Text(activity.content)
          .width('100%')
          .fontSize(12)
          .fontFamily('monospace')
          .lineHeight(20)
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
      }
      .width('100%')
      .constraintSize({ maxHeight: 220 })
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Constants.COLOR_MAP_SURFACE)
    .borderRadius(Constants.RADIUS_SM)
  }

  @Builder
  private CodeRunPanel(activity: LearningActivity) {
    Column({ space: 10 }) {
      Row() {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.play_circle_fill'))
            .fontSize(17)
            .fontColor([Constants.COLOR_BRAND])
          Text('代码推演器')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
        }
        Text('本地状态演算')
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Text('不是远程沙盒：它按“入口 → 状态 → 出口”帮你手动运行一遍，先形成预测，再对照答案。')
        .width('100%')
        .fontSize(12)
        .lineHeight(19)
        .fontColor(Constants.COLOR_TEXT_TERTIARY)

      Progress({
        value: this.codeRunProgressValue(activity),
        total: this.codeRunSteps(activity).length,
        type: ProgressType.Linear
      })
        .width('100%')
        .color(Constants.COLOR_SUCCESS)
        .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)

      ForEach(this.codeRunSteps(activity), (step: string, index: number): void => {
        Row({ space: 10 }) {
          Text((index + 1).toString())
            .width(24)
            .height(24)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(index <= this.codeRunStepIndex ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_BRAND)
            .textAlign(TextAlign.Center)
            .backgroundColor(index <= this.codeRunStepIndex ? Constants.COLOR_SUCCESS : Constants.COLOR_BRAND_LIGHT)
            .borderRadius(12)
          Text(step)
            .layoutWeight(1)
            .fontSize(12)
            .lineHeight(20)
            .fontColor(index <= this.codeRunStepIndex ? Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_TEXT_SECONDARY)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      })

      Row({ space: 10 }) {
        Button('重来')
          .layoutWeight(1)
          .height(40)
          .fontSize(12)
          .enabled(this.codeRunStepIndex >= 0)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
          .backgroundColor(Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_SM)
          .onClick((): void => { this.codeRunStepIndex = -1; })
        Button(this.codeRunButtonLabel(activity))
          .layoutWeight(1)
          .height(40)
          .fontSize(12)
          .enabled(this.codeRunStepIndex < this.codeRunSteps(activity).length - 1)
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
          .backgroundColor(Constants.COLOR_BRAND)
          .borderRadius(Constants.RADIUS_SM)
          .onClick((): void => { this.advanceCodeRun(activity); })
      }
      .width('100%')

      if (this.codeRunStepIndex >= this.codeRunSteps(activity).length - 1) {
        Text(this.feedbackVisible ? '推演、作答、对照都已完成，这一题形成了可复盘闭环。' : '推演完成：现在作答，再用解析检查自己的状态链。')
          .width('100%')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_SUCCESS)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Constants.COLOR_SUCCESS_LIGHT)
    .borderRadius(Constants.RADIUS_MD)
  }

  @Builder
  private ActivityOption(option: string, index: number, ordered: boolean) {
    Button({ type: ButtonType.Normal }) {
      Text((ordered && this.selectedIndexes.includes(index) ?
        (this.selectedIndexes.indexOf(index) + 1).toString() + '. ' : '') + option)
        .width('100%')
        .fontSize(13)
        .lineHeight(20)
        .fontColor(this.selectedIndexes.includes(index) ?
          Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_PRIMARY)
        .textAlign(TextAlign.Start)
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(this.selectedIndexes.includes(index) ?
      (ordered ? Constants.COLOR_BRAND : (this.activityIsCorrect() ? Constants.COLOR_SUCCESS : Constants.COLOR_WARNING)) :
      Constants.COLOR_BG_TAG)
    .borderRadius(Constants.RADIUS_MD)
    .onClick((): void => {
      if (ordered) {
        this.chooseOrderStep(index);
      } else {
        this.chooseSingle(index);
      }
    })
  }

  @Builder
  private IntroExperience() {
    if (this.experience !== null) {
      Column({ space: 14 }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.book_open_fill'))
            .fontSize(18)
            .fontColor([Constants.COLOR_BRAND])
          Text('一眼看懂')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
        }
        .width('100%')
        Text(this.experience.visualTitle)
          .width('100%')
          .fontSize(13)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
        Row({ space: 6 }) {
          ForEach(this.experience.visualSteps, (step: string, index: number): void => {
            Text(step)
              .layoutWeight(1)
              .constraintSize({ minHeight: 44 })
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(index === this.experienceStepCount() - 1 ?
                Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_PRIMARY)
              .textAlign(TextAlign.Center)
              .padding({ left: 4, right: 4, top: 6, bottom: 6 })
              .backgroundColor(index === this.experienceStepCount() - 1 ?
                Constants.COLOR_BRAND : Constants.COLOR_BRAND_LIGHT)
              .borderRadius(Constants.RADIUS_SM)
          })
        }
        .width('100%')
      }
      .width('100%')

      Column({ space: 8 }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.lightbulb_max_fill'))
            .fontSize(17)
            .fontColor([Constants.COLOR_WARNING])
          Text(this.experience.caseTitle)
            .layoutWeight(1)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
        }
        .width('100%')
        Text(this.experience.caseBody)
          .width('100%')
          .fontSize(14)
          .lineHeight(24)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Constants.COLOR_SUCCESS_LIGHT)
      .borderRadius(Constants.RADIUS_MD)
    }
  }

  @Builder
  private PracticeExperience() {
    if (this.experience !== null) {
      Column({ space: 10 }) {
        Row() {
          Text('分步示例')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_BRAND)
          Text(this.experience.workedExampleSteps.length.toString() + ' 步')
            .fontSize(11)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        Text(this.experience.workedExampleTitle)
          .width('100%')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        ForEach(this.experience.workedExampleSteps, (step: string, index: number): void => {
          Row({ space: 10 }) {
            Text((index + 1).toString())
              .width(24)
              .height(24)
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
              .textAlign(TextAlign.Center)
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(12)
            Text(step)
              .layoutWeight(1)
              .fontSize(13)
              .lineHeight(21)
              .fontColor(Constants.COLOR_TEXT_TERTIARY)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Constants.COLOR_BG_CARD)
      .border({ width: 1, color: Constants.COLOR_BORDER })
      .borderRadius(Constants.RADIUS_MD)

      if (this.activeActivity() !== null) {
        Column({ space: 12 }) {
          Row() {
            Text('主动练习 · ' + this.activeActivity()!.title)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_BRAND)
            Text((this.activeActivityIndex + 1).toString() + ' / ' +
              this.experience.activities.length.toString())
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          Text(this.activeActivity()!.prompt)
            .width('100%')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .lineHeight(25)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)

          if (this.activeActivity()!.content.length > 0) {
            this.CodeBlock(this.activeActivity()!)
            this.CodeRunPanel(this.activeActivity()!)
          }

          if (this.activeActivity()!.interactionMode === 'single_choice') {
            ForEach(this.activeActivity()!.options, (option: string, index: number): void => {
              this.ActivityOption(option, index, false)
            })
          } else if (this.activeActivity()!.interactionMode === 'ordered_choice') {
            ForEach(this.activeActivity()!.options, (option: string, index: number): void => {
              this.ActivityOption(option, index, true)
            })
            Row({ space: 10 }) {
              Button('重置顺序')
                .layoutWeight(1)
                .height(44)
                .enabled(!this.feedbackVisible)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
                .backgroundColor(Constants.COLOR_BG_TAG)
                .borderRadius(Constants.RADIUS_MD)
                .onClick((): void => { this.resetActivityInput(); })
              Button('提交顺序')
                .layoutWeight(1)
                .height(44)
                .enabled(this.selectedIndexes.length === this.activeActivity()!.options.length &&
                  !this.feedbackVisible)
                .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                .backgroundColor(Constants.COLOR_BRAND)
                .borderRadius(Constants.RADIUS_MD)
                .onClick((): void => { this.submitOrder(); })
            }
            .width('100%')
          } else {
            TextArea({ placeholder: '先写下你的答案或推演过程', text: this.responseText })
              .width('100%')
              .height(132)
              .fontSize(14)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
              .backgroundColor(Constants.COLOR_SURFACE_TINT)
              .border({ width: 1, color: Constants.COLOR_BORDER })
              .borderRadius(Constants.RADIUS_MD)
              .onChange((value: string): void => { this.responseText = value; })
            Button(this.feedbackVisible ? '已提交，向下对照答案' : '提交并对照答案')
              .width('100%')
              .height(46)
              .enabled(!this.feedbackVisible)
              .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.revealFreeResponse(); })
          }

          if (this.feedbackVisible) {
            Column({ space: 8 }) {
              Text(this.activeActivity()!.interactionMode === 'free_response' ?
                '标准答案' : (this.activityIsCorrect() ? '回答正确' : '对照正确答案'))
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.activeActivity()!.interactionMode === 'free_response' || this.activityIsCorrect() ?
                  Constants.COLOR_SUCCESS : Constants.COLOR_WARNING)
              Text(this.activeActivity()!.answer)
                .width('100%')
                .fontSize(13)
                .lineHeight(21)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
              Text(this.activeActivity()!.feedback)
                .width('100%')
                .fontSize(12)
                .lineHeight(20)
                .fontColor(Constants.COLOR_TEXT_TERTIARY)
              Text('来源：' + this.activeActivity()!.source)
                .width('100%')
                .fontSize(11)
                .lineHeight(18)
                .fontColor(Constants.COLOR_TEXT_SECONDARY)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(this.activeActivity()!.interactionMode === 'free_response' || this.activityIsCorrect() ?
              Constants.COLOR_SUCCESS_LIGHT : Constants.COLOR_SURFACE_TINT)
            .borderRadius(Constants.RADIUS_SM)

            if (this.activeActivity()!.interactionMode === 'free_response' &&
              !this.attemptedActivityIds.includes(this.activeActivity()!.id)) {
              Row({ space: 10 }) {
                Button('还需巩固')
                  .layoutWeight(1)
                  .height(44)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  .backgroundColor(Constants.COLOR_BG_TAG)
                  .borderRadius(Constants.RADIUS_MD)
                  .onClick((): void => { this.selfAssess(this.activeActivity()!.id); })
                Button('我答对了')
                  .layoutWeight(1)
                  .height(44)
                  .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                  .backgroundColor(Constants.COLOR_SUCCESS)
                  .borderRadius(Constants.RADIUS_MD)
                  .onClick((): void => { this.selfAssess(this.activeActivity()!.id); })
              }
              .width('100%')
            }
          }

          if (this.attemptedActivityIds.includes(this.activeActivity()!.id)) {
            Row() {
              Text('本练习已完成')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(Constants.COLOR_SUCCESS)
              if (this.activeActivityIndex < this.experience.activities.length - 1) {
                Button('下一练习')
                  .height(40)
                  .fontSize(12)
                  .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                  .backgroundColor(Constants.COLOR_BRAND)
                  .borderRadius(Constants.RADIUS_SM)
                  .onClick((): void => { this.goToActivity(this.activeActivityIndex + 1); })
              }
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Constants.COLOR_BG_CARD)
        .border({ width: 1, color: Constants.COLOR_BORDER })
        .borderRadius(Constants.RADIUS_LG)
      }
    }
  }

  build() {
    Column() {
      TitleBar(this.topic.length > 0 ? this.topic : '课程内容', this.courseTitle,
        () => this.getUIContext().getRouter().back())

      if (this.chunks.length === 0) {
        Column({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.book_open_fill'))
            .fontSize(38)
            .fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
          Text('该主题暂无课程内容')
            .fontSize(15)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Column({ space: 10 }) {
          Row() {
            Text('精选课程内容')
              .fontSize(11)
              .fontColor(Constants.COLOR_BRAND)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(Constants.RADIUS_SM)
            Text((this.currentIndex + 1).toString() + ' / ' + this.chunks.length.toString())
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)

          Progress({ value: this.currentIndex + 1, total: this.chunks.length, type: ProgressType.Linear })
            .width('100%')
            .color(Constants.COLOR_BRAND)
            .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 4, bottom: 12 })

        Scroll(this.contentScroller) {
          Column({ space: 24 }) {
            this.MasteryBrief()

            Column({ space: 12 }) {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.lightbulb_max_fill'))
                  .fontSize(18)
                  .fontColor([Constants.COLOR_BRAND])
                Text('先抓住核心')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Constants.COLOR_BRAND)
              }
              .width('100%')

              Text(this.contentBeats()[0] ?? this.activeChunk.text)
                .width('100%')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .lineHeight(34)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 22, bottom: 22 })
            .backgroundColor(Constants.COLOR_SURFACE_TINT)
            .borderRadius(Constants.RADIUS_LG)

            if (this.showIntroExperience()) {
              this.IntroExperience()
            }

            if (this.showPracticeExperience()) {
              this.PracticeExperience()
            }

            if (this.contentBeats().length > 1) {
              Column({ space: 16 }) {
                Text('拆开理解')
                  .width('100%')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)

                ForEach(this.contentBeats().slice(1), (sentence: string, index: number): void => {
                  Row({ space: 12 }) {
                    Column()
                      .width(8)
                      .height(8)
                      .backgroundColor(index === this.contentBeats().length - 2 ?
                        Constants.COLOR_SUCCESS : Constants.COLOR_BRAND)
                      .borderRadius(4)
                      .margin({ top: 9 })
                    Text(sentence)
                      .layoutWeight(1)
                      .fontSize(15)
                      .lineHeight(26)
                      .fontColor(Constants.COLOR_TEXT_TERTIARY)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Top)
                })
              }
              .width('100%')
            }

            Row({ space: 10 }) {
              SymbolGlyph($r('sys.symbol.book_open_fill'))
                .fontSize(17)
                .fontColor([Constants.COLOR_TEXT_SECONDARY])
              Column({ space: 2 }) {
                Text('内容来源')
                  .fontSize(11)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
                Text(this.activeChunk.source)
                  .fontSize(13)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              if (this.completedChunkIds.includes(this.activeChunk.id)) {
                Text('已学')
                  .fontSize(11)
                  .fontColor(Constants.COLOR_SUCCESS)
                  .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                  .backgroundColor(Constants.COLOR_SUCCESS_LIGHT)
                  .borderRadius(Constants.RADIUS_SM)
              }
            }
            .width('100%')
            .padding({ top: 16 })
            .border({ width: { top: 1 }, color: Constants.COLOR_BORDER })
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .justifyContent(FlexAlign.Start)
          .padding({ left: 18, right: 18, top: 4, bottom: 24 + SafeAreaInsets.bottomVp() })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16 })

        if (this.message.length > 0) {
          Text(this.message)
            .width('100%')
            .fontSize(12)
            .fontColor(this.message.includes('失败') ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
            .padding({ left: 18, right: 18, top: 8 })
        }

        Row({ space: 10 }) {
          Button('上一篇')
            .width(92)
            .height(48)
            .enabled(this.currentIndex > 0)
            .fontColor(this.currentIndex > 0 ? Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_BUTTON_DISABLED_TEXT)
            .backgroundColor(Constants.COLOR_BG_TAG)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.moveTo(this.currentIndex - 1); })

          Button(this.finalActionLabel())
            .layoutWeight(1)
            .height(48)
            .enabled(!this.saving)
            .fontSize(14)
            .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
            .backgroundColor(Constants.COLOR_BRAND)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.completeCurrent(); })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 20 + SafeAreaInsets.bottomVp() })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
