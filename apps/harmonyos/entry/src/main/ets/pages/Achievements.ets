import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { AchievementProgress, Course } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct AchievementsPage {
  @State achievements: AchievementProgress[] = [];
  @State courses: Course[] = [];
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void {
    this.loadAchievements();
  }

  private async loadAchievements(): Promise<void> {
    try {
      this.achievements = await LocalLearningRepository.getAchievements();
      this.courses = await LocalLearningRepository.getCourses() ?? [];
    } catch (error) {
      this.message = '成就进度读取失败';
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

  private nextAchievementTitle(): string {
    const item = this.achievements.find((achievement: AchievementProgress): boolean => !this.isUnlocked(achievement));
    return item !== undefined ? item.title : '';
  }

  private nextAchievement(): AchievementProgress | null {
    const item = this.achievements.find((achievement: AchievementProgress): boolean => !this.isUnlocked(achievement));
    return item !== undefined ? item : null;
  }

  private activeCourse(): Course | null {
    const selectedCourseId = AppStorage.get<string>('selectedCourseId') ?? '';
    const selectedCourse = this.courses.find((course: Course): boolean => course.id === selectedCourseId);
    if (selectedCourse !== undefined) return selectedCourse;
    const inProgress = this.courses.find((course: Course): boolean => course.progress < 1);
    if (inProgress !== undefined) return inProgress;
    return this.courses.length > 0 ? this.courses[0] : null;
  }

  private topicForCourse(course: Course): string {
    return course.topics.length > 0 ? course.topics[0] : '';
  }

  private remainingText(item: AchievementProgress): string {
    const remaining = Math.max(item.target - item.current, 0);
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
    if (item.id === 'first_quiz') return '完成一次精选练习';
    if (item.id === 'active_learning_3') return '完成一次课程互动';
    if (item.id === 'task_5') return '打开学习计划';
    if (item.id === 'mastery_3') return '完成一次主题测验';
    return '继续学习';
  }

  private nextActionHint(): string {
    const item = this.nextAchievement();
    if (item === null) return '全部里程碑均已由本机学习事件解锁，可回看完整学习记录。';
    if (item.id === 'task_5') return this.remainingText(item) + '，完成计划中的真实任务后会自动更新。';
    if (item.id === 'mastery_3') {
      return this.remainingText(item) + '，完成主题测验并达到 80% 正确率后自动更新。';
    }
    const course = this.activeCourse();
    if (course === null) return this.remainingText(item) + '，本地课程目录暂无可执行主题。';
    const topic = this.topicForCourse(course);
    const context = topic.length > 0 ? course.title + ' · ' + topic : course.title;
    return this.remainingText(item) + '，下一步将进入 ' + context + '。';
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

  private openCourseAction(course: Course, page: string, topicStorageKey: string,
    failureMessage: string): void {
    const topic = this.topicForCourse(course);
    if (topic.length === 0) {
      this.message = '当前课程没有可执行主题';
      return;
    }
    this.setCourseContext(course);
    AppStorage.setOrCreate<string>(topicStorageKey, topic);
    this.pushPage(page, failureMessage);
  }

  private openMasteryAction(): void {
    const course = this.activeCourse();
    if (course === null) {
      this.message = '本地课程目录暂无可用课程';
      return;
    }
    AppStorage.setOrCreate<string>('selectedQuizFocusTag', '');
    this.openCourseAction(course, 'pages/Quiz', 'selectedQuizTopic', '无法打开主题测验，请重试');
  }

  private openNextAchievement(): void {
    const item = this.nextAchievement();
    if (item === null) {
      this.pushPage('pages/ActivityRecords', '无法打开学习记录，请重试');
      return;
    }
    if (item.id === 'task_5') {
      this.pushPage('pages/Plan', '无法打开学习计划，请重试');
      return;
    }
    if (item.id === 'mastery_3') {
      this.openMasteryAction();
      return;
    }
    const course = this.activeCourse();
    if (course === null) {
      this.message = '本地课程目录暂无可用课程';
      return;
    }
    if (item.id === 'first_quiz') {
      this.openCourseAction(course, 'pages/Practice', 'selectedPracticeTopic', '无法打开精选练习，请重试');
    } else if (item.id === 'active_learning_3') {
      this.openCourseAction(course, 'pages/Lesson', 'selectedContentTopic', '无法打开课程互动，请重试');
    } else {
      this.setCourseContext(course);
      this.pushPage('pages/CourseDetail', '无法打开课程详情，请重试');
    }
  }

  build() {
    Column() {
      TitleBar('成就', '每个里程碑都来自真实学习记录', () => this.getUIContext().getRouter().back())
      if (this.loading) {
        Column().width('90%').height(220).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(Constants.RADIUS_LG)
      } else if (this.achievements.length === 0) {
        Column() {
          Text(this.message.length > 0 ? this.message : '暂无成就规则')
            .fontSize(14)
            .fontColor(this.message.length > 0 ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
        }
        .layoutWeight(1)
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

              if (this.nextAchievementTitle().length > 0) {
                Row({ space: 7 }) {
                  SymbolGlyph($r('sys.symbol.star_fill'))
                    .fontSize(15)
                    .fontColor([Constants.COLOR_WARNING])
                  Text('下一目标 · ' + this.nextAchievementTitle())
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
                .height(44)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                .backgroundColor(Constants.COLOR_BRAND)
                .borderRadius(Constants.RADIUS_MD)
                .onClick((): void => { this.openNextAchievement(); })

              if (this.message.length > 0) {
                Text(this.message)
                  .width('100%')
                  .fontSize(12)
                  .fontColor(Constants.COLOR_ERROR)
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
                      Row() {
                        Text(item.title)
                          .fontSize(15)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(Constants.COLOR_TEXT_PRIMARY)
                        Text(this.isUnlocked(item) ? '已解锁' : item.current.toString() + '/' + item.target.toString())
                          .fontSize(11)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(this.isUnlocked(item) ? Constants.COLOR_SUCCESS : Constants.COLOR_TEXT_SECONDARY)
                      }
                      .width('100%')
                      .justifyContent(FlexAlign.SpaceBetween)
                      Text(item.description)
                        .fontSize(12)
                        .fontColor(Constants.COLOR_TEXT_SECONDARY)
                      Row({ space: 8 }) {
                        Text(this.achievementSource(item))
                          .layoutWeight(1)
                          .fontSize(11)
                          .lineHeight(17)
                          .fontColor(Constants.COLOR_TEXT_TERTIARY)
                          .maxLines(2)
                        Text(this.isUnlocked(item) ? this.unlockedAtLabel(item) : this.remainingText(item))
                          .fontSize(11)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(this.isUnlocked(item) ? Constants.COLOR_SUCCESS : Constants.COLOR_WARNING)
                      }
                      .width('100%')
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
