import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { Course, TopicMastery, TopicRelation } from '../model/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface MapNode {
  id: string;
  order: number;
  topic: string;
  prerequisiteIds: string[];
  level: number;
  x: number;
  y: number;
  mastery: TopicMastery | null;
}

interface MapEdge {
  fromX: number;
  fromY: number;
  toX: number;
  toY: number;
  active: boolean;
}

const MAP_WIDTH: number = 328;
const NODE_WIDTH: number = 72;
const LEVEL_GAP: number = 82;

@Entry
@Component
struct LearningMapPage {
  @State courses: Course[] = [];
  @State selectedCourseId: string = 'cs101';
  @State selectedCourseTitle: string = '数据结构';
  @State nodes: MapNode[] = [];
  @State edges: MapEdge[] = [];
  @State levelRows: number[] = [];
  @State canvasHeight: number = 420;
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
    const relations = LearningContentRepository.getTopicRelations(course.id);
    const nextNodes: MapNode[] = [];
    const levels: number[] = [];
    let maxLevel = 0;
    for (let relationIndex = 0; relationIndex < relations.length; relationIndex++) {
      const relation = relations[relationIndex];
      const peers = relations.filter((item: TopicRelation): boolean => item.level === relation.level);
      const peerIndex = peers.findIndex((item: TopicRelation): boolean => item.id === relation.id);
      const item = mastery.find((value: TopicMastery): boolean => value.topic === relation.topic) ?? null;
      if (!levels.includes(relation.level)) levels.push(relation.level);
      maxLevel = Math.max(maxLevel, relation.level);
      nextNodes.push({
        id: relation.id,
        order: relationIndex + 1,
        topic: relation.topic,
        prerequisiteIds: relation.prerequisiteIds,
        level: relation.level,
        x: Math.round((peerIndex + 1) * MAP_WIDTH / (peers.length + 1) - NODE_WIDTH / 2),
        y: 30 + relation.level * LEVEL_GAP,
        mastery: item
      });
    }
    this.nodes = nextNodes;
    this.selectedTopic = nextNodes[0]?.topic ?? '';
    const nextEdges: MapEdge[] = [];
    for (const node of nextNodes) {
      for (const prerequisiteId of node.prerequisiteIds) {
        const source = nextNodes.find((item: MapNode): boolean => item.id === prerequisiteId);
        if (source === undefined) continue;
        nextEdges.push({
          fromX: source.x + NODE_WIDTH / 2,
          fromY: source.y + 22,
          toX: node.x + NODE_WIDTH / 2,
          toY: node.y + 22,
          active: node.mastery !== null || source.mastery?.mastered === true
        });
      }
    }
    this.edges = nextEdges;
    this.levelRows = levels.sort((left: number, right: number): number => left - right);
    this.canvasHeight = Math.max(420, 30 + maxLevel * LEVEL_GAP + 92);
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

  private masteredCount(): number {
    return this.nodes.filter((node: MapNode): boolean => node.mastery?.mastered === true).length;
  }

