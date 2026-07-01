import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { Course, TopicMastery } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface MapNode {
  topic: string;
  x: number;
  y: number;
  mastery: TopicMastery | null;
}

const NODE_POSITIONS: number[][] = [
  [12, 42], [222, 34], [230, 132], [202, 238], [28, 242], [0, 138]
];

@Entry
@Component
struct LearningMapPage {
  @State courses: Course[] = [];
  @State selectedCourseId: string = 'cs101';
  @State selectedCourseTitle: string = '数据结构';
  @State nodes: MapNode[] = [];
  @State selectedTopic: string = '';
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void {
    this.loadMap();
  }

  private async loadMap(): Promise<void> {
    this.loading = true;
    try {
      this.courses = await LocalLearningRepository.getCourses() ?? [];
      const storedCourse = AppStorage.get<string>('selectedCourseId') ?? '';
      const selected = this.courses.find((course: Course): boolean => course.id === storedCourse) ?? this.courses[0];
      if (selected !== undefined) {
        this.selectedCourseId = selected.id;
        this.selectedCourseTitle = selected.title;
        await this.selectCourse(selected);
      }
    } catch (error) {
      this.message = '本地学习星图加载失败';
    } finally {
      this.loading = false;
    }
  }

  private async selectCourse(course: Course): Promise<void> {
    this.selectedCourseId = course.id;
    this.selectedCourseTitle = course.title;
    this.selectedTopic = '';
    const mastery = await LocalLearningRepository.getTopicMastery(course.id);
    const nextNodes: MapNode[] = [];
    const visibleTopics = course.topics.slice(0, NODE_POSITIONS.length);
    for (let index = 0; index < visibleTopics.length; index++) {
      const topic = visibleTopics[index];
      const item = mastery.find((value: TopicMastery): boolean => value.topic === topic) ?? null;
      nextNodes.push({
        topic: topic,
        x: NODE_POSITIONS[index][0],
        y: NODE_POSITIONS[index][1],
        mastery: item
      });
    }
    this.nodes = nextNodes;
  }

  private nodeColor(node: MapNode): ResourceColor {
    if (node.mastery === null) return Constants.COLOR_MAP_NODE_IDLE;
    if (node.mastery.mastered) return Constants.COLOR_SUCCESS;
    return Constants.COLOR_WARNING;
  }

  private nodeSize(node: MapNode): number {
    if (node.mastery === null) return 34;
    return Math.min(38 + node.mastery.attempts * 3, 50);
  }

  private masteryLabel(node: MapNode): string {
    if (node.mastery === null) return '尚未练习';
    if (node.mastery.mastered) return '已掌握 · ' + Math.round(node.mastery.accuracy * 100).toString() + '%';
    return '学习中 · ' + Math.round(node.mastery.accuracy * 100).toString() + '%';
  }

