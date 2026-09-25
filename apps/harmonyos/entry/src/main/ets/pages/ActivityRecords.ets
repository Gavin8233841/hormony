import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { LearningStudyEvent as StudyEvent } from '../model/LearningMetadataModels';
import { Course, PlanTask } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface ActivityDay {
  key: string;
  label: string;
  count: number;
  completed: boolean;
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
  @State overviewExpanded: boolean = false;
  @State streakDays: number = 0;
  @State loading: boolean = true;
  @State message: string = '';

  onPageShow(): void {
    this.loadEvents();
  }

  private async loadEvents(): Promise<void> {
    this.loading = true;
    this.message = '';
    try {
      const events: StudyEvent[] = (await LocalLearningRepository.getStudyEvents()).slice().reverse();
      const visibleEvents: StudyEvent[] = events.filter((event: StudyEvent): boolean =>
        this.eventMatchesFilter(event, this.selectedFilter));
      const courses: Course[] = await LocalLearningRepository.getCourses() ?? [];
      const plan = await LocalLearningRepository.getPlan();
      const planTasks: PlanTask[] = plan?.tasks ?? [];
      const recentDays: ActivityDay[] = this.buildActivityDays(events);
      const profile = await LocalLearningRepository.getProfile();
      const streakDays: number = profile?.stats.streakDays ?? 0;

      this.events = events;
      this.visibleEvents = visibleEvents;
      this.courses = courses;
      this.planTasks = planTasks;
      this.recentDays = recentDays;
      this.streakDays = streakDays;
    } catch (error) {
      this.message = '学习记录读取失败';
    } finally {
      this.loading = false;
    }
  }

  private title(event: StudyEvent): string {
    if (event.type === 'task_completed') return '完成学习任务';
    if (event.type === 'lesson_completed') return '学完课程主题';
    if (event.type === 'lesson_activity') return '完成互动';
    if (event.type === 'quiz_mastered') return '已掌握';
    if (event.type === 'quiz_submitted') return '完成练习';
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
    return '';
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

  private setCourseContext(courseId: string): boolean {
    const title = this.courseTitle(courseId);
    if (title.length === 0) {
      this.message = '无法定位这条记录对应的课程';
      return false;
    }
    AppStorage.setOrCreate<string>('selectedCourseId', courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', title);
    return true;
  }

  private pushPage(url: string, failureMessage: string): void {
    this.message = '';
    this.getUIContext().getRouter().pushUrl({ url: url }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'ActivityRecordsPage navigation failed: %{public}s', error.message);
      this.message = failureMessage;
    });
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
    const days = this.overviewExpanded ? this.recentDays : this.recentDays.slice(-7);
    for (let index = 0; index < days.length; index += 7) {
      weeks.push(days.slice(index, index + 7));
    }
    return weeks;
  }

  private activeDaysCount(): number {
    return this.recentDays.filter((day: ActivityDay): boolean => day.count > 0).length;
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
    return '近 4 周学习节奏，连续 ' + this.streakDays.toString() + ' 天，' +
      this.activeDaysCount().toString() + ' 天有学习，共 ' + this.recentEventCount().toString() +
      ' 次学习，学习最多的日期：' + this.bestDayLabel();
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
      this.pushPage('pages/Plan', '无法打开学习计划，请重试');
      return;
    }
    const courseId = event.courseId;
    if (courseId === undefined || !this.setCourseContext(courseId)) return;
    const topic = event.topic ?? '';
    const hasExactTopic = topic.length > 0 && this.hasCourseTopic(courseId, topic);
    if ((event.type === 'lesson_activity' || event.type === 'lesson_completed') && hasExactTopic) {
      AppStorage.setOrCreate<string>('selectedContentTopic', topic);
      this.pushPage('pages/Lesson', '无法打开对应课程，请重试');
      return;
    }
    if ((event.type === 'quiz_submitted' || event.type === 'quiz_mastered') && hasExactTopic) {
      if (event.source === 'curated') {
        AppStorage.setOrCreate<string>('selectedPracticeTopic', topic);
        this.pushPage('pages/Practice', '无法打开精选练习，请重试');
      } else if (event.source === 'ai') {
        AppStorage.setOrCreate<string>('selectedQuizTopic', topic);
        const focusTag = event.tags !== undefined && event.tags.length > 0 ? event.tags[0] : '';
        AppStorage.setOrCreate<string>('selectedQuizFocusTag', focusTag);
        this.pushPage('pages/Quiz', '无法打开 AI 测验，请重试');
      } else {
        this.pushPage('pages/CourseDetail', '无法打开课程详情，请重试');
      }
      return;
    }
    this.pushPage('pages/CourseDetail', '无法打开课程详情，请重试');
  }

  @Builder
  FilterPill(value: string) {
    Button({ type: ButtonType.Normal }) {
      Text(this.filterLabel(value))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.selectedFilter === value ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_TERTIARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
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
          Text('学习节奏')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text('近 4 周学了 ' + this.activeDaysCount().toString() + ' 天 · 连续 ' + this.streakDays.toString() + ' 天')
            .fontSize(11)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(this.recentEventCount().toString() + ' 次')
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

      Row({ space: 8 }) {
        Text(this.overviewExpanded ? '近 4 周' : '最近 7 天')
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
        Blank()
        Text(this.overviewExpanded ? '收起' : '查看 4 周')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_BRAND)
          .onClick((): void => { this.overviewExpanded = !this.overviewExpanded; })
      }
      .width('100%')
      Row({ space: 12 }) {
        Row({ space: 5 }) {
          Column().width(10).height(10).backgroundColor(Constants.COLOR_BRAND).borderRadius(5)
          Text('有学习').fontSize(10).fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        Row({ space: 5 }) {
          Column().width(10).height(10).backgroundColor(Constants.COLOR_SUCCESS).borderRadius(5)
          Text('完成目标').fontSize(10).fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        Blank()
        if (this.overviewExpanded) {
          Text('最多 ' + this.bestDayLabel())
            .fontSize(10)
            .fontColor(Constants.COLOR_TEXT_TERTIARY)
        }
      }
      .width('100%')
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
        TitleBar('学习记录', '正在加载', () => this.getUIContext().getRouter().back())
      } else {
        TitleBar('学习记录', this.events.length.toString() + ' 次学习',
          () => this.getUIContext().getRouter().back())
      }
      if (this.loading) {
        Column()
          .width('90%')
          .height(180)
          .backgroundColor(Constants.COLOR_BG_SKELETON)
          .borderRadius(Constants.RADIUS_LG)
          .accessibilityGroup(true)
          .accessibilityText('正在加载学习记录')
      } else if (this.events.length === 0) {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.clock')).fontSize(38).fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
          Text(this.message.length > 0 ? this.message : '完成第一次学习后，记录会出现在这里')
            .fontSize(14)
            .fontColor(this.message.length > 0 ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
          if (this.message.length > 0) {
            Button('重新读取')
              .width(144)
              .constraintSize({ minHeight: 48 })
              .fontSize(13)
              .fontColor(Constants.COLOR_BRAND)
              .backgroundColor(Constants.COLOR_BG_CARD)
              .border({ width: 1, color: Constants.COLOR_BRAND })
              .borderRadius(24)
              .accessibilityText('重新读取学习记录')
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
          if (this.message.length > 0) {
            ListItem() {
              Column({ space: 10 }) {
                Text(this.message)
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
                  .accessibilityText('重新读取学习记录')
                  .onClick((): void => { this.loadEvents(); })
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
                Text('这个分类下还没有记录')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
                Text('完成一次' + this.filterLabel(this.selectedFilter) + '后会自动出现')
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
