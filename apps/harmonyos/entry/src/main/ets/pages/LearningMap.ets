import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { LearningContentRepository } from '../common/LearningContentRepository';
import { LocalLearningRepository } from '../common/LocalLearningRepository';
import { Course, LessonProgress, TopicMastery, TopicRelation } from '../model/DataModels';
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
  lessonCompleted: boolean;
  unlocked: boolean;
  recommended: boolean;
}

interface MapEdge {
  fromX: number;
  fromY: number;
  toX: number;
  toY: number;
  active: boolean;
}

interface NebulaStar {
  x: number;
  y: number;
  size: number;
  opacity: number;
}

const MAP_WIDTH: number = 328;
const NODE_WIDTH: number = 72;
const LEVEL_GAP: number = 82;
const NEBULA_STARS: NebulaStar[] = [
  { x: 26, y: 36, size: 2, opacity: 0.52 },
  { x: 72, y: 92, size: 3, opacity: 0.36 },
  { x: 128, y: 48, size: 2, opacity: 0.42 },
  { x: 196, y: 118, size: 2, opacity: 0.34 },
  { x: 286, y: 64, size: 3, opacity: 0.44 },
  { x: 42, y: 188, size: 2, opacity: 0.30 },
  { x: 112, y: 246, size: 3, opacity: 0.38 },
  { x: 238, y: 214, size: 2, opacity: 0.32 },
  { x: 298, y: 286, size: 2, opacity: 0.40 },
  { x: 74, y: 356, size: 2, opacity: 0.34 },
  { x: 164, y: 404, size: 3, opacity: 0.36 },
  { x: 266, y: 468, size: 2, opacity: 0.30 },
  { x: 36, y: 532, size: 3, opacity: 0.32 },
  { x: 206, y: 574, size: 2, opacity: 0.35 }
];

