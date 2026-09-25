import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { AchievementProgress, Course, LessonExperience, StudyEvent } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface AchievementActionTarget {
  course: Course;
  topic: string;
}

@Entry
@Component
struct AchievementsPage {
  @State achievements: AchievementProgress[] = [];
  @State courses: Course[] = [];
  @State studyEvents: StudyEvent[] = [];
  @State actionContextReady: boolean = false;
  @State loading: boolean = true;
  @State message: string = '';

  onPageShow(): void {
    this.loadAchievements();
  }

  private async loadAchievements(): Promise<void> {
    this.loading = true;
    this.message = '';
    this.actionContextReady = false;
    try {
      this.achievements = await LocalLearningRepository.getAchievements();
    } catch (error) {
      this.achievements = [];
      this.courses = [];
      this.studyEvents = [];
      this.message = '成就进度读取失败，请重新读取';
      this.loading = false;
      return;
    }
    try {
      this.courses = await LocalLearningRepository.getCourses() ?? [];
      this.studyEvents = await LocalLearningRepository.getStudyEvents();
      if (this.courses.length === 0) {
        this.message = '本地课程目录为空，请重新读取';
      } else {
        this.actionContextReady = true;
      }
    } catch (error) {
      this.courses = [];
      this.studyEvents = [];
      this.message = '学习入口准备失败，请重新读取';
    }
    this.loading = false;
  }

  private isUnlocked(item: AchievementProgress): boolean {
    return item.current >= item.target;
  }

  private unlockedCount(): number {
    return this.achievements.filter((item: AchievementProgress): boolean => this.isUnlocked(item)).length;
  }

  private completionRatio(item: AchievementProgress): number {
    return Math.min(Math.max(item.current / Math.max(item.target, 1), 0), 1);
  }

  private remainingCount(item: AchievementProgress): number {
    return Math.max(item.target - item.current, 0);
  }

  private nextAchievement(): AchievementProgress | null {
    let next: AchievementProgress | null = null;
    for (const item of this.achievements) {
      if (this.isUnlocked(item)) continue;
      if (next === null) {
        next = item;
        continue;
      }
      const remainingDelta = this.remainingCount(item) - this.remainingCount(next);
      const ratioDelta = this.completionRatio(item) - this.completionRatio(next);
      if (remainingDelta < 0 || (remainingDelta === 0 && ratioDelta > 0.001)) {
        next = item;
      }
    }
    return next;
  }

  private isNextAchievement(item: AchievementProgress): boolean {
    return this.nextAchievement()?.id === item.id;
  }

  private activeCourse(): Course | null {
    const storedCourseId = AppStorage.get<string>('selectedCourseId') ?? '';
    const storedCourse = this.courses.find((item: Course): boolean => item.id === storedCourseId);
    if (storedCourse !== undefined) return storedCourse;
    let active: Course | null = null;
    for (const course of this.courses) {
      if (course.progress >= 1) continue;
      if (active === null || course.progress > active.progress) active = course;
    }
    if (active !== null) return active;
    return this.courses.length > 0 ? this.courses[0] : null;
  }

  private orderedCourses(): Course[] {
    const active = this.activeCourse();
    if (active === null) return [];
    const ordered: Course[] = [active];
    for (const course of this.courses) {
      if (course.id !== active.id) ordered.push(course);
    }
    return ordered;
  }

  private orderedTopics(course: Course): string[] {
    const topics = LearningContentRepository.getTopics(course.id);
    const storedTopics: string[] = [
      AppStorage.get<string>('selectedContentTopic') ?? '',
      AppStorage.get<string>('selectedPracticeTopic') ?? '',
      AppStorage.get<string>('selectedQuizTopic') ?? ''
    ];
    const ordered: string[] = [];
    for (const topic of storedTopics) {
      if (topics.includes(topic) && !ordered.includes(topic)) ordered.push(topic);
    }
    for (const topic of topics) {
      if (!ordered.includes(topic)) ordered.push(topic);
    }
    return ordered;
  }

  private practiceTarget(): AchievementActionTarget | null {
    for (const course of this.orderedCourses()) {
      for (const topic of this.orderedTopics(course)) {
        if (LearningContentRepository.getQuestions(course.id, topic).length > 0) {
          return { course: course, topic: topic };
        }
      }
    }
    return null;
  }

