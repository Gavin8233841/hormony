import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
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
  @State canvasWidth: number = MAP_WIDTH;
  @State canvasHeight: number = 420;
  @State selectedTopic: string = '';
  @State relationDetailsExpanded: boolean = false;
  @State loading: boolean = true;
  @State message: string = '';
  @State mapLoadFailed: boolean = false;
  @State failedCourseId: string = '';
  private requestVersion: number = 0;
  private pageScroller: Scroller = new Scroller();

  onPageShow(): void {
    this.loadMap();
  }

  private async loadMap(): Promise<void> {
    const requestVersion = ++this.requestVersion;
    this.loading = true;
    this.message = '';
    this.mapLoadFailed = false;
    this.failedCourseId = '';
    try {
      const courses = await LocalLearningRepository.getCourses() ?? [];
      if (requestVersion !== this.requestVersion) return;
      this.courses = courses;
      const storedCourse = AppStorage.get<string>('selectedCourseId') ?? '';
      const selected = courses.find((course: Course): boolean => course.id === storedCourse) ?? courses[0];
      if (selected !== undefined) {
        await this.loadCourseSnapshot(selected, requestVersion);
      } else {
        this.clearMapSnapshot();
      }
    } catch (error) {
      if (requestVersion === this.requestVersion) {
        this.clearMapSnapshot();
        this.message = '本地学习星图加载失败，请重新读取';
        this.mapLoadFailed = true;
        this.failedCourseId = '';
      }
    } finally {
      if (requestVersion === this.requestVersion) this.loading = false;
    }
  }

  private async selectCourse(course: Course): Promise<void> {
    const requestVersion = ++this.requestVersion;
    this.loading = true;
    this.message = '';
    this.mapLoadFailed = false;
    this.failedCourseId = '';
    try {
      await this.loadCourseSnapshot(course, requestVersion);
    } catch (error) {
      if (requestVersion === this.requestVersion) {
        this.message = course.title + '的学习星图读取失败，请重试';
        this.mapLoadFailed = true;
        this.failedCourseId = course.id;
      }
    } finally {
      if (requestVersion === this.requestVersion) this.loading = false;
    }
  }

  private async loadCourseSnapshot(course: Course, requestVersion: number): Promise<void> {
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
          active: source.mastery?.mastered === true
        });
      }
    }
    if (requestVersion !== this.requestVersion) return;
    AppStorage.setOrCreate<string>('selectedCourseId', course.id);
    AppStorage.setOrCreate<string>('selectedCourseTitle', course.title);
    this.selectedCourseId = course.id;
    this.selectedCourseTitle = course.title;
    this.nodes = nextNodes;
    this.selectedTopic = recommended?.topic ?? nextNodes[0]?.topic ?? '';
    this.relationDetailsExpanded = false;
    this.edges = nextEdges;
    this.levelRows = levels.sort((left: number, right: number): number => left - right);
    this.canvasWidth = calculatedWidth;
    this.canvasHeight = Math.max(420, 30 + maxLevel * LEVEL_GAP + 92);
    this.message = '';
    this.mapLoadFailed = false;
    this.failedCourseId = '';
  }

  private clearMapSnapshot(): void {
    this.nodes = [];
    this.edges = [];
    this.levelRows = [];
    this.selectedTopic = '';
    this.canvasWidth = MAP_WIDTH;
    this.canvasHeight = 420;
  }

  private retryMapLoad(): void {
    const failedCourse = this.courses.find((course: Course): boolean => course.id === this.failedCourseId);
    if (failedCourse !== undefined) this.selectCourse(failedCourse);
    else this.loadMap();
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
    if (node.mastery !== null && node.mastery.mastered) {
      const accuracy = Math.round(node.mastery.accuracy * 100).toString() + '%';
      return node.unlocked ? '已掌握 · ' + accuracy : '已掌握 · ' + accuracy + ' · 先修待巩固';
    }
    if (node.mastery !== null && !node.unlocked) {
      return '已练习 · ' + Math.round(node.mastery.accuracy * 100).toString() + '% · 先修待巩固';
    }
    if (!node.unlocked) return '先学前置主题';
    if (node.mastery === null && node.lessonCompleted) return '已学习 · 待练习';
    if (node.mastery === null) return '可开始 · 尚未练习';
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

  private selectedNode(): MapNode | null {
    return this.nodes.find((node: MapNode): boolean => node.topic === this.selectedTopic) ?? null;
  }

  private isPrerequisiteOfSelected(node: MapNode): boolean {
    const selected = this.selectedNode();
    return selected !== null && selected.prerequisiteIds.includes(node.id);
  }

  private isSuccessorOfSelected(node: MapNode): boolean {
    const selected = this.selectedNode();
    return selected !== null && node.prerequisiteIds.includes(selected.id);
  }

  private isFocusedNode(node: MapNode): boolean {
    if (this.selectedTopic.length === 0) return true;
    return node.topic === this.selectedTopic || this.isPrerequisiteOfSelected(node) || this.isSuccessorOfSelected(node);
  }

  private isFocusedEdge(edge: MapEdge): boolean {
    const selected = this.selectedNode();
    return selected === null || edge.fromId === selected.id || edge.toId === selected.id;
  }

  private nodeOpacity(node: MapNode): number {
    if (!this.isFocusedNode(node)) return 0.70;
    return (node.mastery?.mastered === true || node.unlocked) ? 1 : 0.78;
  }

  private nodeOuterOpacity(node: MapNode): number {
    if (node.topic === this.selectedTopic) return 0.34;
    if (!this.isFocusedNode(node)) return 0.05;
    return node.mastery === null ? 0.14 : 0.22;
  }

  private nodeRelationLabel(node: MapNode): string {
    if (this.isPrerequisiteOfSelected(node)) return '前置';
    if (this.isSuccessorOfSelected(node)) return '后继';
    return '';
  }

  private edgeColor(edge: MapEdge): ResourceColor {
    const selected = this.selectedNode();
    if (selected !== null && edge.toId === selected.id) return Constants.COLOR_WARNING;
    if (selected !== null && edge.fromId === selected.id) return Constants.COLOR_MAP_LINE_ACTIVE;
    return edge.active ? Constants.COLOR_MAP_LINE_ACTIVE : Constants.COLOR_MAP_LINE;
  }

  private edgeWidth(edge: MapEdge): number {
    if (this.isFocusedEdge(edge)) return edge.active ? 2.6 : 1.8;
    return edge.active ? 1.2 : 0.8;
  }

  private edgeOpacity(edge: MapEdge): number {
    if (this.isFocusedEdge(edge)) return edge.active ? 0.92 : 0.72;
    return 0.14;
  }

  private firstIncompletePrerequisite(node: MapNode): MapNode | null {
    for (const prerequisiteId of node.prerequisiteIds) {
      const prerequisite = this.nodes.find((item: MapNode): boolean => item.id === prerequisiteId);
      if (prerequisite !== undefined && prerequisite.mastery?.mastered !== true) return prerequisite;
    }
    return null;
  }

  private firstActionablePrerequisite(node: MapNode): MapNode | null {
    let target = this.firstIncompletePrerequisite(node);
    const visitedIds: string[] = [];
    while (target !== null && !target.unlocked && !visitedIds.includes(target.id)) {
      visitedIds.push(target.id);
      const earlier = this.firstIncompletePrerequisite(target);
      if (earlier === null) return null;
      target = earlier;
    }
    return target !== null && target.unlocked ? target : null;
  }

  private reachableSuccessors(node: MapNode): MapNode[] {
    const successors: MapNode[] = [];
    const pendingIds: string[] = [node.id];
    let pendingIndex = 0;
    while (pendingIndex < pendingIds.length) {
      const sourceId = pendingIds[pendingIndex];
      pendingIndex += 1;
      for (const item of this.nodes) {
        if (!item.prerequisiteIds.includes(sourceId) ||
          successors.some((value: MapNode): boolean => value.id === item.id)) continue;
        successors.push(item);
        pendingIds.push(item.id);
      }
    }
    return successors;
  }

  private recommendedReachableAction(node: MapNode): MapNode | null {
    const successors = this.reachableSuccessors(node);
    const successor = this.findRecommendedNode(successors);
    if (successor !== null) return successor;
    const prerequisiteTargets: MapNode[] = [];
    for (const item of successors) {
      if (item.mastery?.mastered === true) continue;
      const target = this.firstActionablePrerequisite(item);
      if (target !== null &&
        !prerequisiteTargets.some((value: MapNode): boolean => value.id === target.id)) {
        prerequisiteTargets.push(target);
      }
    }
    return this.findRecommendedNode(prerequisiteTargets);
  }

  private isReachableSuccessor(node: MapNode, target: MapNode): boolean {
    return this.reachableSuccessors(node).some((item: MapNode): boolean => item.id === target.id);
  }

  private nextActionTarget(node: MapNode): MapNode | null {
    if (node.mastery?.mastered === true) {
      return this.recommendedReachableAction(node) ?? node;
    }
    if (!node.unlocked) return this.firstActionablePrerequisite(node);
    return node;
  }

  private nextActionUsesPractice(node: MapNode): boolean {
    const target = this.nextActionTarget(node);
    return target !== null && (target.lessonCompleted || target.mastery !== null);
  }

  private nextActionLabel(node: MapNode): string {
    const target = this.nextActionTarget(node);
    if (target === null) return '暂时无法继续';
    return (this.nextActionUsesPractice(node) ? '练习 ' : '学习 ') + target.topic;
  }

  private nextActionDescription(node: MapNode): string {
    const target = this.nextActionTarget(node);
    if (target === null) return '暂时没有可继续的课程';
    if (target.id !== node.id) {
      const action = this.nextActionUsesPractice(node) ? '练习' : '学习';
      return this.isReachableSuccessor(node, target) ? '接着' + action + ' ' + target.topic :
        '先' + action + ' ' + target.topic;
    }
    if (node.mastery?.mastered === true) return '可以复习，也可以继续下一主题';
    if (node.mastery !== null) return '继续练习这个主题';
    if (node.lessonCompleted) return '学过了，做几道题巩固一下';
    return '从这个主题开始学';
  }

  private runNextAction(node: MapNode): void {
    const target = this.nextActionTarget(node);
    if (target === null) {
      this.message = '暂时没有可继续的课程';
      return;
    }
    if (this.nextActionUsesPractice(node)) this.openPractice(target.topic);
    else this.openLesson(target.topic);
  }

  private nodeAccessibilityText(node: MapNode): string {
    const selected = this.selectedTopic === node.topic ? '，已选择' : '';
    const recommended = node.recommended ? '，当前推荐' : '';
    return node.topic + '，' + this.masteryLabel(node) + recommended + selected;
  }

  private actionAccessibilityText(node: MapNode): string {
    const target = this.nextActionTarget(node);
    return target === null ? this.nextActionLabel(node) : this.nextActionLabel(node) + '，' + target.topic;
  }

  private openPractice(topic: string): void {
    this.message = '';
    this.mapLoadFailed = false;
    this.failedCourseId = '';
    AppStorage.setOrCreate<string>('selectedCourseId', this.selectedCourseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.selectedCourseTitle);
    AppStorage.setOrCreate<string>('selectedPracticeTopic', topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Practice' }).catch((error: Error): void => {
      this.message = '精选练习打开失败，请重试';
      hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
        'LearningMapPage Practice navigation failed: %{public}s', error.message);
    });
  }

  private openLesson(topic: string): void {
    this.message = '';
    this.mapLoadFailed = false;
    this.failedCourseId = '';
    AppStorage.setOrCreate<string>('selectedCourseId', this.selectedCourseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', this.selectedCourseTitle);
    AppStorage.setOrCreate<string>('selectedContentTopic', topic);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Lesson' }).catch((error: Error): void => {
      this.message = '课程内容打开失败，请重试';
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
          .constraintSize({ minHeight: 48 })
          .fontSize(12)
          .fontColor(this.selectedCourseId === course.id ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_SECONDARY)
          .backgroundColor(this.selectedCourseId === course.id ? Constants.COLOR_BRAND : Constants.COLOR_BG_TAG)
          .borderRadius(Constants.RADIUS_MD)
          .onClick((): void => { this.selectCourse(course); })
          .accessibilityText(course.title + (this.selectedCourseId === course.id ? '，已选择' : '，未选择'))
          .accessibilityDescription('切换课程，查看主题和学习进度')
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

      ForEach(this.levelRows, (level: number): void => {
        Text('第 ' + (level + 1).toString() + ' 层')
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
          .stroke(this.edgeColor(edge))
          .strokeWidth(this.edgeWidth(edge))
          .opacity(this.edgeOpacity(edge))
        Line()
          .width(this.canvasWidth)
          .height(this.canvasHeight)
          .startPoint([edge.arrowLeftX, edge.arrowLeftY])
          .endPoint([edge.arrowX, edge.arrowY])
          .stroke(this.edgeColor(edge))
          .strokeWidth(this.edgeWidth(edge))
          .opacity(this.edgeOpacity(edge))
        Line()
          .width(this.canvasWidth)
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
          if (this.nodeRelationLabel(node).length > 0) {
            Text(this.nodeRelationLabel(node))
              .fontSize(8)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_MAP_CORE)
              .padding({ left: 5, right: 5, top: 2, bottom: 2 })
              .backgroundColor(Constants.COLOR_MAP_LINE)
              .borderRadius(6)
              .position({ x: 18, y: -2 })
          }
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
        .width(NODE_WIDTH)
        .height(72)
        .position({ x: node.x, y: node.y })
        .opacity(this.nodeOpacity(node))
        .scale({ x: this.selectedTopic === node.topic ? 1.10 : (this.isFocusedNode(node) ? 1 : 0.94),
          y: this.selectedTopic === node.topic ? 1.10 : (this.isFocusedNode(node) ? 1 : 0.94) })
        .animation({ duration: Constants.ANIM_FAST, curve: Curve.EaseOut })
        .onClick((): void => {
          this.selectedTopic = node.topic;
          this.relationDetailsExpanded = false;
          this.pageScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
        })
        .accessibilityGroup(true)
        .accessibilityText(this.nodeAccessibilityText(node))
        .accessibilityDescription('选择后查看主题状态和练习入口')
      })
    }
    .width(this.canvasWidth)
    .height(this.canvasHeight)
  }

  @Builder
  SelectedTopicCard() {
    ForEach(this.nodes.filter((node: MapNode): boolean => node.topic === this.selectedTopic),
      (node: MapNode): void => {
        Column({ space: 10 }) {
          Row() {
            Column({ space: 4 }) {
              Text(node.topic)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Constants.COLOR_TEXT_PRIMARY)
              Text(this.masteryLabel(node))
                .fontSize(12)
                .fontColor(Constants.COLOR_TEXT_SECONDARY)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            if (node.recommended) {
              Text('推荐')
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(Constants.COLOR_BRAND)
                .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                .borderRadius(Constants.RADIUS_SM)
            }
          }
          .width('100%')
          Button(this.nextActionLabel(node))
            .width('100%')
            .constraintSize({ minHeight: 48 })
            .enabled(this.nextActionTarget(node) !== null)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.nextActionTarget(node) !== null ? Constants.COLOR_TEXT_ON_GRADIENT :
              Constants.COLOR_BUTTON_DISABLED_TEXT)
            .backgroundColor(this.nextActionTarget(node) !== null ? Constants.COLOR_BRAND :
              Constants.COLOR_BUTTON_DISABLED_BG)
            .borderRadius(Constants.RADIUS_MD)
            .onClick((): void => { this.runNextAction(node); })
            .accessibilityText(this.actionAccessibilityText(node))
            .accessibilityDescription(this.nextActionDescription(node))
          Text(this.relationDetailsExpanded ? '收起关系' : '查看前后关系')
            .width('100%')
            .fontSize(12)
            .fontColor(Constants.COLOR_BRAND)
            .onClick((): void => { this.relationDetailsExpanded = !this.relationDetailsExpanded; })
          if (this.relationDetailsExpanded) {
            Text(this.prerequisiteLabel(node))
              .width('100%')
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
            Text(this.unlockedAfterLabel(node))
              .width('100%')
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
          }
          if (this.message.length > 0 && !this.mapLoadFailed) {
            Text(this.message)
              .width('100%')
              .fontSize(12)
              .fontColor(Constants.COLOR_ERROR)
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Constants.COLOR_BG_CARD)
        .borderRadius(Constants.RADIUS_LG)
      })
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
    .padding({ left: 4, right: 4, top: 4, bottom: 4 })
    .accessibilityGroup(true)
    .accessibilityText(this.selectedCourseTitle + '学习星图，已掌握' + this.masteredCount().toString() +
      '个，共' + this.nodes.length.toString() + '个主题，当前推荐' + this.nextTopicLabel())
    .accessibilityDescription('显示这门课的主题和已保存的学习进度')
  }

  build() {
    Column() {
      TitleBar('学习星图', '看看主题之间的联系', () => this.getUIContext().getRouter().back())

      Scroll(this.pageScroller) {
        Column({ space: 16 }) {
          if (this.courses.length > 0) {
            this.CourseSelector()
          }

          if (!this.loading && this.mapLoadFailed && this.nodes.length > 0) {
            Column({ space: 10 }) {
              Text(this.message)
                .width('100%')
                .fontSize(13)
                .lineHeight(20)
                .fontColor(Constants.COLOR_ERROR)
              Button('重新读取失败课程')
                .width('100%')
                .constraintSize({ minHeight: 48 })
                .fontSize(14)
                .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                .backgroundColor(Constants.COLOR_ERROR)
                .borderRadius(Constants.RADIUS_MD)
                .onClick((): void => { this.retryMapLoad(); })
                .accessibilityText('重新读取失败课程的学习星图')
            }
            .width('100%')
            .padding(14)
            .backgroundColor(Constants.COLOR_ERROR_LIGHT)
            .borderRadius(Constants.RADIUS_MD)
          }

          if (this.loading) {
            Column()
              .width(MAP_WIDTH)
              .height(420)
              .backgroundColor(Constants.COLOR_BG_SKELETON)
              .borderRadius(Constants.RADIUS_LG)
              .accessibilityGroup(true)
              .accessibilityText('正在加载学习星图')
          } else if (this.nodes.length === 0) {
            Column({ space: 14 }) {
              Text(this.message.length > 0 ? this.message : '还没有可展示的课程主题')
                .fontSize(14)
                .fontColor(this.message.length > 0 ? Constants.COLOR_ERROR : Constants.COLOR_TEXT_SECONDARY)
                .textAlign(TextAlign.Center)
              if (this.mapLoadFailed) {
                Button('重新读取星图')
                  .constraintSize({ minHeight: 48 })
                  .fontSize(14)
                  .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
                  .backgroundColor(Constants.COLOR_BRAND)
                  .borderRadius(Constants.RADIUS_MD)
                  .onClick((): void => { this.retryMapLoad(); })
                  .accessibilityText('重新加载学习星图')
              }
            }
            .width('100%')
            .height(260)
            .justifyContent(FlexAlign.Center)
          } else {
            this.MapSummary()
            this.SelectedTopicCard()
            Scroll() {
              this.MapCanvas()
            }
            .width('100%')
            .height(this.canvasHeight)
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
          }

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
            Row({ space: 6 }) {
              Column().width(9).height(9).backgroundColor(Constants.COLOR_MAP_NODE_IDLE).borderRadius(5)
              Text('可开始').fontSize(11).fontColor(Constants.COLOR_TEXT_SECONDARY)
            }
            .margin({ left: 8, right: 8, top: 4, bottom: 4 })
            Row({ space: 6 }) {
              Column().width(9).height(9).backgroundColor(Constants.COLOR_BRAND).borderRadius(5)
              Text('已学习').fontSize(11).fontColor(Constants.COLOR_TEXT_SECONDARY)
            }
            .margin({ left: 8, right: 8, top: 4, bottom: 4 })
            Row({ space: 6 }) {
              Column().width(9).height(9).backgroundColor(Constants.COLOR_WARNING).borderRadius(5)
              Text('学习中').fontSize(11).fontColor(Constants.COLOR_TEXT_SECONDARY)
            }
            .margin({ left: 8, right: 8, top: 4, bottom: 4 })
            Row({ space: 6 }) {
              Column().width(9).height(9).backgroundColor(Constants.COLOR_SUCCESS).borderRadius(5)
              Text('已掌握').fontSize(11).fontColor(Constants.COLOR_TEXT_SECONDARY)
            }
            .margin({ left: 8, right: 8, top: 4, bottom: 4 })
          }
          .width('100%')
          .accessibilityGroup(true)
          .accessibilityText('星图状态图例：可开始、已学习、学习中、已掌握')

          Row({ space: 6 }) {
            Text('↓')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_MAP_LINE_ACTIVE)
            Text('箭头由前置主题指向后继主题')
              .fontSize(11)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ left: 16, right: 16, bottom: 28 + SafeAreaInsets.bottomVp() })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