@Entry
@Component
struct LearningMapPage {
  @State courses: Course[] = [];
  @State selectedCourseId: string = 'cs101';
  @State selectedCourseTitle: string = '数据结构';
  @State nodes: MapNode[] = [];
  @State edges: MapEdge[] = [];
  @State levelRows: number[] = [];
  @State canvasWidth: number = MAP_WIDTH;
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
    const lessonProgress = await LocalLearningRepository.getLessonProgress(course.id);
    const relations = LearningContentRepository.getTopicRelations(course.id);
    const nextNodes: MapNode[] = [];
    const levels: number[] = [];
    let maxLevel = 0;
    let maxPeers = 1;
    for (const relation of relations) {
      const peers = relations.filter((item: TopicRelation): boolean => item.level === relation.level);
      maxPeers = Math.max(maxPeers, peers.length);
    }
    const calculatedWidth = Math.max(MAP_WIDTH, maxPeers * 82 + 40);
    for (let relationIndex = 0; relationIndex < relations.length; relationIndex++) {
      const relation = relations[relationIndex];
      const peers = relations.filter((item: TopicRelation): boolean => item.level === relation.level);
      const peerIndex = peers.findIndex((item: TopicRelation): boolean => item.id === relation.id);
      const item = mastery.find((value: TopicMastery): boolean => value.topic === relation.topic) ?? null;
      const progress = lessonProgress.find((value: LessonProgress): boolean => value.topic === relation.topic);
      if (!levels.includes(relation.level)) levels.push(relation.level);
      maxLevel = Math.max(maxLevel, relation.level);
      nextNodes.push({
        id: relation.id,
        order: relationIndex + 1,
        topic: relation.topic,
        prerequisiteIds: relation.prerequisiteIds,
        level: relation.level,
        x: Math.round((peerIndex + 1) * calculatedWidth / (peers.length + 1) - NODE_WIDTH / 2),
        y: 30 + relation.level * LEVEL_GAP,
        mastery: item,
        lessonCompleted: progress?.completedAt !== undefined,
        unlocked: false,
        recommended: false
      });
    }
    for (const node of nextNodes) {
      node.unlocked = this.isUnlocked(node, nextNodes);
    }
    const recommended = this.findRecommendedNode(nextNodes);
    for (const node of nextNodes) {
      node.recommended = recommended !== null && node.id === recommended.id;
    }
    this.nodes = nextNodes;
    this.selectedTopic = recommended?.topic ?? nextNodes[0]?.topic ?? '';
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
          active: source.mastery?.mastered === true
        });
      }
    }
    this.edges = nextEdges;
    this.levelRows = levels.sort((left: number, right: number): number => left - right);
    this.canvasWidth = calculatedWidth;
    this.canvasHeight = Math.max(420, 30 + maxLevel * LEVEL_GAP + 92);
  }

  private nodeColor(node: MapNode): ResourceColor {
    if (node.mastery?.mastered === true) return Constants.COLOR_SUCCESS;
    if (node.mastery !== null) return Constants.COLOR_WARNING;
    if (node.lessonCompleted) return Constants.COLOR_BRAND;
    if (node.unlocked) return Constants.COLOR_MAP_NODE_IDLE;
    return Constants.COLOR_MAP_LINE;
  }

  private nodeSize(node: MapNode): number {
    if (node.recommended) return 50;
    if (node.mastery === null) return node.lessonCompleted ? 38 : 34;
    return Math.min(38 + node.mastery.attempts * 3, 50);
  }

  private masteryLabel(node: MapNode): string {
    if (!node.unlocked) return '未解锁 · ' + this.prerequisiteLabel(node);
    if (node.mastery === null && node.lessonCompleted) return '已学习 · 待练习';
    if (node.mastery === null) return '可开始 · 尚未练习';
    if (node.mastery.mastered) return '已掌握 · ' + Math.round(node.mastery.accuracy * 100).toString() + '%';
    return '学习中 · ' + Math.round(node.mastery.accuracy * 100).toString() + '%';
  }

  private masteredCount(): number {
    return this.nodes.filter((node: MapNode): boolean => node.mastery?.mastered === true).length;
  }

  private nextTopicLabel(): string {
    const next = this.findRecommendedNode(this.nodes);
    return next?.topic ?? '本课程已全部点亮';
  }

  private findRecommendedNode(nodes: MapNode[]): MapNode | null {
    const openNodes = nodes.filter((node: MapNode): boolean => node.mastery?.mastered !== true && node.unlocked);
    if (openNodes.length === 0) return null;
    return openNodes.sort((left: MapNode, right: MapNode): number => {
      const leftPracticed = left.mastery !== null ? 1 : 0;
      const rightPracticed = right.mastery !== null ? 1 : 0;
      if (leftPracticed !== rightPracticed) return rightPracticed - leftPracticed;
      if (left.level !== right.level) return left.level - right.level;
      const accuracyDelta = (left.mastery?.accuracy ?? 0) - (right.mastery?.accuracy ?? 0);
      if (Math.abs(accuracyDelta) > 0.001) return accuracyDelta;
      return left.order - right.order;
    })[0];
  }

  private isUnlocked(node: MapNode, nodes: MapNode[]): boolean {
    if (node.prerequisiteIds.length === 0) return true;
    for (const prerequisiteId of node.prerequisiteIds) {
      const source = nodes.find((item: MapNode): boolean => item.id === prerequisiteId);
      if (source?.mastery?.mastered !== true) return false;
    }
    return true;
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

  private unlockedAfterLabel(node: MapNode): string {
    const topics = this.nodes.filter((item: MapNode): boolean => item.prerequisiteIds.includes(node.id))
      .map((item: MapNode): string => item.topic);
    if (topics.length === 0) return '后续：本课程终点主题';
    return '解锁后续：' + topics.join(' · ');
  }

  private recommendationLabel(node: MapNode): string {
    if (node.recommended) {
      if (node.mastery !== null && !node.mastery.mastered) return '推荐原因：已练习但未达 80%，优先巩固';
      if (node.lessonCompleted) return '推荐原因：已完成学习内容，下一步做精选练习';
      if (node.prerequisiteIds.length === 0) return '推荐原因：课程起点，适合立即开始';
      return '推荐原因：先修主题已掌握，进入下一节点';
    }
    if (!node.unlocked) return '暂未解锁：先完成前置主题并达到掌握';
    if (node.mastery?.mastered === true) return '已掌握：可作为后续节点的先修支撑';
    return '可学习：按当前节奏安排到后续练习';
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
        .width(this.canvasWidth)
        .height(this.canvasHeight)
        .backgroundColor(Constants.COLOR_MAP_SURFACE)
        .borderRadius(Constants.RADIUS_LG)
      Column()
        .width(210)
        .height(170)
        .backgroundColor(Constants.COLOR_BRAND)
        .borderRadius(105)
        .opacity(0.10)
        .position({ x: 28, y: 28 })
      Column()
        .width(190)
        .height(220)
        .backgroundColor(Constants.COLOR_MAP_LINE_ACTIVE)
        .borderRadius(95)
        .opacity(0.08)
        .position({ x: 116, y: Math.max(160, Math.floor(this.canvasHeight * 0.36)) })
      Column()
        .width(120)
        .height(120)
        .backgroundColor(Constants.COLOR_SUCCESS)
        .borderRadius(60)
        .opacity(0.06)
        .position({ x: 22, y: Math.max(280, this.canvasHeight - 156) })

      ForEach(NEBULA_STARS, (star: NebulaStar): void => {
        Column()
          .width(star.size)
          .height(star.size)
          .backgroundColor(Constants.COLOR_MAP_STAR)
          .borderRadius(star.size / 2)
          .opacity(star.opacity)
          .position({ x: star.x, y: Math.min(star.y, this.canvasHeight - 18) })
      })

      ForEach(this.levelRows, (level: number): void => {
        Text('Level ' + level.toString())
          .fontSize(9)
          .fontColor(Constants.COLOR_MAP_TEXT_MUTED)
          .position({ x: 12, y: 34 + level * LEVEL_GAP })
        Line()
          .width(this.canvasWidth - 40)
          .height(1)
          .startPoint([0, 0])
          .endPoint([this.canvasWidth - 40, 0])
          .stroke(Constants.COLOR_MAP_LINE)
          .strokeWidth(0.5)
          .opacity(0.7)
          .position({ x: 26, y: 50 + level * LEVEL_GAP })
      })

      ForEach(this.edges, (edge: MapEdge): void => {
        Line()
          .width(this.canvasWidth)
          .height(this.canvasHeight)
          .startPoint([edge.fromX, edge.fromY])
          .endPoint([edge.toX, edge.toY])
          .stroke(edge.active ? Constants.COLOR_MAP_LINE_ACTIVE : Constants.COLOR_MAP_LINE)
          .strokeWidth(edge.active ? 2.2 : 1)
          .opacity(edge.active ? 0.86 : 0.52)
      })

      ForEach(this.nodes, (node: MapNode): void => {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(this.nodeSize(node) + 18)
            .height(this.nodeSize(node) + 18)
            .backgroundColor(this.nodeColor(node))
            .borderRadius((this.nodeSize(node) + 18) / 2)
            .opacity(this.selectedTopic === node.topic ? 0.28 : node.mastery === null ? 0.12 : 0.20)
          Column()
            .width(this.nodeSize(node) + 8)
            .height(this.nodeSize(node) + 8)
            .backgroundColor(Constants.COLOR_MAP_SURFACE)
            .border({
              width: this.selectedTopic === node.topic ? 2 : 1,
              color: this.selectedTopic === node.topic ? Constants.COLOR_MAP_CORE : Constants.COLOR_MAP_LINE
            })
            .borderRadius((this.nodeSize(node) + 8) / 2)
            .opacity(0.92)
          Column()
            .width(node.mastery === null ? 28 : 32)
            .height(node.mastery === null ? 28 : 32)
            .backgroundColor(this.nodeColor(node))
            .borderRadius(node.mastery === null ? 14 : 16)
            .border({
              width: 1,
              color: this.selectedTopic === node.topic ? Constants.COLOR_MAP_CORE : Constants.COLOR_MAP_SURFACE
            })
            .shadow(node.mastery === null ? undefined :
              { radius: 8, color: this.nodeColor(node), offsetX: 0, offsetY: 0 })
          Text((node.order < 10 ? '0' : '') + node.order.toString())
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
          if (this.selectedTopic === node.topic || node.recommended) {
            Text(node.topic)
              .width(NODE_WIDTH)
              .fontSize(node.topic.length > 7 ? 9 : 10)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_MAP_CORE)
              .textAlign(TextAlign.Center)
              .maxLines(2)
              .wordBreak(WordBreak.BREAK_ALL)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: 4, right: 4, top: 3, bottom: 3 })
              .backgroundColor(Constants.COLOR_MAP_LINE)
              .borderRadius(8)
              .position({ x: 0, y: 43 })
          }
        }
        .width(NODE_WIDTH)
        .height(72)
        .position({ x: node.x, y: node.y })
        .opacity(node.unlocked ? 1 : 0.58)
        .scale({ x: this.selectedTopic === node.topic ? 1.08 : (node.recommended ? 1.04 : 1),
          y: this.selectedTopic === node.topic ? 1.08 : (node.recommended ? 1.04 : 1) })
        .animation({ duration: Constants.ANIM_FAST, curve: Curve.EaseOut })
        .onClick((): void => { this.selectedTopic = node.topic; })
      })
    }
    .width(this.canvasWidth)
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
        Text('当前推荐：' + this.nextTopicLabel())
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
            Scroll() {
              this.MapCanvas()
            }
            .width('100%')
            .height(this.canvasHeight)
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
          }

          Row({ space: 18 }) {
            Row({ space: 6 }) {
              Column().width(9).height(9).backgroundColor(Constants.COLOR_MAP_NODE_IDLE).borderRadius(5)
              Text('可开始').fontSize(11).fontColor(Constants.COLOR_TEXT_SECONDARY)
            }
            Row({ space: 6 }) {
              Column().width(9).height(9).backgroundColor(Constants.COLOR_BRAND).borderRadius(5)
              Text('已学习').fontSize(11).fontColor(Constants.COLOR_TEXT_SECONDARY)
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
                  Text(this.unlockedAfterLabel(node))
                    .width('100%')
                    .fontSize(12)
                    .lineHeight(19)
                    .fontColor(Constants.COLOR_TEXT_TERTIARY)
                  Text(this.recommendationLabel(node))
                    .width('100%')
                    .fontSize(12)
                    .lineHeight(19)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(node.recommended ? Constants.COLOR_BRAND : Constants.COLOR_TEXT_TERTIARY)
                  if (!node.unlocked) {
                    Text('完成前置主题并达到 80% 正确率后，该节点会进入推荐路径')
                      .width('100%')
                      .fontSize(11)
                      .lineHeight(18)
                      .fontColor(Constants.COLOR_TEXT_SECONDARY)
                  }
                  Row({ space: 10 }) {
                    Button({ type: ButtonType.Normal }) {
                      Text('学习主题').fontSize(14).fontColor(node.unlocked ? Constants.COLOR_TEXT_ON_GRADIENT :
                        Constants.COLOR_BUTTON_DISABLED_TEXT)
                    }
                      .layoutWeight(1)
                      .height(48)
                      .enabled(node.unlocked)
                      .backgroundColor(node.unlocked ? Constants.COLOR_BRAND : Constants.COLOR_BUTTON_DISABLED_BG)
                      .borderRadius(Constants.RADIUS_MD)
                      .onClick((): void => { this.openLesson(this.selectedTopic); })
                    Button({ type: ButtonType.Normal }) {
                      Text('主题练习').fontSize(14).fontColor(node.unlocked ? Constants.COLOR_BRAND :
                        Constants.COLOR_BUTTON_DISABLED_TEXT)
                    }
                      .layoutWeight(1)
                      .height(48)
                      .enabled(node.unlocked)
                      .backgroundColor(node.unlocked ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BUTTON_DISABLED_BG)
                      .borderRadius(Constants.RADIUS_MD)
                      .onClick((): void => { this.openPractice(this.selectedTopic); })
                  }
                  .width('100%')
                })
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
