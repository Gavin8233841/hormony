import { Course, PlanTask } from '../model/DataModels';
import {
  LearningReviewItem as ReviewItem,
  LearningStudyEvent as StudyEvent
} from '../model/LearningMetadataModels';
import { LocalLearningRepository } from './LocalLearningRepository';

const PROACTIVE_PARAMETER_MAX_LENGTH: number = 128;

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

export interface ProactiveLearningLaunch {
  targetPage: string;
  courseId: string;
  courseTitle: string;
  topic: string;
  focusTag: string;
  taskAction: string;
}

export class ProactiveLearningService {
  static planTaskTitle(task: PlanTask): string {
    const topic = task.topic?.trim() ?? '';
    if (topic.length === 0) return task.title;
    if (task.action === 'lesson') return '学习' + topic;
    if (task.action === 'practice') return '练习' + topic;
    if (task.action === 'quiz') return '测验' + topic;
    if (task.action === 'review') return '复习' + topic;
    return task.title;
  }

  static async resolve(now: Date = new Date()): Promise<ProactiveLearningAction> {
    const courses = await LocalLearningRepository.getCourses() ?? [];
    const events = await LocalLearningRepository.getStudyEvents();
    const currentCourse = ProactiveLearningService.recentCourse(courses, events);

    const dueReviews = await LocalLearningRepository.getDueReviewItems(now);
    const executableReviews = dueReviews.filter((item: ReviewItem): boolean =>
      ProactiveLearningService.hasCourseTopic(courses, item.courseId, item.topic));
    if (executableReviews.length > 0) {
      return ProactiveLearningService.reviewAction(executableReviews[0], executableReviews.length, courses);
    }

    const plan = await LocalLearningRepository.getPlan();
    const today = ProactiveLearningService.localDateKey(now);
    const todayTasks = plan?.tasks.filter((task: PlanTask): boolean => task.date === today) ?? [];
    const executableTasks = todayTasks.filter((task: PlanTask): boolean =>
      ProactiveLearningService.isExecutablePlanTask(task, courses));
    const pendingTask = executableTasks.find((task: PlanTask): boolean => task.done !== true);
    if (pendingTask !== undefined) {
      return ProactiveLearningService.taskAction(pendingTask, executableTasks, courses);
    }
    const invalidPendingCount = todayTasks.filter((task: PlanTask): boolean =>
      task.done !== true && !ProactiveLearningService.isExecutablePlanTask(task, courses)).length;
    if (invalidPendingCount > 0) {
      return ProactiveLearningService.repairPlanAction(invalidPendingCount);
    }

    if (todayTasks.length > 0 && todayTasks.every((task: PlanTask): boolean => task.done === true)) {
      const completedCourse = executableTasks.length > 0 ?
        courses.find((course: Course): boolean => course.id === executableTasks[0].courseId) : undefined;
      return ProactiveLearningService.completedTodayAction(todayTasks.length, completedCourse ?? currentCourse);
    }

    return ProactiveLearningService.fallback(currentCourse);
  }

