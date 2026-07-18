/**
 * 学习画像页
 * 浅色主题 · 加载状态 · 内联统计卡片
 */

import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { Course, TopicMastery, UserProfile } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

const PROFILE_RECOVERY_NONE: string = '';
const PROFILE_RECOVERY_CORE: string = 'core';
const PROFILE_RECOVERY_MASTERY: string = 'mastery';
const PROFILE_NAVIGATION_NONE: string = '';
const PROFILE_NAVIGATION_ROUTE: string = 'route';
const PROFILE_NAVIGATION_QUIZ: string = 'quiz';

@Component
export struct ProfileContent {
  @State profile: UserProfile | null = null;
  @State courses: Course[] = [];
  @State topicMastery: TopicMastery[] = [];
  @State loading: boolean = false;
  @State masteryLoading: boolean = false;
  @State dataMessage: string = '';
  @State dataRecoveryAction: string = PROFILE_RECOVERY_NONE;
  @State navigationMessage: string = '';
  @State navigationTarget: string = '';
  private masteryLoadSequence: number = 0;
  private navigationSequence: number = 0;
  private pendingNavigationKind: string = PROFILE_NAVIGATION_NONE;
  private pendingRoute: string = '';
  private pendingCourseId: string = '';
  private pendingTopic: string = '';

  aboutToAppear(): void {
    this.loadProfile();
  }

  async loadProfile(): Promise<void> {
    if (this.loading) return;
    this.masteryLoadSequence += 1;
    this.loading = true;
    this.masteryLoading = false;
    this.dataMessage = '';
    this.dataRecoveryAction = PROFILE_RECOVERY_NONE;
    try {
      const profile = await LocalLearningRepository.getProfile();
      this.profile = profile;
    } catch (_) {
      this.dataMessage = this.profile === null ? '本地学习画像加载失败' :
        '学习画像刷新失败，当前显示上次读取结果';
      this.dataRecoveryAction = PROFILE_RECOVERY_CORE;
      this.loading = false;
      return;
    }
    this.loading = false;
    if (this.profile === null) {
      this.courses = [];
      this.topicMastery = [];
      return;
    }
    await this.loadMasteryContext();
  }

  private async loadMasteryContext(): Promise<void> {
    const requestSequence = ++this.masteryLoadSequence;
    this.masteryLoading = true;
    this.dataMessage = '';
    this.dataRecoveryAction = PROFILE_RECOVERY_NONE;
    try {
      const courses = (await LocalLearningRepository.getCourses()) ?? [];
      const mastery = await LocalLearningRepository.getTopicMastery();
      if (requestSequence !== this.masteryLoadSequence) return;
      const topicMastery = this.sortTopicMastery(mastery.filter((item: TopicMastery): boolean =>
        courses.some((course: Course): boolean =>
          course.id === item.courseId && course.topics.includes(item.topic)))).slice(0, 6);
      this.courses = courses;
      this.topicMastery = topicMastery;
    } catch (_) {
      if (requestSequence !== this.masteryLoadSequence) return;
      this.dataMessage = '知识点画像读取失败，当前统计与成长入口仍可使用';
      this.dataRecoveryAction = PROFILE_RECOVERY_MASTERY;
    } finally {
      if (requestSequence === this.masteryLoadSequence) this.masteryLoading = false;
    }
  }

  private dataRecoveryLabel(): string {
    return this.dataRecoveryAction === PROFILE_RECOVERY_MASTERY ? '重新读取知识点画像' : '重新加载学习画像';
  }

  private retryDataRecovery(): void {
    if (this.dataRecoveryAction === PROFILE_RECOVERY_MASTERY) {
      this.loadMasteryContext();
      return;
    }
    this.loadProfile();
  }

  private sortTopicMastery(items: TopicMastery[]): TopicMastery[] {
    return items.slice().sort((left: TopicMastery, right: TopicMastery): number => {
      if (left.mastered !== right.mastered) return left.mastered ? 1 : -1;
      const accuracyDelta = left.accuracy - right.accuracy;
      if (accuracyDelta !== 0) return accuracyDelta;
      return (right.lastPracticedAt ?? '').localeCompare(left.lastPracticedAt ?? '');
    });
  }