  private activityCompleted(activityId: string): boolean {
    return this.studyEvents.some((event: StudyEvent): boolean =>
      event.type === 'lesson_activity' && event.taskId === activityId);
  }

  private activityTarget(): AchievementActionTarget | null {
    for (const course of this.orderedCourses()) {
      for (const topic of this.orderedTopics(course)) {
        const experience: LessonExperience | null =
          LearningContentRepository.getLessonExperience(course.id, topic);
        const firstActivityId = experience?.activities[0]?.id ?? '';
        if (firstActivityId.length > 0 && !this.activityCompleted(firstActivityId)) {
          return { course: course, topic: topic };
        }
      }
    }
    return null;
  }

  private topicMastered(courseId: string, topic: string): boolean {
    return this.studyEvents.some((event: StudyEvent): boolean =>
      event.type === 'quiz_mastered' && event.courseId === courseId && event.topic === topic);
  }

  private masteryTarget(): AchievementActionTarget | null {
    for (const course of this.orderedCourses()) {
      for (const topic of this.orderedTopics(course)) {
        if (!this.topicMastered(course.id, topic)) return { course: course, topic: topic };
      }
    }
    return null;
  }

  private actionTarget(item: AchievementProgress): AchievementActionTarget | null {
    if (!this.actionContextReady) return null;
    if (item.id === 'first_quiz') return this.practiceTarget();
    if (item.id === 'active_learning_3') return this.activityTarget();
    if (item.id === 'mastery_3') return this.masteryTarget();
    return null;
  }

  private needsActionContext(item: AchievementProgress | null): boolean {
    return item !== null && item.id !== 'task_5';
  }

  private nextActionLabel(): string {
    const item = this.nextAchievement();
    if (item === null) return '查看学习记录';
    if (this.needsActionContext(item) && !this.actionContextReady) return '重新加载';
    if (item.id === 'task_5') return '打开今日计划';
    const target = this.actionTarget(item);
    if (item.id === 'first_quiz') return target === null ? '开始练习' : '练习 ' + target.topic;
    if (item.id === 'active_learning_3') return target === null ? '继续学习' : '学习 ' + target.topic;
    if (item.id === 'mastery_3') return target === null ? '开始测验' : '测验 ' + target.topic;
    return '查看目标详情';
  }

  private nextActionHint(): string {
    const item = this.nextAchievement();
    if (item === null) return '所有成就已解锁。';
    const remaining = this.remainingCount(item).toString();
    if (item.id === 'task_5') return '还差 ' + remaining + ' 项任务。';
    if (!this.actionContextReady) return '课程暂时无法打开，请重新加载。';
    const target = this.actionTarget(item);
    if (target === null) return '暂时没有可继续的课程，请重新加载。';
    const context = target.course.title + ' · ' + target.topic;
    if (item.id === 'first_quiz') {
      return '还差 ' + remaining + ' 次练习 · ' + context;
    }
    if (item.id === 'active_learning_3') {
      return '还差 ' + remaining + ' 次互动 · ' + context;
    }
    if (item.id === 'mastery_3') {
      return '还差 ' + remaining + ' 个主题 · ' + context;
    }
    return '还差 ' + remaining + ' 项。';
  }

  private unlockedAtLabel(item: AchievementProgress): string {
    if (item.unlockedAt === undefined) return '';
    const date = new Date(item.unlockedAt);
    if (Number.isNaN(date.getTime())) return '';
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return date.getFullYear().toString() + '-' + month + '-' + day;
  }

  private achievementIcon(item: AchievementProgress): Resource {
    if (item.id === 'first_quiz') return $r('sys.symbol.checkmark_circle_fill');
    if (item.id === 'active_learning_3') return $r('sys.symbol.book_pages_fill_1');
    if (item.id === 'task_5') return $r('sys.symbol.calendar_fill');
    if (item.id === 'mastery_3') return $r('sys.symbol.lightbulb_max_fill');
    return $r('sys.symbol.star_fill');
  }

  private setCourseContext(course: Course): void {
    AppStorage.setOrCreate<string>('selectedCourseId', course.id);
    AppStorage.setOrCreate<string>('selectedCourseTitle', course.title);
  }

