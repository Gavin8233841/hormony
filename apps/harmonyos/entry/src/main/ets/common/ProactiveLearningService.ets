import { Course, PlanTask } from '../model/DataModels';
import {
  LearningReviewItem as ReviewItem,
  LearningStudyEvent as StudyEvent,
  LearningTagInsight as TagInsight
} from '../model/LearningMetadataModels';
import { LocalLearningRepository } from './LocalLearningRepository';

export interface ProactiveLearningAction {
  kind: string;
  badge: string;
  title: string;
  subtitle: string;
  cta: string;
  courseId: string;
  courseTitle: string;
  topic: string;
  focusTag: string;
  taskAction: string;
  targetPage: string;
  evidence: string;
  progressText: string;
}

export class ProactiveLearningService {
  static async resolve(now: Date = new Date()): Promise<ProactiveLearningAction> {
    const courses = await LocalLearningRepository.getCourses() ?? [];
    const events = await LocalLearningRepository.getStudyEvents();
    const currentCourse = ProactiveLearningService.recentCourse(courses, events);

    const dueReviews = await LocalLearningRepository.getDueReviewItems(now);
    if (dueReviews.length > 0) {
      return ProactiveLearningService.reviewAction(dueReviews[0], dueReviews.length, courses);
    }

    const insights = await LocalLearningRepository.getTagInsights(12);
    const weakTag = ProactiveLearningService.selectWeakTagInsights(insights, 1)[0];
    if (weakTag !== undefined) {
      return ProactiveLearningService.tagAction(weakTag, courses);
    }

    const plan = await LocalLearningRepository.getPlan();
    const today = ProactiveLearningService.localDateKey(now);
    const todayTasks = plan?.tasks.filter((task: PlanTask): boolean => task.date === today) ?? [];
    const pendingTask = todayTasks.find((task: PlanTask): boolean => task.done !== true);
    if (pendingTask !== undefined) {
      return ProactiveLearningService.taskAction(pendingTask, todayTasks, courses, currentCourse);
    }

    return ProactiveLearningService.fallback(currentCourse);
  }

  static fallback(course?: Course): ProactiveLearningAction {
    if (course === undefined) {
      return {
        kind: 'plan',
        badge: '今日起步',
        title: '制定今天的学习计划',
        subtitle: '让学伴把目标拆成可执行任务',
        cta: '制定计划',
        courseId: '',
        courseTitle: '',
        topic: '',
        focusTag: '',
        taskAction: 'plan',
        targetPage: 'pages/Plan',
        evidence: '本机还没有可继续的课程状态或今日任务',
        progressText: '等待制定计划'
      };
    }
    const percent = Math.round(course.progress * 100);
    return {
      kind: 'course',
      badge: '继续学习',
      title: '继续' + course.title,
      subtitle: course.title + ' · 已完成 ' + percent.toString() + '%',
      cta: '进入课程',
      courseId: course.id,
      courseTitle: course.title,
      topic: '',
      focusTag: '',
      taskAction: 'course',
      targetPage: 'pages/Index',
      evidence: '当前没有到期复习、未掌握标签或今日待办',
      progressText: percent.toString() + '% 课程进度'
    };
  }

