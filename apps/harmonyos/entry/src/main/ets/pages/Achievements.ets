import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { LearningContentRepository } from '../common/LearningContentRepository';
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
    const course = this.courses.find((item: Course): boolean => item.progress < 1);
    if (course !== undefined) return course;
    return this.courses.length > 0 ? this.courses[0] : null;
  }

  private firstTopic(course: Course): string {
    const topics = LearningContentRepository.getTopics(course.id);
    if (topics.length > 0) return topics[0];
    return course.topics.length > 0 ? course.topics[0] : '';
  }

  private nextActionLabel(): string {
    const item = this.nextAchievement();
    if (item === null) return '查看学习记录';
    if (item.id === 'first_quiz') return '去做第一次练习';
    if (item.id === 'task_5') return '继续完成学习任务';
    if (item.id === 'mastery_3') return '去做 AI 测验';
    return '继续学习';
  }

  private nextActionHint(): string {
    const item = this.nextAchievement();
    if (item === null) return '所有里程碑已点亮，可回看学习记录和薄弱标签。';
    const remaining = Math.max(item.target - item.current, 0);
    if (item.id === 'first_quiz') return '还差 ' + remaining.toString() + ' 次练习，先完成一组精选题。';
    if (item.id === 'task_5') return '还差 ' + remaining.toString() + ' 项任务，回到课程继续推进。';
    if (item.id === 'mastery_3') return '还差 ' + remaining.toString() + ' 个知识点，用 AI 测验验证掌握。';
    return '还差 ' + remaining.toString() + ' 次记录，继续完成真实学习动作。';
  }

  private setCourseContext(course: Course): void {
    AppStorage.setOrCreate<string>('selectedCourseId', course.id);
    AppStorage.setOrCreate<string>('selectedCourseTitle', course.title);
  }

  private pushPage(url: string, failureMessage: string): void {
    this.getUIContext().getRouter().pushUrl({ url: url }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'AchievementsPage navigation failed: %{public}s', error.message);
      this.message = failureMessage;
    });
  }

  private openCourseDetail(course: Course): void {
    this.setCourseContext(course);
    this.pushPage('pages/CourseDetail', '无法打开课程详情，请重试');
  }

  private openPractice(course: Course): void {
    const topic = this.firstTopic(course);
    if (topic.length === 0) {
      this.message = '当前课程没有可练习主题';
      return;
    }
    this.setCourseContext(course);
    AppStorage.setOrCreate<string>('selectedPracticeTopic', topic);
    this.pushPage('pages/Practice', '无法打开精选练习，请重试');
  }

  private openQuiz(course: Course): void {
    const topic = this.firstTopic(course);
    if (topic.length === 0) {
      this.message = '当前课程没有可测验主题';
      return;
    }
    this.setCourseContext(course);
    AppStorage.setOrCreate<string>('selectedQuizTopic', topic);
    this.pushPage('pages/Quiz', '无法打开 AI 测验，请重试');
  }

  private openActivityRecords(): void {
    this.pushPage('pages/ActivityRecords', '无法打开学习记录，请重试');
  }

  private openNextAchievement(): void {
    const item = this.nextAchievement();
    if (item === null) {
      this.openActivityRecords();
      return;
    }
    const course = this.activeCourse();
    if (course === null) {
      this.message = '暂时没有可继续学习的课程';
      return;
    }
    if (item.id === 'first_quiz') {
      this.openPractice(course);
    } else if (item.id === 'mastery_3') {
      this.openQuiz(course);
    } else {
      this.openCourseDetail(course);
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
                .lineHeight(18)
                .fontColor(Constants.COLOR_TEXT_TERTIARY)

              Button(this.nextActionLabel())
                .width('100%')
                .height(42)
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
                      SymbolGlyph($r('sys.symbol.star_fill'))
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
        .padding({ left: 16, right: 16, bottom: 24 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