  static fallback(course?: Course): ProactiveLearningAction {
    if (course === undefined) {
      return {
        kind: 'plan',
        badge: '今日起步',
        title: '制定今天的学习计划',
        subtitle: '设定目标，安排每天的学习',
        cta: '制定计划',
        courseId: '',
        courseTitle: '',
        topic: '',
        focusTag: '',
        taskAction: 'plan',
        targetPage: 'pages/Plan',
        evidence: '还没有学习计划',
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
      targetPage: 'pages/CourseDetail',
      evidence: '接着上次的进度',
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

  static validateLaunch(courses: Course[], source: string, targetPage: string, courseId: string,
    topic: string, focusTag: string, taskAction: string): ProactiveLearningLaunch | undefined {
    if (!ProactiveLearningService.isLaunchSource(source) ||
      !ProactiveLearningService.validLaunchText(targetPage) ||
      !ProactiveLearningService.validLaunchText(courseId) ||
      !ProactiveLearningService.validLaunchText(topic) ||
      !ProactiveLearningService.validLaunchText(focusTag) ||
      !ProactiveLearningService.validLaunchText(taskAction) ||
      !ProactiveLearningService.isTargetPage(targetPage) ||
      !ProactiveLearningService.isLaunchAction(taskAction) ||
      !ProactiveLearningService.isActionTarget(taskAction, targetPage)) {
      return undefined;
    }
    if (focusTag.length > 0) return undefined;
    if (taskAction === 'plan') {
      if (courseId.length > 0 || topic.length > 0) return undefined;
      return {
        targetPage: targetPage,
        courseId: '',
        courseTitle: '',
        topic: '',
        focusTag: '',
        taskAction: taskAction
      };
    }

    const course = courses.find((item: Course): boolean => item.id === courseId);
    if (course === undefined) return undefined;
    if (taskAction === 'course') {
      if (topic.length > 0) return undefined;
    } else if (topic.length === 0 || !course.topics.includes(topic)) {
      return undefined;
    }
    return {
      targetPage: targetPage,
      courseId: course.id,
      courseTitle: course.title,
      topic: topic,
      focusTag: focusTag,
      taskAction: taskAction
    };
  }

  static requestLaunch(launch: ProactiveLearningLaunch): void {
    AppStorage.setOrCreate<string>('selectedCourseId', launch.courseId);
    AppStorage.setOrCreate<string>('selectedCourseTitle', launch.courseTitle);
    AppStorage.setOrCreate<string>('selectedQuizTopic', launch.topic);
    AppStorage.setOrCreate<string>('selectedQuizFocusTag', launch.focusTag);
    AppStorage.setOrCreate<string>('selectedPracticeTopic', launch.topic);
    AppStorage.setOrCreate<string>('selectedContentTopic', launch.topic);
    AppStorage.setOrCreate<string>('proactiveTaskAction', launch.taskAction);
    AppStorage.setOrCreate<string>('proactiveTargetPage', launch.targetPage);
    AppStorage.setOrCreate<number>('proactiveTargetTab', launch.targetPage === 'pages/Index' ? 1 : 0);
    const version = AppStorage.get<number>('proactiveLaunchVersion') ?? 0;
    AppStorage.setOrCreate<number>('proactiveLaunchVersion', version + 1);
  }

  static requestAction(action: ProactiveLearningAction): void {
    ProactiveLearningService.requestLaunch({
      targetPage: action.targetPage,
      courseId: action.courseId,
      courseTitle: action.courseTitle,
      topic: action.topic,
      focusTag: action.focusTag,
      taskAction: action.taskAction
    });
  }

  static isTargetPage(page: string): boolean {
    return page === 'pages/Index' || page === 'pages/Plan' || page === 'pages/MistakeBook' ||
      page === 'pages/Quiz' || page === 'pages/Practice' || page === 'pages/Lesson' ||
      page === 'pages/CourseDetail';
  }

  static isLaunchSource(source: string): boolean {
    return source === 'proactive_learning_card' || source === 'proactive_learning_reminder';
  }

  static validateChatAction(courses: Course[], targetPage: string, courseId: string,
    topic: string, kind: string): ProactiveLearningLaunch | undefined {
    return ProactiveLearningService.validateLaunch(courses, 'proactive_learning_card',
      targetPage, courseId, topic, '', kind);
  }

  private static reviewAction(item: ReviewItem, dueCount: number, courses: Course[]): ProactiveLearningAction {
    const title = ProactiveLearningService.courseTitle(courses, item.courseId);
    const stem = item.stem.length > 34 ? item.stem.slice(0, 34) + '…' : item.stem;
    return {
      kind: 'review',
      badge: '今日任务',
      title: '错题复习',
      subtitle: title + ' · ' + dueCount.toString() + ' 道待复习',
      cta: '开始复习',
      courseId: item.courseId,
      courseTitle: title,
      topic: item.topic,
      focusTag: '',
      taskAction: 'review',
      targetPage: 'pages/MistakeBook',
      evidence: '上次错题：' + stem,
      progressText: item.topic
    };
  }

  private static repairPlanAction(invalidPendingCount: number): ProactiveLearningAction {
    return {
      kind: 'plan',
      badge: '计划待修复',
      title: '重新生成今天的学习计划',
      subtitle: invalidPendingCount.toString() + ' 项任务需要更新',
      cta: '重新生成计划',
      courseId: '',
      courseTitle: '',
      topic: '',
      focusTag: '',
      taskAction: 'plan',
      targetPage: 'pages/Plan',
      evidence: '课程内容或任务入口已变化',
      progressText: invalidPendingCount.toString() + ' 项需要更新'
    };
  }

  private static completedTodayAction(count: number, course?: Course): ProactiveLearningAction {
    return {
      kind: 'course',
      badge: '今日已完成',
      title: '今天的计划已完成',
      subtitle: '已完成 ' + count.toString() + '/' + count.toString() + ' 项计划任务',
      cta: course === undefined ? '浏览课程' : '继续课程',
      courseId: course?.id ?? '',
      courseTitle: course?.title ?? '',
      topic: '',
      focusTag: '',
      taskAction: 'course',
      targetPage: course === undefined ? 'pages/Index' : 'pages/CourseDetail',
      evidence: '今天的任务已勾选',
      progressText: count.toString() + '/' + count.toString() + ' 项已完成'
    };
  }

  private static taskAction(task: PlanTask, todayTasks: PlanTask[], courses: Course[]): ProactiveLearningAction {
    const courseId = task.courseId ?? '';
    const courseTitle = ProactiveLearningService.courseTitle(courses, courseId);
    const action = task.action ?? '';
    const completed = todayTasks.filter((item: PlanTask): boolean => item.done === true).length;
    return {
      kind: 'task',
      badge: '今日任务',
      title: ProactiveLearningService.planTaskTitle(task),
      subtitle: task.topic !== undefined && task.topic.length > 0 ?
        courseTitle + ' · ' + task.topic : task.estimatedMin.toString() + ' 分钟',
      cta: ProactiveLearningService.taskCta(action),
      courseId: courseId,
      courseTitle: courseTitle,
      topic: task.topic ?? '',
      focusTag: '',
      taskAction: action,
      targetPage: ProactiveLearningService.taskTarget(action),
      evidence: '预计 ' + task.estimatedMin.toString() + ' 分钟',
      progressText: completed.toString() + '/' + todayTasks.length.toString() + ' 已完成'
    };
  }

  private static taskTarget(action: string): string {
    if (action === 'quiz') return 'pages/Quiz';
    if (action === 'practice' || action === 'review') return 'pages/Practice';
    if (action === 'lesson') return 'pages/Lesson';
    return 'pages/Plan';
  }

  private static taskCta(action: string): string {
    if (action === 'quiz') return '开始测验';
    if (action === 'practice') return '开始练习';
    if (action === 'review') return '开始复盘';
    if (action === 'lesson') return '继续学习';
    return '重新生成计划';
  }

  private static recentCourse(courses: Course[], events: StudyEvent[]): Course | undefined {
    for (let index = events.length - 1; index >= 0; index--) {
      const courseId = events[index].courseId;
      if (courseId === undefined) continue;
      const course = courses.find((item: Course): boolean => item.id === courseId);
      if (course !== undefined) return course;
    }
    return courses.find((course: Course): boolean => course.progress > 0);
  }

  private static isExecutablePlanTask(task: PlanTask, courses: Course[]): boolean {
    const courseId = task.courseId;
    const topic = task.topic;
    if (courseId === undefined || courseId.length === 0 || topic === undefined || topic.length === 0) {
      return false;
    }
    if (task.action === undefined || !ProactiveLearningService.isPlanTaskAction(task.action)) return false;
    return ProactiveLearningService.hasCourseTopic(courses, courseId, topic);
  }

  private static hasCourseTopic(courses: Course[], courseId: string, topic: string): boolean {
    const course = courses.find((item: Course): boolean => item.id === courseId);
    return course !== undefined && course.topics.includes(topic);
  }

  private static isPlanTaskAction(action: string): boolean {
    return action === 'lesson' || action === 'practice' || action === 'quiz' || action === 'review';
  }

  private static isLaunchAction(action: string): boolean {
    return ProactiveLearningService.isPlanTaskAction(action) || action === 'course' || action === 'plan';
  }

  private static isActionTarget(action: string, targetPage: string): boolean {
    if (action === 'plan') return targetPage === 'pages/Plan';
    if (action === 'course') return targetPage === 'pages/CourseDetail' || targetPage === 'pages/Index';
    if (action === 'lesson') return targetPage === 'pages/Lesson';
    if (action === 'quiz') return targetPage === 'pages/Quiz';
    if (action === 'practice') return targetPage === 'pages/Practice';
    if (action === 'review') return targetPage === 'pages/MistakeBook' || targetPage === 'pages/Practice';
    return false;
  }

  private static validLaunchText(value: string): boolean {
    return value.length <= PROACTIVE_PARAMETER_MAX_LENGTH && !value.includes('\n') && !value.includes('\r');
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