  static applySelection(action: ProactiveLearningAction): void {
    AppStorage.setOrCreate<string>('selectedCourseId', action.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', action.courseTitle);
    AppStorage.setOrCreate<string>('selectedQuizTopic', action.topic);
    AppStorage.setOrCreate<string>('selectedQuizFocusTag', action.focusTag);
    AppStorage.setOrCreate<string>('selectedPracticeTopic', action.topic);
    AppStorage.setOrCreate<string>('selectedContentTopic', action.topic);
  }

  static requestLaunch(targetPage: string, courseId: string, courseTitle: string, topic: string,
    focusTag: string, taskAction: string): void {
    const safeTarget = ProactiveLearningService.isTargetPage(targetPage) ? targetPage : 'pages/Index';
    AppStorage.setOrCreate<string>('selectedCourseId', courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', courseTitle);
    AppStorage.setOrCreate<string>('selectedQuizTopic', topic);
    AppStorage.setOrCreate<string>('selectedQuizFocusTag', focusTag);
    AppStorage.setOrCreate<string>('selectedPracticeTopic', topic);
    AppStorage.setOrCreate<string>('selectedContentTopic', topic);
    AppStorage.setOrCreate<string>('proactiveTaskAction', taskAction);
    AppStorage.setOrCreate<string>('proactiveTargetPage', safeTarget);
    AppStorage.setOrCreate<number>('proactiveTargetTab', safeTarget === 'pages/Index' ? 1 : 0);
    const version = AppStorage.get<number>('proactiveLaunchVersion') ?? 0;
    AppStorage.setOrCreate<number>('proactiveLaunchVersion', version + 1);
  }

  static isTargetPage(page: string): boolean {
    return page === 'pages/Index' || page === 'pages/Plan' || page === 'pages/MistakeBook' ||
      page === 'pages/Quiz' || page === 'pages/Practice' || page === 'pages/Lesson';
  }

  static selectWeakTagInsights(insights: TagInsight[], limit: number): TagInsight[] {
    if (limit <= 0) return [];
    return insights.filter((item: TagInsight): boolean =>
      item.wrongQuestions > 0 && item.masteryPoints < 72).slice(0, limit);
  }

  private static reviewAction(item: ReviewItem, dueCount: number, courses: Course[]): ProactiveLearningAction {
    const title = ProactiveLearningService.courseTitle(courses, item.courseId);
    const stem = item.stem.length > 34 ? item.stem.slice(0, 34) + '…' : item.stem;
    return {
      kind: 'review',
      badge: '到期复习',
      title: dueCount.toString() + ' 道错题今天到期',
      subtitle: title + ' · ' + item.topic,
      cta: '开始复习',
      courseId: item.courseId,
      courseTitle: title,
      topic: item.topic,
      focusTag: (item.tags ?? [])[0] ?? item.topic,
      taskAction: 'review',
      targetPage: 'pages/MistakeBook',
      evidence: '最早到期：' + stem + ' · 已练 ' + item.attempts.toString() + ' 次',
      progressText: dueCount.toString() + ' 道今日到期'
    };
  }

  private static tagAction(item: TagInsight, courses: Course[]): ProactiveLearningAction {
    const title = ProactiveLearningService.courseTitle(courses, item.courseId);
    return {
      kind: 'tag',
      badge: item.masteryLevel,
      title: '优先补强：' + item.tag,
      subtitle: title + ' · ' + item.topic,
      cta: '练这个标签',
      courseId: item.courseId,
      courseTitle: title,
      topic: item.topic,
      focusTag: item.tag,
      taskAction: 'quiz',
      targetPage: 'pages/Quiz',
      evidence: '最近 ' + item.totalQuestions.toString() + ' 道错 ' + item.wrongQuestions.toString() +
        ' 道 · ' + item.weakReason,
      progressText: '掌握值 ' + item.masteryPoints.toString() + ' · 目标 72'
    };
  }

  private static taskAction(task: PlanTask, todayTasks: PlanTask[], courses: Course[],
    currentCourse?: Course): ProactiveLearningAction {
    const fallbackCourseId = currentCourse?.id ?? '';
    const courseId = task.courseId ?? fallbackCourseId;
    const courseTitle = ProactiveLearningService.courseTitle(courses, courseId);
    const action = task.action ?? task.type;
    const completed = todayTasks.filter((item: PlanTask): boolean => item.done === true).length;
    return {
      kind: 'task',
      badge: '今日任务',
      title: task.title,
      subtitle: task.topic !== undefined && task.topic.length > 0 ?
        courseTitle + ' · ' + task.topic : task.estimatedMin.toString() + ' 分钟',
      cta: ProactiveLearningService.taskCta(action),
      courseId: courseId,
      courseTitle: courseTitle,
      topic: task.topic ?? '',
      focusTag: '',
      taskAction: action,
      targetPage: ProactiveLearningService.taskTarget(action),
      evidence: '今日计划中最早尚未完成 · 预计 ' + task.estimatedMin.toString() + ' 分钟',
      progressText: completed.toString() + '/' + todayTasks.length.toString() + ' 已完成'
    };
  }

  private static taskTarget(action: string): string {
    if (action === 'quiz') return 'pages/Quiz';
    if (action === 'practice' || action === 'review') return 'pages/Practice';
    return 'pages/Lesson';
  }

  private static taskCta(action: string): string {
    if (action === 'quiz') return '开始测验';
    if (action === 'practice') return '开始练习';
    if (action === 'review') return '开始复盘';
    return '继续学习';
  }

  private static recentCourse(courses: Course[], events: StudyEvent[]): Course | undefined {
    for (let index = events.length - 1; index >= 0; index--) {
      const courseId = events[index].courseId;
      if (courseId === undefined) continue;
      const course = courses.find((item: Course): boolean => item.id === courseId);
      if (course !== undefined) return course;
    }
    return courses[0];
  }

  private static courseTitle(courses: Course[], courseId: string): string {
    const course = courses.find((item: Course): boolean => item.id === courseId);
    return course?.title ?? '课程';
  }

  private static localDateKey(date: Date): string {
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return date.getFullYear().toString() + '-' + month + '-' + day;
  }
}
