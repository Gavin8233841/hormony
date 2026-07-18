import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { LearningStudyEvent as StudyEvent } from '../model/LearningMetadataModels';
import { Course, PlanTask } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

const ACTIVITY_WINDOW_LIMIT: number = 500;
const NAVIGATION_PLAN: string = 'plan';
const NAVIGATION_COURSE_DETAIL: string = 'course_detail';
const NAVIGATION_LESSON: string = 'lesson';
const NAVIGATION_PRACTICE: string = 'practice';
const NAVIGATION_QUIZ: string = 'quiz';

interface ActivityDay {
  key: string;
  label: string;
  count: number;
  completed: boolean;
}

interface PendingNavigationAction {
  kind: string;
  route: string;
  target: string;
  failureMessage: string;
  courseId: string;
  courseTitle: string;
  topic: string;
  focusTag: string;
}

@Entry
@Component
struct ActivityRecordsPage {
  @State events: StudyEvent[] = [];
  @State visibleEvents: StudyEvent[] = [];
  @State courses: Course[] = [];
  @State planTasks: PlanTask[] = [];
  @State recentDays: ActivityDay[] = [];
  @State selectedFilter: string = 'all';
  @State streakDays: number = 0;
  @State loading: boolean = true;
  @State dataMessage: string = '';
  @State navigationMessage: string = '';
  @State navigationTarget: string = '';
  private pendingNavigationAction: PendingNavigationAction | null = null;
  private loadSequence: number = 0;
  private navigationAttemptSequence: number = 0;

  aboutToAppear(): void {
    this.loadEvents();
  }

  private async loadEvents(): Promise<void> {
    const requestSequence = ++this.loadSequence;
    this.loading = true;
    this.dataMessage = '';
    try {
      const events: StudyEvent[] = (await LocalLearningRepository.getStudyEvents())
        .slice(-ACTIVITY_WINDOW_LIMIT).reverse();
      const visibleEvents: StudyEvent[] = events.filter((event: StudyEvent): boolean =>
        this.eventMatchesFilter(event, this.selectedFilter));
      const courses: Course[] = await LocalLearningRepository.getCourses() ?? [];
      const plan = await LocalLearningRepository.getPlan();
      const planTasks: PlanTask[] = plan?.tasks ?? [];
      const recentDays: ActivityDay[] = this.buildActivityDays(events);
      const profile = await LocalLearningRepository.getProfile();
      const streakDays: number = profile?.stats.streakDays ?? 0;

      if (requestSequence !== this.loadSequence) return;
      this.events = events;
      this.visibleEvents = visibleEvents;
      this.courses = courses;
      this.planTasks = planTasks;
      this.recentDays = recentDays;
      this.streakDays = streakDays;
    } catch (error) {
      if (requestSequence !== this.loadSequence) return;
      this.dataMessage = this.events.length > 0 ? '学习记录刷新失败，当前显示上次读取结果' :
        '学习记录读取失败';
    } finally {
      if (requestSequence === this.loadSequence) this.loading = false;
    }
  }

  private title(event: StudyEvent): string {
    if (event.type === 'task_completed') return '完成学习任务';
    if (event.type === 'lesson_completed') return '完成课程主题';
    if (event.type === 'lesson_activity') return '提交课程互动';
    if (event.type === 'quiz_mastered') return '掌握练习主题';
    if (event.type === 'quiz_submitted') return '提交练习';
    return '学习活动';
  }

  private detail(event: StudyEvent): string {
    const source = event.source === 'ai' ? 'AI 出题' :
      (event.source === 'curated' ? '精选题库' : (event.source === 'lesson_interactive' ? '课程互动' : ''));
    const difficulty = event.difficulty !== undefined ? this.difficultyLabel(event.difficulty) : '';
    const prefix = source.length > 0 || difficulty.length > 0 ? source + (source.length > 0 && difficulty.length > 0 ? ' · ' : '') + difficulty + ' · ' : '';
    if (event.topic !== undefined && event.totalQuestions !== undefined && event.correctCount !== undefined) {
      return prefix + event.topic + ' · ' + event.correctCount.toString() + '/' + event.totalQuestions.toString() + ' 题正确';
    }
    if (event.topic !== undefined) return event.topic;
    if (event.taskId !== undefined) return this.taskTitle(event.taskId);
    return '本地学习记录';
  }