  private prerequisiteLabel(node: MapNode): string {
    if (node.prerequisiteIds.length === 0) return '课程起点，无先修主题';
    const topics: string[] = [];
    for (const id of node.prerequisiteIds) {
      const prerequisite = this.nodes.find((item: MapNode): boolean => item.id === id);
      if (prerequisite !== undefined) topics.push(prerequisite.topic);
    }
    return '先修：' + topics.join(' · ');
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

  private openLesson(topic: string): void {
    AppStorage.setOrCreate<string>('selectedCourseId', this.selectedCourseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.selectedCourseTitle);
    AppStorage.setOrCreate<string>('selectedContentTopic', topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Lesson' }).catch((error: Error): void => {
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'LearningMapPage Lesson navigation failed: %{public}s', error.message);
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
        .width(MAP_WIDTH)
        .height(this.canvasHeight)
        .backgroundColor(Constants.COLOR_MAP_SURFACE)
        .borderRadius(Constants.RADIUS_LG)

      ForEach(this.levelRows, (level: number): void => {
        Text('L' + level.toString())
          .fontSize(9)
          .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
          .position({ x: 10, y: 38 + level * LEVEL_GAP })
        Line()
          .width(MAP_WIDTH - 40)
          .height(1)
          .startPoint([0, 0])
          .endPoint([MAP_WIDTH - 40, 0])
          .stroke(Constants.COLOR_MAP_LINE)
          .strokeWidth(0.5)
          .position({ x: 26, y: 50 + level * LEVEL_GAP })
      })

      ForEach(this.edges, (edge: MapEdge): void => {
        Line()
          .width(MAP_WIDTH)
          .height(this.canvasHeight)
          .startPoint([edge.fromX, edge.fromY])
          .endPoint([edge.toX, edge.toY])
          .stroke(edge.active ? Constants.COLOR_MAP_LINE_ACTIVE : Constants.COLOR_MAP_LINE)
          .strokeWidth(edge.active ? 1.8 : 1)
      })

      ForEach(this.nodes, (node: MapNode): void => {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(this.nodeSize(node))
            .height(this.nodeSize(node))
            .backgroundColor(this.nodeColor(node))
            .borderRadius(this.nodeSize(node) / 2)
            .opacity(node.mastery === null ? 0.14 : 0.18)
          Column()
            .width(node.mastery === null ? 26 : 30)
            .height(node.mastery === null ? 26 : 30)
            .backgroundColor(this.nodeColor(node))
            .borderRadius(node.mastery === null ? 13 : 15)
            .border({
              width: this.selectedTopic === node.topic ? 2 : 0,
              color: Constants.COLOR_BG_CARD
            })
            .shadow(node.mastery === null ? undefined :
              { radius: 5, color: this.nodeColor(node), offsetX: 0, offsetY: 0 })
          Text((node.order < 10 ? '0' : '') + node.order.toString())
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(node.mastery === null ? Constants.COLOR_TEXT_SECONDARY : Constants.COLOR_TEXT_ON_GRADIENT)
          if (this.selectedTopic === node.topic) {
            Text(node.topic)
            .width(NODE_WIDTH)
            .fontSize(node.topic.length > 7 ? 9 : 10)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .wordBreak(WordBreak.BREAK_ALL)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .position({ x: 2, y: 40 })
          }
        }
        .width(NODE_WIDTH)
        .height(72)
        .position({ x: node.x, y: node.y })
        .scale({ x: this.selectedTopic === node.topic ? 1.08 : 1, y: this.selectedTopic === node.topic ? 1.08 : 1 })
        .animation({ duration: Constants.ANIM_FAST, curve: Curve.EaseOut })
        .onClick((): void => { this.selectedTopic = node.topic; })
      })
    }
    .width(MAP_WIDTH)
    .height(this.canvasHeight)
  }

  @Builder
  MapSummary() {
    Row({ space: 16 }) {
      Stack({ alignContent: Alignment.Center }) {
        Progress({ value: this.masteredCount(), total: Math.max(this.nodes.length, 1), type: ProgressType.Ring })
          .width(62)
          .height(62)
          .color(Constants.COLOR_SUCCESS)
        Text(this.masteredCount().toString())
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
      }
      Column({ space: 4 }) {
        Text(this.selectedCourseTitle)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text('已掌握 ' + this.masteredCount().toString() + ' / ' + this.nodes.length.toString() + ' 个主题')
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
        Text('连线表示真实先修关系')
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
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
            Column().width(MAP_WIDTH).height(420).backgroundColor(Constants.COLOR_BG_SKELETON).borderRadius(Constants.RADIUS_LG)
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
            this.MapSummary()
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
                  Text(this.prerequisiteLabel(node))
                    .width('100%')
                    .fontSize(12)
                    .lineHeight(19)
                    .fontColor(Constants.COLOR_TEXT_TERTIARY)
                })
              Row({ space: 10 }) {
                Button({ type: ButtonType.Normal }) {
                  Text('学习主题').fontSize(14).fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                }
                  .layoutWeight(1)
                  .height(48)
                  .backgroundColor(Constants.COLOR_BRAND)
                  .borderRadius(Constants.RADIUS_MD)
                  .onClick((): void => { this.openLesson(this.selectedTopic); })
                Button({ type: ButtonType.Normal }) {
                  Text('主题练习').fontSize(14).fontColor(Constants.COLOR_BRAND)
                }
                  .layoutWeight(1)
                  .height(48)
                  .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                  .borderRadius(Constants.RADIUS_MD)
                  .onClick((): void => { this.openPractice(this.selectedTopic); })
              }
              .width('100%')
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