  private pushPage(url: string, failureMessage: string): void {
    this.message = '';
    this.getUIContext().getRouter().pushUrl({ url: url }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'AchievementsPage navigation failed: %{public}s', error.message);
      this.message = failureMessage;
    });
  }

  private openNextAchievement(): void {
    const item = this.nextAchievement();
    if (item === null) {
      this.pushPage('pages/ActivityRecords', '无法打开学习记录，请重试');
      return;
    }
    if (item.id === 'task_5') {
      this.pushPage('pages/Plan', '无法打开今日计划，请重试');
      return;
    }
    if (!this.actionContextReady) {
      this.loadAchievements();
      return;
    }
    const target = this.actionTarget(item);
    if (target === null) {
      this.message = '暂时没有可继续的课程';
      return;
    }
    this.setCourseContext(target.course);
    if (item.id === 'first_quiz') {
      AppStorage.setOrCreate<string>('selectedPracticeTopic', target.topic);
      this.pushPage('pages/Practice', '无法打开精选练习，请重试');
      return;
    }
    if (item.id === 'active_learning_3') {
      AppStorage.setOrCreate<string>('selectedContentTopic', target.topic);
      this.pushPage('pages/Lesson', '无法打开课程互动，请重试');
      return;
    }
    if (item.id === 'mastery_3') {
      AppStorage.setOrCreate<string>('selectedQuizTopic', target.topic);
      AppStorage.setOrCreate<string>('selectedQuizFocusTag', '');
      this.pushPage('pages/Quiz', '无法打开 AI 测验，请重试');
      return;
    }
    this.message = '暂时无法打开，请稍后再试';
  }

  @Builder
  AchievementsSkeleton() {
    Column({ space: 16 }) {
      Column({ space: 12 }) {
        Row() {
          Column().width(116).height(18).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
          Blank()
          Column().width(48).height(20).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
        }
        .width('100%')
        Column().width('100%').height(6).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(3)
        Column().width('78%').height(14).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
        Column().width('100%').height(44).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(Constants.RADIUS_MD)
      }
      .width('100%')
      .height(168)
      .padding(18)
      .backgroundColor(Constants.COLOR_BG_CARD)
      .borderRadius(Constants.RADIUS_LG)

      ForEach([1, 2, 3], (_: number): void => {
        Row({ space: 13 }) {
          Column().width(46).height(46).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(23)
          Column({ space: 8 }) {
            Column().width('48%').height(15).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
            Column().width('78%').height(12).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
            Column().width('100%').height(4).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(2)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height(88)
        .padding(16)
        .backgroundColor(Constants.COLOR_BG_CARD)
        .borderRadius(Constants.RADIUS_MD)
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 24 + SafeAreaInsets.bottomVp() })
  }

  build() {
    Column() {
      TitleBar('成就', '继续学习，解锁新目标', () => this.getUIContext().getRouter().back())
      if (this.loading) {
        this.AchievementsSkeleton()
      } else if (this.achievements.length === 0) {
        Column({ space: 14 }) {
          SymbolGlyph($r('sys.symbol.star_fill'))
            .fontSize(40)
            .fontColor([this.message.length > 0 ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_PLACEHOLDER])
          Text(this.message.length > 0 ? this.message : '暂无成就规则')
            .fontSize(14)
            .fontColor(this.message.length > 0 ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
          if (this.message.length > 0) {
            Button('重新读取')
              .height(42)
              .fontSize(14)
              .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.loadAchievements(); })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 16 }) {
          ListItem() {
            Column({ space: 12 }) {
              Row() {
                Column({ space: 3 }) {
                  Text('已解锁')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  Text('学习进度')
                    .fontSize(12)
                    .fontColor(Constants.COLOR_TEXT_TERTIARY)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Text(this.unlockedCount().toString() + ' / ' + this.achievements.length.toString())
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.COLOR_BRAND)
              }
              .width('100%')

              Progress({ value: this.unlockedCount(), total: this.achievements.length, type: ProgressType.Linear })
                .width('100%')
                .height(6)
                .color(Constants.COLOR_BRAND)
                .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)

              if (this.nextAchievement() !== null) {
                Row({ space: 7 }) {
                  SymbolGlyph($r('sys.symbol.star_fill'))
                    .fontSize(15)
                    .fontColor([Constants.COLOR_WARNING])
                  Text('待完成 · ' + (this.nextAchievement()?.title ?? ''))
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Constants.COLOR_TEXT_TERTIARY)
                }
                .width('100%')
              } else {
                Text('当前里程碑已全部解锁')
                  .width('100%')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Constants.COLOR_SUCCESS)
              }

              Text(this.nextActionHint())
                .width('100%')
                .fontSize(12)
                .lineHeight(18)
                .fontColor(Constants.COLOR_TEXT_TERTIARY)

              Button() {
                Row({ space: 8 }) {
                  Text(this.nextActionLabel())
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                  SymbolGlyph($r('sys.symbol.arrow_right'))
                    .fontSize(15)
                    .fontColor([Constants.COLOR_TEXT_ON_GRADIENT])
                }
                .justifyContent(FlexAlign.Center)
              }
              .width('100%')
              .constraintSize({ minHeight: 48 })
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.openNextAchievement(); })

              if (this.message.length > 0) {
                Row({ space: 7 }) {
                  SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
                    .fontSize(14)
                    .fontColor([Constants.COLOR_ERROR])
                  Text(this.message)
                    .fontSize(12)
                    .fontColor(Constants.COLOR_ERROR)
                }
                .width('100%')
              }
            }
            .width('100%')
            .padding(18)
            .backgroundColor(Constants.COLOR_BRAND_LIGHT)
            .borderRadius(Constants.RADIUS_LG)
          }

          ListItem() {
            Column() {
              Row() {
                Text('全部成就')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
                Text(this.achievements.length.toString() + ' 项')
                  .fontSize(11)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .padding({ left: 16, right: 16, top: 16, bottom: 8 })

              ForEach(this.achievements, (item: AchievementProgress, index: number): void => {
                Column() {
                  Row({ space: 13 }) {
                    Stack({ alignContent: Alignment.Center }) {
                      Column()
                        .width(46)
                        .height(46)
                        .backgroundColor(this.isUnlocked(item) ? Constants.COLOR_SUCCESS_LIGHT :
                          (this.isNextAchievement(item) ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_TAG))
                        .borderRadius(23)
                      SymbolGlyph(this.achievementIcon(item))
                        .fontSize(22)
                        .fontColor([this.isUnlocked(item) ? Constants.COLOR_SUCCESS :
                          (this.isNextAchievement(item) ? Constants.COLOR_BRAND : Constants.COLOR_TEXT_PLACEHOLDER)])
                    }
                    Column({ space: 6 }) {
                      Row() {
                        Text(item.title)
                          .fontSize(15)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(Constants.COLOR_TEXT_PRIMARY)
                        Text(this.isUnlocked(item) ? '已解锁' :
                          (this.isNextAchievement(item) ? '当前目标 · ' : '') +
                          item.current.toString() + '/' + item.target.toString())
                          .fontSize(11)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(this.isUnlocked(item) ? Constants.COLOR_SUCCESS :
                            (this.isNextAchievement(item) ? Constants.COLOR_BRAND : Constants.COLOR_TEXT_SECONDARY))
                      }
                      .width('100%')
                      .justifyContent(FlexAlign.SpaceBetween)
                      Text(item.description)
                        .fontSize(12)
                        .fontColor(Constants.COLOR_TEXT_SECONDARY)
                      Text(this.isUnlocked(item) ? this.unlockedAtLabel(item) :
                        '还差 ' + this.remainingCount(item).toString())
                        .fontSize(11)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.isUnlocked(item) ? Constants.COLOR_SUCCESS : Constants.COLOR_TEXT_SECONDARY)
                      Progress({ value: Math.min(item.current, item.target), total: item.target, type: ProgressType.Linear })
                        .width('100%')
                        .height(4)
                        .color(this.isUnlocked(item) ? Constants.COLOR_SUCCESS :
                          (this.isNextAchievement(item) ? Constants.COLOR_BRAND : Constants.COLOR_MAP_NODE_IDLE))
                        .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 14, bottom: 14 })

                  if (index < this.achievements.length - 1) {
                    Divider()
                      .color(Constants.COLOR_BORDER)
                      .margin({ left: 75 })
                  }
                }
                .width('100%')
              })
            }
            .width('100%')
            .backgroundColor(Constants.COLOR_BG_CARD)
            .borderRadius(Constants.RADIUS_LG)
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