  private difficultyLabel(value: string): string {
    if (value === 'easy') return '基础';
    if (value === 'hard') return '挑战';
    return '进阶';
  }

  private taskTitle(taskId: string): string {
    const task = this.planTasks.find((item: PlanTask): boolean => item.id === taskId);
    return task !== undefined ? task.title : '已完成计划任务';
  }

  private courseTitle(courseId: string): string {
    const course = this.courses.find((item: Course): boolean => item.id === courseId);
    return course !== undefined ? course.title : '';
  }

  private hasCourseTopic(courseId: string, topic: string): boolean {
    const course = this.courses.find((item: Course): boolean => item.id === courseId);
    return course !== undefined && course.topics.includes(topic);
  }

  private clearNavigationFailure(): void {
    this.navigationMessage = '';
    this.navigationTarget = '';
    this.pendingNavigationAction = null;
  }

  private beginNavigation(): number {
    this.navigationAttemptSequence += 1;
    this.clearNavigationFailure();
    return this.navigationAttemptSequence;
  }

  private applyNavigationContext(action: PendingNavigationAction): void {
    if (action.kind === NAVIGATION_PLAN) return;
    AppStorage.setOrCreate<string>('selectedCourseId', action.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', action.courseTitle);
    if (action.kind === NAVIGATION_LESSON) {
      AppStorage.setOrCreate<string>('selectedContentTopic', action.topic);
    } else if (action.kind === NAVIGATION_PRACTICE) {
      AppStorage.setOrCreate<string>('selectedPracticeTopic', action.topic);
    } else if (action.kind === NAVIGATION_QUIZ) {
      AppStorage.setOrCreate<string>('selectedQuizTopic', action.topic);
      AppStorage.setOrCreate<string>('selectedQuizFocusTag', action.focusTag);
    }
  }

  private navigate(action: PendingNavigationAction): void {
    const attemptSequence = this.beginNavigation();
    this.applyNavigationContext(action);
    this.getUIContext().getRouter().pushUrl({ url: action.route }).then((): void => {
      if (attemptSequence === this.navigationAttemptSequence) this.clearNavigationFailure();
    }).catch((error: Error): void => {
      if (attemptSequence !== this.navigationAttemptSequence) return;
      this.pendingNavigationAction = action;
      this.navigationMessage = action.failureMessage;
      this.navigationTarget = action.target;
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'ActivityRecordsPage navigation failed: %{public}s', error.message);
    });
  }

  private retryNavigation(): void {
    const action = this.pendingNavigationAction;
    if (action === null) return;
    if (!this.navigationActionValid(action)) {
      this.beginNavigation();
      this.dataMessage = '课程目录已更新，请重新读取本机学习记录';
      return;
    }
    this.navigate(action);
  }

  private navigationActionValid(action: PendingNavigationAction): boolean {
    if (action.kind === NAVIGATION_PLAN) return true;
    const course = this.courses.find((item: Course): boolean => item.id === action.courseId);
    if (course === undefined) return false;
    if (course.title !== action.courseTitle) return false;
    if (action.kind === NAVIGATION_COURSE_DETAIL) return true;
    return action.topic.length > 0 && course.topics.includes(action.topic);
  }

  private icon(event: StudyEvent): Resource {
    if (event.type === 'task_completed' || event.type === 'lesson_completed') {
      return $r('sys.symbol.checkmark_circle_fill');
    }
    return $r('sys.symbol.book_open_fill');
  }