  private openLearningMap(): void {
    this.openPage('pages/LearningMap', '学习星图');
  }

  private clearNavigationFailure(): void {
    this.navigationMessage = '';
    this.navigationTarget = '';
    this.pendingNavigationKind = PROFILE_NAVIGATION_NONE;
    this.pendingRoute = '';
    this.pendingCourseId = '';
    this.pendingTopic = '';
  }

  private beginNavigation(): number {
    this.navigationSequence += 1;
    this.clearNavigationFailure();
    return this.navigationSequence;
  }

  private openPage(url: string, target: string): void {
    const requestSequence = this.beginNavigation();
    this.getUIContext().getRouter().pushUrl({ url: url }).catch((error: Error): void => {
      if (requestSequence !== this.navigationSequence) return;
      this.navigationMessage = target + '打开失败，请重试';
      this.navigationTarget = target;
      this.pendingNavigationKind = PROFILE_NAVIGATION_ROUTE;
      this.pendingRoute = url;
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'ProfileContent route navigation failed: %{public}s', error.message);
    });
  }

  private findCourse(item: TopicMastery): Course | undefined {
    return this.courses.find((course: Course): boolean =>
      course.id === item.courseId && course.topics.includes(item.topic));
  }

  private topicCourseTitle(item: TopicMastery): string {
    const course = this.findCourse(item);
    return course === undefined ? '课程目录已更新' : course.title;
  }

  private openFocusedQuiz(item: TopicMastery): void {
    const course = this.findCourse(item);
    if (course === undefined) {
      this.beginNavigation();
      this.dataMessage = '课程目录已更新，请重新读取知识点画像';
      this.dataRecoveryAction = PROFILE_RECOVERY_MASTERY;
      return;
    }
    this.navigateFocusedQuiz(course, item.topic);
  }

  private navigateFocusedQuiz(course: Course, topic: string): void {
    const requestSequence = this.beginNavigation();
    AppStorage.setOrCreate<string>('selectedCourseId', course.id);
    AppStorage.setOrCreate<string>('selectedCourseTitle', course.title);
    AppStorage.setOrCreate<string>('selectedQuizTopic', topic);
    AppStorage.setOrCreate<string>('selectedQuizFocusTag', '');
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Quiz' }).catch((error: Error): void => {
      if (requestSequence !== this.navigationSequence) return;
      this.navigationMessage = course.title + ' · ' + topic + ' 测验打开失败，请重试';
      this.navigationTarget = course.title + ' · ' + topic + ' 测验';
      this.pendingNavigationKind = PROFILE_NAVIGATION_QUIZ;
      this.pendingCourseId = course.id;
      this.pendingTopic = topic;
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'ProfileContent focused quiz navigation failed: %{public}s', error.message);
    });
  }

  private retryNavigation(): void {
    if (this.pendingNavigationKind === PROFILE_NAVIGATION_ROUTE) {
      const route = this.pendingRoute;
      const target = this.navigationTarget;
      this.openPage(route, target);
      return;
    }
    if (this.pendingNavigationKind === PROFILE_NAVIGATION_QUIZ) {
      const courseId = this.pendingCourseId;
      const topic = this.pendingTopic;
      const course = this.courses.find((item: Course): boolean =>
        item.id === courseId && item.topics.includes(topic));
      if (course !== undefined) {
        this.navigateFocusedQuiz(course, topic);
        return;
      }
      this.beginNavigation();
      this.dataMessage = '课程目录已更新，请重新读取知识点画像';
      this.dataRecoveryAction = PROFILE_RECOVERY_MASTERY;
    }
  }

  @Builder
  GrowthEntry(title: string, subtitle: string, icon: Resource, url: string) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column().width(38).height(38).backgroundColor(Constants.COLOR_BRAND_LIGHT).borderRadius(12)
        SymbolGlyph(icon).fontSize(20).fontColor([Constants.COLOR_BRAND])
      }
      Column({ space: 3 }) {
        Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text(subtitle).fontSize(11).fontColor(Constants.COLOR_TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(17).fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
    }
    .width('100%')
    .constraintSize({ minHeight: 64 })
    .padding({ top: 8, bottom: 8 })
    .onClick((): void => { this.openPage(url, title); })
    .accessibilityGroup(true)
    .accessibilityText(title)
    .accessibilityDescription(subtitle)
  }

  @Builder
  Metric(value: string, label: string, color: ResourceColor) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(23)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(11)
        .fontColor(Constants.COLOR_TEXT_SECONDARY)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  TopicMasteryRow(item: TopicMastery) {
    Column({ space: 10 }) {
      Flex({ wrap: FlexWrap.Wrap }) {
        Text(this.topicCourseTitle(item) + ' · ' + item.topic)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
          .margin({ right: 8, bottom: 6 })
        Text(item.mastered ? '已掌握' : '待巩固')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(item.mastered ? Constants.COLOR_SUCCESS : Constants.COLOR_WARNING)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(item.mastered ? Constants.COLOR_SUCCESS_LIGHT : Constants.COLOR_SURFACE_TINT)
          .borderRadius(Constants.RADIUS_SM)
          .margin({ bottom: 6 })
      }
      .width('100%')
      Progress({ value: Math.round(item.accuracy * 100), total: 100, type: ProgressType.Linear })
        .width('100%')
        .color(item.mastered ? Constants.COLOR_SUCCESS : (item.accuracy >= 0.6 ? Constants.COLOR_WARNING :
          Constants.COLOR_ERROR))
        .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
        .borderRadius(4)
        .accessibilityText(item.topic + '累计正确率' + Math.round(item.accuracy * 100).toString() + '%')
      Text('累计答对 ' + item.correctQuestions.toString() + '/' + item.totalQuestions.toString() +
        ' 题 · ' + item.attempts.toString() + ' 次测验')
        .fontSize(11)
        .fontColor(Constants.COLOR_TEXT_SECONDARY)
      Text(item.mastered ? '掌握依据：累计正确率达到 80%' : '下一步：继续测验，新的答题结果会更新这里')
        .fontSize(11)
        .fontColor(Constants.COLOR_TEXT_TERTIARY)
        .lineHeight(18)
      Button('练习 ' + item.topic)
        .width('100%')
        .constraintSize({ minHeight: 48 })
        .fontSize(13)
        .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
        .backgroundColor(Constants.COLOR_BRAND)
        .borderRadius(Constants.RADIUS_SM)
        .onClick((): void => { this.openFocusedQuiz(item); })
        .accessibilityText('练习' + this.topicCourseTitle(item) + item.topic)
        .accessibilityDescription('打开测验，新结果将更新知识点画像')
    }
    .width('100%')
  }

  @Builder
  ProfileSkeleton() {
    Column({ space: 14 }) {
      Row({ space: 14 }) {
        Column().width(56).height(56).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(28)
        Column({ space: 8 }) {
          Column().width(130).height(18).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(6)
          Column().width(180).height(14).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(5)
        }
        .alignItems(HorizontalAlign.Start)
      }
      Column().width('100%').height(92).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
      Column().width('100%').height(150).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(12)
    }
    .width('100%')
    .padding(16)
    .accessibilityGroup(true)
    .accessibilityText('正在加载学习画像')
  }

  build() {
    Column() {
      Column() {
        Text('我的')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text('你的学习节奏与成长记录')
          .fontSize(14)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .margin({ top: 6 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 22, right: 22, top: 24, bottom: 18 })

      if (this.loading && this.profile === null) {
        this.ProfileSkeleton()
      } else if (this.profile) {
        Scroll() {
          Column({ space: 12 }) {
            if (this.dataMessage.length > 0) {
              Column({ space: 10 }) {
                Row({ space: 10 }) {
                  SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
                    .fontSize(20)
                    .fontColor([Constants.COLOR_ERROR])
                  Text(this.dataMessage)
                    .layoutWeight(1)
                    .fontSize(13)
                    .fontColor(Constants.COLOR_ERROR)
                    .lineHeight(20)
                }
                .width('100%')
                Button(this.dataRecoveryLabel())
                  .width('100%')
                  .constraintSize({ minHeight: 48 })
                  .fontSize(12)
                  .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                  .backgroundColor(Constants.COLOR_ERROR)
                  .borderRadius(Constants.RADIUS_SM)
                  .onClick((): void => { this.retryDataRecovery(); })
                  .accessibilityText(this.dataRecoveryLabel())
                  .accessibilityDescription(this.dataMessage)
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor(Constants.COLOR_ERROR_LIGHT)
                .borderRadius(Constants.RADIUS_MD)
            }

            if (this.navigationMessage.length > 0) {
              Column({ space: 10 }) {
                Row({ space: 10 }) {
                  SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
                    .fontSize(20)
                    .fontColor([Constants.COLOR_ERROR])
                  Text(this.navigationMessage)
                    .layoutWeight(1)
                    .fontSize(13)
                    .fontColor(Constants.COLOR_ERROR)
                    .lineHeight(20)
                }
                .width('100%')
                Button('重试打开 ' + this.navigationTarget)
                  .width('100%')
                  .constraintSize({ minHeight: 48 })
                  .fontSize(12)
                  .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                  .backgroundColor(Constants.COLOR_ERROR)
                  .borderRadius(Constants.RADIUS_SM)
                  .onClick((): void => { this.retryNavigation(); })
                  .accessibilityText('重试打开' + this.navigationTarget)
                  .accessibilityDescription(this.navigationMessage)
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor(Constants.COLOR_ERROR_LIGHT)
              .borderRadius(Constants.RADIUS_MD)
            }

            Row({ space: 16 }) {
              Text(this.profile.name.charAt(0))
                .fontSize(28)
                .fontColor(Constants.COLOR_BRAND)
                .width(56)
                .height(56)
                .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                .borderRadius(28)
                .textAlign(TextAlign.Center)

              Column() {
                Text(this.profile.name)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
                Text(this.profile.stage)
                  .fontSize(13)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Constants.COLOR_BG_CARD)
            .borderRadius(Constants.RADIUS_LG)
            .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
            .accessibilityGroup(true)
            .accessibilityText(this.profile.name + '，' + this.profile.stage)

            Column() {
              this.GrowthEntry('学习记录', '按时间回看练习与任务', $r('sys.symbol.clock'), 'pages/ActivityRecords')
              Divider().color(Constants.COLOR_BORDER).margin({ left: 50 })
              this.GrowthEntry('错题本', '集中复习尚未解决的问题', $r('sys.symbol.xmark_circle_fill'), 'pages/MistakeBook')
              Divider().color(Constants.COLOR_BORDER).margin({ left: 50 })
              this.GrowthEntry('成就', '用真实完成记录解锁里程碑', $r('sys.symbol.star_fill'), 'pages/Achievements')
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 4, bottom: 4 })
            .backgroundColor(Constants.COLOR_BG_CARD)
            .borderRadius(Constants.RADIUS_LG)

            Row({ space: 14 }) {
              Stack({ alignContent: Alignment.Center }) {
                Column()
                  .width(48)
                  .height(48)
                  .backgroundColor(Constants.COLOR_MAP_CORE)
                  .borderRadius(16)
                  .shadow({ radius: 7, color: Constants.SHADOW_CARD_LG, offsetX: 0, offsetY: 2 })
                SymbolGlyph($r('sys.symbol.book_open_fill'))
                  .fontSize(20)
                  .fontColor([Constants.COLOR_TEXT_ON_GRADIENT])
              }
              .width(48)
              .height(48)

              Column({ space: 5 }) {
                Text('学习星图')
                  .fontSize(19)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.COLOR_TEXT_PRIMARY)
                Text('查看知识之间的联系与掌握状态')
                  .fontSize(12)
                  .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
                  .lineHeight(18)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(20)
                .fontColor([Constants.COLOR_TEXT_PRIMARY])
            }
            .width('100%')
            .constraintSize({ minHeight: 96 })
            .padding(18)
            .backgroundColor(Constants.COLOR_MAP_SURFACE)
            .borderRadius(Constants.RADIUS_LG)
            .onClick((): void => { this.openLearningMap(); })
            .accessibilityGroup(true)
            .accessibilityText('打开学习星图')
            .accessibilityDescription('查看知识之间的联系与掌握状态')

            Column({ space: 10 }) {
              Row() {
                this.Metric(Math.round(this.profile.stats.accuracy * 100).toString() + '%', '正确率', Constants.COLOR_SUCCESS)
                Column().width(1).height(36).backgroundColor(Constants.COLOR_BORDER)
                this.Metric(this.profile.stats.totalQuestions.toString(), '累计答题', Constants.COLOR_TEXT_PRIMARY)
                Column().width(1).height(36).backgroundColor(Constants.COLOR_BORDER)
                this.Metric(this.profile.stats.streakDays.toString(), '连续天数', Constants.COLOR_BRAND)
              }
              .width('100%')
              Text('累计活跃 ' + this.profile.stats.studyDays.toString() + ' 天 · 来自本机答题与学习事件')
                .width('100%')
                .fontSize(11)
                .fontColor(Constants.COLOR_TEXT_SECONDARY)
                .textAlign(TextAlign.Center)
                .lineHeight(18)
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            .backgroundColor(Constants.COLOR_BG_CARD)
            .borderRadius(Constants.RADIUS_LG)
            .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
            .accessibilityGroup(true)
            .accessibilityText('学习统计，正确率' + Math.round(this.profile.stats.accuracy * 100).toString() +
              '%，累计答题' + this.profile.stats.totalQuestions.toString() + '题，连续学习' +
              this.profile.stats.streakDays.toString() + '天，累计活跃' +
              this.profile.stats.studyDays.toString() + '天')
            .accessibilityDescription('统计来自本机已保存的答题与学习事件')

            Column({ space: 12 }) {
              Text('知识点画像')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
              Text('按课程与知识点汇总本机测验，优先显示尚未掌握且正确率较低的项目')
                .fontSize(11)
                .fontColor(Constants.COLOR_TEXT_SECONDARY)
                .lineHeight(18)
              if (this.masteryLoading) {
                Text(this.topicMastery.length > 0 ? '正在刷新本机知识点画像，当前保留上次读取结果' :
                  '正在读取本机知识点画像')
                  .fontSize(12)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
                  .lineHeight(20)
                  .accessibilityText(this.topicMastery.length > 0 ?
                    '正在刷新本机知识点画像，当前显示上次读取结果' : '正在读取本机知识点画像')
              }
              if (this.topicMastery.length === 0 && !this.masteryLoading) {
                Text('完成一次测验后，这里会显示累计答题、正确率与掌握依据')
                  .fontSize(12)
                  .fontColor(Constants.COLOR_TEXT_SECONDARY)
                  .lineHeight(20)
              } else {
                ForEach(this.topicMastery, (item: TopicMastery, index: number): void => {
                  this.TopicMasteryRow(item)
                  if (index < this.topicMastery.length - 1) {
                    Divider().color(Constants.COLOR_BORDER)
                  }
                })
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Constants.COLOR_BG_CARD)
            .borderRadius(Constants.RADIUS_LG)
            .shadow({ radius: 8, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 1 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 12 + SafeAreaInsets.bottomVp() })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      } else {
        Column({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.person'))
            .fontSize(42)
            .fontColor([Constants.COLOR_TEXT_PLACEHOLDER])
          Text(this.dataMessage.length > 0 ? this.dataMessage : '暂无学习画像')
            .fontSize(15)
            .fontColor(this.dataMessage.length > 0 ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
            .textAlign(TextAlign.Center)
            .lineHeight(22)
          Button('重新加载')
            .constraintSize({ minHeight: 48 })
            .fontSize(14)
            .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
            .backgroundColor(Constants.COLOR_BRAND)
            .borderRadius(Constants.RADIUS_SM)
            .onClick((): void => { this.loadProfile(); })
            .accessibilityText('重新加载学习画像')
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 24, right: 24 })
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }

}

@Entry
@Component
struct ProfilePage {
  build() {
    Column() {
      ProfileContent()
    }
  }
}
