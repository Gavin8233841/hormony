// 题库数据文件
// 覆盖三门课程：CS101 数据结构、CS102 操作系统、CS103 计算机网络
// 33 个 Topic 各含 5 道选择题；每门课程另含 7 道简答题
// 当前共 165 道选择题和 21 道简答题

import type { Quiz } from "@/lib/types";


type QuizDifficulty = "easy" | "medium" | "hard";
type QuizSeedQuestion = Omit<Quiz["questions"][number], "difficulty" | "tags"> & {
  difficulty?: QuizDifficulty;
  tags?: string[];
};
type QuizSeed = Omit<Quiz, "questions"> & { questions: QuizSeedQuestion[] };

const QUESTION_DIFFICULTY: Record<string, QuizDifficulty> = {
  "cs101_q01": "easy",
  "cs101_q02": "hard",
  "cs101_q03": "medium",
  "cs101_q04": "hard",
  "cs101_q06": "easy",
  "cs101_q07": "medium",
  "cs101_q09": "medium",
  "cs101_q10": "medium",
  "cs101_q11": "hard",
  "cs101_q13": "hard",
  "cs101_q15": "easy",
  "cs101_q16": "medium",
  "cs101_q17": "hard",
  "cs101_q18": "medium",
  "cs101_q19": "medium",
  "cs101_q21": "medium",
  "cs101_q23": "medium",
  "cs101_q25": "medium",
  "cs101_q26": "medium",
  "cs101_q27": "hard",
  "cs101_q28": "easy",
  "cs101_q29": "easy",
  "cs101_q30": "medium",
  "cs101_q31": "easy",
  "cs101_q32": "easy",
  "cs101_q33": "hard",
  "cs101_q34": "easy",
  "cs101_q35": "easy",
  "cs101_q36": "easy",
  "cs101_q37": "easy",
  "cs101_q38": "easy",
  "cs101_q39": "easy",
  "cs101_q40": "medium",
  "cs101_q41": "medium",
  "cs101_q42": "easy",
  "cs101_q43": "medium",
  "cs101_q44": "easy",
  "cs101_q45": "medium",
  "cs101_q46": "hard",
  "cs101_q47": "medium",
  "cs101_q48": "easy",
  "cs101_q49": "hard",
  "cs101_q50": "easy",
  "cs101_q51": "hard",
  "cs101_q52": "medium",
  "cs101_q53": "easy",
  "cs101_q54": "medium",
  "cs101_q55": "easy",
  "cs101_q56": "medium",
  "cs101_q57": "medium",
  "cs101_q58": "easy",
  "cs101_q59": "hard",
  "cs101_q60": "easy",
  "cs101_q61": "medium",
  "cs101_q62": "medium",
  "cs101_q63": "easy",
  "cs101_q64": "medium",
  "cs101_q65": "easy",
  "cs101_q66": "hard",
  "cs101_q67": "medium",
  "cs102_q01": "medium",
  "cs102_q02": "easy",
  "cs102_q04": "hard",
  "cs102_q05": "medium",
  "cs102_q07": "medium",
  "cs102_q08": "medium",
  "cs102_q10": "medium",
  "cs102_q11": "medium",
  "cs102_q13": "hard",
  "cs102_q14": "medium",
  "cs102_q16": "medium",
  "cs102_q17": "easy",
  "cs102_q19": "medium",
  "cs102_q20": "easy",
  "cs102_q22": "easy",
  "cs102_q23": "medium",
  "cs102_q24": "medium",
  "cs102_q25": "hard",
  "cs102_q26": "hard",
  "cs102_q27": "hard",
  "cs102_q28": "easy",
  "cs102_q29": "hard",
  "cs102_q30": "easy",
  "cs102_q31": "easy",
  "cs102_q32": "medium",
  "cs102_q33": "easy",
  "cs102_q34": "medium",
  "cs102_q35": "hard",
  "cs102_q36": "easy",
  "cs102_q37": "medium",
  "cs102_q38": "easy",
  "cs102_q39": "easy",
  "cs102_q40": "easy",
  "cs102_q41": "medium",
  "cs102_q42": "medium",
  "cs102_q43": "hard",
  "cs102_q44": "medium",
  "cs102_q45": "medium",
  "cs102_q46": "easy",
  "cs102_q47": "easy",
  "cs102_q48": "easy",
  "cs102_q49": "hard",
  "cs102_q50": "easy",
  "cs102_q51": "medium",
  "cs102_q52": "easy",
  "cs102_q53": "easy",
  "cs102_q54": "hard",
  "cs102_q55": "easy",
  "cs102_q56": "easy",
  "cs102_q57": "medium",
  "cs103_q01": "easy",
  "cs103_q02": "easy",
  "cs103_q04": "medium",
  "cs103_q05": "easy",
  "cs103_q07": "easy",
  "cs103_q08": "medium",
  "cs103_q09": "easy",
  "cs103_q10": "easy",
  "cs103_q12": "medium",
  "cs103_q13": "easy",
  "cs103_q15": "medium",
  "cs103_q16": "easy",
  "cs103_q18": "medium",
  "cs103_q19": "hard",
  "cs103_q21": "easy",
  "cs103_q22": "medium",
  "cs103_q24": "hard",
  "cs103_q25": "hard",
  "cs103_q26": "medium",
  "cs103_q27": "hard",
  "cs103_q28": "medium",
  "cs103_q29": "hard",
  "cs103_q30": "easy",
  "cs103_q31": "easy",
  "cs103_q32": "easy",
  "cs103_q33": "medium",
  "cs103_q34": "hard",
  "cs103_q35": "medium",
  "cs103_q36": "medium",
  "cs103_q37": "easy",
  "cs103_q38": "easy",
  "cs103_q39": "medium",
  "cs103_q40": "medium",
  "cs103_q41": "easy",
  "cs103_q42": "hard",
  "cs103_q43": "medium",
  "cs103_q44": "medium",
  "cs103_q45": "hard",
  "cs103_q46": "hard",
  "cs103_q47": "easy",
  "cs103_q48": "medium",
  "cs103_q49": "medium",
  "cs103_q50": "easy",
  "cs103_q51": "easy",
  "cs103_q52": "medium",
  "cs103_q53": "hard",
  "cs103_q54": "easy",
  "cs103_q55": "medium",
  "cs103_q56": "easy",
  "cs103_q57": "easy",
  "cs103_q58": "easy",
  "cs103_q59": "easy",
  "cs103_q60": "hard",
  "cs103_q61": "medium",
  "cs103_q62": "easy",
};

const TOPIC_TAGS: Record<string, string> = {
  "数组与线性表": "线性表操作",
  "链表": "链式结构",
  "栈与队列": "受限线性结构",
  "二叉树与BST": "树结构性质",
  "AVL树与红黑树": "平衡树机制",
  "图的表示与遍历": "图遍历建模",
  "排序算法": "排序策略",
  "动态规划": "状态转移",
  "哈希表": "散列冲突",
  "堆与优先队列": "堆结构维护",
  "最短路径算法": "路径搜索",
  "贪心算法与分治": "算法设计范式",
  "进程与线程": "进程线程模型",
  "CPU调度算法": "调度策略",
  "内存管理基础": "内存分配",
  "虚拟内存与分页": "分页置换",
  "文件系统": "文件组织",
  "死锁": "死锁分析",
  "同步与互斥": "并发同步",
  "I/O系统与磁盘调度": "I/O调度",
  "分段与段页式": "地址转换",
  "进程间通信": "IPC机制",
  "OSI与TCP/IP模型": "网络分层",
  "TCP握手与挥手": "TCP状态",
  "TCP流量控制与拥塞控制": "拥塞控制",
  "UDP协议": "UDP机制",
  "HTTP协议": "HTTP语义",
  "HTTPS与TLS": "TLS安全",
  "DNS系统": "DNS解析",
  "路由算法与协议": "路由决策",
  "网络安全基础": "安全机制",
  "物理层与数据链路层": "链路层机制",
  "网络层与IP协议": "IP寻址",
};

function withQuizMetadata(quizzes: QuizSeed[]): Quiz[] {
  return quizzes.map((quiz) => {
    const choiceTargetIndexes = buildChoiceTargetIndexes(quiz);
    let choicePosition = 0;

    return {
      ...quiz,
      questions: quiz.questions.map((question) => {
        const balancedQuestion = question.type === "choice"
          ? balanceChoiceOptions(question, choiceTargetIndexes[choicePosition++])
          : question;
        const difficulty = balancedQuestion.difficulty ?? QUESTION_DIFFICULTY[balancedQuestion.id] ??
          inferQuestionDifficulty(balancedQuestion);
        return {
          ...balancedQuestion,
          difficulty,
          tags: buildQuestionTags(quiz.topic, balancedQuestion, difficulty),
        };
      }),
    };
  });
}

const CHOICE_LABELS = ["A", "B", "C", "D"] as const;

function buildChoiceTargetIndexes(quiz: QuizSeed): number[] {
  const firstFour = CHOICE_LABELS.map((_, index) => index).sort((left, right) =>
    stableQuestionHash(`${quiz.quizId}:${CHOICE_LABELS[left]}`) -
    stableQuestionHash(`${quiz.quizId}:${CHOICE_LABELS[right]}`)
  );
  return quiz.questions
    .filter((question) => question.type === "choice")
    .map((question, index) => index < CHOICE_LABELS.length
      ? firstFour[index]
      : stableQuestionHash(question.id) % CHOICE_LABELS.length);
}

export function balanceChoiceOptions(question: QuizSeedQuestion, targetIndex: number): QuizSeedQuestion {
  if (question.type !== "choice" || question.options?.length !== CHOICE_LABELS.length) {
    return question;
  }

  const answerIndex = CHOICE_LABELS.indexOf(question.answer as typeof CHOICE_LABELS[number]);
  const optionBodies = question.options.map((option, index) => {
    const prefix = `${CHOICE_LABELS[index]}.`;
    return option.startsWith(prefix) ? option.slice(prefix.length).trimStart() : "";
  });
  if (answerIndex < 0 || optionBodies.some((option) => option.length === 0)) {
    return question;
  }

  const shift = (targetIndex - answerIndex + CHOICE_LABELS.length) % CHOICE_LABELS.length;
  const rotatedBodies = optionBodies.map((_, index) =>
    optionBodies[(index - shift + CHOICE_LABELS.length) % CHOICE_LABELS.length]
  );

  return {
    ...question,
    options: rotatedBodies.map((option, index) => `${CHOICE_LABELS[index]}. ${option}`),
    answer: CHOICE_LABELS[targetIndex],
  };
}

