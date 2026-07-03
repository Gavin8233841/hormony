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
  fromId: string;
  toId: string;
  fromX: number;
  fromY: number;
  toX: number;
  toY: number;
  arrowX: number;
  arrowY: number;
  arrowLeftX: number;
  arrowLeftY: number;
  arrowRightX: number;
  arrowRightY: number;
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
        const fromX = source.x + NODE_WIDTH / 2;
        const fromY = source.y + 22;
        const toX = node.x + NODE_WIDTH / 2;
        const toY = node.y + 22;
        const dx = toX - fromX;
        const dy = toY - fromY;
        const distance = Math.max(Math.sqrt(dx * dx + dy * dy), 1);
        const unitX = dx / distance;
        const unitY = dy / distance;
        const arrowX = fromX + dx * 0.72;
        const arrowY = fromY + dy * 0.72;
        const perpendicularX = -unitY;
        const perpendicularY = unitX;
        const arrowSize = 8;
        nextEdges.push({
          fromId: source.id,
          toId: node.id,
          fromX: fromX,
          fromY: fromY,
          toX: toX,
          toY: toY,
          arrowX: arrowX,
          arrowY: arrowY,
          arrowLeftX: arrowX - unitX * arrowSize + perpendicularX * 4,
          arrowLeftY: arrowY - unitY * arrowSize + perpendicularY * 4,
          arrowRightX: arrowX - unitX * arrowSize - perpendicularX * 4,
          arrowRightY: arrowY - unitY * arrowSize - perpendicularY * 4,
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

  private selectedNode(): MapNode | null {
    return this.nodes.find((node: MapNode): boolean => node.topic === this.selectedTopic) ?? null;
  }

  private isPrerequisiteOfSelected(node: MapNode): boolean {
    const selected = this.selectedNode();
    if (selected === null) return false;
    return selected.prerequisiteIds.includes(node.id);
  }

  private isSuccessorOfSelected(node: MapNode): boolean {
    const selected = this.selectedNode();
    if (selected === null) return false;
    return node.prerequisiteIds.includes(selected.id);
  }

  private isFocusedNode(node: MapNode): boolean {
    if (this.selectedTopic.length === 0) return true;
    return node.topic === this.selectedTopic || this.isPrerequisiteOfSelected(node) || this.isSuccessorOfSelected(node);
  }

  private isFocusedEdge(edge: MapEdge): boolean {
    const selected = this.selectedNode();
    if (selected === null) return true;
    return edge.fromId === selected.id || edge.toId === selected.id;
  }

  private edgeColor(edge: MapEdge): ResourceColor {
    return this.isFocusedEdge(edge) ? Constants.COLOR_MAP_LINE_ACTIVE :
      (edge.active ? Constants.COLOR_MAP_LINE_ACTIVE : Constants.COLOR_MAP_LINE);
  }

  private edgeWidth(edge: MapEdge): number {
    if (this.isFocusedEdge(edge)) return 2.4;
    return edge.active ? 1.4 : 0.8;
  }

  private edgeOpacity(edge: MapEdge): number {
    if (this.selectedTopic.length === 0) return edge.active ? 0.82 : 0.48;
    return this.isFocusedEdge(edge) ? 0.92 : 0.16;
  }

  private nodeOuterOpacity(node: MapNode): number {
    if (node.topic === this.selectedTopic) return 0.32;
    if (this.isPrerequisiteOfSelected(node) || this.isSuccessorOfSelected(node)) return 0.22;
    return node.mastery === null ? 0.10 : 0.18;
  }

  private nodeRelationLabel(node: MapNode): string {
    if (node.topic === this.selectedTopic) return '当前';
    if (this.isPrerequisiteOfSelected(node)) return '前置';
    if (this.isSuccessorOfSelected(node)) return '后继';
    return '';
  }

  private masteredCount(): number {
    return this.nodes.filter((node: MapNode): boolean => node.mastery?.mastered === true).length;
  }

  private nextTopicLabel(): string {
    const next = this.nodes.find((node: MapNode): boolean => node.mastery?.mastered !== true);
    return next?.topic ?? '本课程已全部点亮';
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

  private topicListLabel(topics: string[], emptyText: string): string {
    return topics.length > 0 ? topics.join(' · ') : emptyText;
  }

  private prerequisiteTopics(node: MapNode): string[] {
    const topics: string[] = [];
    for (const id of node.prerequisiteIds) {
      const prerequisite = this.nodes.find((item: MapNode): boolean => item.id === id);
      if (prerequisite !== undefined) topics.push(prerequisite.topic);
    }
    return topics;
  }

  private successorTopics(node: MapNode): string[] {
    return this.nodes
      .filter((item: MapNode): boolean => item.prerequisiteIds.includes(node.id))
      .map((item: MapNode): string => item.topic);
  }

  private prerequisiteProgress(node: MapNode): string {
    const prerequisites = this.nodes.filter((item: MapNode): boolean => node.prerequisiteIds.includes(item.id));
    if (prerequisites.length === 0) return '课程起点';
    const mastered = prerequisites.filter((item: MapNode): boolean => item.mastery?.mastered === true).length;
    return '前置 ' + mastered.toString() + '/' + prerequisites.length.toString() + ' 已掌握';
  }

  private masteryEvidence(node: MapNode): string {
    if (node.mastery === null) return '暂无练习记录，先学主题再做精选练习。';
    return '练习 ' + node.mastery.attempts.toString() + ' 次 · ' + node.mastery.correctQuestions.toString() +
      '/' + node.mastery.totalQuestions.toString() + ' 题正确';
  }

  private nextAction(node: MapNode): string {
    const unfinishedPrerequisite = this.nodes.find((item: MapNode): boolean =>
      node.prerequisiteIds.includes(item.id) && item.mastery?.mastered !== true);
    if (unfinishedPrerequisite !== undefined) {
      return '下一步：先补前置主题《' + unfinishedPrerequisite.topic + '》';
    }
    if (node.mastery === null) return '下一步：学习主题后完成一组精选练习';
    if (!node.mastery.mastered) return '下一步：复盘错题，再做主题练习';
    const successor = this.successorTopics(node)[0];
    return successor !== undefined ? '下一步：进入后继主题《' + successor + '》' : '下一步：回到课程继续综合复盘';
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
          .width(MAP_WIDTH - 40)
          .height(1)
          .startPoint([0, 0])
          .endPoint([MAP_WIDTH - 40, 0])
          .stroke(Constants.COLOR_MAP_LINE)
          .strokeWidth(0.5)
          .opacity(0.7)
          .position({ x: 26, y: 50 + level * LEVEL_GAP })
      })

      ForEach(this.edges, (edge: MapEdge): void => {
        Line()
          .width(MAP_WIDTH)
          .height(this.canvasHeight)
          .startPoint([edge.fromX, edge.fromY])
          .endPoint([edge.toX, edge.toY])
          .stroke(this.edgeColor(edge))
          .strokeWidth(this.edgeWidth(edge))
          .opacity(this.edgeOpacity(edge))
        Line()
          .width(MAP_WIDTH)
          .height(this.canvasHeight)
          .startPoint([edge.arrowLeftX, edge.arrowLeftY])
          .endPoint([edge.arrowX, edge.arrowY])
          .stroke(this.edgeColor(edge))
          .strokeWidth(this.edgeWidth(edge))
          .opacity(this.edgeOpacity(edge))
        Line()
          .width(MAP_WIDTH)
          .height(this.canvasHeight)
          .startPoint([edge.arrowRightX, edge.arrowRightY])
          .endPoint([edge.arrowX, edge.arrowY])
          .stroke(this.edgeColor(edge))
          .strokeWidth(this.edgeWidth(edge))
          .opacity(this.edgeOpacity(edge))
      })

      ForEach(this.nodes, (node: MapNode): void => {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(this.nodeSize(node) + 18)
            .height(this.nodeSize(node) + 18)
            .backgroundColor(this.nodeColor(node))
            .borderRadius((this.nodeSize(node) + 18) / 2)
            .opacity(this.nodeOuterOpacity(node))
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
          if (this.nodeRelationLabel(node).length > 0 && this.selectedTopic !== node.topic) {
            Text(this.nodeRelationLabel(node))
              .fontSize(8)
              .fontWeight(FontWeight.Medium)
              .fontColor(Constants.COLOR_MAP_CORE)
              .padding({ left: 5, right: 5, top: 2, bottom: 2 })
              .backgroundColor(Constants.COLOR_MAP_LINE)
              .borderRadius(6)
              .position({ x: 18, y: 47 })
          }
          if (this.selectedTopic === node.topic) {
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
        .opacity(this.isFocusedNode(node) ? 1 : 0.36)
        .scale({
          x: this.selectedTopic === node.topic ? 1.10 : (this.isFocusedNode(node) ? 1.03 : 0.96),
          y: this.selectedTopic === node.topic ? 1.10 : (this.isFocusedNode(node) ? 1.03 : 0.96)
        })
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
        Row({ space: 6 }) {
          Image($rawfile('icons/fluent_branch_24_regular.svg'))
            .width(14)
            .height(14)
            .fillColor(Constants.COLOR_TEXT_TERTIARY)
          Text('下一节点：' + this.nextTopicLabel())
            .fontSize(11)
            .fontColor(Constants.COLOR_TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
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
            Row({ space: 6 }) {
              Line()
                .width(18)
                .height(1)
                .startPoint([0, 0])
                .endPoint([18, 0])
                .stroke(Constants.COLOR_MAP_LINE_ACTIVE)
                .strokeWidth(2)
              Text('箭头表示先修方向').fontSize(11).fontColor(Constants.COLOR_TEXT_SECONDARY)
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
                  Text(this.masteryEvidence(node))
                    .width('100%')
                    .fontSize(12)
                    .lineHeight(19)
                    .fontColor(Constants.COLOR_TEXT_TERTIARY)
                  Row({ space: 8 }) {
                    Text(this.prerequisiteProgress(node))
                      .fontSize(11)
                      .fontColor(Constants.COLOR_BRAND)
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                      .borderRadius(Constants.RADIUS_SM)
                    Text('大小=练习次数')
                      .fontSize(11)
                      .fontColor(Constants.COLOR_TEXT_SECONDARY)
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor(Constants.COLOR_BG_TAG)
                      .borderRadius(Constants.RADIUS_SM)
                  }
                  .width('100%')
                  Text(this.nextAction(node))
                    .width('100%')
                    .fontSize(12)
                    .lineHeight(19)
                    .fontColor(Constants.COLOR_TEXT_PRIMARY)
                  Column({ space: 8 }) {
                    Row({ space: 8 }) {
                      Text('前置')
                        .fontSize(11)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Constants.COLOR_BRAND)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                        .borderRadius(Constants.RADIUS_SM)
                      Text(this.topicListLabel(this.prerequisiteTopics(node), '无前置主题'))
                        .layoutWeight(1)
                        .fontSize(12)
                        .fontColor(Constants.COLOR_TEXT_SECONDARY)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .width('100%')
                    Row({ space: 8 }) {
                      Text('后继')
                        .fontSize(11)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Constants.COLOR_SUCCESS)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .backgroundColor(Constants.COLOR_SUCCESS_LIGHT)
                        .borderRadius(Constants.RADIUS_SM)
                      Text(this.topicListLabel(this.successorTopics(node), '暂无直接后继'))
                        .layoutWeight(1)
                        .fontSize(12)
                        .fontColor(Constants.COLOR_TEXT_SECONDARY)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .width('100%')
                  }
                  .width('100%')
                  .padding(10)
                  .backgroundColor(Constants.COLOR_SURFACE_TINT)
                  .borderRadius(Constants.RADIUS_MD)
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