  private iconColor(event: StudyEvent): string {
    if (event.type === 'lesson_activity') {
      return event.accuracy !== undefined && event.accuracy >= 0.8 ? Constants.COLOR_SUCCESS : Constants.COLOR_WARNING;
    }
    if (event.type === 'task_completed' || event.type === 'lesson_completed' || event.type === 'quiz_mastered') {
      return Constants.COLOR_SUCCESS;
    }
    return Constants.COLOR_BRAND;
  }

  private iconBackground(event: StudyEvent): string {
    if (event.type === 'lesson_activity') {
      return event.accuracy !== undefined && event.accuracy >= 0.8 ?
        Constants.COLOR_SUCCESS_LIGHT : Constants.COLOR_BRAND_LIGHT;
    }
    if (event.type === 'task_completed' || event.type === 'lesson_completed' || event.type === 'quiz_mastered') {
      return Constants.COLOR_SUCCESS_LIGHT;
    }
    return Constants.COLOR_BRAND_LIGHT;
  }

  private localDateKey(timestamp: string): string {
    const date = new Date(timestamp);
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return date.getFullYear().toString() + '-' + month + '-' + day;
  }

  private buildActivityDays(events: StudyEvent[]): ActivityDay[] {
    const days: ActivityDay[] = [];
    const today = new Date();
    for (let offset = 27; offset >= 0; offset--) {
      const date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - offset);
      const month = (date.getMonth() + 1).toString().padStart(2, '0');
      const day = date.getDate().toString().padStart(2, '0');
      const key = date.getFullYear().toString() + '-' + month + '-' + day;
      const dayEvents = events.filter((event: StudyEvent): boolean => this.localDateKey(event.timestamp) === key);
      days.push({
        key: key,
        label: date.getDate().toString(),
        count: dayEvents.length,
        completed: dayEvents.some((event: StudyEvent): boolean =>
          event.type === 'quiz_mastered' || event.type === 'lesson_completed' || event.type === 'task_completed')
      });
    }
    return days;
  }

  private activityWeeks(): ActivityDay[][] {
    const weeks: ActivityDay[][] = [];
    for (let index = 0; index < this.recentDays.length; index += 7) {
      weeks.push(this.recentDays.slice(index, index + 7));
    }
    return weeks;
  }

  private activeDaysCount(): number {
    return this.recentDays.filter((day: ActivityDay): boolean => day.count > 0).length;
  }

  private completedDaysCount(): number {
    return this.recentDays.filter((day: ActivityDay): boolean => day.completed).length;
  }

  private recentEventCount(): number {
    let total = 0;
    for (const day of this.recentDays) total += day.count;
    return total;
  }

  private bestDayLabel(): string {
    let best: ActivityDay | null = null;
    for (const day of this.recentDays) {
      if (best === null || day.count > best.count) best = day;
    }
    return best !== null && best.count > 0 ? best.key.slice(5).replace('-', '/') + ' · ' +
      best.count.toString() + ' 条' : '暂无记录';
  }

  private activityOverviewAccessibilityText(): string {
    return '近 4 周学习节奏，来自本机记录中最新 500 条的页面窗口，连续 ' +
      this.streakDays.toString() + ' 天，' + this.activeDaysCount().toString() + ' 天有学习，其中 ' +
      this.completedDaysCount().toString() + ' 天出现完成节点，窗口近 4 周共有 ' +
      this.recentEventCount().toString() + ' 条事件，记录最多：' + this.bestDayLabel();
  }

  private activityDayColor(day: ActivityDay): string {
    if (day.count === 0) return Constants.COLOR_BG_TAG;
    if (day.completed) return Constants.COLOR_SUCCESS;
    if (day.count >= 3) return Constants.COLOR_BRAND;
    return Constants.COLOR_BRAND_LIGHT;
  }

  private activityDayTextColor(day: ActivityDay): string {
    if (day.count === 0) return Constants.COLOR_TEXT_PLACEHOLDER;
    if (day.completed || day.count >= 3) return Constants.COLOR_TEXT_ON_GRADIENT;
    return Constants.COLOR_BRAND;
  }

  private filterLabel(value: string): string {
    if (value === 'quiz') return '练习';
    if (value === 'lesson') return '课程';
    if (value === 'task') return '任务';
    return '全部';
  }

  private filterAccessibilityText(value: string): string {
    return this.filterLabel(value) + '记录筛选，' + (this.selectedFilter === value ? '已选中' : '未选中');
  }

  private eventMatchesFilter(event: StudyEvent, filter: string): boolean {
    if (filter === 'all') return true;
    if (filter === 'quiz') {
      return event.type === 'quiz_mastered' || event.type === 'quiz_submitted';
    }
    if (filter === 'lesson') {
      return event.type === 'lesson_completed' || event.type === 'lesson_activity';
    }
    if (filter === 'task') return event.type === 'task_completed';
    return true;
  }

  private selectFilter(value: string): void {
    this.selectedFilter = value;
    this.visibleEvents = this.events.filter((event: StudyEvent): boolean =>
      this.eventMatchesFilter(event, value));
  }

  private isFirstOfDayIn(events: StudyEvent[], index: number): boolean {
    if (index === 0) return true;
    return this.localDateKey(events[index - 1].timestamp) !== this.localDateKey(events[index].timestamp);
  }

  private dateLabel(timestamp: string): string {
    const date = new Date(timestamp);
    return (date.getMonth() + 1).toString() + '月' + date.getDate().toString() + '日';
  }

  private timeLabel(timestamp: string): string {
    const date = new Date(timestamp);
    const hour = date.getHours().toString().padStart(2, '0');
    const minute = date.getMinutes().toString().padStart(2, '0');
    return hour + ':' + minute;
  }

  private canOpenEvent(event: StudyEvent): boolean {
    if (event.type === 'task_completed') return true;
    return event.courseId !== undefined && this.courseTitle(event.courseId).length > 0;
  }

  private eventActionLabel(event: StudyEvent): string {
    if (event.type === 'task_completed') return '查看计划';
    const courseId = event.courseId ?? '';
    const topic = event.topic ?? '';
    const hasExactTopic = courseId.length > 0 && topic.length > 0 && this.hasCourseTopic(courseId, topic);
    if (event.type === 'lesson_activity' || event.type === 'lesson_completed') {
      return hasExactTopic ? '回看课程' : '查看课程';
    }
    if (event.type === 'quiz_submitted' || event.type === 'quiz_mastered') {
      if (event.source === 'curated' && hasExactTopic) return '再次练习';
      if (event.source === 'ai' && hasExactTopic) return '再次测验';
      return '查看课程';
    }
    return event.courseId !== undefined ? '查看课程' : '';
  }

  private eventAccessibilityText(event: StudyEvent): string {
    const summary = this.dateLabel(event.timestamp) + ' ' + this.timeLabel(event.timestamp) + '，' +
      this.title(event) + '，' + this.detail(event);
    if (!this.canOpenEvent(event)) return summary + '，仅供回顾';
    return summary + '，操作：' + this.eventActionLabel(event);
  }

  private openEvent(event: StudyEvent): void {
    if (event.type === 'task_completed') {
      this.navigate({
        kind: NAVIGATION_PLAN,
        route: 'pages/Plan',
        target: '学习计划',
        failureMessage: '无法打开学习计划，请重试',
        courseId: '',
        courseTitle: '',
        topic: '',
        focusTag: ''
      });
      return;
    }
    const courseId = event.courseId;
    const courseTitle = courseId !== undefined ? this.courseTitle(courseId) : '';
    if (courseId === undefined || courseTitle.length === 0) {
      this.beginNavigation();
      this.dataMessage = '无法定位这条记录对应的课程，请重新读取本机学习记录';
      return;
    }
    const topic = event.topic ?? '';
    const hasExactTopic = topic.length > 0 && this.hasCourseTopic(courseId, topic);
    if ((event.type === 'lesson_activity' || event.type === 'lesson_completed') && hasExactTopic) {
      this.navigate({
        kind: NAVIGATION_LESSON,
        route: 'pages/Lesson',
        target: courseTitle + ' · ' + topic + ' 课程',
        failureMessage: '无法打开对应课程，请重试',
        courseId: courseId,
        courseTitle: courseTitle,
        topic: topic,
        focusTag: ''
      });
      return;
    }
    if ((event.type === 'quiz_submitted' || event.type === 'quiz_mastered') && hasExactTopic) {
      if (event.source === 'curated') {
        this.navigate({
          kind: NAVIGATION_PRACTICE,
          route: 'pages/Practice',
          target: courseTitle + ' · ' + topic + ' 精选练习',
          failureMessage: '无法打开精选练习，请重试',
          courseId: courseId,
          courseTitle: courseTitle,
          topic: topic,
          focusTag: ''
        });
      } else if (event.source === 'ai') {
        const focusTag = event.tags !== undefined && event.tags.length > 0 ? event.tags[0] : '';
        this.navigate({
          kind: NAVIGATION_QUIZ,
          route: 'pages/Quiz',
          target: courseTitle + ' · ' + topic + ' AI 测验',
          failureMessage: '无法打开 AI 测验，请重试',
          courseId: courseId,
          courseTitle: courseTitle,
          topic: topic,
          focusTag: focusTag
        });
      } else {
        this.navigate({
          kind: NAVIGATION_COURSE_DETAIL,
          route: 'pages/CourseDetail',
          target: courseTitle + ' 课程详情',
          failureMessage: '无法打开课程详情，请重试',
          courseId: courseId,
          courseTitle: courseTitle,
          topic: '',
          focusTag: ''
        });
      }
      return;
    }
    this.navigate({
      kind: NAVIGATION_COURSE_DETAIL,
      route: 'pages/CourseDetail',
      target: courseTitle + ' 课程详情',
      failureMessage: '无法打开课程详情，请重试',
      courseId: courseId,
      courseTitle: courseTitle,
      topic: '',
      focusTag: ''
    });
  }

  @Builder
  FilterPill(value: string) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 4 }) {
        if (this.selectedFilter === value) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(12)
            .fontColor([Constants.COLOR_TEXT_ON_GRADIENT])
        }
        Text(this.filterLabel(value))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.selectedFilter === value ? Constants.COLOR_TEXT_ON_GRADIENT :
            Constants.COLOR_TEXT_TERTIARY)
          .textAlign(TextAlign.Center)
      }
      .justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: 48 })
    .padding({ left: 8, right: 8, top: 8, bottom: 8 })
    .backgroundColor(this.selectedFilter === value ? Constants.COLOR_BRAND : Constants.COLOR_BG_TAG)
    .borderRadius(20)
    .accessibilityText(this.filterAccessibilityText(value))
    .onClick((): void => { this.selectFilter(value); })
  }

  @Builder
  ActivityOverview() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text('近 4 周学习节奏')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text('连续 ' + this.streakDays.toString() + ' 天 · ' + this.activeDaysCount().toString() + ' 天有学习')
            .fontSize(11)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
          Text(this.completedDaysCount().toString() + ' 天有完成节点')
            .fontSize(11)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('4 周内 ' + this.recentEventCount().toString() + ' 条')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_BRAND)
      }
      .width('100%')

      Column({ space: 7 }) {
        ForEach(this.activityWeeks(), (week: ActivityDay[]): void => {
          Row({ space: 7 }) {
            ForEach(week, (day: ActivityDay): void => {
              Column({ space: 2 }) {
                Text(day.count > 0 ? day.count.toString() : '')
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.activityDayTextColor(day))
                Text(day.label)
                  .fontSize(10)
                  .fontColor(this.activityDayTextColor(day))
              }
              .layoutWeight(1)
              .constraintSize({ minHeight: 42 })
              .padding({ top: 4, bottom: 4 })
              .justifyContent(FlexAlign.Center)
              .backgroundColor(this.activityDayColor(day))
              .borderRadius(Constants.RADIUS_SM)
            })
          }
          .width('100%')
        })
      }
      .width('100%')

      Column({ space: 8 }) {
        Text('记录最多：' + this.bestDayLabel())
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)
        Flex({ wrap: FlexWrap.Wrap }) {
          Row({ space: 4 }) {
            Text('无活动').fontSize(10).fontColor(Constants.COLOR_TEXT_SECONDARY)
            Column().width(14).height(8).backgroundColor(Constants.COLOR_BG_TAG).borderRadius(4)
          }
          .margin({ right: 10, bottom: 4 })
          Row({ space: 4 }) {
            Text('普通活动').fontSize(10).fontColor(Constants.COLOR_TEXT_SECONDARY)
            Column().width(14).height(8).backgroundColor(Constants.COLOR_BRAND_LIGHT).borderRadius(4)
            Column().width(14).height(8).backgroundColor(Constants.COLOR_BRAND).borderRadius(4)
          }
          .margin({ right: 10, bottom: 4 })
          Row({ space: 4 }) {
            Text('完成节点').fontSize(10).fontColor(Constants.COLOR_TEXT_SECONDARY)
            Column().width(14).height(8).backgroundColor(Constants.COLOR_SUCCESS).borderRadius(4)
          }
          .margin({ bottom: 4 })
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
    .accessibilityGroup(true)
    .accessibilityText(this.activityOverviewAccessibilityText())
  }

  build() {
    Column() {
      if (this.loading) {
        TitleBar('学习记录', '正在读取本地记录', () => this.getUIContext().getRouter().back())
      } else {
        TitleBar('学习记录', '本页近期 ' + this.events.length.toString() + ' 条 · 最多展示 500 条',
          () => this.getUIContext().getRouter().back())
      }
      if (this.loading) {
        Column()
          .width('90%')
          .height(180)
          .backgroundColor(Constants.COLOR_BG_SKELETON)
          .borderRadius(Constants.RADIUS_LG)
          .accessibilityGroup(true)
          .accessibilityText('正在读取本机学习记录')
      } else if (this.events.length === 0) {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.clock')).fontSize(38).fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
          Text(this.dataMessage.length > 0 ? this.dataMessage : '完成第一次学习后，记录会出现在这里')
            .fontSize(14)
            .fontColor(this.dataMessage.length > 0 ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
          if (this.dataMessage.length > 0) {
            Button('重新读取')
              .width(144)
              .constraintSize({ minHeight: 48 })
              .fontSize(13)
              .fontColor(Constants.COLOR_BRAND)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .border({ width: 1, color: Constants.COLOR_BRAND })
              .borderRadius(24)
              .accessibilityText('重新读取本机学习记录')
              .onClick((): void => { this.loadEvents(); })
          }
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ListItem() {
            this.ActivityOverview()
          }
          ListItem() {
            Row({ space: 6 }) {
              this.FilterPill('all')
              this.FilterPill('quiz')
              this.FilterPill('lesson')
              this.FilterPill('task')
            }
            .width('100%')
          }
          if (this.dataMessage.length > 0) {
            ListItem() {
              Column({ space: 10 }) {
                Text(this.dataMessage)
                  .width('100%')
                  .fontSize(12)
                  .fontColor(Constants.COLOR_ERROR)
                Button('重新读取')
                  .width('100%')
                  .constraintSize({ minHeight: 48 })
                  .fontSize(13)
                  .fontColor(Constants.COLOR_ERROR)
                  .backgroundColor(Constants.COLOR_BG_CARD)
                  .border({ width: 1, color: Constants.COLOR_ERROR })
                  .borderRadius(24)
                  .accessibilityText('重新读取本机学习记录')
                  .onClick((): void => { this.loadEvents(); })
              }
              .width('100%')
              .padding(12)
              .backgroundColor(Constants.COLOR_ERROR_LIGHT)
              .borderRadius(Constants.RADIUS_MD)
            }
          }
          if (this.navigationMessage.length > 0) {
            ListItem() {
              Column({ space: 10 }) {
                Text(this.navigationMessage)
                  .width('100%')
                  .fontSize(12)
                  .fontColor(Constants.COLOR_ERROR)
                Button('重试打开 ' + this.navigationTarget)
                  .width('100%')
                  .constraintSize({ minHeight: 48 })
                  .fontSize(13)
                  .fontColor(Constants.COLOR_ERROR)
                  .backgroundColor(Constants.COLOR_BG_CARD)
                  .border({ width: 1, color: Constants.COLOR_ERROR })
                  .borderRadius(24)
                  .accessibilityText('重试打开' + this.navigationTarget)
                  .accessibilityDescription(this.navigationMessage)
                  .onClick((): void => { this.retryNavigation(); })
              }
              .width('100%')
              .padding(12)
              .backgroundColor(Constants.COLOR_ERROR_LIGHT)
              .borderRadius(Constants.RADIUS_MD)
            }
          }
          ForEach(this.visibleEvents, (event: StudyEvent, index: number): void => {
            ListItem() {
              Column() {
                if (this.isFirstOfDayIn(this.visibleEvents, index)) {
                  Row() {
                    Text(this.dateLabel(event.timestamp))
                      .fontSize(13)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Constants.COLOR_TEXT_TERTIARY)
                    if (index === 0) {
                      Text('最近')
                        .fontSize(10)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Constants.COLOR_BRAND)
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                        .borderRadius(Constants.RADIUS_SM)
                    }
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.SpaceBetween)
                  .padding({ left: 4, right: 4, top: index === 0 ? 2 : 12, bottom: 2 })
                }

                Row({ space: 12 }) {
                  Stack({ alignContent: Alignment.Center }) {
                    Column()
                      .width(44)
                      .height(44)
                      .backgroundColor(this.iconBackground(event))
                      .borderRadius(Constants.RADIUS_MD)
                    SymbolGlyph(this.icon(event))
                      .fontSize(21)
                      .fontColor([this.iconColor(event)])
                  }
                  Column({ space: 4 }) {
                    Text(this.title(event))
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Constants.COLOR_TEXT_PRIMARY)
                      .maxLines(2)
                    Text(this.detail(event))
                      .fontSize(12)
                      .fontColor(Constants.COLOR_TEXT_SECONDARY)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Flex({ wrap: FlexWrap.Wrap }) {
                      Text(this.timeLabel(event.timestamp))
                        .fontSize(11)
                        .fontColor(Constants.COLOR_TEXT_SECONDARY)
                        .margin({ right: 10, top: 2 })
                      if (this.canOpenEvent(event)) {
                        Text(this.eventActionLabel(event))
                          .fontSize(10)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(Constants.COLOR_BRAND)
                          .margin({ top: 2 })
                      }
                    }
                    .width('100%')
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  if (this.canOpenEvent(event)) {
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(15)
                      .fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
                  }
                }
                .width('100%')
                .constraintSize({ minHeight: 76 })
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .backgroundColor(Constants.COLOR_BG_CARD)
                .borderRadius(Constants.RADIUS_LG)
                .accessibilityGroup(true)
                .accessibilityText(this.eventAccessibilityText(event))
                .onClick((): void => {
                  if (this.canOpenEvent(event)) this.openEvent(event);
                })
              }
              .width('100%')
            }
          })
          if (this.visibleEvents.length === 0) {
            ListItem() {
              Column({ space: 6 }) {
                Text('本机保留窗口中没有此类记录')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
                Text('完成一次' + this.filterLabel(this.selectedFilter) + '后会在此窗口中出现')
                  .fontSize(12)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
              }
              .width('100%')
              .padding(18)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .borderRadius(Constants.RADIUS_LG)
            }
          }
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 24 + SafeAreaInsets.bottomVp() })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