function stableQuestionHash(value: string): number {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function inferQuestionDifficulty(question: QuizSeedQuestion): QuizDifficulty {
  if (question.type === "short") return "medium";
  return "medium";
}

function buildQuestionTags(topic: string, question: QuizSeedQuestion, difficulty: QuizDifficulty): string[] {
  const source = [question.stem, question.explanation].join(" ");
  const tags = [TOPIC_TAGS[topic] ?? topic, abilityTag(source), difficultyTag(difficulty)];
  return tags.filter((tag, index, values) => values.indexOf(tag) === index).slice(0, 3);
}

function difficultyTag(difficulty: QuizDifficulty): string {
  if (difficulty === "easy") return "基础识别";
  if (difficulty === "hard") return "挑战推演";
  return "应用推理";
}

function abilityTag(source: string): string {
  if (source.includes("复杂度") || source.includes("O(") || source.includes("O（") ||
    source.includes("时间") || source.includes("空间")) return "复杂度分析";
  if (/指针|链表|插入|删除|旋转|上浮|下沉/.test(source)) return "结构操作";
  if (/状态|SYN|ACK|FIN|TIME_WAIT|CLOSE_WAIT|就绪|阻塞|运行态/.test(source)) return "状态推演";
  if (source.includes("公式") || source.includes("平均") || source.includes("计算") ||
    source.includes("序列") || source.includes("CIDR") || source.includes("Hz") ||
    source.includes("bps") || source.includes("窗口") || source.includes("等待时间") ||
    source.includes("P(") || source.includes("V(") || source.includes("信号量")) return "数值计算";
  if (/原因|作用|主要|为什么|目的|优势|缺点/.test(source)) return "机制解释";
  if (/比较|区别|相比|正确|错误|下列说法|描述/.test(source)) return "概念辨析";
  if (/协议|HTTP|HTTPS|TLS|DNS|TCP|UDP|IP|ARP|ICMP|BGP|OSPF|RIP/.test(source)) return "协议机制";
  if (/死锁|调度|页面|磁盘|内存|分段|分页|进程|线程|文件/.test(source)) return "系统机制";
  if (/算法|Dijkstra|BFS|DFS|排序|动态规划|贪心|分治|背包|LCS|LIS|Floyd|Bellman/.test(source)) return "算法推演";
  return "概念理解";
}


// ===========================================================================
// CS101 数据结构（共 67 题：60 选择 + 7 简答）
// ===========================================================================

export const cs101Quizzes: Quiz[] = withQuizMetadata([
  // ---- 数组与线性表 ----
  {
    quizId: "quiz_cs101_array",
    courseId: "cs101",
    topic: "数组与线性表",
    questions: [
      {
        id: "cs101_q01",
        type: "choice",
        stem: "在一个长度为 n 的顺序表中删除第 i 个元素，需要移动多少个元素？",
        options: ["A. n-i", "B. n-i-1", "C. n-i+1", "D. i"],
        answer: "A",
        explanation:
          "删除第 i 个元素后，第 i+1 到第 n 个元素都要前移一位填补空缺，共需移动 n-i 个元素。等概率情况下平均移动次数约为 n/2，时间复杂度为 O(n)。",
      },
      {
        id: "cs101_q02",
        type: "choice",
        stem: "一个空动态数组初始容量为 1；每次容量满时先扩为 2 倍并复制全部已有元素。连续插入 9 个元素，仅扩容复制发生了多少次元素复制？",
        options: ["A. 8 次", "B. 12 次", "C. 15 次", "D. 16 次"],
        answer: "C",
        explanation:
          "插入第 2、3、5、9 个元素前分别触发容量 1->2、2->4、4->8、8->16 的扩容，对应复制 1、2、4、8 个已有元素。复制总数为 1+2+4+8=15，这个几何级数也说明连续插入的扩容总代价为 O(n)，均摊到每次插入为 O(1)。",
      },
      {
        id: "cs101_q03",
        type: "choice",
        stem: "关于顺序表和链表的比较，下列说法正确的是？",
        options: [
          "A. 顺序表支持随机访问 O(1)，链表也支持随机访问 O(1)",
          "B. 链表插入删除需移动元素，顺序表只需修改指针",
          "C. 顺序表缓存友好，链表插入删除（已知位置）为 O(1)",
          "D. 顺序表和链表的空间开销完全相同",
        ],
        answer: "C",
        explanation:
          "顺序表元素连续存储，缓存命中率高，支持随机访问 O(1)；链表节点离散分布，插入删除只需修改指针 O(1)，但不支持随机访问。读多写少选顺序表，频繁插删选链表。",
      },
      {
        id: "cs101_q28",
        type: "choice",
        stem: "在顺序表（数组）中，访问第 i 个元素的时间复杂度为？",
        options: ["A. O(1)", "B. O(log n)", "C. O(n)", "D. O(n²)"],
        answer: "A",
        explanation:
          "顺序表采用连续存储结构，元素物理地址可通过首地址加偏移量直接计算，因此随机访问任意位置元素的时间复杂度为 O(1)。这是顺序表相比链表最大的优势，也是二分查找等算法的前提条件。",
      },
      {
        id: "cs101_q29",
        type: "choice",
        stem: "关于线性表的说法，错误的是？",
        options: [
          "A. 线性表是由 n 个数据元素组成的有限序列",
          "B. 线性表中的元素具有相同的数据类型",
          "C. 线性表只能采用顺序存储结构",
          "D. 线性表的元素之间存在一对一的逻辑关系",
        ],
        answer: "C",
        explanation:
          "线性表是由 n（n≥0）个数据元素组成的有限序列，元素具有相同类型且存在一对一的前驱后继关系。线性表可以采用顺序存储（顺序表）或链式存储（链表）两种方式实现，并非只能顺序存储。",
      },
    ],
  },

  // ---- 链表 ----
  {
    quizId: "quiz_cs101_linkedlist",
    courseId: "cs101",
    topic: "链表",
    questions: [
      {
        id: "cs101_q04",
        type: "choice",
        stem: "在双链表中，在节点 p 之后插入新节点 s，正确的指针赋值顺序是？",
        options: [
          "A. p->next=s; s->prior=p; s->next=p->next->next; p->next->prior=s",
          "B. s->next=p->next; s->prior=p; p->next->prior=s; p->next=s",
          "C. p->next=s; s->prior=p; s->next=p->next; p->next->prior=s",
          "D. s->prior=p; p->next=s; s->next=p->next; p->next->prior=s",
        ],
        answer: "B",
        explanation:
          "必须先设置 s 的前驱后继指针，再修改 p->next 的前驱指针指向 s，最后将 p->next 指向 s。若先执行 p->next=s 则丢失原后继节点，导致链表断裂。指针赋值顺序是链表编程的关键。",
      },
      {
        id: "cs101_q05",
        type: "short",
        stem: "简述循环链表的特点及其典型应用场景。",
        answer:
          "循环链表将尾节点的指针指向头节点，形成环状结构。其特点是任意节点出发均可遍历整个链表。典型应用包括约瑟夫环问题、操作系统轮转调度、缓冲区管理及循环复用等场景。",
        explanation:
          "循环链表尾节点 next 指向头节点，形成闭合环路。从任意节点出发均可遍历全表，无需从头开始。常用于需要循环访问的场景如约瑟夫环、轮转调度和缓冲区管理。",
      },
      {
        id: "cs101_q06",
        type: "choice",
        stem: "在单链表中查找第 i 个节点的时间复杂度为？",
        options: ["A. O(1)", "B. O(log n)", "C. O(n)", "D. O(n²)"],
        answer: "C",
        explanation:
          "单链表只能从头指针开始顺序遍历，不支持随机访问。查找第 i 个节点需移动 i 次，最坏需遍历整个链表，时间复杂度为 O(n)。这是链表相比顺序表的主要劣势。",
      },
      {
        id: "cs101_q30",
        type: "choice",
        stem: "逆置一个单链表的时间复杂度为？",
        options: ["A. O(1)", "B. O(log n)", "C. O(n)", "D. O(n²)"],
        answer: "C",
        explanation:
          "逆置单链表需遍历所有节点并逐一修改指针方向，每个节点处理时间为 O(1)，共 n 个节点，总时间复杂度为 O(n)。常用头插法实现：依次取下各节点插入到新链表头部即可完成逆置。",
      },
      {
        id: "cs101_q31",
        type: "choice",
        stem: "带头节点的单链表 L 为空的判断条件是？",
        options: ["A. L == NULL", "B. L->next == NULL", "C. L->next == L", "D. L->data == 0"],
        answer: "B",
        explanation:
          "带头节点的单链表中，头节点 L 始终存在但不存储有效数据。当链表为空时，头节点的 next 指针为空，即 L->next == NULL。引入头节点可统一处理空表和首元节点的操作，避免对空链表的特殊判断。",
      },
      {
        id: "cs101_q32",
        type: "choice",
        stem: "在已知节点位置的条件下，单链表插入和删除操作的时间复杂度为？",
        options: ["A. O(1)", "B. O(log n)", "C. O(n)", "D. O(n²)"],
        answer: "A",
        explanation:
          "若已持有待操作位置的指针，单链表的插入和删除只需修改相邻节点的指针域，无需移动元素，时间复杂度为 O(1)。但若需要先查找该位置，则查找时间为 O(n)。这是链表相比顺序表在频繁插入删除场景下的核心优势。",
      },
    ],
  },

  // ---- 栈与队列 ----
  {
    quizId: "quiz_cs101_stackqueue",
    courseId: "cs101",
    topic: "栈与队列",
    questions: [
      {
        id: "cs101_q07",
        type: "choice",
        stem: "循环队列存储在容量为 N 的数组中，队头指针 front，队尾指针 rear。采用牺牲一个存储单元的方法，队列满的条件是？",
        options: [
          "A. front == rear",
          "B. (rear + 1) % N == front",
          "C. rear % N == front",
          "D. (front + 1) % N == rear",
        ],
        answer: "B",
        explanation:
          "采用牺牲一个存储单元的方法，约定队尾指针的下一个位置等于队头时为满，即 (rear+1)%N==front。判空条件为 front==rear。取模运算是实现循环的关键，使指针在数组范围内循环移动。",
      },
      {
        id: "cs101_q08",
        type: "short",
        stem: "列举栈的至少三个典型应用场景。",
        answer:
          "栈的典型应用包括：1. 函数调用栈（保存返回地址和局部变量）；2. 表达式求值与括号匹配（中缀转后缀）；3. 深度优先搜索 DFS；4. 浏览器前进后退功能；5. 递归的迭代化转换。",
        explanation:
          "栈是后进先出（LIFO）结构，适合需要回溯或逆序处理的场景。函数调用栈保存返回地址，表达式求值利用栈进行运算符优先级处理，DFS 用栈实现深度探索与回溯，浏览器用双栈实现前进后退。",
      },
      {
        id: "cs101_q09",
        type: "choice",
        stem: "在滑动窗口最大值问题中，使用单调双端队列的时间复杂度为？",
        options: ["A. O(n²)", "B. O(n log n)", "C. O(n)", "D. O(n × k)"],
        answer: "C",
        explanation:
          "维护单调递减的双端队列，每个元素最多入队和出队各一次，总操作次数为 O(n)。队列头部始终为当前窗口最大值。相比优先队列的 O(n log n)，单调队列利用窗口滑动特性实现了线性时间。",
      },
      {
        id: "cs101_q33",
        type: "choice",
        stem: "入栈序列为 1,2,3,4,5，以下哪个不可能是合法的出栈序列？",
        options: ["A. 5,4,3,2,1", "B. 4,5,3,2,1", "C. 4,3,5,1,2", "D. 2,3,4,5,1"],
        answer: "C",
        explanation:
          "栈遵循后进先出原则。出栈序列 4,3,5,1,2 中，当 1 在 2 之前出栈时，2 必须在栈中且位于 1 之上（后入栈），因此 2 应先于 1 出栈，矛盾。判断出栈序列合法性可用模拟法：按入栈顺序依次压栈，匹配出栈序列中当前元素时弹栈。",
      },
      {
        id: "cs101_q34",
        type: "choice",
        stem: "函数递归调用时，系统使用什么数据结构来保存每次调用的返回地址和局部变量？",
        options: ["A. 队列", "B. 栈", "C. 堆", "D. 数组"],
        answer: "B",
        explanation:
          "函数递归调用时，系统使用运行时栈（调用栈）保存每次调用的返回地址、参数和局部变量。最后调用的函数最先返回，符合栈的后进先出特性。递归深度过大可能导致栈溢出，这是递归算法需要注意的问题。",
      },
      {
        id: "cs101_q35",
        type: "choice",
        stem: "顺序队列采用普通数组实现时，频繁出队操作会导致什么问题？",
        options: ["A. 内部碎片", "B. 假溢出（队头前空间无法利用）", "C. 死锁", "D. 缓存颠簸"],
        answer: "B",
        explanation:
          "普通数组实现的顺序队列中，出队操作只移动队头指针而不移动元素，导致队头之前的数组空间无法被复用。当队尾指针到达数组末尾时，即使队头前有大量空闲空间也无法入队，称为假溢出。采用循环队列可解决此问题。",
      },
    ],
  },

  // ---- 二叉树与 BST ----
  {
    quizId: "quiz_cs101_tree",
    courseId: "cs101",
    topic: "二叉树与BST",
    questions: [
      {
        id: "cs101_q10",
        type: "choice",
        stem: "在任意二叉树中，若叶子节点数为 n0，度为 2 的节点数为 n2，则下列关系成立的是？",
        options: ["A. n0 = n2", "B. n0 = n2 + 1", "C. n0 = n2 - 1", "D. n0 = 2 × n2"],
        answer: "B",
        explanation:
          "设度为 1 的节点数为 n1，总边数为 n0+n1+n2-1（根节点无边）。又总边数等于 n1+2×n2（每个节点的度即出边数）。联立得 n0+n1+n2-1=n1+2n2，化简得 n0=n2+1。这是二叉树的基本性质。",
      },
      {
        id: "cs101_q11",
        type: "choice",
        stem: "依次将 50、30、70、20、40、60、80、65 插入空 BST。删除根 50 时规定用中序后继替换；删除完成后，新根及节点 70 的左孩子分别是？",
        options: [
          "A. 新根 60，70 的左孩子 65",
          "B. 新根 60，70 的左孩子为空",
          "C. 新根 65，70 的左孩子 60",
          "D. 新根 70，70 的左孩子 60",
        ],
        answer: "A",
        explanation:
          "根 50 的中序后继是右子树最小节点 60，因此先用 60 替换根值。原位置的 60 只有右孩子 65，删除它后需把 65 接到 70 的左侧，所以新根为 60，70 的左孩子为 65；中序序列仍保持递增。",
      },
      {
        id: "cs101_q12",
        type: "short",
        stem: "为什么已知二叉树的前序遍历和中序遍历可以唯一确定该二叉树，而前序和后序不能？",
        answer:
          "前序遍历第一个元素是根节点，在中序遍历中找到根节点位置即可划分左右子树，递归处理即可唯一确定树结构。而前序和后序都无法确定根节点的左右子树边界（单子树时无法区分左子树还是右子树），因此不能唯一确定。",
        explanation:
          "前序首元素为根，在中序中定位根可划分左右子树集合，递归确定结构。后序末元素为根同理。但前序加后序无法区分只有一个子节点的情形，该子节点是左还是右无法判断，因此不能唯一确定二叉树。",
      },
      {
        id: "cs101_q36",
        type: "choice",
        stem: "具有 n 个节点的完全二叉树的深度为？",
        options: ["A. log₂(n)", "B. ⌊log₂n⌋ + 1", "C. n/2", "D. √n"],
        answer: "B",
        explanation:
          "完全二叉树中，深度为 k 的完全二叉树节点数范围是 2^(k-1) 到 2^k-1。由 n 反推深度 k，得到 k = ⌊log₂n⌋ + 1。这一性质是堆排序中父子节点索引计算的基础，使得完全二叉树可用数组高效存储。",
      },
      {
        id: "cs101_q37",
        type: "choice",
        stem: "一棵有 n 个节点的平衡二叉搜索树（BST），查找操作的时间复杂度为？",
        options: ["A. O(1)", "B. O(log n)", "C. O(n)", "D. O(n log n)"],
        answer: "B",
        explanation:
          "平衡 BST 的高度为 O(log n)，每次比较可排除一半子树，因此查找时间复杂度为 O(log n)。若 BST 退化成链表（如有序插入），高度为 n，查找退化为 O(n)。保持平衡（如 AVL 树、红黑树）是保证对数级查找的关键。",
      },
      {
        id: "cs101_q38",
        type: "choice",
        stem: "对二叉树进行前序遍历的访问顺序是？",
        options: [
          "A. 左子树→根→右子树",
          "B. 根→左子树→右子树",
          "C. 左子树→右子树→根",
          "D. 右子树→根→左子树",
        ],
        answer: "B",
        explanation:
          "前序遍历的访问顺序是根节点、左子树、右子树（NLR）。前序遍历的第一个访问节点是根节点，常用于复制树结构或序列化二叉树。中序遍历为左根右，后序遍历为左右根，三种遍历方式在二叉树操作中各有用途。",
      },
    ],
  },

  // ---- AVL 树与红黑树 ----
  {
    quizId: "quiz_cs101_avl",
    courseId: "cs101",
    topic: "AVL树与红黑树",
    questions: [
      {
        id: "cs101_q13",
        type: "choice",
        stem: "依次将 50、20、70、10、30、25 插入空 AVL 树，并在首次失衡处完成旋转。调整后根节点、根的左孩子、根的右孩子依次是？",
        options: [
          "A. 20、10、50",
          "B. 25、20、50",
          "C. 30、20、50",
          "D. 30、25、70",
        ],
        answer: "C",
        explanation:
          "插入 25 后，节点 50 的左子树高度比右子树高 2，而其左孩子 20 的右侧更高，形成 LR 型失衡。先对 20 左旋、再对 50 右旋，得到根 30，左孩子 20（孩子为 10 和 25），右孩子 50（右孩子为 70）。",
      },
      {
        id: "cs101_q14",
        type: "short",
        stem: "比较 AVL 树和红黑树在平衡策略和适用场景上的区别。",
        answer:
          "AVL 树严格平衡（平衡因子绝对值不超过 1），查找效率高但插入删除旋转频繁，适合查找密集型场景。红黑树弱平衡（最长路径不超过最短路径两倍），查找略慢但插入删除旋转少（最多 3 次），适合频繁修改的场景，如 C++ STL 的 map 和 Linux 内核 CFS 调度。",
        explanation:
          "AVL 树严格平衡，树高低，查找快但维护成本高。红黑树弱平衡，保证最长路径不超过最短路径两倍，查找略慢但旋转次数少。AVL 适合查找多修改少的场景；红黑树在查找与修改间取得更优平衡，工程中更常用。",
      },
      {
        id: "cs101_q25",
        type: "choice",
        stem: "红黑树中，从任一节点到其所有后代叶节点的简单路径上黑色节点数相同。这一性质保证了最长路径不超过最短路径的多少倍？",
        options: ["A. 1 倍", "B. 1.5 倍", "C. 2 倍", "D. 3 倍"],
        answer: "C",
        explanation:
          "最短路径全为黑节点，最长路径为黑红交替（红节点的子节点必为黑），因此最长路径不超过最短路径的 2 倍。这一弱平衡条件保证树高度为 O(log n)，同时插入删除最多 3 次旋转即可恢复平衡，是红黑树工程实用性优于 AVL 树的关键。",
      },
      {
        id: "cs101_q39",
        type: "choice",
        stem: "AVL 树中任意节点的平衡因子（左子树高度减右子树高度）的取值范围是？",
        options: ["A. {-1, 0, 1}", "B. {-2, -1, 0, 1, 2}", "C. {0, 1}", "D. 任意整数"],
        answer: "A",
        explanation:
          "AVL 树要求任意节点的左右子树高度差的绝对值不超过 1，因此平衡因子取值范围为 {-1, 0, 1}。当插入或删除导致某节点平衡因子绝对值超过 1 时，需要通过旋转操作恢复平衡。这是 AVL 树严格平衡的体现。",
      },
      {
        id: "cs101_q40",
        type: "choice",
        stem: "在红黑树中插入新节点时，新节点的初始颜色通常设为？",
        options: ["A. 黑色", "B. 红色", "C. 根据父节点颜色决定", "D. 随意"],
        answer: "B",
        explanation:
          "红黑树插入新节点时通常设为红色，因为红色节点不改变路径上的黑色节点数，减少对红黑性质的破坏。若新节点的父节点也是红色则违反性质（红色节点的子节点必须为黑），需通过重新着色和旋转调整。将新节点设为黑色则必然导致某条路径黑色节点数增加，调整更复杂。",
      },
      {
        id: "cs101_q41",
        type: "choice",
        stem: "在 AVL 树中插入一个节点导致 LR 或 RL 型失衡后，恢复平衡需要进行几次基本旋转？",
        options: ["A. 1 次", "B. 2 次", "C. 3 次", "D. log n 次"],
        answer: "B",
        explanation:
          "LR 型和 RL 型失衡需要一次双旋，而双旋由两次基本旋转组成，因此答案为 2 次。LL 型和 RR 型只需一次基本旋转。一次插入只需在最低失衡祖先处完成一次重平衡操作，但不能把一次重平衡操作误写成一次基本旋转。",
      },
    ],
  },

  // ---- 图的表示与遍历 ----
  {
    quizId: "quiz_cs101_graph",
    courseId: "cs101",
    topic: "图的表示与遍历",
    questions: [
      {
        id: "cs101_q15",
        type: "choice",
        stem: "对于有 n 个顶点、e 条边的图，邻接表存储下 DFS 的时间复杂度为？",
        options: ["A. O(n²)", "B. O(n + e)", "C. O(e²)", "D. O(n × e)"],
        answer: "B",
        explanation:
          "邻接表存储下，DFS 遍历每个顶点访问一次 O(n)，每条边通过邻接链表访问一次 O(e)，总时间复杂度为 O(n+e)。邻接矩阵存储下则为 O(n²)，因需检查所有 n² 个矩阵元素。邻接表对稀疏图更高效。",
      },
      {
        id: "cs101_q16",
        type: "choice",
        stem: "下列关于 BFS（广度优先搜索）的描述，正确的是？",
        options: [
          "A. BFS 使用栈实现，适合求无权图最短路径",
          "B. BFS 使用队列实现，可求无权图的最短路径（边数最少）",
          "C. BFS 使用递归实现，可求带权图最短路径",
          "D. BFS 只能用于连通图，不能求最短路径",
        ],
        answer: "B",
        explanation:
          "BFS 借助队列逐层扩展，先访问的顶点距离源点更近。在无权图中 BFS 首次到达某顶点的路径即为最短路径（边数最少）。BFS 不适用于带权图最短路径，带权图需用 Dijkstra 等算法。",
      },
      {
        id: "cs101_q17",
        type: "choice",
        stem: "有向图含边 S->A=2、S->B=5、B->A=-4。若 Dijkstra 从 S 出发并规定顶点一旦确定就不再更新，它给出的 d(A) 与真实最短距离分别是？",
        options: [
          "A. 2 与 1",
          "B. 1 与 1",
          "C. 2 与 2",
          "D. 5 与 1",
        ],
        answer: "A",
        explanation:
          "Dijkstra 先以距离 2 确定 A，随后才以距离 5 确定 B；按题设，B->A 的松弛不能再改写已确定的 A，所以算法输出 2。真实路径 S->B->A 的长度为 5+(-4)=1，短于直接边 2，这一反例精确展示了负权边如何破坏贪心不变量。",
      },
      {
        id: "cs101_q42",
        type: "choice",
        stem: "用邻接矩阵存储有 n 个顶点的无向图，所需的存储空间为？",
        options: ["A. O(n)", "B. O(n²)", "C. O(n + e)", "D. O(e²)"],
        answer: "B",
        explanation:
          "邻接矩阵使用 n×n 的二维数组表示顶点间的边关系，无论边数多少都需 O(n²) 空间。无向图的邻接矩阵是对称的，可压缩存储上三角部分节省一半空间。邻接矩阵适合稠密图，邻接表适合稀疏图。",
      },
      {
        id: "cs101_q43",
        type: "choice",
        stem: "对于有 n 个顶点、e 条边的稀疏图，以下存储方式中空间效率最高的是？",
        options: ["A. 邻接矩阵", "B. 邻接表", "C. 邻接多重表", "D. 边集数组"],
        answer: "B",
        explanation:
          "稀疏图中边数 e 远小于 n²，邻接表仅需 O(n+e) 空间，而邻接矩阵需 O(n²) 空间，因此邻接表空间效率更高。邻接表对稀疏图更优，是图算法中最常用的存储方式。稠密图则邻接矩阵更合适，因查询边是否存在为 O(1)。",
      },
    ],
  },

  // ---- 排序算法 ----
  {
    quizId: "quiz_cs101_sort",
    courseId: "cs101",
    topic: "排序算法",
    questions: [
      {
        id: "cs101_q18",
        type: "choice",
        stem: "快速排序在以下哪种情况下会退化为最坏时间复杂度 O(n²)？",
        options: [
          "A. 数据完全随机分布",
          "B. 每次选取的基准元素恰好是当前子数组的最大或最小值",
          "C. 数据中有大量重复元素",
          "D. 使用了三数取中法选取基准",
        ],
        answer: "B",
        explanation:
          "快排最坏情况发生在分区极度不平衡时，即每次基准都是最大或最小值，导致一侧为空另一侧 n-1 个元素，递归深度退化为 n 层，每层 O(n) 扫描，总计 O(n²)。有序输入取首尾元素为基准即触发此情况。随机化基准可降低概率。",
      },
      {
        id: "cs101_q19",
        type: "choice",
        stem: "下列排序算法中，属于稳定排序的是？",
        options: [
          "A. 快速排序",
          "B. 堆排序",
          "C. 归并排序",
          "D. 选择排序",
        ],
        answer: "C",
        explanation:
          "归并排序在合并两个有序子数组时，相等元素保持左子数组在前，因此是稳定的。快速排序的分区交换可能改变相等元素相对顺序；堆排序的下沉交换破坏稳定性；选择排序的跨越交换也不稳定。稳定性在多关键字排序中重要。",
      },
      {
        id: "cs101_q20",
        type: "short",
        stem: "比较归并排序和快速排序的特点，说明各自适用场景。",
        answer:
          "归并排序时间始终 O(n log n) 且稳定，但需 O(n) 额外空间，适合外部排序和链表排序。快速排序平均 O(n log n) 且原地排序缓存友好，常数小实际更快，但最坏 O(n²) 且不稳定，适合内存排序。工程中常用 introsort 结合两者优点。",
        explanation:
          "归并排序保证 O(n log n) 且稳定，但需额外空间，适合外部排序和链表排序。快排平均最快且原地，但最坏 O(n²) 不稳定，适合内存数据排序。实际工程如 introsort 结合快排加堆排加插入排序，保证最坏 O(n log n)。",
      },
      {
        id: "cs101_q44",
        type: "choice",
        stem: "归并排序的空间复杂度为？",
        options: ["A. O(1)", "B. O(log n)", "C. O(n)", "D. O(n²)"],
        answer: "C",
        explanation:
          "归并排序在合并两个有序子数组时需要一个与原数组等大的辅助数组，空间复杂度为 O(n)。归并排序是稳定的排序算法，时间复杂度始终为 O(n log n)，但额外空间开销是其主要缺点。外部排序常使用归并排序思想。",
      },
      {
        id: "cs101_q45",
        type: "choice",
        stem: "堆排序在建堆阶段的时间复杂度为 O(n)，排序阶段（不断取出堆顶并调整）的时间复杂度为？",
        options: ["A. O(n)", "B. O(n log n)", "C. O(n²)", "D. O(log n)"],
        answer: "B",
        explanation:
          "堆排序的排序阶段需执行 n-1 次取堆顶和下沉调整操作，每次下沉调整的时间复杂度为 O(log n)，因此排序阶段总时间复杂度为 O(n log n)。加上建堆的 O(n)，堆排序总时间复杂度为 O(n log n)。堆排序是不稳定排序。",
      },
      {
        id: "cs101_q46",
        type: "choice",
        stem: "仅允许二元关键字比较来排序 8 个互异元素。比较决策树至少要容纳 8! 个叶子，因此最坏情况下至少需要多少次比较？",
        options: ["A. 15 次", "B. 16 次", "C. 24 次", "D. 32 次"],
        answer: "B",
        explanation:
          "8 个互异元素共有 8!=40320 种排列，深度为 h 的二元比较决策树最多区分 2^h 种结果。因为 2^15=32768<40320<=65536=2^16，所以 h 至少为 ceil(log2(8!))=16；这也是比较排序 Omega(n log n) 下界的具体边界计算。",
      },
    ],
  },

  // ---- 动态规划 ----
  {
    quizId: "quiz_cs101_dp",
    courseId: "cs101",
    topic: "动态规划",
    questions: [
      {
        id: "cs101_q21",
        type: "choice",
        stem: "在 0-1 背包问题中，状态 dp[i][j] 表示前 i 件物品在容量 j 下的最大价值。若第 i 件物品重量为 w[i] 价值为 v[i]，当 j >= w[i] 时状态转移方程为？",
        options: [
          "A. dp[i][j] = dp[i-1][j] + v[i]",
          "B. dp[i][j] = max(dp[i-1][j], dp[i-1][j-w[i]] + v[i])",
          "C. dp[i][j] = dp[i-1][j-w[i]] + v[i]",
          "D. dp[i][j] = max(dp[i][j-1], dp[i-1][j-w[i]] + v[i])",
        ],
        answer: "B",
        explanation:
          "对每件物品有选或不选两种决策。不选第 i 件则 dp[i][j]=dp[i-1][j]；选第 i 件则需容量 j>=w[i] 且 dp[i][j]=dp[i-1][j-w[i]]+v[i]。取两者较大值。一维优化时需逆序更新 j 以避免覆盖。",
      },
      {
        id: "cs101_q22",
        type: "short",
        stem: "简述动态规划适用的两个关键性质，并解释其含义。",
        answer:
          "动态规划适用于具有最优子结构和重叠子问题的问题。最优子结构指问题的最优解由子问题的最优解组合而成；重叠子问题指递归求解时同一子问题被重复计算。DP 通过存储子问题解避免重复计算，将指数级递归降为多项式时间。",
        explanation:
          "最优子结构保证子问题最优解能组合成原问题最优解，是 DP 正确性的基础。重叠子问题意味着递归会重复计算相同子问题，DP 通过缓存（表格法或记忆化）避免重复，将指数复杂度降为多项式。两者缺一不可。",
      },
      {
        id: "cs101_q26",
        type: "choice",
        stem: "最长公共子序列（LCS）问题中，字符串 X 长度为 m、字符串 Y 长度为 n，使用动态规划求解的时间和空间复杂度分别为？",
        options: ["A. O(m+n) 和 O(m+n)", "B. O(m×n) 和 O(m×n)", "C. O(m×n) 和 O(1)", "D. O(2^m) 和 O(m×n)"],
        answer: "B",
        explanation:
          "LCS 使用二维数组 dp[i][j] 表示 X 前 i 个字符与 Y 前 j 个字符的 LCS 长度，每个状态转移为 O(1)，共 m×n 个状态，因此时间和空间均为 O(m×n)。若只需 LCS 长度可用滚动数组将空间优化至 O(min(m,n))，但回溯 LCS 序列仍需完整表格。",
      },
      {
        id: "cs101_q47",
        type: "choice",
        stem: "使用动态规划求解长度为 n 的数组的最长递增子序列（LIS），二维 DP 的时间复杂度为？",
        options: ["A. O(n)", "B. O(n log n)", "C. O(n²)", "D. O(2^n)"],
        answer: "C",
        explanation:
          "LIS 的动态规划解法定义 dp[i] 为以第 i 个元素结尾的最长递增子序列长度，每个状态需遍历前面所有状态比较，共 n 个状态每个 O(n)，总时间复杂度为 O(n²)。使用二分查找优化可将时间复杂度降至 O(n log n)。",
      },
      {
        id: "cs101_q48",
        type: "choice",
        stem: "编辑距离（Levenshtein Distance）问题的动态规划解法中，dp[i][j] 表示什么？",
        options: [
          "A. 字符串 X 的前 i 个字符与字符串 Y 的前 j 个字符之间的最小编辑距离",
          "B. 字符串 X 和 Y 的最长公共子序列长度",
          "C. 字符串 X 的第 i 个字符",
          "D. 字符串 Y 的第 j 个字符",
        ],
        answer: "A",
        explanation:
          "编辑距离的 dp[i][j] 表示将字符串 X 的前 i 个字符转换为字符串 Y 的前 j 个字符所需的最少操作次数（插入、删除、替换）。当 X[i]=Y[j] 时 dp[i][j]=dp[i-1][j-1]；否则取删除、插入、替换三种操作的最小值加 1。时间复杂度为 O(m×n)。",
      },
      {
        id: "cs101_q49",
        type: "choice",
        stem: "在 0-1 背包问题中，将二维 dp 数组优化为一维数组时，内层循环的遍历方向应为？",
        options: ["A. 从小到大（正序）", "B. 从大到小（逆序）", "C. 任意方向均可", "D. 交替方向"],
        answer: "B",
        explanation:
          "0-1 背包问题中，一维优化时必须逆序遍历容量 j，从大到小更新。若正序遍历，dp[j-w[i]] 可能在本轮已更新过（即同一物品被重复使用），违背 0-1 背包每件物品最多选一次的约束。逆序遍历保证 dp[j-w[i]] 引用的是上一轮的值，确保每件物品仅使用一次。",
      },
    ],
  },

  // ---- 哈希表 ----
  {
    quizId: "quiz_cs101_hash",
    courseId: "cs101",
    topic: "哈希表",
    questions: [
      {
        id: "cs101_q23",
        type: "choice",
        stem: "开放地址法解决哈希冲突时，负载因子 α（元素数/表容量）必须满足的条件是？",
        options: [
          "A. α 可以大于 1",
          "B. α 必须小于 1",
          "C. α 必须等于 1",
          "D. α 无任何限制",
        ],
        answer: "B",
        explanation:
          "开放地址法要求表中至少有一个空位供探测使用，因此负载因子必须严格小于 1。当 α 趋近 1 时探测序列急剧增长，性能恶化。实践中常在 α 超过 0.7 时扩容 rehash。链地址法则允许 α 大于 1，因链表可延长。",
      },
      {
        id: "cs101_q50",
        type: "choice",
        stem: "关于哈希冲突，下列说法正确的是？",
        options: [
          "A. 好的哈希函数可以完全避免冲突",
          "B. 冲突是不可避免的，只能尽量减少",
          "C. 冲突说明哈希函数设计错误",
          "D. 只有链地址法才能解决冲突",
        ],
        answer: "B",
        explanation:
          "由于关键字集合通常大于哈希表地址集合，根据鸽巢原理，哈希冲突是不可避免的，只能通过好的哈希函数尽量减少冲突概率。解决冲突的方法包括链地址法（拉链法）和开放地址法（线性探测、二次探测、双重散列等）。选择合适的散列函数和冲突解决策略是哈希表设计的关键。",
      },
      {
        id: "cs101_q51",
        type: "choice",
        stem: "容量为 8 的链地址哈希表使用 h(k)=k mod 8，并按插入顺序把新元素追加到链尾。依次插入 0、8、16、1、9 后，逐一成功查找这 5 个键所需的平均关键字比较次数是？",
        options: ["A. 1 次", "B. 1.5 次", "C. 1.8 次", "D. 2.5 次"],
        answer: "C",
        explanation:
          "键 0、8、16 位于桶 0 的第 1、2、3 个位置，键 1、9 位于桶 1 的第 1、2 个位置，五次成功查找分别比较 1、2、3、1、2 次。平均值为 (1+2+3+1+2)/5=9/5=1.8；这个结果还取决于题设明确的链尾追加与顺序查找规则。",
      },
      {
        id: "cs101_q52",
        type: "choice",
        stem: "哈希表的查找效率主要取决于以下哪个因素？",
        options: [
          "A. 哈希表的长度",
          "B. 哈希函数的类型",
          "C. 装填因子（负载因子）α",
          "D. 关键字的类型",
        ],
        answer: "C",
        explanation:
          "哈希表的查找效率主要取决于装填因子 α=n/m（n 为元素数，m 为表长），而非哈希函数类型或表长本身。α 越小冲突概率越低，查找越快。通常控制 α 在 0.7-0.75 以下，超过阈值时进行扩容 rehash。哈希函数和冲突解决策略也影响性能，但装填因子是决定性因素。",
      },
      {
        id: "cs101_q53",
        type: "choice",
        stem: "开放地址法中，二次探测法的探测序列为？",
        options: [
          "A. H(key), H(key)+1, H(key)+2, ...",
          "B. H(key), H(key)+1², H(key)+2², ...",
          "C. H(key), H(key)-1, H(key)-2, ...",
          "D. H(key), H(key)×2, H(key)×3, ...",
        ],
        answer: "B",
        explanation:
          "二次探测法的探测序列为 H(key)+d_i，其中 d_i = 1², 2², 3², ...（或 ±i²）。二次探测避免了线性探测的聚集（primary clustering）现象，但可能产生二次聚集。注意二次探测不能保证遍历所有表位置，当表长为 4k+3 型质数时才能保证探测到所有位置。",
      },
    ],
  },

  // ---- 堆与优先队列 ----
  {
    quizId: "quiz_cs101_heap",
    courseId: "cs101",
    topic: "堆与优先队列",
    questions: [
      {
        id: "cs101_q24",
        type: "short",
        stem: "解释使用容量为 k 的小顶堆解决 TopK 问题的原理和时间复杂度。",
        answer:
          "维护容量 k 的小顶堆，堆顶为当前 k 个元素的最小值。遍历 n 个元素，堆未满时直接插入；堆满时若当前元素大于堆顶则替换堆顶并下沉调整。最终堆中即最大的 k 个元素。每个元素入堆出堆最多 O(log k)，总时间 O(n log k)，空间 O(k)。",
        explanation:
          "小顶堆堆顶是最小值，大于堆顶的元素才有资格进入 TopK。遍历时堆未满直接插入，堆满时若元素大于堆顶则替换并下沉。每元素操作 O(log k)，总 O(n log k)，远优于全排序的 O(n log n)，适合海量数据。",
      },
      {
        id: "cs101_q27",
        type: "choice",
        stem: "对数组 [3, 1, 6, 5, 2, 4] 执行自底向上的大顶堆建堆（从最后一个非叶子节点开始逐个下沉），最终数组是？",
        options: [
          "A. [6, 5, 4, 1, 2, 3]",
          "B. [6, 3, 5, 1, 2, 4]",
          "C. [6, 5, 3, 4, 2, 1]",
          "D. [5, 3, 6, 1, 2, 4]",
        ],
        answer: "A",
        explanation:
          "从下标 2 开始，6 与孩子 4 已满足堆序；下标 1 的 1 与较大孩子 5 交换，数组变为 [3,5,6,1,2,4]。最后下沉根 3：先与 6 交换，再与其孩子 4 交换，得到 [6,5,4,1,2,3]，每个父节点都不小于孩子。",
      },
      {
        id: "cs101_q54",
        type: "choice",
        stem: "关于大顶堆（最大堆），下列说法正确的是？",
        options: [
          "A. 堆中每个节点的值都大于或等于其子节点的值",
          "B. 堆是一棵平衡二叉搜索树",
          "C. 堆的中序遍历是有序序列",
          "D. 堆的根节点是最小值",
        ],
        answer: "A",
        explanation:
          "大顶堆中每个节点的值都大于或等于其子节点的值，因此根节点是堆中的最大值。堆是一棵完全二叉树，但不是二叉搜索树，中序遍历不一定有序。堆常用于实现优先队列，支持 O(1) 取最值、O(log n) 插入和删除最值。",
      },
      {
        id: "cs101_q55",
        type: "choice",
        stem: "优先队列最适合使用以下哪种数据结构实现？",
        options: ["A. 普通队列", "B. 堆", "C. 哈希表", "D. 链表"],
        answer: "B",
        explanation:
          "优先队列需要频繁插入元素和取出优先级最高（或最低）的元素。堆能在 O(log n) 时间内完成插入和删除最值，O(1) 时间取最值，是优先队列的理想实现。普通队列是 FIFO 结构不支持优先级，链表取最值需 O(n)，哈希表不支持有序操作。",
      },
      {
        id: "cs101_q56",
        type: "choice",
        stem: "向含有 n 个元素的大顶堆中插入一个新元素，最坏情况下的时间复杂度为？",
        options: ["A. O(1)", "B. O(log n)", "C. O(n)", "D. O(n log n)"],
        answer: "B",
        explanation:
          "堆插入操作将新元素放在堆末尾，然后通过上浮（sift-up）操作与父节点比较交换直到满足堆性质。完全二叉树高度为 O(log n)，上浮最多到根节点，因此最坏时间复杂度为 O(log n)。这与堆删除堆顶后的下沉操作复杂度相同。",
      },
      {
        id: "cs101_q57",
        type: "choice",
        stem: "关于堆排序的稳定性，下列说法正确的是？",
        options: [
          "A. 堆排序是稳定排序",
          "B. 堆排序是不稳定排序",
          "C. 堆排序的稳定性取决于堆的类型",
          "D. 堆排序的稳定性取决于数据分布",
        ],
        answer: "B",
        explanation:
          "堆排序是不稳定排序。在堆调整过程中，相等元素可能因为堆结构中的位置交换而改变相对顺序。例如，堆顶元素与末尾元素交换时，相等元素之间的先后关系可能被破坏。堆排序的时间复杂度为 O(n log n)，空间复杂度为 O(1)，但不保证稳定性。",
      },
    ],
  },

  // ---- 最短路径算法 ----
  {
    quizId: "quiz_cs101_shortestpath",
    courseId: "cs101",
    topic: "最短路径算法",
    questions: [
      {
        id: "cs101_q58",
        type: "choice",
        stem: "Dijkstra 最短路径算法适用于以下哪种图？",
        options: [
          "A. 含负权边的有向图",
          "B. 含负权边的无向图",
          "C. 所有边权非负的图",
          "D. 任意带权图",
        ],
        answer: "C",
        explanation:
          "Dijkstra 算法基于贪心策略，要求图中所有边的权值非负。若存在负权边，已确定最短路径的顶点可能通过负权边获得更短路径，破坏贪心假设。对于含负权边的图，应使用 Bellman-Ford 算法。Dijkstra 使用优先队列优化时时间复杂度为 O((V+E) log V)。",
      },
      {
        id: "cs101_q59",
        type: "choice",
        stem: "有向图含边 S->A=4、S->B=1、B->A=2、A->C=1、B->C=5、A->D=7、C->D=3，边权均非负。从 S 运行 Dijkstra 后，d(A)、d(C)、d(D) 依次为？",
        options: ["A. 3、4、7", "B. 4、5、8", "C. 3、6、9", "D. 4、4、7"],
        answer: "A",
        explanation:
          "先确定 B=1，经 B 松弛得到 A=3、C=6；再确定 A=3，把 C 更新为 4、D 更新为 10。确定 C=4 后把 D 更新为 7，因此最终 d(A)、d(C)、d(D) 为 3、4、7；直接边 S->A=4 和 A->D=7 都不是对应终点的最优组合。",
      },
      {
        id: "cs101_q60",
        type: "choice",
        stem: "Floyd-Warshall 算法用于求解图中所有顶点对之间的最短路径，其时间复杂度为？",
        options: ["A. O(V²)", "B. O(V³)", "C. O(V × E)", "D. O(V² × E)"],
        answer: "B",
        explanation:
          "Floyd 算法使用三重循环，对每对顶点 (i,j) 尝试以每个顶点 k 作为中间节点进行松弛，时间复杂度为 O(V³)。Floyd 算法可以处理负权边但不能处理负权回路。与 Dijkstra 求单源最短路径不同，Floyd 一次求出所有顶点对的最短路径。",
      },
      {
        id: "cs101_q61",
        type: "choice",
        stem: "Bellman-Ford 算法相比 Dijkstra 算法的主要优势是？",
        options: [
          "A. 时间复杂度更低",
          "B. 可以处理含负权边的图",
          "C. 可以求所有顶点对的最短路径",
          "D. 不需要任何图存储结构",
        ],
        answer: "B",
        explanation:
          "Bellman-Ford 算法可以处理含负权边的图，而 Dijkstra 不能。Bellman-Ford 通过对所有边进行 V-1 轮松弛操作保证正确性，时间复杂度为 O(VE)。此外，Bellman-Ford 还能检测图中是否存在负权回路：若第 V 轮松弛仍有更新则存在负权回路。",
      },
      {
        id: "cs101_q62",
        type: "choice",
        stem: "在无权图中，求单源最短路径（边数最少）最适合使用的算法是？",
        options: [
          "A. Dijkstra 算法",
          "B. BFS（广度优先搜索）",
          "C. DFS（深度优先搜索）",
          "D. Floyd 算法",
        ],
        answer: "B",
        explanation:
          "无权图中每条边权值为 1，BFS 按层扩展，首次到达某顶点的路径即为最短路径（边数最少），时间复杂度为 O(V+E)。DFS 不保证找到最短路径。Dijkstra 虽然也能求无权图最短路径但更复杂。因此无权图最短路径问题直接用 BFS 即可。",
      },
    ],
  },

  // ---- 贪心算法与分治 ----
  {
    quizId: "quiz_cs101_greedy",
    courseId: "cs101",
    topic: "贪心算法与分治",
    questions: [
      {
        id: "cs101_q63",
        type: "choice",
        stem: "贪心算法中，使当前局部最优选择能够扩展为整体最优解的核心性质是？",
        options: ["A. 重叠子问题", "B. 贪心选择性质", "C. 无后效性", "D. 对称性"],
        answer: "B",
        explanation:
          "贪心选择性质是指整体最优解可由一系列局部最优选择构成，这是贪心算法正确性的核心依据。可用贪心法得到全局最优通常还需要最优子结构；重叠子问题则是动态规划常利用的性质。",
      },
      {
        id: "cs101_q64",
        type: "choice",
        stem: "关于贪心算法和动态规划的比较，下列说法正确的是？",
        options: [
          "A. 贪心算法一定能得到最优解",
          "B. 动态规划一定能得到最优解但贪心不一定",
          "C. 贪心算法的时间复杂度一定高于动态规划",
          "D. 两者完全等价",
        ],
        answer: "B",
        explanation:
          "动态规划通过考虑所有子问题的最优解组合来保证全局最优，因此能求得最优解。贪心算法只做局部最优选择且不回退，仅当问题具有贪心选择性质时才能得到最优解。贪心算法通常更高效，但不保证所有问题都能得到最优解。0-1 背包问题适合 DP 而非贪心。",
      },
      {
        id: "cs101_q65",
        type: "choice",
        stem: "分治法的三个基本步骤是？",
        options: [
          "A. 分解、解决、合并",
          "B. 划分、排序、合并",
          "C. 递归、回溯、剪枝",
          "D. 选择、迭代、终止",
        ],
        answer: "A",
        explanation:
          "分治法的三个基本步骤为：分解（将原问题分解为若干规模更小的子问题）、解决（递归求解子问题，足够小时直接求解）、合并（将子问题的解合并为原问题的解）。归并排序和快速排序是分治法的典型应用。分治法的效率取决于子问题规模和合并代价。",
      },
      {
        id: "cs101_q66",
        type: "choice",
        stem: "分治法中，若问题规模为 n 的递推关系为 T(n) = 2T(n/2) + O(n)，则时间复杂度为？",
        options: ["A. O(n)", "B. O(n log n)", "C. O(n²)", "D. O(2^n)"],
        answer: "B",
        explanation:
          "根据主定理（Master Theorem），T(n) = aT(n/b) + O(n^d)，当 a=2, b=2, d=1 时 a = b^d，属于第二种情况，时间复杂度为 O(n^d log n) = O(n log n)。归并排序的递推关系正是 T(n)=2T(n/2)+O(n)，时间复杂度为 O(n log n)。",
      },
      {
        id: "cs101_q67",
        type: "choice",
        stem: "以下问题中，适合使用贪心算法求解最优解的是？",
        options: [
          "A. 0-1 背包问题",
          "B. 活动选择（区间调度）问题",
          "C. 旅行商问题（TSP）",
          "D. 编辑距离问题",
        ],
        answer: "B",
        explanation:
          "活动选择问题具有贪心选择性质，按活动结束时间排序后每次选择结束最早且不冲突的活动即可得到最优解。0-1 背包问题不具备贪心选择性质，需用动态规划。旅行商问题是 NP 困难问题，贪心只能求近似解。编辑距离问题适合动态规划求解。",
      },
    ],
  },
]);

// ===========================================================================
// CS102 操作系统（共 57 题：50 选择 + 7 简答）
// ===========================================================================

export const cs102Quizzes: Quiz[] = withQuizMetadata([
  // ---- 进程与线程 ----
  {
    quizId: "quiz_cs102_process",
    courseId: "cs102",
    topic: "进程与线程",
    questions: [
      {
        id: "cs102_q01",
        type: "choice",
        stem: "关于进程和线程的区别，下列说法正确的是？",
        options: [
          "A. 线程是资源分配的基本单位，进程是调度的基本单位",
          "B. 进程是资源分配的基本单位，线程是 CPU 调度的基本单位",
          "C. 进程和线程都是资源分配的基本单位",
          "D. 线程拥有独立的地址空间",
        ],
        answer: "B",
        explanation:
          "进程是资源分配的基本单位，拥有独立的地址空间和资源；线程是 CPU 调度的基本单位，同一进程内的线程共享地址空间和资源。线程切换开销小于进程切换，因无需切换地址空间和页表。",
      },
      {
        id: "cs102_q02",
        type: "choice",
        stem: "一个进程从运行态转换为就绪态，可能的原因是？",
        options: [
          "A. 等待 I/O 操作完成",
          "B. 时间片用完被抢占",
          "C. 进程执行完毕",
          "D. 创建新子进程",
        ],
        answer: "B",
        explanation:
          "运行态到就绪态的转换发生在时间片用完或被高优先级进程抢占时。等待 I/O 会从运行态转为阻塞态；执行完毕则转为终止态。时间片轮转调度中进程在运行态和就绪态间频繁切换以实现公平调度。",
      },
      {
        id: "cs102_q03",
        type: "short",
        stem: "为什么线程切换的开销通常小于进程切换？",
        answer:
          "线程切换在同一进程内进行，共享地址空间、页表和资源，无需切换页表和刷新 TLB，仅保存恢复寄存器和栈指针。进程切换需切换页表、刷新 TLB、更新内存管理单元，开销显著更大。但同一进程内线程切换仍需保存恢复 CPU 上下文。",
        explanation:
          "线程共享进程地址空间和页表，切换时无需切换页表和刷新 TLB，仅保存恢复寄存器和栈。进程切换需更换页表、刷新 TLB、切换资源描述符，内存管理开销大。因此线程切换上下文更轻量，开销更小。",
      },
      {
        id: "cs102_q24",
        type: "choice",
        stem: "进程控制块（PCB）中不包含以下哪项信息？",
        options: ["A. 进程标识符（PID）", "B. 进程状态和优先级", "C. CPU 寄存器现场", "D. 源程序代码"],
        answer: "D",
        explanation:
          "PCB 存储进程的管理信息，包括进程标识符、状态、优先级、CPU 寄存器现场、内存指针、打开文件表等。源程序代码存储在代码段中，是程序本身的静态内容，不属于 PCB 的管理信息。PCB 是操作系统感知和管理进程存在的核心数据结构。",
      },
      {
        id: "cs102_q28",
        type: "choice",
        stem: "一个进程从阻塞态转换为就绪态，可能的原因是？",
        options: ["A. 时间片用完", "B. 等待的 I/O 操作完成", "C. 进程被调度执行", "D. 进程主动放弃 CPU"],
        answer: "B",
        explanation:
          "阻塞态到就绪态的转换发生在进程等待的事件（如 I/O 完成、信号量释放）发生时。时间片用完是运行态到就绪态的转换。进程被调度执行是从就绪态到运行态。阻塞态的进程不占用 CPU，当等待条件满足后被唤醒转为就绪态等待调度。",
      },
      {
        id: "cs102_q29",
        type: "choice",
        stem: "一个进程有 3 个始终可运行的用户线程 U1、U2、U3，运行在 4 核系统上；随后 U1 发起阻塞系统调用。实现 X 把三个用户线程映射到同一个内核线程，实现 Y 为每个用户线程各映射一个内核线程。忽略其他负载，哪项判断正确？",
        options: [
          "A. X 中 U2、U3 可在另外两核并行；Y 中三个线程都会随 U1 阻塞",
          "B. X 中整个进程会因唯一内核线程阻塞且不能多核并行；Y 中 U2、U3 可在 U1 阻塞期间并行运行",
          "C. X 和 Y 都只能使用一个 CPU 核，因为三个线程共享同一地址空间",
          "D. X 和 Y 中三个线程都会阻塞，因为系统调用属于进程级操作",
        ],
        answer: "B",
        explanation:
          "X 是 many-to-one：多个用户线程共享唯一内核线程，一个线程进入阻塞系统调用会使该内核线程阻塞，而且该映射无法让多个用户线程同时运行在多核上。Y 是 one-to-one：U1 对应的内核线程阻塞不妨碍 U2、U3 对应的内核线程被其他核心调度，代价是创建和管理更多内核线程。",
      },
    ],
  },

  // ---- CPU调度算法 ----
  {
    quizId: "quiz_cs102_schedule",
    courseId: "cs102",
    topic: "CPU调度算法",
    questions: [
      {
        id: "cs102_q04",
        type: "choice",
        stem: "采用最短剩余时间优先（SRTF）调度，忽略上下文切换开销。P1、P2、P3、P4 的（到达时间，CPU 执行时间）依次为（0，8）、（1，4）、（2，9）、（3，5）。完成顺序与平均等待时间分别是？",
        options: [
          "A. P2 -> P4 -> P1 -> P3，6.5",
          "B. P2 -> P4 -> P1 -> P3，5.5",
          "C. P2 -> P1 -> P4 -> P3，6.5",
          "D. P1 -> P2 -> P4 -> P3，7.0",
        ],
        answer: "A",
        explanation:
          "SRTF 在每次新进程到达时比较剩余时间：P1 先运行 1 个时间单位，P2 到达后以 4 < 7 抢占；P2 随后完成，再依次运行 P4、P1、P3，完成顺序为 P2、P4、P1、P3。四个进程的等待时间分别为 9、0、15、2，平均等待时间为 (9+0+15+2)/4=6.5。",
      },
      {
        id: "cs102_q05",
        type: "choice",
        stem: "时间片轮转（RR）调度中，时间片大小对系统性能的影响是？",
        options: [
          "A. 时间片越大，响应越快，系统开销越小",
          "B. 时间片越大，响应越慢，系统开销越小",
          "C. 时间片越小，响应越快，但上下文切换开销增大",
          "D. 时间片大小不影响系统性能",
        ],
        answer: "C",
        explanation:
          "时间片越小，每个进程更快获得 CPU，响应越快，但上下文切换频率增高，系统开销增大。时间片过大则退化为 FCFS，响应变慢。时间片选择需平衡响应时间和切换开销，通常设为 10 至 100 毫秒。",
      },
      {
        id: "cs102_q06",
        type: "short",
        stem: "简述多级反馈队列（MLFQ）调度的基本思想。",
        answer:
          "MLFQ 设置多个不同优先级的就绪队列，高优先级队列时间片短，低优先级时间片长。新进程进入最高优先级队列，用完时间片后降入下一级队列。I/O 密集型进程因频繁阻塞留在高优先级获得快速响应，CPU 密集型进程逐渐降级以较长时间片运行。兼顾响应时间和吞吐量。",
        explanation:
          "MLFQ 通过多个优先级队列和时间片递增实现自适应调度。新进程从高优先级短时间片开始，CPU 密集型进程逐渐降级获得更长执行时间。I/O 密集型进程因频繁阻塞而保持高优先级，获得快速响应。兼顾交互响应和 CPU 利用率。",
      },
      {
        id: "cs102_q30",
        type: "choice",
        stem: "先来先服务（FCFS）调度算法的主要缺点是？",
        options: [
          "A. 实现过于复杂",
          "B. 可能导致长作业阻塞短作业（护航效应）",
          "C. 无法用于单处理器系统",
          "D. 不支持非抢占式调度",
        ],
        answer: "B",
        explanation:
          "FCFS 按进程到达顺序调度，若一个长作业先到达，后续的短作业需长时间等待，称为护航效应（convoy effect），导致平均等待时间较长。FCFS 实现简单且无饥饿，但响应时间差，不适合交互式系统。FCFS 是非抢占式调度算法。",
      },
      {
        id: "cs102_q31",
        type: "choice",
        stem: "在优先级调度中，解决低优先级进程饥饿问题的常用方法是？",
        options: [
          "A. 增加进程数量",
          "B. 老化（Aging）技术，随时间推移逐渐提高等待进程的优先级",
          "C. 禁止使用高优先级",
          "D. 缩短时间片",
        ],
        answer: "B",
        explanation:
          "老化技术通过随时间推移逐渐提高等待进程的优先级来解决饥饿问题。等待时间越长优先级越高，最终能被调度执行。这种方法兼顾了优先级调度的灵活性和公平性。优先级调度分为静态优先级（创建时确定不变）和动态优先级（运行时可调整，老化即属此类）。",
      },
      {
        id: "cs102_q32",
        type: "choice",
        stem: "高响应比优先（HRRN）调度算法的响应比计算公式为？",
        options: [
          "A. 响应比 = 服务时间 / 等待时间",
          "B. 响应比 = （等待时间 + 服务时间）/ 服务时间",
          "C. 响应比 = 等待时间 / 服务时间",
          "D. 响应比 = 服务时间 × 等待时间",
        ],
        answer: "B",
        explanation:
          "高响应比优先算法的响应比 R = (等待时间 + 要求服务时间) / 要求服务时间。该算法兼顾了短作业（服务时间短则比值大）和长作业（等待时间长则比值增大），既偏向短作业又防止长作业饥饿。HRRN 是非抢占式调度，每次调度时选择响应比最高的进程。",
      },
    ],
  },

  // ---- 内存管理基础 ----
  {
    quizId: "quiz_cs102_memory",
    courseId: "cs102",
    topic: "内存管理基础",
    questions: [
      {
        id: "cs102_q07",
        type: "choice",
        stem: "在可变分区存储管理中，首次适应（First-Fit）算法的分配策略是？",
        options: [
          "A. 从空闲分区表中找到满足要求的最小分区进行分配",
          "B. 从空闲分区表的第一个分区开始查找，找到第一个满足要求的分区进行分配",
          "C. 从空闲分区表的最后一个分区开始查找",
          "D. 将所有空闲分区合并后分配",
        ],
        answer: "B",
        explanation:
          "首次适应算法从空闲分区链表头部开始顺序查找，将第一个满足大小要求的空闲分区分配给进程。优点是算法简单、分配速度快，且高地址空间保留大分区。最佳适应找最小合适分区，最差适应找最大分区。",
      },
      {
        id: "cs102_q08",
        type: "choice",
        stem: "关于内存碎片，下列说法正确的是？",
        options: [
          "A. 内部碎片是分区外部未被利用的空间，外部碎片是分区内部浪费的空间",
          "B. 外部碎片是分区之间因太小无法利用的空闲空间，内部碎片是分配的分区内部浪费的空间",
          "C. 紧凑技术可以消除内部碎片",
          "D. 分页机制会产生大量外部碎片",
        ],
        answer: "B",
        explanation:
          "外部碎片是空闲分区之间因太小无法分配利用的空间；内部碎片是已分配分区内部未被使用的空间。紧凑技术通过移动进程合并空闲分区消除外部碎片，但不能消除内部碎片。分页机制消除了外部碎片但可能产生少量内部碎片。",
      },
      {
        id: "cs102_q09",
        type: "short",
        stem: "比较分页机制和分段机制的主要区别。",
        answer:
          "分页将内存划分为固定大小的页框，按物理地址划分，用户不可见，消除外部碎片但有内部碎片。分段按逻辑单位（如函数、数组）划分，大小不固定，用户可见，便于共享和保护但可能产生外部碎片。分页面向硬件管理，分段面向用户逻辑。",
        explanation:
          "分页以固定大小页为单位，由系统自动管理，消除外部碎片但页内可能有内部碎片。分段以逻辑段为单位，大小可变，便于编程和共享保护，但可能产生外部碎片需紧凑。现代系统采用段页式结合两者优点。",
      },
      {
        id: "cs102_q33",
        type: "choice",
        stem: "在分页存储管理中，将逻辑地址转换为物理地址需要以下哪个数据结构？",
        options: ["A. 页表", "B. 段表", "C. 文件分配表", "D. 进程控制块"],
        answer: "A",
        explanation:
          "分页存储管理中，页表记录了逻辑页号到物理页框号的映射关系。地址转换时，逻辑地址分为页号和页内偏移，通过页号查页表得到物理页框号，再与页内偏移拼接成物理地址。TLB 缓存常用页表项以加速转换。分页消除了外部碎片但可能有少量内部碎片。",
      },
      {
        id: "cs102_q34",
        type: "choice",
        stem: "在可变分区分配中，最佳适应（Best-Fit）算法的分配策略是？",
        options: [
          "A. 将第一个满足要求的空闲分区分配",
          "B. 将满足要求的最小空闲分区分配",
          "C. 将满足要求的最大空闲分区分配",
          "D. 将所有空闲分区合并后分配",
        ],
        answer: "B",
        explanation:
          "最佳适应算法在所有满足大小要求的空闲分区中选择最小的一个进行分配，旨在尽量保留大的空闲分区。最佳适应的缺点是分配后剩余的小碎片通常太小无法利用，产生大量外部碎片。首次适应选第一个满足要求的分区，最差适应选最大的分区。",
      },
      {
        id: "cs102_q35",
        type: "choice",
        stem: "某进程逻辑地址空间实际使用 10000 字节。方案甲页大小为 4096 字节，方案乙页大小为 2048 字节，每个页表项均占 8 字节。只计算已用逻辑页对应的页表项，不把页表自身再按页框取整。若总开销=最后一页内部碎片+页表项字节数，哪项正确？",
        options: [
          "A. 甲为 2288 字节，乙为 240 字节；乙少 2048 字节",
          "B. 甲为 2312 字节，乙为 280 字节；乙少 2032 字节",
          "C. 甲为 2312 字节，乙为 280 字节；甲少 2032 字节",
          "D. 甲为 24 字节，乙为 40 字节；甲少 16 字节",
        ],
        answer: "B",
        explanation:
          "方案甲需 ceil(10000/4096)=3 页，内部碎片为 3*4096-10000=2288 字节，页表项占 3*8=24 字节，总开销 2312 字节。方案乙需 5 页，内部碎片为 240 字节，页表项占 40 字节，总开销 280 字节，因此乙比甲少 2032 字节；只算碎片或只算页表都会得到干扰项。",
      },
    ],
  },

  // ---- 虚拟内存与分页 ----
  {
    quizId: "quiz_cs102_vm",
    courseId: "cs102",
    topic: "虚拟内存与分页",
    questions: [
      {
        id: "cs102_q10",
        type: "choice",
        stem: "TLB（Translation Lookaside Buffer）的作用是？",
        options: [
          "A. 缓存磁盘数据以加速 I/O",
          "B. 缓存最近访问的页表项，加速虚拟地址到物理地址的转换",
          "C. 存储中断向量表",
          "D. 管理虚拟内存的页面置换",
        ],
        answer: "B",
        explanation:
          "TLB 是页表的高速缓存（cache），存储最近使用的虚拟页号到物理页框号的映射。CPU 访存时先查 TLB，命中则直接获得物理地址无需访问内存中的页表，大幅降低地址转换开销。TLB 缺失则需多次访问内存页表。",
      },
      {
        id: "cs102_q11",
        type: "choice",
        stem: "LRU 页面置换算法的基本思想是？",
        options: [
          "A. 淘汰最近最少使用的页面",
          "B. 淘汰最近最久未使用的页面",
          "C. 淘汰最先进入内存的页面",
          "D. 随机淘汰一个页面",
        ],
        answer: "B",
        explanation:
          "LRU（Least Recently Used）淘汰最长时间未被访问的页面，基于局部性原理认为最近未使用的页面将来也不太可能被使用。实现需维护页面访问时间戳或使用栈结构。LRU 性能接近理想置换算法 OPT，但实现开销较大。",
      },
      {
        id: "cs102_q12",
        type: "short",
        stem: "什么是工作集？它在虚拟内存管理中的作用是什么？",
        answer:
          "工作集是进程在某段时间间隔内频繁访问的页面集合，反映了进程当前的内存需求。工作集模型用于指导驻留集大小：若分配的物理页框数小于工作集大小则产生频繁缺页（抖动）。操作系统通过监控工作集调整驻留集，防止抖动并保持系统吞吐量。",
        explanation:
          "工作集是进程在时间窗口内访问的页面集合，反映程序局部性。若物理页框不足以容纳工作集会导致频繁缺页中断即抖动，系统吞吐量急剧下降。操作系统通过调整驻留集大小匹配工作集来防止抖动，保障系统性能。",
      },
      {
        id: "cs102_q25",
        type: "choice",
        stem: "对页面引用串 1、2、3、4、1、2、5、1、2、3、4、5 使用 FIFO 页面置换，初始页框均为空。分配 3 个页框和 4 个页框时的缺页次数，以及能否据此判定 Belady 异常，哪项正确？",
        options: [
          "A. 3 个页框 9 次，4 个页框 8 次；未出现 Belady 异常",
          "B. 3 个页框 9 次，4 个页框 10 次；出现 Belady 异常",
          "C. 3 个页框 10 次，4 个页框 9 次；未出现 Belady 异常",
          "D. 3 个页框 10 次，4 个页框 10 次；页框数不影响缺页次数",
        ],
        answer: "B",
        explanation:
          "按 FIFO 队列逐次推进，3 个页框时在 1、2、3、4、1、2、5、3、4 处发生缺页，共 9 次；4 个页框时除最初装入外，后半段 5、1、2、3、4、5 连续触发置换，共 10 次。页框从 3 增至 4 后缺页次数反而从 9 增至 10，这正是 Belady 异常，不能只凭定义作答而必须完成两轮状态模拟。",
      },
      {
        id: "cs102_q36",
        type: "choice",
        stem: "在请求分页系统中，当 CPU 访问的页面不在内存中时，会产生什么事件？",
        options: ["A. 时钟中断", "B. 缺页中断", "C. 硬件故障", "D. 系统调用"],
        answer: "B",
        explanation:
          "请求分页系统中，当 CPU 访问的页面不在物理内存中（有效位为 0）时，硬件产生缺页中断，操作系统响应中断将该页面从磁盘调入内存。若内存已满则需通过页面置换算法选择淘汰页面。缺页中断属于内部异常（trap），处理过程包括保存现场、调入页面、更新页表、恢复现场。",
      },
      {
        id: "cs102_q37",
        type: "choice",
        stem: "理想页面置换算法（OPT）淘汰的是以下哪种页面？",
        options: [
          "A. 最先进入内存的页面",
          "B. 最近最久未使用的页面",
          "C. 未来最长时间不会被访问的页面",
          "D. 访问频率最低的页面",
        ],
        answer: "C",
        explanation:
          "OPT（最优页面置换）算法淘汰未来最长时间不会被访问的页面，理论上可获得最低缺页率，但需要预知未来的页面访问序列，实际无法实现。OPT 常作为评价其他置换算法性能的理论基准。FIFO 淘汰最先进入的页面，LRU 淘汰最近最久未使用的页面。",
      },
    ],
  },

  // ---- 文件系统 ----
  {
    quizId: "quiz_cs102_fs",
    courseId: "cs102",
    topic: "文件系统",
    questions: [
      {
        id: "cs102_q13",
        type: "choice",
        stem: "初始时 `/lab/a` 是指向 inode 42 的唯一目录项，硬链接计数为 1。以下操作均成功：`link(\"/lab/a\", \"/lab/b\")`；`fd=open(\"/lab/b\")`；`unlink(\"/lab/a\")`；`unlink(\"/lab/b\")`。在 `close(fd)` 之前，哪项描述正确？",
        options: [
          "A. `/lab/a` 和 `/lab/b` 都不存在，inode 42 已立即回收，fd 失效",
          "B. `/lab/a` 仍存在，硬链接计数为 1，fd 有效",
          "C. `/lab/b` 仍存在，硬链接计数为 1，fd 有效",
          "D. 两个路径都不存在，硬链接计数为 0，但 fd 仍可访问文件内容；最后引用关闭后才可回收",
        ],
        answer: "D",
        explanation:
          "link 先把 inode 42 的硬链接计数从 1 增至 2，两次 unlink 又依次删除两个目录项并把计数降至 0，所以两个路径都无法再解析。打开文件描述符仍持有对该文件的引用，文件内容的回收要推迟到最后一个打开引用关闭之后，因而 close(fd) 前 fd 仍有效。",
      },
      {
        id: "cs102_q14",
        type: "choice",
        stem: "在文件系统的连续分配策略中，主要缺点是？",
        options: [
          "A. 随机访问效率低",
          "B. 文件大小难以动态增长，容易产生外部碎片",
          "C. 目录管理复杂",
          "D. 不支持顺序访问",
        ],
        answer: "B",
        explanation:
          "连续分配将文件数据存储在连续的磁盘块中，顺序访问和随机访问效率高，但文件大小固定后难以动态扩展。删除文件后产生的外部碎片难以利用，需要紧凑整理。链接分配和索引分配解决了此问题但牺牲了随机访问性能。",
      },
      {
        id: "cs102_q15",
        type: "short",
        stem: "比较硬链接和软链接（符号链接）的区别。",
        answer:
          "硬链接是多个目录项指向同一个 inode，共享文件数据，删除原文件名后硬链接仍可访问数据，但不能跨文件系统且不能链接目录。软链接是一个特殊文件存储目标路径，删除原文件后软链接变为悬空指针，但可跨文件系统且可链接目录。",
        explanation:
          "硬链接与原文件共享同一 inode，删除任一链接不影响其他链接访问数据，但限制在同一文件系统内。软链接存储目标路径字符串，原文件删除后变悬空，但灵活支持跨文件系统和目录链接。硬链接节省空间，软链接更灵活。",
      },
      {
        id: "cs102_q38",
        type: "choice",
        stem: "在文件系统的索引分配方式中，文件数据块的位置存储在哪里？",
        options: [
          "A. 文件目录项中直接存储所有数据块地址",
          "B. 索引块中存储所有数据块地址",
          "C. 数据块本身包含下一块地址",
          "D. 文件名中隐含块地址",
        ],
        answer: "B",
        explanation:
          "索引分配方式为每个文件建立索引块，索引块中存储该文件所有数据块的地址。索引分配支持随机访问，文件可动态增长。对于大文件可采用多级索引或链接索引。UNIX inode 采用多级索引结构：直接地址、一级间接、二级间接、三级间接索引，兼顾小文件和大文件的访问效率。",
      },
      {
        id: "cs102_q39",
        type: "choice",
        stem: "在树形目录结构中，不同目录下的文件是否允许同名？",
        options: [
          "A. 不允许，文件名必须全局唯一",
          "B. 允许，只要在同一目录下不同名即可",
          "C. 只允许在子目录中同名",
          "D. 由文件系统决定，无固定规则",
        ],
        answer: "B",
        explanation:
          "树形目录结构中，文件由路径名唯一标识，不同目录下的文件允许同名。文件的绝对路径从根目录开始，唯一确定文件位置。树形目录便于文件分类管理和共享，是现代文件系统（如 UNIX、Windows）的标准目录结构。相对路径则从当前工作目录开始。",
      },
      {
        id: "cs102_q40",
        type: "choice",
        stem: "为提高文件系统性能，将最近访问的文件数据块缓存在内存中的技术称为？",
        options: [
          "A. 预读（Read-ahead）",
          "B. 缓冲区缓存（Buffer Cache）",
          "C. 日志（Journaling）",
          "D. 压缩（Compression）",
        ],
        answer: "B",
        explanation:
          "缓冲区缓存将最近访问的磁盘数据块缓存在内存中，利用局部性原理减少磁盘 I/O 次数。读操作先查缓存命中则直接返回，未命中则从磁盘读取并缓存。写操作可采用写缓存（延迟写）或写穿策略。现代操作系统还结合预读技术提前读取相邻数据块进一步提升性能。",
      },
    ],
  },

  // ---- 死锁 ----
  {
    quizId: "quiz_cs102_deadlock",
    courseId: "cs102",
    topic: "死锁",
    questions: [
      {
        id: "cs102_q16",
        type: "choice",
        stem: "产生死锁的四个必要条件中，不包括以下哪一项？",
        options: [
          "A. 互斥条件",
          "B. 占有并等待",
          "C. 先来先服务",
          "D. 循环等待",
        ],
        answer: "C",
        explanation:
          "死锁的四个必要条件是：互斥（资源不可共享）、占有并等待（持有资源并请求新资源）、非抢占（资源不能被强制剥夺）、循环等待（存在进程间资源的循环等待链）。先来先服务是调度算法，不是死锁条件。破坏任一条件即可预防死锁。",
      },
      {
        id: "cs102_q17",
        type: "choice",
        stem: "银行家算法用于？",
        options: [
          "A. 死锁预防",
          "B. 死锁避免",
          "C. 死锁检测",
          "D. 死锁恢复",
        ],
        answer: "B",
        explanation:
          "银行家算法是死锁避免策略，在资源分配前检查分配后系统是否处于安全状态（存在安全序列使所有进程能顺利完成）。若安全则分配，否则让进程等待。它允许存在死锁可能的状态但通过预检查避免进入不安全状态，比死锁预防资源利用率更高。",
      },
      {
        id: "cs102_q18",
        type: "short",
        stem: "比较死锁预防和死锁避免的区别。",
        answer:
          "死锁预防通过破坏四个必要条件之一来保证不发生死锁，如破坏循环等待（资源有序分配），是静态策略资源利用率低。死锁避免在运行时动态检查资源分配是否安全（如银行家算法），允许存在死锁可能但不进入不安全状态，资源利用率更高但需预知最大需求。",
        explanation:
          "死锁预防是静态策略，在系统设计时破坏死锁必要条件（如资源有序分配破坏循环等待），简单但资源利用率低。死锁避免在运行时动态评估每次分配的安全性，允许更多资源分配状态但需预先知道进程最大资源需求，开销较大但利用率更高。",
      },
      {
        id: "cs102_q26",
        type: "choice",
        stem: "资源 A 有 2 个实例，资源 B 有 1 个实例。当前 P1 持有 1 个 A 并请求 1 个 B；P2 持有 1 个 B 并请求 1 个 A；P3 持有另 1 个 A 且不再请求资源。当前 Available(A,B)=(0,0)。对该状态的判断哪项正确？",
        options: [
          "A. 已死锁，因为资源分配图中 P1->B->P2->A->P1 构成环",
          "B. 未死锁，可按 P1->P2->P3 的顺序完成",
          "C. 已死锁，因为 Available 的两个分量都为 0",
          "D. 未死锁，可按 P3->P2->P1 的顺序完成",
        ],
        answer: "D",
        explanation:
          "P3 不再请求资源，可以先完成并释放 1 个 A；P2 随后取得 A、完成并释放 A 和 B，最后 P1 取得 B 完成，因此存在 P3->P2->P1 的完成序列。资源类型存在多个实例时，资源分配图有环只表示可能死锁，并非充分条件；只看环或 Available=(0,0) 都会误判。",
      },
      {
        id: "cs102_q41",
        type: "choice",
        stem: "通过资源有序分配策略来预防死锁，破坏的是死锁四个必要条件中的哪一个？",
        options: ["A. 互斥条件", "B. 占有并等待", "C. 非抢占条件", "D. 循环等待"],
        answer: "D",
        explanation:
          "资源有序分配策略要求所有资源按序编号，进程必须按序号递增顺序申请资源，从而破坏循环等待条件。由于资源按序申请，不可能形成资源的循环等待链。该方法实现简单但可能降低资源利用率，因进程可能需要先申请暂不需要的低序号资源。",
      },
      {
        id: "cs102_q42",
        type: "choice",
        stem: "死锁检测算法主要适用于以下哪种情况？",
        options: [
          "A. 死锁很少发生且允许死锁发生后处理",
          "B. 死锁频繁发生必须严格预防",
          "C. 系统不允许任何资源竞争",
          "D. 所有资源只有一个实例",
        ],
        answer: "A",
        explanation:
          "死锁检测算法允许系统进入不安全状态，定期运行检测算法判断是否发生死锁，若检测到死锁则通过终止进程或抢占资源恢复。这种方法适用于死锁发生概率较低的场景，避免了死锁预防和避免带来的资源利用率降低。检测开销和恢复代价是其主要考虑因素。",
      },
    ],
  },

  // ---- 同步与互斥 ----
  {
    quizId: "quiz_cs102_sync",
    courseId: "cs102",
    topic: "同步与互斥",
    questions: [
      {
        id: "cs102_q19",
        type: "choice",
        stem: "若信号量 S 的初始值为 3，经过操作 P(S)、P(S)、V(S)、P(S) 后，S 的值为？",
        options: ["A. 0", "B. 1", "C. 2", "D. 3"],
        answer: "B",
        explanation:
          "P 操作（wait）将信号量减 1，V 操作（signal）将信号量加 1。初始 S=3，经 P 后 S=2，再 P 后 S=1，V 后 S=2，最后 P 后 S=1。P 操作在 S 为 0 时阻塞进程，V 操作在 S 从负值变为正值时唤醒阻塞进程。",
      },
      {
        id: "cs102_q20",
        type: "choice",
        stem: "在生产者-消费者问题中，用于控制缓冲区空位的信号量应初始化为？",
        options: ["A. 0", "B. 1", "C. 缓冲区容量 N", "D. -N"],
        answer: "C",
        explanation:
          "空位信号量 empty 表示缓冲区可用空位数，初始化为缓冲区容量 N。生产者 P(empty) 获取空位放入产品后 V(full) 增加产品数。满位信号量 full 初始化为 0，消费者 P(full) 获取产品后 V(empty) 释放空位。互斥信号量 mutex 初始化为 1。",
      },
      {
        id: "cs102_q21",
        type: "short",
        stem: "比较互斥锁和自旋锁的区别及其适用场景。",
        answer:
          "互斥锁在获取失败时将线程投入睡眠，释放 CPU 给其他线程，适用于临界区较长或持有锁时间不确定的场景，避免 CPU 空转。自旋锁在获取失败时忙等待不断检测锁状态，适用于临界区极短且多核 CPU 的场景，避免线程切换开销。单核 CPU 上自旋锁无意义。",
        explanation:
          "互斥锁失败时线程阻塞睡眠，由操作系统调度切换，适合长时间持有锁的场景避免 CPU 空转。自旋锁失败时忙等待不释放 CPU，适合极短临界区且多核环境，避免上下文切换开销。单核环境下自旋锁浪费 CPU 且无法推进，应使用互斥锁。",
      },
      {
        id: "cs102_q43",
        type: "choice",
        stem: "5 位哲学家 Pi 的左筷子为 Ci，右筷子为 C(i+1) mod 5。每人依次 wait(room)、wait(左筷子)、wait(右筷子)，进餐后逆序释放；room 初值为 4。某时刻 P0～P3 已通过 room 并分别持有 C0～C3，P4 阻塞在 room。下一步及该方案性质的判断哪项正确？",
        options: [
          "A. P0 可取得右筷子 C1；该方案同时保证无死锁和无饥饿",
          "B. P4 可取得右筷子 C0；该方案只避免饥饿",
          "C. P3 可取得右筷子 C4；该方案避免死锁，但公平性不足时仍可能饥饿",
          "D. P0～P3 都无法取得右筷子；系统已经死锁",
        ],
        answer: "C",
        explanation:
          "P4 尚未取得 C4，因此 P3 的右筷子 C4 空闲，P3 能继续进餐并释放资源；这会打破五人同时各持一根筷子的循环等待。room=N-1 能保证至少一位已入场哲学家推进，从而避免死锁，但若 room 或筷子信号量不公平，并不自动保证每位哲学家最终都能进餐。",
      },
      {
        id: "cs102_q44",
        type: "choice",
        stem: "解决进程互斥问题的临界区管理中，下列哪项不是临界区管理的必要条件？",
        options: [
          "A. 互斥条件：任一时刻最多一个进程在临界区内",
          "B. 空闲让进：临界区空闲时应允许等待进程进入",
          "C. 有限等待：等待进程应在有限时间内进入临界区",
          "D. 优先级调度：高优先级进程必须先进入临界区",
        ],
        answer: "D",
        explanation:
          "临界区管理的四个必要条件是：互斥（任一时刻最多一个进程在临界区内）、空闲让进（临界区空闲时允许等待进程进入）、有限等待（进程等待进入临界区的时间有限）、让权等待（不能进入时应释放 CPU 避免忙等）。优先级调度不是临界区管理的必要条件。",
      },
      {
        id: "cs102_q45",
        type: "choice",
        stem: "记录型信号量中，当 P 操作发现 S.value < 0 时，进程会？",
        options: [
          "A. 继续执行",
          "B. 进入阻塞队列并调用 block 原语阻塞自己",
          "C. 终止执行",
          "D. 自动重试 P 操作",
        ],
        answer: "B",
        explanation:
          "记录型信号量的 P 操作将 S.value 减 1，若减后 S.value < 0 则表示资源不足，进程调用 block 原语进入 S 的阻塞队列等待。V 操作将 S.value 加 1，若加后 S.value <= 0 则从阻塞队列唤醒一个进程（wakeup 原语）。负值的绝对值表示阻塞队列中的进程数。记录型信号量遵循让权等待条件。",
      },
    ],
  },

  // ---- I/O系统与磁盘调度 ----
  {
    quizId: "quiz_cs102_io",
    courseId: "cs102",
    topic: "I/O系统与磁盘调度",
    questions: [
      {
        id: "cs102_q22",
        type: "choice",
        stem: "下列磁盘调度算法中，可能导致请求饥饿的是？",
        options: [
          "A. FCFS（先来先服务）",
          "B. SSTF（最短寻道时间优先）",
          "C. SCAN（电梯算法）",
          "D. C-SCAN（循环扫描）",
        ],
        answer: "B",
        explanation:
          "SSTF 优先选择离当前磁头最近的请求，可能导致远离磁头的请求长期得不到服务而饥饿。FCFS 按请求顺序服务无饥饿但效率低。SCAN 和 C-SCAN 按固定方向扫描避免饥饿，性能和公平性较好，是实际系统常用算法。",
      },
      {
        id: "cs102_q23",
        type: "choice",
        stem: "DMA 方式相比中断驱动 I/O 方式的主要优势是？",
        options: [
          "A. DMA 不需要任何硬件支持",
          "B. DMA 方式下数据传输以字节为单位",
          "C. DMA 方式下数据传输以块为单位，CPU 只需在传输开始和结束时介入",
          "D. DMA 方式只能用于输入操作",
        ],
        answer: "C",
        explanation:
          "DMA（直接内存访问）由 DMA 控制器直接控制数据在设备与内存间传输，以块为单位，传输期间 CPU 无需干预，仅在传输开始和结束时介入。中断驱动方式每传输一个字节或一个数据就中断 CPU 一次，DMA 大幅减少了中断次数和 CPU 开销。",
      },
      {
        id: "cs102_q27",
        type: "choice",
        stem: "磁盘柱面编号为 0～199，当前磁头位于 53，待处理请求为 98、183、37、122、14、124、65、67。采用向柱面号增大方向服务的 C-SCAN，且移动到 199、从 199 回到 0 的距离均计入总移动量。服务顺序与磁头总移动量是哪项？",
        options: [
          "A. 65->67->98->122->124->183->37->14，共 331 个柱面",
          "B. 65->67->98->122->124->183->14->37，共 322 个柱面",
          "C. 65->67->98->122->124->183->14->37，共 382 个柱面",
          "D. 37->14->65->67->98->122->124->183，共 236 个柱面",
        ],
        answer: "C",
        explanation:
          "C-SCAN 先沿增大方向依次服务 65、67、98、122、124、183，再移动到 199，回卷到 0 后服务 14、37；回卷途中不服务请求。总移动量为 (199-53)+(199-0)+(37-0)=146+199+37=382；直接从 183 跳到 14 是 C-LOOK 的边界处理，不是题设 C-SCAN。",
      },
      {
        id: "cs102_q46",
        type: "choice",
        stem: "在中断驱动 I/O 方式中，CPU 和 I/O 设备之间的数据传输特点是？",
        options: [
          "A. CPU 和设备完全并行工作，无需中断",
          "B. 每传输一个字节或一个字，设备中断 CPU 一次",
          "C. 数据传输完全由 DMA 控制器完成",
          "D. CPU 必须轮询设备状态",
        ],
        answer: "B",
        explanation:
          "中断驱动 I/O 方式中，CPU 向设备控制器发出 I/O 命令后可执行其他任务，设备完成数据传输（通常一次传输一个字节或一个字）后向 CPU 发送中断信号。CPU 响应中断处理数据。相比轮询方式提高了 CPU 利用率，但频繁中断仍有一定开销，大量数据传输更适合 DMA 方式。",
      },
      {
        id: "cs102_q47",
        type: "choice",
        stem: "SPOOLing（假脱机）技术的主要目的是？",
        options: [
          "A. 提高磁盘读写速度",
          "B. 将独占设备改造为共享设备，提高设备利用率",
          "C. 减少内存使用",
          "D. 加速网络传输",
        ],
        answer: "B",
        explanation:
          "SPOOLing（Simultaneous Peripheral Operations On-Line）技术通过在磁盘上建立输入井和输出井，将独占设备（如打印机）改造为共享设备。多个进程的打印请求先存入磁盘输出井排队，再由 SPOOLing 进程依次送往打印机，实现了设备虚拟化。SPOOLing 提高了设备利用率和系统吞吐量。",
      },
    ],
  },

  // ---- 分段与段页式 ----
  {
    quizId: "quiz_cs102_segmentation",
    courseId: "cs102",
    topic: "分段与段页式",
    questions: [
      {
        id: "cs102_q48",
        type: "choice",
        stem: "在分段存储管理中，逻辑地址由哪两部分组成？",
        options: ["A. 页号和页内偏移", "B. 段号和段内偏移", "C. 基址和限长", "D. 段号和页号"],
        answer: "B",
        explanation:
          "分段存储管理中，逻辑地址由段号和段内偏移两部分组成。地址转换时，用段号查段表得到段基址和段限长，检查段内偏移是否越界，然后将段基址与段内偏移相加得到物理地址。分段按程序的逻辑结构划分，便于编程、共享和保护，但段大小不固定可能产生外部碎片。",
      },
      {
        id: "cs102_q49",
        type: "choice",
        stem: "某段页式系统页大小为 1024 字节。段 2 的段长为 3000 字节，其页表中逻辑页 2 已在内存并映射到物理页框 17。分别访问逻辑地址（段 2，段内偏移 2500）和（段 2，段内偏移 3000），结果是哪项？",
        options: [
          "A. 前者转换为物理地址 17860；后者触发段越界异常",
          "B. 前者转换为物理地址 17452；后者转换为 18360",
          "C. 前者触发缺页异常；后者转换为物理地址 18360",
          "D. 前者转换为物理地址 17860；后者也有效并转换为 18360",
        ],
        answer: "A",
        explanation:
          "偏移 2500 小于段长 3000，页号为 floor(2500/1024)=2、页内偏移为 452，因此物理地址为 17*1024+452=17860。合法段内偏移范围是 0～2999，偏移 3000 恰好等于段长，必须先触发段越界异常，不能因逻辑页 2 已映射就继续地址转换。",
      },
      {
        id: "cs102_q50",
        type: "choice",
        stem: "在段页式存储管理中，逻辑地址由哪三部分组成？",
        options: [
          "A. 段号、页号、页内偏移",
          "B. 段号、段内偏移、物理地址",
          "C. 页号、页内偏移、段基址",
          "D. 段号、段基址、段限长",
        ],
        answer: "A",
        explanation:
          "段页式存储管理中，逻辑地址由段号、段内页号和页内偏移三部分组成。地址转换需三次访问内存：先查段表得到段的页表起始地址，再查页表得到物理页框号，最后与页内偏移拼接得到物理地址。段页式结合了分段的逻辑共享和分页的无外部碎片优点，但地址转换开销较大。",
      },
      {
        id: "cs102_q51",
        type: "choice",
        stem: "分段存储管理中，实现代码段共享的前提条件是？",
        options: [
          "A. 代码段必须是可写的",
          "B. 共享的代码段必须是可重入的（纯代码）",
          "C. 所有进程的段号必须相同",
          "D. 内存必须足够大",
        ],
        answer: "B",
        explanation:
          "分段存储管理中，共享的代码段必须是可重入的（纯代码），即代码在执行过程中不被修改，多个进程可同时执行同一段代码。可重入代码不能包含自修改代码和进程私有的可变数据。分段机制通过不同进程的段表项指向同一物理段实现共享，便于实现共享库和公共代码。",
      },
      {
        id: "cs102_q52",
        type: "choice",
        stem: "在分段存储管理中，段表的每个表项至少包含以下哪些信息？",
        options: [
          "A. 段号和段内偏移",
          "B. 段基址和段限长",
          "C. 页号和页框号",
          "D. 段号和页框号",
        ],
        answer: "B",
        explanation:
          "段表每个表项至少包含段基址（段在内存中的起始物理地址）和段限长（段的长度）。地址转换时用段号查段表得到段基址和段限长，检查段内偏移是否超过段限长（越界检查），然后将段基址与段内偏移相加得到物理地址。段表还可能包含存取控制位（读/写/执行权限）等保护信息。",
      },
    ],
  },

  // ---- 进程间通信 ----
  {
    quizId: "quiz_cs102_ipc",
    courseId: "cs102",
    topic: "进程间通信",
    questions: [
      {
        id: "cs102_q53",
        type: "choice",
        stem: "在 UNIX/Linux 系统中，管道（Pipe）是一种进程间通信方式，其特点是？",
        options: [
          "A. 管道是双向通信的",
          "B. 管道是半双工的，数据单向流动，通常用于具有亲缘关系的进程间通信",
          "C. 管道通信不经过内核",
          "D. 管道可以跨网络通信",
        ],
        answer: "B",
        explanation:
          "管道是一种半双工通信机制，数据只能单向流动。普通管道只能用于具有共同祖先的进程间通信（如父子进程），通过 fork 继承管道描述符。管道本质上是内核维护的固定大小缓冲区，读写操作可能阻塞。命名管道（FIFO）可用于无亲缘关系进程间的通信。",
      },
      {
        id: "cs102_q54",
        type: "choice",
        stem: "两个无亲缘关系的本机进程传递小型命令。生产者发送后可能退出，消费者稍后才启动；通信必须保留消息边界，并允许消费者先接收类型 2、再接收类型 1 的消息，且不自行实现共享内存同步。假设系统未重启、IPC 对象未被显式删除，哪种机制最直接满足全部要求？",
        options: [
          "A. 匿名管道：以字节流保存消息，并可按消息类型选择接收",
          "B. 共享内存：内核自动维护消息边界、类型筛选和互斥",
          "C. UNIX 域 SOCK_STREAM：发送者退出后连接仍可供尚未启动的消费者接收，并原生按类型筛选",
          "D. System V 消息队列：内核保存带类型的消息，接收方可按消息类型选择接收",
        ],
        answer: "D",
        explanation:
          "System V 消息队列由内核维护消息对象，msgsnd/msgrcv 保留消息边界，msgrcv 的 msgtyp 可选择特定类型；队列未被 IPC_RMID 删除时，不依赖发送进程继续存活。匿名管道和 SOCK_STREAM 是字节流且不原生支持按消息类型选择，共享内存则需要应用自行定义消息布局并实现同步，因此都不能直接同时满足题设约束。",
      },
      {
        id: "cs102_q55",
        type: "choice",
        stem: "在以下进程间通信方式中，速度最快的是？",
        options: ["A. 管道", "B. 消息队列", "C. 共享内存", "D. 套接字（Socket）"],
        answer: "C",
        explanation:
          "共享内存是速度最快的进程间通信方式，多个进程映射同一块物理内存区域，直接读写内存即可通信，无需内核中转和数据拷贝。但共享内存本身不提供同步机制，需配合信号量或互斥锁保证数据一致性。管道、消息队列和套接字都需要内核参与数据拷贝，开销较大。",
      },
      {
        id: "cs102_q56",
        type: "choice",
        stem: "信号量作为进程间通信机制，主要用于实现以下哪个功能？",
        options: ["A. 数据传输", "B. 进程同步与互斥", "C. 进程创建与终止", "D. 内存分配"],
        answer: "B",
        explanation:
          "信号量主要用于进程间的同步与互斥，而非数据传输。信号量是一个整数值，通过 P（wait）和 V（signal）操作实现对共享资源的访问控制。P 操作申请资源（信号量减 1），V 操作释放资源（信号量加 1）。信号量广泛用于生产者-消费者、读者-写者等经典同步问题。",
      },
      {
        id: "cs102_q57",
        type: "choice",
        stem: "套接字（Socket）通信方式的主要特点是？",
        options: [
          "A. 只能用于同一台主机上的进程通信",
          "B. 支持跨网络的进程间通信，也可用于本机通信",
          "C. 不支持双向通信",
          "D. 通信速度比共享内存更快",
        ],
        answer: "B",
        explanation:
          "套接字是一种通用的进程间通信机制，既可用于同一主机上的进程通信（UNIX 域套接字），也可用于跨网络的进程通信（TCP/UDP 套接字）。套接字支持双向数据流，是网络编程的基础。虽然套接字通信需经过网络协议栈开销较大，但其跨网络通信能力是管道、共享内存等本机 IPC 机制所不具备的。",
      },
    ],
  },
]);

// ===========================================================================
// CS103 计算机网络（共 62 题：55 选择 + 7 简答）
// ===========================================================================

export const cs103Quizzes: Quiz[] = withQuizMetadata([
  // ---- OSI与TCP/IP模型 ----
  {
    quizId: "quiz_cs103_model",
    courseId: "cs103",
    topic: "OSI与TCP/IP模型",
    questions: [
      {
        id: "cs103_q01",
        type: "choice",
        stem: "在 OSI 参考模型中，负责数据加密和解密的层是？",
        options: [
          "A. 物理层",
          "B. 数据链路层",
          "C. 表示层",
          "D. 会话层",
        ],
        answer: "C",
        explanation:
          "表示层负责数据格式转换、加密解密和数据压缩，确保应用层发送的数据能被接收方正确解释。OSI 七层从下到上为物理层、数据链路层、网络层、传输层、会话层、表示层、应用层。TCP/IP 模型将其简化为四层。",
      },
      {
        id: "cs103_q02",
        type: "choice",
        stem: "在 TCP/IP 模型中，IP 协议工作在？",
        options: [
          "A. 应用层",
          "B. 传输层",
          "C. 网络层（网际层）",
          "D. 数据链路层",
        ],
        answer: "C",
        explanation:
          "IP 协议是 TCP/IP 模型网络层（网际层）的核心协议，负责将数据包从源主机路由到目的主机，提供无连接、不可靠的数据报服务。TCP 和 UDP 工作在传输层，HTTP、DNS 等工作在应用层，ARP 工作在网络接口层。",
      },
      {
        id: "cs103_q28",
        type: "choice",
        stem: "OSI 参考模型中，传输层的主要功能是？",
        options: [
          "A. 物理寻址与介质访问控制",
          "B. 端到端可靠数据传输与流量控制",
          "C. 路由选择与分组转发",
          "D. 数据格式转换与加密",
        ],
        answer: "B",
        explanation:
          "传输层是 OSI 模型中负责端到端通信的层次，提供进程间的数据传输服务，包括可靠传输、流量控制、差错控制和拥塞控制。物理寻址属于数据链路层功能，路由选择属于网络层功能，数据格式转换属于表示层功能。传输层通过端口号实现进程到进程的复用与分用。",
      },
      {
        id: "cs103_q29",
        type: "choice",
        stem: "以太网 MTU 为 1500 字节，IPv4 与 TCP 首部均无选项且各为 20 字节。TCP 按可用 MSS 分段发送 3200 字节 HTTP 数据，不考虑链路或分段卸载；最终形成多少个 IP 数据报，各自的 IP Total Length 是多少？",
        options: [
          "A. 2 个：1500、1780 字节",
          "B. 3 个：1500、1500、280 字节",
          "C. 3 个：1460、1460、280 字节",
          "D. 3 个：1500、1500、320 字节",
        ],
        answer: "D",
        explanation:
          "可用 MSS = 1500 - 20 - 20 = 1460 字节，因此 3200 字节应用数据被分为 1460、1460、280 三个 TCP 数据块。每个 IP Total Length 还要加 20 字节 IPv4 首部和 20 字节 TCP 首部，所以结果是 1500、1500、320 字节，TCP 分段避免了 IP 层再分片。",
      },
      {
        id: "cs103_q30",
        type: "choice",
        stem: "在 OSI 模型中，数据链路层的协议数据单元（PDU）称为？",
        options: ["A. 比特", "B. 帧", "C. 分组", "D. 报文段"],
        answer: "B",
        explanation:
          "OSI 各层的 PDU 分别为：物理层是比特（Bit），数据链路层是帧（Frame），网络层是分组（Packet），传输层是报文段（Segment），应用层是报文（Message）。数据链路层将网络层交下来的分组封装成帧，添加帧头和帧尾，实现相邻节点间的可靠传输。",
      },
      {
        id: "cs103_q03",
        type: "short",
        stem: "比较 OSI 参考模型和 TCP/IP 模型的区别。",
        answer:
          "OSI 七层模型是理论参考标准，包括物理层、数据链路层、网络层、传输层、会话层、表示层、应用层，分层严格但实现复杂。TCP/IP 四层模型是工程实践标准，包括网络接口层、网际层、传输层、应用层，将 OSI 的上三层合并为应用层，下两层合并为网络接口层，简洁实用被广泛部署。",
        explanation:
          "OSI 是七层理论模型，分层清晰但过于复杂，从未真正实现。TCP/IP 是四层实用模型，将 OSI 会话层、表示层、应用层合并为应用层，物理层和数据链路层合并为网络接口层，更简洁实用。TCP/IP 是互联网实际使用的协议栈标准。",
      },
    ],
  },

  // ---- TCP握手与挥手 ----
  {
    quizId: "quiz_cs103_tcp_hs",
    courseId: "cs103",
    topic: "TCP握手与挥手",
    questions: [
      {
        id: "cs103_q04",
        type: "choice",
        stem: "TCP 建立连接的三次握手中，第二次握手报文中的标志位为？",
        options: [
          "A. SYN=1, ACK=0",
          "B. SYN=1, ACK=1",
          "C. SYN=0, ACK=1",
          "D. FIN=1, ACK=1",
        ],
        answer: "B",
        explanation:
          "三次握手过程：第一次客户端发送 SYN=1, seq=x；第二次服务器回复 SYN=1, ACK=1, seq=y, ack=x+1，同时确认客户端的 SYN 并发送自己的 SYN；第三次客户端发送 ACK=1, seq=x+1, ack=y+1。第二次握手同时包含 SYN 和 ACK 标志。",
      },
      {
        id: "cs103_q25",
        type: "choice",
        stem: "TCP 端点 A 处于 ESTABLISHED，应用调用 CLOSE 后 A 已发送 FIN。A 尚未收到确认自身 FIN 的 ACK，就收到对端发来的 FIN（该报文未确认 A 的 FIN）；A 回 ACK，随后才收到确认自身 FIN 的 ACK。A 从调用 CLOSE 起的状态序列是？",
        options: [
          "A. FIN-WAIT-1 -> FIN-WAIT-2 -> TIME-WAIT -> CLOSED",
          "B. FIN-WAIT-1 -> CLOSING -> CLOSED",
          "C. FIN-WAIT-1 -> CLOSING -> TIME-WAIT -> CLOSED",
          "D. CLOSE-WAIT -> LAST-ACK -> TIME-WAIT -> CLOSED",
        ],
        answer: "C",
        explanation:
          "主动关闭先进入 FIN-WAIT-1；在本端 FIN 尚未获确认时收到对端 FIN，属于同时关闭边界，发送 ACK 后进入 CLOSING。随后收到本端 FIN 的 ACK 才进入 TIME-WAIT，等待 2MSL 后进入 CLOSED。",
      },
      {
        id: "cs103_q31",
        type: "choice",
        stem: "TCP 三次握手中，SYN 报文中序列号（seq）的作用是？",
        options: [
          "A. 确认已收到的数据",
          "B. 初始化发送方的发送序列号",
          "C. 通告接收窗口大小",
          "D. 请求关闭连接",
        ],
        answer: "B",
        explanation:
          "SYN 报文中的 seq 字段用于初始化发送方的初始序列号（ISN），双方通过交换 SYN 报文告知对方自己的 ISN。后续数据传输的序列号基于 ISN 递增，确保数据按序到达。ACK 号用于确认已收到的数据，窗口大小通过 win 字段通告，FIN 标志用于请求关闭连接。",
      },
      {
        id: "cs103_q32",
        type: "choice",
        stem: "TCP 连接建立过程中，客户端发送第一个 SYN 后进入的状态是？",
        options: ["A. LISTEN", "B. SYN_SENT", "C. SYN_RCVD", "D. ESTABLISHED"],
        answer: "B",
        explanation:
          "客户端发送 SYN 后进入 SYN_SENT 状态，等待服务器确认。服务器收到 SYN 后回复 SYN+ACK 并进入 SYN_RCVD 状态。客户端收到 SYN+ACK 后发送 ACK，进入 ESTABLISHED 状态。LISTEN 是服务器等待连接的初始状态。三次握手完成后双方均处于 ESTABLISHED 状态，可以开始数据传输。",
      },
      {
        id: "cs103_q33",
        type: "choice",
        stem: "TCP 四次挥手中，被动关闭方收到 FIN 后首先发送的报文标志位为？",
        options: ["A. SYN=1", "B. ACK=1", "C. FIN=1", "D. RST=1"],
        answer: "B",
        explanation:
          "被动关闭方收到 FIN 后先回复 ACK=1 确认收到关闭请求，进入 CLOSE_WAIT 状态。待自身数据发送完毕后再发送 FIN=1 进入 LAST_ACK 状态。主动关闭方收到 ACK 后进入 FIN_WAIT_2，收到 FIN 后回复 ACK 并进入 TIME_WAIT。四次挥手确保双方都完成数据发送后再关闭连接。",
      },
    ],
  },

  // ---- TCP流量控制与拥塞控制 ----
  {
    quizId: "quiz_cs103_tcp_fc",
    courseId: "cs103",
    topic: "TCP流量控制与拥塞控制",
    questions: [
      {
        id: "cs103_q05",
        type: "choice",
        stem: "TCP 流量控制采用的机制是？",
        options: [
          "A. 拥塞窗口",
          "B. 滑动窗口",
          "C. 快速重传",
          "D. 三次握手",
        ],
        answer: "B",
        explanation:
          "TCP 流量控制通过滑动窗口机制实现，接收方在 ACK 报文中通过窗口字段（rwnd）通告自己的接收缓冲区大小，发送方据此调整发送窗口，防止发送过快导致接收方缓冲区溢出。流量控制是端到端的，而拥塞控制是面向网络的。",
      },
      {
        id: "cs103_q06",
        type: "short",
        stem: "简述 TCP 拥塞控制的四个阶段。",
        answer:
          "TCP 拥塞控制包括四个阶段：慢开始（cwnd 从 1 指数增长到 ssthresh）、拥塞避免（cwnd 线性增长）、快重传（收到 3 个重复 ACK 立即重传丢失报文）、快恢复（ssthresh 设为当前 cwnd 一半，cwnd 设为 ssthresh 后线性增长）。目的是避免网络拥塞崩溃。",
        explanation:
          "慢开始阶段拥塞窗口指数增长快速探测网络容量；达到阈值后进入拥塞避免线性增长；检测到 3 个重复 ACK 触发快重传立即重传；快恢复将阈值减半后线性增长避免回到慢开始。超时则阈值减半并重新慢开始，逐步探测合理发送速率。",
      },
      {
        id: "cs103_q34",
        type: "choice",
        stem: "按 RFC 5681 的简化推演，TCP 发送方当前 cwnd=4 MSS、ssthresh=16 MSS，rwnd 足够大，每个满载报文段都立即得到 ACK。连续两个 RTT 无丢包后，下一轮发出的全部在途数据因超时判定丢失；超时前 FlightSize 等于当时 cwnd。此时“第二个 RTT 后的 cwnd、新 ssthresh、超时后的 cwnd”依次是？",
        options: [
          "A. 16 MSS、8 MSS、1 MSS",
          "B. 16 MSS、8 MSS、8 MSS",
          "C. 8 MSS、4 MSS、1 MSS",
          "D. 16 MSS、16 MSS、1 MSS",
        ],
        answer: "A",
        explanation:
          "慢启动阶段每个被确认的满载报文段使 cwnd 增加 1 MSS，因此两个完整 RTT 后窗口从 4 依次增长为 8、16 MSS。RTO 发生且 FlightSize=16 MSS 时，ssthresh=max(16/2, 2)=8 MSS，重传超时后的丢失窗口为 1 MSS；把 cwnd 保持为 8 MSS 是混淆了超时与快速恢复。",
      },
      {
        id: "cs103_q35",
        type: "choice",
        stem: "TCP 拥塞控制中，慢开始阶段拥塞窗口（cwnd）的增长方式是？",
        options: [
          "A. 线性增长（每 RTT 加 1）",
          "B. 指数增长（每 RTT 翻倍）",
          "C. 对数增长",
          "D. 固定不变",
        ],
        answer: "B",
        explanation:
          "慢开始阶段 cwnd 从 1 开始，每经过一个 RTT 翻倍（指数增长），快速探测网络容量。当 cwnd 达到慢开始门限（ssthresh）时，切换到拥塞避免阶段，cwnd 线性增长（每 RTT 加 1）。指数增长使 cwnd 快速增加到合理水平，但为避免过快增长引发拥塞，达到阈值后转为线性增长。",
      },
      {
        id: "cs103_q36",
        type: "choice",
        stem: "TCP 快重传机制被触发的条件是？",
        options: [
          "A. 超时计时器到期",
          "B. 收到 3 个重复的 ACK",
          "C. 接收窗口降为 0",
          "D. 收到 RST 报文",
        ],
        answer: "B",
        explanation:
          "快重传要求接收方每收到一个失序报文就立即发出重复 ACK。当发送方收到 3 个重复 ACK 时，判定该报文段已丢失，立即重传而不等待超时，提高恢复速度。快重传后进入快恢复阶段，ssthresh 设为当前 cwnd 的一半，cwnd 设为 ssthresh 后线性增长。超时则 ssthresh 减半并重新慢开始。",
      },
      {
        id: "cs103_q37",
        type: "choice",
        stem: "TCP 拥塞控制采用 AIMD 策略，其中乘性减少的含义是？",
        options: [
          "A. 每次将 cwnd 减半",
          "B. 每次将 cwnd 减 1",
          "C. 每次将 cwnd 乘以 0.1",
          "D. 每次将 cwnd 置 0",
        ],
        answer: "A",
        explanation:
          "AIMD（加性增、乘性减）策略中，加性增指拥塞避免阶段每 RTT 将 cwnd 加 1（线性增长），乘性减指检测到拥塞时将 cwnd 减半。乘性减使窗口快速收缩以迅速缓解拥塞，加性增使窗口缓慢增长以谨慎探测网络容量。这种策略在多条连接共享网络时能实现公平性。",
      },
    ],
  },

  // ---- UDP 协议 ----
  {
    quizId: "quiz_cs103_udp",
    courseId: "cs103",
    topic: "UDP协议",
    questions: [
      {
        id: "cs103_q07",
        type: "choice",
        stem: "关于 UDP 协议，下列说法正确的是？",
        options: [
          "A. UDP 提供可靠的数据传输服务",
          "B. UDP 是无连接的，不保证数据可靠到达",
          "C. UDP 具有流量控制和拥塞控制",
          "D. UDP 首部长度为 20 字节",
        ],
        answer: "B",
        explanation:
          "UDP 是无连接的传输层协议，不建立连接，不保证可靠交付，无流量控制和拥塞控制。UDP 首部仅 8 字节（源端口、目的端口、长度、校验和），开销小效率高。适合实时应用（如视频、DNS 查询）等对速度要求高且能容忍少量丢包的场景。",
      },
      {
        id: "cs103_q08",
        type: "choice",
        stem: "以下应用场景中，最适合使用 UDP 而非 TCP 的是？",
        options: [
          "A. 文件传输",
          "B. 电子邮件",
          "C. 实时视频直播",
          "D. 网页浏览",
        ],
        answer: "C",
        explanation:
          "实时视频直播要求低延迟，能容忍少量丢包，UDP 无连接建立延迟和重传延迟，最适合此场景。文件传输、电子邮件和网页浏览要求可靠传输，适合 TCP。UDP 适合实时性要求高、能容忍丢包的应用，如视频直播、在线游戏、DNS 查询。",
      },
      {
        id: "cs103_q24",
        type: "choice",
        stem: "计算 IPv4 UDP 校验和时，伪首部、UDP 首部和前部数据按 16 位反码加法得到的中间和为 0x7FFF，最后还剩一个数据字节 0xAB。按 RFC 768 在末尾补零后，最终写入 UDP 校验和字段的值是？",
        options: [
          "A. 0xD4FF",
          "B. 0xD500",
          "C. 0x7F55",
          "D. 0x2B00",
        ],
        answer: "A",
        explanation:
          "奇数字节数据在末尾补零，因此最后一个 16 位字是 0xAB00；0x7FFF + 0xAB00 = 0x12AFF，回卷进位后为 0x2B00。再对 0x2B00 按位取反得到 0xD4FF；0xD500 是漏做回卷进位，0x2B00 是漏做最终取反。",
      },
      {
        id: "cs103_q38",
        type: "choice",
        stem: "UDP 数据报首部的固定长度为？",
        options: ["A. 8 字节", "B. 16 字节", "C. 20 字节", "D. 32 字节"],
        answer: "A",
        explanation:
          "UDP 首部仅 8 字节，包含源端口（2 字节）、目的端口（2 字节）、长度（2 字节）和校验和（2 字节）。相比之下 TCP 首部固定部分为 20 字节。UDP 首部开销小是其高效传输的重要原因之一，适合对实时性要求高、能容忍少量丢包的应用场景。",
      },
      {
        id: "cs103_q39",
        type: "choice",
        stem: "UDP 实现多路复用与多路分解（multiplexing/demultiplexing）依赖的机制是？",
        options: [
          "A. IP 地址",
          "B. MAC 地址",
          "C. 端口号",
          "D. 序列号",
        ],
        answer: "C",
        explanation:
          "UDP 通过端口号实现多路复用与多路分解，发送方将不同应用进程的数据通过不同端口复用到一条 UDP 通道，接收方根据目的端口号将数据报分用（demultiplex）到对应的进程。IP 地址用于主机寻址，MAC 地址用于链路层寻址，序列号是 TCP 的可靠传输机制。UDP 无连接但仍需端口区分进程。",
      },
    ],
  },

  // ---- HTTP 协议 ----
  {
    quizId: "quiz_cs103_http",
    courseId: "cs103",
    topic: "HTTP协议",
    questions: [
      {
        id: "cs103_q09",
        type: "choice",
        stem: "HTTP 协议中，用于请求服务器删除指定资源的 HTTP 方法是？",
        options: ["A. GET", "B. POST", "C. PUT", "D. DELETE"],
        answer: "D",
        explanation:
          "HTTP 方法语义：GET 获取资源（安全且幂等）、POST 创建或提交数据（非幂等）、PUT 更新或替换资源（幂等）、DELETE 删除资源（幂等）。幂等指多次执行结果相同。RESTful API 设计中这些方法对应资源的增删改查操作。",
      },
      {
        id: "cs103_q10",
        type: "choice",
        stem: "HTTP 状态码 301 表示的含义是？",
        options: [
          "A. 请求成功",
          "B. 永久重定向",
          "C. 临时重定向",
          "D. 资源不存在",
        ],
        answer: "B",
        explanation:
          "301 Moved Permanently 表示请求的资源已永久移动到新 URL，客户端应使用新 URL 访问。301 是永久重定向，搜索引擎会更新索引。302 是临时重定向，404 表示资源不存在，200 表示请求成功。3xx 类状态码均表示重定向。",
      },
      {
        id: "cs103_q40",
        type: "choice",
        stem: "HTTP/1.1 默认使用的连接方式是？",
        options: [
          "A. 短连接（每请求新建连接）",
          "B. 持久连接（keep-alive）",
          "C. 管道化连接",
          "D. WebSocket 连接",
        ],
        answer: "B",
        explanation:
          "HTTP/1.1 默认开启持久连接（Connection: keep-alive），同一 TCP 连接可发送多个请求和响应，避免每次请求都建立新连接的开销。HTTP/1.0 默认为短连接，每次请求需新建 TCP 连接。管道化允许在同一连接上连续发送多个请求但存在队头阻塞问题，并非默认行为。WebSocket 是独立的通信协议。",
      },
      {
        id: "cs103_q41",
        type: "choice",
        stem: "HTTP Cookie 的主要用途是？",
        options: [
          "A. 缓存网页内容以加速访问",
          "B. 在客户端存储会话状态信息",
          "C. 加密 HTTP 通信内容",
          "D. 压缩 HTTP 响应数据",
        ],
        answer: "B",
        explanation:
          "HTTP 是无状态协议，Cookie 通过在客户端存储键值对来维持会话状态。服务器通过 Set-Cookie 响应头设置 Cookie，浏览器在后续请求中通过 Cookie 请求头携带。Cookie 常用于用户身份认证、个性化设置和购物车等功能。缓存内容由 Cache-Control 等头部控制，加密由 HTTPS/TLS 实现。",
      },
      {
        id: "cs103_q42",
        type: "choice",
        stem: "对同一资源 http://example.com/a?b=1，依次考虑：客户端直接请求源站、客户端向正向代理发送请求、用 CONNECT 建立 example.com:443 隧道、对服务器整体发送 OPTIONS。四个 HTTP/1.1 request-target 依次应为？",
        options: [
          "A. /a?b=1；/a?b=1；/；*",
          "B. http://example.com/a?b=1；/a?b=1；example.com；/*",
          "C. /a?b=1；http://example.com/a?b=1；example.com:443；*",
          "D. example.com/a?b=1；http://example.com/a?b=1；https://example.com:443；OPTIONS",
        ],
        answer: "C",
        explanation:
          "直接访问源站使用 origin-form，即路径与查询串；向正向代理发送普通 HTTP 请求使用 absolute-form，即完整绝对 URI。CONNECT 使用 authority-form 的 host:port，服务器范围的 OPTIONS 使用 asterisk-form，因此四项依次为 /a?b=1、完整 URI、example.com:443 和 *。",
      },
      {
        id: "cs103_q11",
        type: "short",
        stem: "比较 HTTP/1.1 和 HTTP/2 的主要改进。",
        answer:
          "HTTP/2 相比 HTTP/1.1 的主要改进：1. 多路复用，在单一 TCP 连接上并行传输多个流，消除 HTTP/1.1 管线化的应用层队头阻塞；2. 使用 HPACK 压缩头部；3. 使用二进制分帧；4. 支持服务器推送。HTTP/2 仍基于 TCP，因此丢包时仍可能出现 TCP 层队头阻塞。",
        explanation:
          "HTTP/1.1 使用文本报文，管线化受到响应顺序限制。HTTP/2 通过二进制分帧和多路复用让多个流并行传输，并用 HPACK 减少头部冗余；它解决的是 HTTP 层的顺序阻塞，不会消除同一 TCP 连接上的传输层队头阻塞。",
      },
    ],
  },

  // ---- HTTPS 与 TLS ----
  {
    quizId: "quiz_cs103_https",
    courseId: "cs103",
    topic: "HTTPS与TLS",
    questions: [
      {
        id: "cs103_q12",
        type: "choice",
        stem: "TLS 握手过程中，客户端和服务器协商出的对称密钥用于？",
        options: [
          "A. 验证服务器身份",
          "B. 对后续应用数据进行加密传输",
          "C. 生成数字证书",
          "D. 建立 TCP 连接",
        ],
        answer: "B",
        explanation:
          "TLS 握手使用非对称加密（如 RSA/ECDHE）安全协商出对称会话密钥，之后的应用数据使用该对称密钥加密传输。非对称加密计算成本高仅用于握手阶段，对称加密速度快用于大量数据传输。这种混合加密机制兼顾了安全性和性能。",
      },
      {
        id: "cs103_q13",
        type: "choice",
        stem: "在 HTTPS 中，服务器身份验证主要通过什么机制实现？",
        options: [
          "A. 对称加密",
          "B. 数字证书和 CA（证书颁发机构）签名",
          "C. 哈希函数",
          "D. TCP 三次握手",
        ],
        answer: "B",
        explanation:
          "HTTPS 中服务器向客户端发送数字证书，证书包含服务器公钥并由受信任的 CA 签名。客户端验证 CA 签名（使用 CA 公钥）确认证书真实性，从而信任证书中的服务器公钥。这防止了中间人攻击，确保客户端连接到真实服务器。",
      },
      {
        id: "cs103_q43",
        type: "choice",
        stem: "TLS 1.3 相比 TLS 1.2 的一个重要改进是？",
        options: [
          "A. 增加了更多加密算法支持",
          "B. 将握手往返次数从 2-RTT 减少到 1-RTT",
          "C. 使用了更大的密钥长度",
          "D. 不再需要数字证书",
        ],
        answer: "B",
        explanation:
          "TLS 1.3 将基本握手从 2-RTT 减少到 1-RTT，降低了连接建立延迟，还支持 0-RTT 恢复模式。TLS 1.3 删除了不安全的算法（如 RSA 密钥交换、CBC 模式），仅保留 AEAD 加密。数字证书在 TLS 1.3 中仍然必需，用于身份验证。更少的往返次数和更精简的密码套件提升了安全性和性能。",
      },
      {
        id: "cs103_q44",
        type: "choice",
        stem: "在 TLS 证书链验证中，根 CA 证书的特点是？",
        options: [
          "A. 由服务器在握手时发送",
          "B. 自签名且预装在操作系统或浏览器信任库中",
          "C. 每次握手时动态生成",
          "D. 由中间 CA 签发",
        ],
        answer: "B",
        explanation:
          "根 CA 证书是自签名的，预装在操作系统或浏览器的信任库中，作为信任锚点。证书链验证从服务器证书开始，逐级向上验证签名：服务器证书由中间 CA 签发，中间 CA 证书由根 CA 签发。根 CA 证书不需要在网络中传输，客户端直接从本地信任库获取并验证。",
      },
      {
        id: "cs103_q45",
        type: "choice",
        stem: "攻击者记录了三次完整握手及其密文：S1 使用 TLS 1.2 RSA 密钥传输，S2 使用 TLS 1.2 ECDHE_RSA，S3 使用 TLS 1.3 ECDHE 且以 RSA 证书签名认证。会话结束后临时私钥均已销毁；攻击者后来只窃取服务器 RSA 长期私钥。哪些历史会话可仅凭记录流量与该长期私钥解密？",
        options: [
          "A. 三个都不能",
          "B. S1 和 S2",
          "C. S2 和 S3",
          "D. 只有 S1",
        ],
        answer: "D",
        explanation:
          "S1 的 premaster secret 由服务器 RSA 公钥加密并记录在握手中，长期私钥泄露后可恢复该秘密并派生历史会话密钥。S2 与 S3 的 RSA 私钥只用于签名认证，共享秘密来自已销毁的临时 ECDHE 私钥，因此在题设条件下保持前向保密。",
      },
      {
        id: "cs103_q14",
        type: "short",
        stem: "简述数字证书的作用和验证过程。",
        answer:
          "数字证书将公钥与持有者身份绑定，由可信 CA 签名。验证时客户端使用 CA 的公钥验证证书签名，检查证书有效期和吊销状态（CRL/OCSP），确认证书中的域名与访问目标匹配。验证通过后使用证书中的公钥进行密钥交换，确保通信方身份可信。",
        explanation:
          "数字证书由 CA 用私钥签名，包含持有者公钥和身份信息。客户端用 CA 公钥验签确认证书未被篡改，再检查有效期、吊销列表和域名匹配。通过验证后使用证书公钥加密协商信息防止中间人攻击，确保通信对方的身份真实性。",
      },
    ],
  },

  // ---- DNS 系统 ----
  {
    quizId: "quiz_cs103_dns",
    courseId: "cs103",
    topic: "DNS系统",
    questions: [
      {
        id: "cs103_q15",
        type: "choice",
        stem: "当本地 DNS 服务器无法直接解析域名时，正确的查询顺序通常是？",
        options: [
          "A. 浏览器缓存→本地 DNS 缓存→根 DNS 服务器→顶级域名服务器→权威 DNS 服务器",
          "B. 根 DNS 服务器→顶级域名服务器→权威 DNS 服务器→本地 DNS 缓存",
          "C. 权威 DNS 服务器→顶级域名服务器→根 DNS 服务器",
          "D. 本地 DNS 缓存→权威 DNS 服务器→根 DNS 服务器",
        ],
        answer: "A",
        explanation:
          "DNS 解析首先查浏览器和操作系统缓存，未命中则向本地 DNS 服务器查询。本地 DNS 服务器若缓存未命中则递归查询：先问根 DNS 服务器获取顶级域名服务器地址，再问顶级域名服务器获取权威 DNS 服务器地址，最后从权威 DNS 服务器获取最终 IP 地址。",
      },
      {
        id: "cs103_q16",
        type: "choice",
        stem: "DNS 记录中，MX 记录的作用是？",
        options: [
          "A. 将域名映射到 IPv4 地址",
          "B. 将域名映射到 IPv6 地址",
          "C. 指定邮件交换服务器",
          "D. 指定域名的别名",
        ],
        answer: "C",
        explanation:
          "MX（Mail Exchange）记录指定处理该域名的邮件服务器及其优先级，邮件发送方根据 MX 记录找到目标域的邮件服务器。A 记录将域名映射到 IPv4 地址，AAAA 记录映射到 IPv6 地址，CNAME 记录设置域名别名。不同记录类型服务于不同的网络服务需求。",
      },
      {
        id: "cs103_q17",
        type: "short",
        stem: "解释 DNS 缓存的作用及 TTL 值的影响。",
        answer:
          "DNS 缓存将解析结果暂存在浏览器、操作系统和各级 DNS 服务器中，减少重复查询延迟和网络流量。TTL（Time To Live）指定缓存有效时间，TTL 大则缓存命中率高、查询快但域名变更生效慢；TTL 小则变更生效快但查询频繁增加延迟和服务器负载。需平衡性能与时效性。",
        explanation:
          "DNS 缓存各级存储解析结果减少递归查询。TTL 决定缓存存活时间，TTL 大命中率高减少网络流量和延迟，但域名变更后旧记录影响时间长。TTL 小变更生效快但缓存命中率低增加查询延迟和服务器负担。通常设为几分钟到几小时平衡性能与灵活性。",
      },
      {
        id: "cs103_q26",
        type: "choice",
        stem: "DNS 中 CNAME 记录的作用是？",
        options: [
          "A. 将域名映射到 IPv4 地址",
          "B. 将域名映射到 IPv6 地址",
          "C. 将一个域名别名指向另一个域名",
          "D. 指定邮件交换服务器",
        ],
        answer: "C",
        explanation:
          "CNAME（Canonical Name）记录将一个域名设置为另一个域名的别名，常用于将多个子域名指向同一服务。解析 CNAME 时会继续解析目标域名直到获得 A 记录。CNAME 不能与同名的 A、MX 等记录共存，CDN 服务常通过 CNAME 将用户域名指向 CDN 加速域名。",
      },
      {
        id: "cs103_q46",
        type: "choice",
        stem: "缓存为空时，存根解析器向支持递归的本地 DNS 服务器查询 www.example.com；本地服务器再从根服务器开始逐级查询，根服务器返回 referral，最终本地服务器把权威答案返回存根。下列对 RD/RA 标志和 referral 内容的描述哪项正确？",
        options: [
          "A. 存根请求 RD=1；本地服务器向根发 RD=0；根的 referral 在 Authority 中给出 NS；本地最终响应以 RA=1 表示支持递归",
          "B. 存根与本地服务器的所有上游请求都必须 RD=1；根直接在 Answer 中返回最终 A/AAAA；最终 RA=0",
          "C. 存根请求 RD=0；本地服务器向根发 RD=1；根必须返回 NXDOMAIN；最终 RA 复制 RD",
          "D. 存根请求 RD=1；本地服务器向根发 RD=0；根的 referral 必须只放在 Additional；最终响应不能设置 RA",
        ],
        answer: "A",
        explanation:
          "RD=1 请求接收服务器代为递归解析，本地递归服务器的上游查询可使用 RD=0 逐级处理 referral；referral 的 NS 记录位于 Authority，Additional 可携带 glue 地址。RA 是响应方是否提供递归能力的声明，不是 RD 的副本，因此支持递归的本地服务器最终可返回 RA=1 和权威查询所得答案。",
      },
      {
        id: "cs103_q47",
        type: "choice",
        stem: "DNS 默认使用的传输层协议和端口号是？",
        options: ["A. TCP 53", "B. UDP 53", "C. UDP 80", "D. TCP 443"],
        answer: "B",
        explanation:
          "常规 DNS 查询默认使用 UDP 53。若 UDP 响应设置 TC（截断）标志，客户端通常改用 TCP 53 重试；区域传送使用 TCP。512 字节是未使用 EDNS(0) 时的传统 UDP DNS 报文上限，不能把所有较大响应一概写成固定超过 512 字节就切换。",
      },
    ],
  },

  // ---- 路由算法与协议 ----
  {
    quizId: "quiz_cs103_routing",
    courseId: "cs103",
    topic: "路由算法与协议",
    questions: [
      {
        id: "cs103_q18",
        type: "choice",
        stem: "距离向量路由算法（如 RIP）的主要缺点是？",
        options: [
          "A. 算法复杂度高，需要了解全局拓扑",
          "B. 存在计数到无穷问题，收敛速度慢",
          "C. 只能用于小型局域网",
          "D. 不支持负载均衡",
        ],
        answer: "B",
        explanation:
          "距离向量算法中路由器仅与邻居交换距离向量，当链路断开时可能产生计数到无穷问题，路由器间不断递增距离值直到达到最大跳数（RIP 为 16）才收敛，收敛缓慢。解决方法包括水平分割、毒性逆转和触发更新。链路状态算法（如 OSPF）知道全局拓扑无此问题。",
      },
      {
        id: "cs103_q19",
        type: "choice",
        stem: "某路由器有 10.0.0.0/8 -> A、10.64.0.0/10 -> B、10.64.128.0/17 -> C、10.64.160.0/19 -> D 和默认路由 -> E。路由 D 撤销前，目的地址 10.64.173.9 与 10.64.130.7 的出口分别是什么；撤销 D 后，10.64.173.9 的出口又是什么？",
        options: [
          "A. D、C、C",
          "B. C、C、C",
          "C. D、B、C",
          "D. B、C、B",
        ],
        answer: "A",
        explanation:
          "10.64.173.9 同时匹配 /8、/10、/17 和 /19，最长前缀是 /19，因此先走 D；10.64.130.7 不在 /19 范围内，但匹配 /17，因此走 C。撤销 /19 后，10.64.173.9 的剩余最长匹配为 /17，也走 C，故顺序为 D、C、C。",
      },
      {
        id: "cs103_q48",
        type: "choice",
        stem: "OSPF 路由协议使用的链路状态算法基础是？",
        options: [
          "A. Bellman-Ford 算法",
          "B. Dijkstra 最短路径优先（SPF）算法",
          "C. Floyd-Warshall 算法",
          "D. 距离向量算法",
        ],
        answer: "B",
        explanation:
          "OSPF（开放最短路径优先）基于 Dijkstra 算法计算最短路径树。每台路由器维护完整的链路状态数据库，了解全网拓扑，独立计算到达每个目的网络的最短路径。RIP 使用 Bellman-Ford 算法（距离向量）。链路状态算法收敛速度快、无计数到无穷问题，适合大型网络。",
      },
      {
        id: "cs103_q49",
        type: "choice",
        stem: "BGP（边界网关协议）属于哪种类型的路由协议？",
        options: [
          "A. 内部网关协议（IGP）",
          "B. 外部网关协议（EGP）",
          "C. 链路状态协议",
          "D. 组播路由协议",
        ],
        answer: "B",
        explanation:
          "BGP 是外部网关协议（EGP），用于不同自治系统（AS）之间的路由信息交换，是互联网的核心路由协议。OSPF 和 RIP 属于内部网关协议（IGP），用于 AS 内部路由。BGP 采用路径向量算法，考虑 AS 路径长度、策略等属性而非简单度量值，支持策略路由。",
      },
      {
        id: "cs103_q50",
        type: "choice",
        stem: "路由表中 0.0.0.0/0 条目表示？",
        options: [
          "A. 本地回环地址",
          "B. 广播地址",
          "C. 默认路由",
          "D. 子网掩码全 1 的主机路由",
        ],
        answer: "C",
        explanation:
          "0.0.0.0/0 是默认路由，前缀长度为 0 表示匹配任意目的 IP 地址。当路由表中没有更精确的匹配条目时，数据报将按照默认路由转发。默认路由常用于将流量指向上游路由器或互联网网关，减小路由表规模。它是最后匹配的兜底路由，优先级最低。",
      },
      {
        id: "cs103_q20",
        type: "short",
        stem: "比较 RIP 和 OSPF 路由协议的主要区别。",
        answer:
          "RIP 是基于距离向量的路由协议，以跳数为度量值，最大 15 跳，每 30 秒交换完整路由表，收敛慢适合小型网络。OSPF 是基于链路状态的协议，使用 Dijkstra 算法计算最短路径，以带宽为度量，仅交换链路状态变化信息，收敛快支持区域划分适合大型网络。",
        explanation:
          "RIP 是距离向量协议，仅与邻居交换路由表，跳数度量最大 15 跳限制网络规模，计数到无穷问题导致收敛慢。OSPF 是链路状态协议，泛洪链路状态信息使每台路由器掌握全局拓扑，Dijkstra 计算最短路径，支持区域划分和负载均衡，收敛快适合大型网络。",
      },
    ],
  },

  // ---- 网络安全基础 ----
  {
    quizId: "quiz_cs103_security",
    courseId: "cs103",
    topic: "网络安全基础",
    questions: [
      {
        id: "cs103_q21",
        type: "choice",
        stem: "对称加密算法（如 AES）相比非对称加密算法（如 RSA）的主要优势是？",
        options: [
          "A. 安全性更高",
          "B. 加解密速度快，适合大量数据加密",
          "C. 不需要密钥管理",
          "D. 可以用于数字签名",
        ],
        answer: "B",
        explanation:
          "对称加密加解密使用同一密钥，计算速度快，适合加密大量数据。非对称加密使用公钥和私钥对，计算复杂速度慢，但解决了密钥分发问题并支持数字签名。实践中常用混合方式：非对称加密协商对称密钥，对称密钥加密实际数据。",
      },
      {
        id: "cs103_q22",
        type: "choice",
        stem: "下列哪种攻击方式利用了用户已登录的信任身份，诱导用户在不知情下发送请求？",
        options: [
          "A. SQL 注入",
          "B. CSRF（跨站请求伪造）",
          "C. XSS（跨站脚本攻击）",
          "D. DDoS（分布式拒绝服务）",
        ],
        answer: "B",
        explanation:
          "CSRF（Cross-Site Request Forgery）利用用户已登录的身份凭证，诱导用户在不知情下向目标网站发送恶意请求。攻击者构造恶意页面或链接，用户访问后浏览器自动携带 Cookie 发送请求执行操作。防御方法包括 Token 验证、SameSite Cookie 属性和 Referer 检查。",
      },
      {
        id: "cs103_q23",
        type: "short",
        stem: "比较 CSRF 和 XSS 攻击的原理及防御方式。",
        answer:
          "CSRF 利用用户已登录身份诱导其发送恶意请求，攻击者是第三方，防御用 Token 验证和 SameSite Cookie。XSS 在页面中注入恶意脚本在用户浏览器执行，攻击源是网站自身漏洞，防御用输入过滤、输出编码和 CSP 策略。CSRF 冒用身份发请求，XSS 窃取数据或执行脚本。",
        explanation:
          "CSRF 是攻击者冒充已登录用户发送请求，利用 Cookie 自动携带特性，防御用 CSRF Token 和 SameSite Cookie。XSS 是攻击者向页面注入恶意 JavaScript 在受害者浏览器执行，可窃取 Cookie 或执行操作，防御用输入过滤、HTML 实体编码和 CSP 内容安全策略。两者机制不同防御方式也不同。",
      },
      {
        id: "cs103_q27",
        type: "choice",
        stem: "TLS 1.3 使用临时 (EC)DHE、服务器证书认证、无客户端证书且不使用 PSK。ClientHello 之后，哪一项同时给出了服务器主要握手消息的正确顺序，以及客户端开始发送 1-RTT 应用数据前必须完成的动作？",
        options: [
          "A. ServerHello -> Certificate -> EncryptedExtensions -> Finished -> CertificateVerify；收到 ServerHello 后即可发送",
          "B. ServerHello -> EncryptedExtensions -> Certificate -> CertificateVerify -> Finished；验证服务器 Finished 并发送客户端 Finished 后",
          "C. EncryptedExtensions -> ServerHello -> CertificateVerify -> Certificate -> Finished；验证证书后即可发送",
          "D. ServerHello -> EncryptedExtensions -> Finished -> Certificate -> CertificateVerify；收到服务器 Finished 后立即发送且无需客户端 Finished",
        ],
        answer: "B",
        explanation:
          "TLS 1.3 的完整证书握手中，ServerHello 后依次出现加密的 EncryptedExtensions、Certificate、CertificateVerify 和 Finished。客户端必须验证服务器 Finished，并发送自己的 Finished 完成握手认证后，才开始发送普通 1-RTT 应用数据。",
      },
      {
        id: "cs103_q51",
        type: "choice",
        stem: "传统包过滤防火墙主要依据哪一组报文字段执行访问控制？",
        options: [
          "A. 信号频率和传输介质",
          "B. 仅依据源 MAC 地址",
          "C. 源/目的 IP、协议号和传输层端口",
          "D. HTTP 正文中的业务字段",
        ],
        answer: "C",
        explanation:
          "传统包过滤同时检查网络层的源/目的 IP 和协议号，以及 TCP/UDP 源端口、目的端口等传输层字段。把它笼统归为单一 OSI 层会忽略端口条件；应用层防火墙才会进一步解析 HTTP 等应用协议内容。",
      },
      {
        id: "cs103_q52",
        type: "choice",
        stem: "数字签名的主要作用是？",
        options: [
          "A. 加密数据内容防止窃听",
          "B. 验证消息完整性和发送者身份不可否认性",
          "C. 压缩数据减少传输量",
          "D. 路由数据包到正确目的",
        ],
        answer: "B",
        explanation:
          "数字签名使用发送方私钥对消息摘要加密，接收方用发送方公钥验证。签名保证消息完整性（摘要匹配则未被篡改）、身份认证（公钥验证私钥签名）和不可否认性（私钥仅持有者拥有）。数据加密防止窃听是加密的功能而非签名。数字签名和加密通常结合使用实现完整安全通信。",
      },
    ],
  },

  // ---- 物理层与数据链路层 ----
  {
    quizId: "quiz_cs103_phy_dll",
    courseId: "cs103",
    topic: "物理层与数据链路层",
    questions: [
      {
        id: "cs103_q53",
        type: "choice",
        stem: "一个 IPv4 数据报的 Total Length 为 28 字节，将其直接封装进标准 Ethernet 帧。按 RFC 894，Ethernet 数据字段最少 46 字节；不考虑 VLAN。链路层需补多少字节、发送时 Ethernet 数据字段多长、接收端 IP 首部中的 Total Length 仍是多少？",
        options: [
          "A. 18 字节、46 字节、46 字节",
          "B. 18 字节、46 字节、28 字节",
          "C. 36 字节、64 字节、28 字节",
          "D. 0 字节、28 字节、28 字节",
        ],
        answer: "B",
        explanation:
          "Ethernet 数据字段要从 28 字节补到最小 46 字节，因此链路层追加 18 字节零填充。RFC 894 明确填充不属于 IP 数据报，也不计入 IPv4 Total Length，所以发送字段长 46 字节而 IP Total Length 仍为 28 字节。",
      },
      {
        id: "cs103_q54",
        type: "choice",
        stem: "MAC 地址的标准长度为？",
        options: ["A. 32 位", "B. 48 位", "C. 64 位", "D. 128 位"],
        answer: "B",
        explanation:
          "MAC（介质访问控制）地址长度为 48 位（6 字节），通常以十六进制表示如 00:1A:2B:3C:4D:5E。前 24 位为 OUI（组织唯一标识符），由 IEEE 分配给设备厂商；后 24 位由厂商自行分配。MAC 地址在数据链路层用于局域网内的帧寻址，与网络层的 IP 地址配合实现端到端通信。",
      },
      {
        id: "cs103_q55",
        type: "choice",
        stem: "CSMA/CD 协议中，发生冲突后节点执行二进制指数退避算法的目的是？",
        options: [
          "A. 检测冲突是否发生",
          "B. 减少再次冲突的概率",
          "C. 增加数据传输速度",
          "D. 加密数据帧内容",
        ],
        answer: "B",
        explanation:
          "二进制指数退避算法在冲突后让节点等待随机时间再重传，随冲突次数增加退避窗口按指数增大，从而减少多个节点同时重传导致再次冲突的概率。CSMA/CD 用于以太网，先听后发、边发边听、冲突停发、随机重发。现代交换式以太网全双工模式下不再需要 CSMA/CD。",
      },
      {
        id: "cs103_q56",
        type: "choice",
        stem: "VLAN（虚拟局域网）的主要优势是？",
        options: [
          "A. 增加物理带宽",
          "B. 隔离广播域，提高网络安全和管理灵活性",
          "C. 减少物理线缆使用量",
          "D. 自动加密网络通信",
        ],
        answer: "B",
        explanation:
          "VLAN 通过逻辑划分而非物理位置将网络设备分组，每个 VLAN 构成独立的广播域，隔离广播流量提高网络效率。VLAN 增强安全性（不同 VLAN 间需路由才能通信），简化管理（设备移动只需更改 VLAN 配置无需重新布线）。VLAN 基于 IEEE 802.1Q 标准，在以太网帧中插入 VLAN 标签。",
      },
      {
        id: "cs103_q57",
        type: "choice",
        stem: "ARP 协议的作用是？",
        options: [
          "A. 将 IP 地址解析为 MAC 地址",
          "B. 将 MAC 地址解析为 IP 地址",
          "C. 将域名解析为 IP 地址",
          "D. 将 IP 地址解析为端口号",
        ],
        answer: "A",
        explanation:
          "ARP（地址解析协议）将网络层的 IP 地址解析为数据链路层的 MAC 地址，使 IP 数据报能在局域网中通过 MAC 帧传输。主机发送 ARP 请求广播，目标 IP 匹配的主机回复 ARP 应答包含其 MAC 地址。ARP 缓存存储解析结果以减少后续请求。域名解析由 DNS 完成，RARP 实现反向解析。",
      },
    ],
  },

  // ---- 网络层与IP协议 ----
  {
    quizId: "quiz_cs103_net_ip",
    courseId: "cs103",
    topic: "网络层与IP协议",
    questions: [
      {
        id: "cs103_q58",
        type: "choice",
        stem: "IPv6 地址的长度为？",
        options: ["A. 32 位", "B. 64 位", "C. 128 位", "D. 256 位"],
        answer: "C",
        explanation:
          "IPv6 地址长度为 128 位，相比 IPv4 的 32 位地址空间大幅扩展，提供约 3.4 * 10^38 个地址。IPv6 采用冒号分隔的十六进制表示法如 2001:0db8:85a3::8a2e:0370:7334，支持地址压缩。IPv6 还简化了首部格式，取消了首部校验和和分片字段，支持自动配置和端到端安全。",
      },
      {
        id: "cs103_q59",
        type: "choice",
        stem: "IP 数据报分片的原因是？",
        options: [
          "A. 加密数据内容",
          "B. 数据报长度超过链路 MTU（最大传输单元）",
          "C. 减少传输延迟",
          "D. 提高传输可靠性",
        ],
        answer: "B",
        explanation:
          "当 IP 数据报长度超过底层链路的 MTU 时，路由器将数据报分片为多个较小的片段传输。每个分片包含原始数据报的标识号和偏移量，目的主机负责重组。IPv4 中路由器和主机均可分片，IPv6 中仅源主机分片（通过 Path MTU Discovery）。分片会增加开销，应尽量避免。",
      },
      {
        id: "cs103_q60",
        type: "choice",
        stem: "现有地址块 192.0.2.0/24，需要按“需求从大到小、地址从低到高且连续”划分三个不重叠子网，分别至少容纳 100、50、25 个传统 IPv4 可用主机地址（网络地址与广播地址不可分配）。第三个子网的网络、可用地址范围和广播地址是？",
        options: [
          "A. 192.0.2.160/27；192.0.2.161-192.0.2.190；192.0.2.191",
          "B. 192.0.2.192/28；192.0.2.193-192.0.2.206；192.0.2.207",
          "C. 192.0.2.192/27；192.0.2.193-192.0.2.222；192.0.2.223",
          "D. 192.0.2.224/27；192.0.2.225-192.0.2.254；192.0.2.255",
        ],
        answer: "C",
        explanation:
          "100 台主机需 /25，先分配 192.0.2.0/25；50 台需 /26，随后分配 192.0.2.128/26。25 台需含 32 个地址、30 个传统可用地址的 /27，因此第三段从 192.0.2.192 开始，可用范围为 .193-.222，广播地址为 .223。",
      },
      {
        id: "cs103_q61",
        type: "choice",
        stem: "NAT（网络地址转换）的主要作用是？",
        options: [
          "A. 加密网络通信内容",
          "B. 在私有 IP 和公网 IP 之间转换，缓解 IPv4 地址短缺",
          "C. 提高路由转发速度",
          "D. 过滤恶意网络流量",
        ],
        answer: "B",
        explanation:
          "NAT 在边缘路由器上将内部私有 IP 地址转换为公网 IP 地址，使多台内网主机共享少量公网 IP 访问互联网，有效缓解 IPv4 地址枯竭问题。NAT 维护转换表记录内外地址映射关系。常见类型包括静态 NAT、动态 NAT 和 PAT（端口地址转换）。NAT 破坏了端到端通信模型，对某些协议（如 SIP）有兼容性问题。",
      },
      {
        id: "cs103_q62",
        type: "choice",
        stem: "ICMP 协议的主要功能是？",
        options: [
          "A. 传输网页数据",
          "B. 报告网络错误和传递控制信息",
          "C. 分配 IP 地址",
          "D. 解析域名为 IP 地址",
        ],
        answer: "B",
        explanation:
          "ICMP（互联网控制报文协议）工作在网络层，用于报告 IP 数据报传输中的错误（如目的不可达、超时、参数问题）和传递网络控制信息。ping 命令使用 ICMP Echo 请求和应答测试主机连通性，traceroute 利用 ICMP 超时报文追踪路由路径。ICMP 不传输应用数据，是 IP 协议的辅助协议。",
      },
    ],
  },
]);