  private openPractice(topic: string): void {
    AppStorage.setOrCreate<string>('selectedCourseId', this.selectedCourseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.selectedCourseTitle);
    AppStorage.setOrCreate<string>('selectedPracticeTopic', topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Practice' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'LearningMapPage Practice navigation failed: %{public}s', error.message);
    });
  }

  @Builder
  CourseSelector() {
    Row({ space: 8 }) {
      ForEach(this.courses, (course: Course): void => {
        Button(course.title)
          .layoutWeight(1)
          .height(40)
          .fontSize(12)
          .fontColor(this.selectedCourseId === course.id ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_SECONDARY)
          .backgroundColor(this.selectedCourseId === course.id ? Constants.COLOR_TEXT_PRIMARY : Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.selectCourse(course); })
      })
    }
    .width('100%')
  }

  @Builder
  MapCanvas() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(328)
        .height(342)
        .backgroundColor(Constants.COLOR_MAP_SURFACE)
        .borderRadius(Constants.RADIUS_LG)

      ForEach(this.nodes, (node: MapNode): void => {
        Line()
          .width(328)
          .height(342)
          .startPoint([164, 171])
          .endPoint([node.x + 47, node.y + 27])
          .stroke(node.mastery === null ? Constants.COLOR_MAP_LINE : Constants.COLOR_MAP_LINE_ACTIVE)
          .strokeWidth(node.mastery === null ? 1 : 1.5)
      })

      Column({ space: 4 }) {
        Text(this.selectedCourseTitle)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
        Text(this.nodes.length.toString() + ' 个主题')
          .fontSize(10)
          .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
      }
      .width(104)
      .height(72)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(Constants.COLOR_MAP_CORE)
      .borderRadius(Constants.RADIUS_LG)
      .shadow({ radius: 8, color: Constants.SHADOW_CARD_LG, offsetX: 0, offsetY: 3 })

      ForEach(this.nodes, (node: MapNode): void => {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(this.nodeSize(node))
            .height(this.nodeSize(node))
            .backgroundColor(this.nodeColor(node))
            .borderRadius(this.nodeSize(node) / 2)
            .opacity(node.mastery === null ? 0.14 : 0.18)
          Column()
            .width(node.mastery === null ? 10 : 14)
            .height(node.mastery === null ? 10 : 14)
            .backgroundColor(this.nodeColor(node))
            .borderRadius(node.mastery === null ? 5 : 7)
            .shadow(node.mastery === null ? undefined :
              { radius: 5, color: this.nodeColor(node), offsetX: 0, offsetY: 0 })
          Text(node.topic)
            .width(90)
            .fontSize(node.topic.length > 7 ? 10 : 11)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .wordBreak(WordBreak.BREAK_ALL)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .position({ x: 2, y: 40 })
        }
        .width(94)
        .height(58)
        .position({ x: node.x, y: node.y })
        .scale({ x: this.selectedTopic === node.topic ? 1.08 : 1, y: this.selectedTopic === node.topic ? 1.08 : 1 })
        .animation({ duration: Constants.ANIM_FAST, curve: Curve.EaseOut })
        .onClick((): void => { this.selectedTopic = node.topic; })
      })
    }
    .width(328)
    .height(342)
  }

  build() {
    Column() {
      TitleBar('学习星图', '练习越充分，知识节点越清晰', () => this.getUIContext().getRouter().back())

      Scroll() {
        Column({ space: 16 }) {
          if (this.courses.length > 0) {
            this.CourseSelector()
          }

          if (this.loading) {
            Column().width(328).height(342).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(Constants.RADIUS_LG)
          } else if (this.nodes.length === 0) {
            Column({ space: 8 }) {
              Text(this.message.length > 0 ? this.message : '还没有可展示的课程主题')
                .fontSize(14)
                .fontColor(this.message.length > 0 ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
            }
            .width('100%')
            .height(260)
            .justifyContent(FlexAlign.Center)
          } else {
            this.MapCanvas()
          }

          Row({ space: 18 }) {
            Row({ space: 6 }) {
              Column().width(9).height(9).backgroundColor(Constants.COLOR_MAP_NODE_IDLE).borderRadius(5)
              Text('未练习').fontSize(11).fontColor(Constants.COLOR_TEXT_SECONDARY)
            }
            Row({ space: 6 }) {
              Column().width(9).height(9).backgroundColor(Constants.COLOR_WARNING).borderRadius(5)
              Text('学习中').fontSize(11).fontColor(Constants.COLOR_TEXT_SECONDARY)
            }
            Row({ space: 6 }) {
              Column().width(9).height(9).backgroundColor(Constants.COLOR_SUCCESS).borderRadius(5)
              Text('已掌握').fontSize(11).fontColor(Constants.COLOR_TEXT_SECONDARY)
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          if (this.selectedTopic.length > 0) {
            Column({ space: 12 }) {
              Text(this.selectedTopic)
                .width('100%')
                .fontSize(19)
                .fontWeight(FontWeight.Bold)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
              ForEach(this.nodes.filter((node: MapNode): boolean => node.topic === this.selectedTopic),
                (node: MapNode): void => {
                  Text(this.masteryLabel(node))
                    .width('100%')
                    .fontSize(13)
                    .fontColor(Constants.COLOR_TEXT_SECONDARY)
                })
              Button('练习这个主题')
                .width('100%')
                .height(48)
                .fontSize(14)
                .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                .backgroundColor(Constants.COLOR_BRAND)
                .borderRadius(Constants.RADIUS_MD)
                .onClick((): void => { this.openPractice(this.selectedTopic); })
            }
            .width('100%')
            .padding(18)
            .backgroundColor(Constants.COLOR_BG_CARD)
            .borderRadius(Constants.RADIUS_LG)
          } else {
            Text('点击任意节点查看掌握状态')
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Start)
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
