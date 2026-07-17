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
  @State loading: boolean = false;
  @State message: string = '';

  aboutToAppear(): void {
    this.loadAchievements();
  }

  private async loadAchievements(): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    this.message = '';
    this.actionContextReady = false;
    try {
      const achievements = await LocalLearningRepository.getAchievements();
      const courses = await LocalLearningRepository.getCourses() ?? [];
      const studyEvents = await LocalLearningRepository.getStudyEvents();
      this.achievements = achievements;
      this.courses = courses;
      this.studyEvents = studyEvents;
      this.actionContextReady = courses.length > 0;
      if (courses.length === 0) this.message = '本地课程目录为空，请重新读取';
    } catch (error) {
      this.achievements = [];
      this.courses = [];
      this.studyEvents = [];
      this.message = '成就进度与学习入口读取失败，请重新读取';
    } finally {
      this.loading = false;
    }
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
      if (remainingDelta < 0 || (remainingDelta === 0 && ratioDelta > 0.001)) next = item;
    }
    return next;
  }

  private activeCourse(): Course | null {
    const selectedCourseId = AppStorage.get<string>('selectedCourseId') ?? '';
    const selectedCourse = this.courses.find((course: Course): boolean => course.id === selectedCourseId);
    if (selectedCourse !== undefined) return selectedCourse;
    for (let index = this.studyEvents.length - 1; index >= 0; index--) {
      const courseId = this.studyEvents[index].courseId ?? '';
      const recentCourse = this.courses.find((course: Course): boolean => course.id === courseId);
      if (recentCourse !== undefined) return recentCourse;
    }
    let inProgress: Course | null = null;
    for (const course of this.courses) {
      if (course.progress >= 1) continue;
      if (inProgress === null || course.progress > inProgress.progress) inProgress = course;
    }
    if (inProgress !== null) return inProgress;
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
    const topics = LearningContentRepository.getTopics(course.id)
      .filter((topic: string): boolean => course.topics.includes(topic));
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
        const activityId = experience?.activities[0]?.id ?? '';
        if (activityId.length > 0 && !this.activityCompleted(activityId)) {
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
        if (!this.topicMastered(course.id, topic) &&
          LearningContentRepository.getQuestions(course.id, topic).length > 0) {
          return { course: course, topic: topic };
        }
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

  private remainingText(item: AchievementProgress): string {
    const remaining = this.remainingCount(item);
    if (remaining === 0) return '已完成';
    if (item.id === 'first_quiz') return '还差 ' + remaining.toString() + ' 次练习';
    if (item.id === 'active_learning_3') return '还差 ' + remaining.toString() + ' 个课程互动';
    if (item.id === 'task_5') return '还差 ' + remaining.toString() + ' 项任务';
    if (item.id === 'mastery_3') return '还差 ' + remaining.toString() + ' 个知识点';
    return '还差 ' + remaining.toString() + ' 条学习记录';
  }

  private unlockedAtLabel(item: AchievementProgress): string {
    if (item.unlockedAt === undefined) return '';
    const date = new Date(item.unlockedAt);
    if (Number.isNaN(date.getTime())) return '';
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return date.getFullYear().toString() + '-' + month + '-' + day;
  }

  private achievementSource(item: AchievementProgress): string {
    if (item.id === 'first_quiz') return '来源：本机练习提交记录';
    if (item.id === 'active_learning_3') return '来源：课程互动完成记录';
    if (item.id === 'task_5') return '来源：学习计划任务完成记录';
    if (item.id === 'mastery_3') return '来源：正确率达到 80% 的主题记录';
    return '来源：本机学习事件';
  }

  private achievementIcon(item: AchievementProgress): Resource {
    if (item.id === 'first_quiz' || item.id === 'task_5') return $r('sys.symbol.checkmark_circle_fill');
    if (item.id === 'active_learning_3') return $r('sys.symbol.book_open_fill');
    return $r('sys.symbol.star_fill');
  }

  private nextActionLabel(): string {
    const item = this.nextAchievement();
    if (item === null) return '查看学习记录';
    if (this.needsActionContext(item) && !this.actionContextReady) return '重新准备学习入口';
    if (item.id === 'first_quiz') return '完成一次精选练习';
    if (item.id === 'active_learning_3') return '继续课程互动';
    if (item.id === 'task_5') return '推进今日计划';
    if (item.id === 'mastery_3') return '验证知识掌握';
    return '查看目标详情';
  }

  private nextActionHint(): string {
    const item = this.nextAchievement();
    if (item === null) return '全部里程碑均已由本机学习事件解锁，可回看完整学习记录。';
    const remaining = this.remainingCount(item).toString();
    if (item.id === 'task_5') return '还差 ' + remaining + ' 项任务，从今日计划继续推进。';
    if (!this.actionContextReady) return '成就已读取，但学习入口尚未准备好，重新读取后可继续推进。';
    const target = this.actionTarget(item);
    if (target === null) return '本地课程资产中没有能推进该成就的精确 Topic。';
    const context = target.course.title + ' · ' + target.topic;
    if (item.id === 'first_quiz') {
      return '还差 ' + remaining + ' 次练习，提交 ' + context + ' 后写入本机练习记录。';
    }
    if (item.id === 'active_learning_3') {
      return '还差 ' + remaining + ' 个课程互动，完成 ' + context + ' 的未计数互动后写入本机。';
    }
    if (item.id === 'mastery_3') {
      return '还差 ' + remaining + ' 个知识点，在 ' + context + ' 达到 80% 后写入精确掌握记录。';
    }
    return '还差 ' + remaining + ' 条真实学习记录。';
  }

  private nextActionAccessibilityText(): string {
    return this.nextActionLabel() + '。' + this.nextActionHint();
  }

  private achievementAccessibilityText(item: AchievementProgress): string {
    const unlockedAt = this.unlockedAtLabel(item);
    const status = this.isUnlocked(item) ?
      (unlockedAt.length > 0 ? '已解锁，解锁日期' + unlockedAt : '已解锁') : this.remainingText(item);
    return item.title + '。' + item.description + '。' + status + '。' + this.achievementSource(item);
  }

  private achievementStatusText(item: AchievementProgress): string {
    if (!this.isUnlocked(item)) return this.remainingText(item);
    const unlockedAt = this.unlockedAtLabel(item);
    return unlockedAt.length > 0 ? unlockedAt : '已解锁';
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
      this.message = '本地课程资产中没有能推进该成就的精确 Topic';
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
    this.message = '该里程碑没有可执行的本地动作';
  }

  build() {
    Column() {
      TitleBar('成就', '每个里程碑都来自真实学习记录', () => this.getUIContext().getRouter().back())
      if (this.loading) {
        Column()
          .width('90%')
          .height(220)
          .backgroundColor(Constants.COLOR_BG_SKELETON)
          .borderRadius(Constants.RADIUS_LG)
          .accessibilityGroup(true)
          .accessibilityText('正在读取本机成就进度与学习入口')
      } else if (this.achievements.length === 0) {
        Column({ space: 14 }) {
          Text(this.message.length > 0 ? this.message : '暂无成就规则')
            .fontSize(14)
            .fontColor(this.message.length > 0 ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
            .textAlign(TextAlign.Center)
          if (this.message.length > 0) {
            Button('重新读取成就进度')
              .constraintSize({ minHeight: 48 })
              .fontSize(14)
              .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
              .backgroundColor(Constants.COLOR_BRAND)
              .borderRadius(Constants.RADIUS_MD)
              .onClick((): void => { this.loadAchievements(); })
              .accessibilityText('重新读取本机成就进度与学习入口')
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 24, right: 24 })
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 16 }) {
          ListItem() {
            Column({ space: 12 }) {
              Row() {
                Column({ space: 3 }) {
                  Text('里程碑进度')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  Text('坚持完成真实学习任务，逐步点亮成就')
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
                .accessibilityText('已解锁' + this.unlockedCount().toString() + '项，共' +
                  this.achievements.length.toString() + '项成就')

              if (this.nextAchievement() !== null) {
                Row({ space: 7 }) {
                  SymbolGlyph($r('sys.symbol.star_fill'))
                    .fontSize(15)
                    .fontColor([Constants.COLOR_WARNING])
                  Text('下一目标 · ' + (this.nextAchievement()?.title ?? ''))
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
                .lineHeight(19)
                .fontColor(Constants.COLOR_TEXT_TERTIARY)

              Button(this.nextActionLabel())
                .width('100%')
                .constraintSize({ minHeight: 48 })
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                .backgroundColor(Constants.COLOR_BRAND)
                .borderRadius(Constants.RADIUS_MD)
                .onClick((): void => { this.openNextAchievement(); })
                .accessibilityText(this.nextActionAccessibilityText())
                .accessibilityDescription('执行后由本机练习、课程互动、计划任务或掌握记录更新里程碑')

              if (this.message.length > 0) {
                Column({ space: 10 }) {
                  Text(this.message)
                    .width('100%')
                    .fontSize(12)
                    .lineHeight(19)
                    .fontColor(Constants.COLOR_ERROR)
                  Button('重新读取真实进度')
                    .width('100%')
                    .constraintSize({ minHeight: 48 })
                    .fontSize(13)
                    .fontColor(Constants.COLOR_ERROR)
                    .backgroundColor(Constants.COLOR_ERROR_LIGHT)
                    .borderRadius(Constants.RADIUS_MD)
                    .onClick((): void => { this.loadAchievements(); })
                    .accessibilityText('重新读取本机成就进度与学习入口')
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
                        .backgroundColor(this.isUnlocked(item) ? Constants.COLOR_SUCCESS_LIGHT : Constants.COLOR_BG_TAG)
                        .borderRadius(23)
                      SymbolGlyph(this.achievementIcon(item))
                        .fontSize(22)
                        .fontColor([this.isUnlocked(item) ? Constants.COLOR_SUCCESS : Constants.COLOR_TEXT_PLACEHOLDER])
                    }
                    Column({ space: 6 }) {
                      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                        Text(item.title)
                          .fontSize(15)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(Constants.COLOR_TEXT_PRIMARY)
                          .margin({ right: 8, bottom: 4 })
                        Text(this.isUnlocked(item) ? '已解锁' : item.current.toString() + '/' + item.target.toString())
                          .fontSize(11)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(this.isUnlocked(item) ? Constants.COLOR_SUCCESS : Constants.COLOR_TEXT_SECONDARY)
                          .margin({ bottom: 4 })
                      }
                      .width('100%')
                      Text(item.description)
                        .width('100%')
                        .fontSize(12)
                        .lineHeight(18)
                        .fontColor(Constants.COLOR_TEXT_SECONDARY)
                      Text(this.achievementSource(item))
                        .width('100%')
                        .fontSize(11)
                        .lineHeight(17)
                        .fontColor(Constants.COLOR_TEXT_TERTIARY)
                      Text(this.achievementStatusText(item))
                        .width('100%')
                        .fontSize(11)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.isUnlocked(item) ? Constants.COLOR_SUCCESS : Constants.COLOR_WARNING)
                      Progress({ value: item.current, total: item.target, type: ProgressType.Linear })
                        .width('100%')
                        .height(4)
                        .color(this.isUnlocked(item) ? Constants.COLOR_SUCCESS : Constants.COLOR_BRAND)
                        .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                  .accessibilityGroup(true)
                  .accessibilityText(this.achievementAccessibilityText(item))
                  .accessibilityDescription('进度来自本机已保存的学习事实')

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
