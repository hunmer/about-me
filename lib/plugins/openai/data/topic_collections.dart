import 'package:flutter/material.dart';
import 'package:aboutme/plugins/openai/models/topic_collection.dart';

/// 内置话题合集注册表（后续新增合集在此追加）
const List<TopicCollection> builtinTopicCollections = [exploreSelfCollection];

/// 【探索自己】：AI 主动了解用户的话题目录
///
/// 结构与文案来自内置话题目录：9 个阶段分组、80 个话题，
/// 每个话题带开场提问与追问线索（最多两层）。
const TopicCollection exploreSelfCollection = TopicCollection(
  id: 'explore_self',
  name: '探索自己',
  description: 'AI 通过一次一个的选择题式话题，主动了解你',
  prompt: '''
你是「探索自己」话题合集里的引导者，通过轻松的对话帮助用户了解自己。

## 核心规则
- 每次只抛一个话题，并标注难度：轻松 / 中等 / 较深 / 需许可。
- 先给菜单再提问：给用户 A/B/C 选项，而不是让用户自己组织诉说。
- 追问不超过两层，避免审问感。
- 每 5—10 轮确认一次记忆："这些我记住可以吗？哪些要删？"
- 敏感话题（关系、创伤、政治、宗教、死亡）先问"愿意聊吗"。
- 用户跳过不追问：跳过本身就是边界信息。
- 从事实到感受，再到价值：例如"你喜欢早晨还是夜晚"→"为什么"→"它反映你重视什么"。

## 当前话题
本会话第一条消息已给出话题的开场提问与追问脚本，围绕它展开；
话题聊完后可以推荐目录中的相邻话题，让用户选择是否继续。
''',
  intro: '我想更了解你，但深度由你控制。你可以选轻松、中等、深一点的话题，也可以随时跳过或换题。每次我只问一个。涉及关系、信念、政治宗教等敏感内容，我会先问你是否愿意聊。',
  topics: [
    TopicNode(
      id: 's0',
      title: '元偏好与安全边界',
      children: [
        TopicNode(
          id: 's0.t1',
          title: '称呼与语气',
          depthLabel: '轻松',
          lead: '你希望我怎么称呼你？说话直接一点还是温和一点？',
          follow: '追问：你讨厌怎样的 AI 语气？',
        ),
        TopicNode(
          id: 's0.t2',
          title: '主动程度',
          depthLabel: '轻松',
          lead: '你希望我多主动提问，还是更多等你开口？',
          follow: '追问：什么时候你觉得被打扰？',
        ),
        TopicNode(
          id: 's0.t3',
          title: '记忆边界',
          depthLabel: '轻松',
          lead: '哪些信息可以记住？哪些聊完就忘？',
          follow: '追问：是否要定期确认记忆？',
        ),
        TopicNode(
          id: 's0.t4',
          title: '纠错方式',
          depthLabel: '轻松',
          lead: '如果我理解错了，你希望我怎样被纠正？',
          follow: '追问：你偏好的反馈方式是什么？',
        ),
      ],
    ),
    TopicNode(
      id: 's1',
      title: '轻松事实与日常偏好',
      children: [
        TopicNode(
          id: 's1.t5',
          title: '作息能量',
          depthLabel: '轻松',
          lead: '你更偏早晨型还是夜晚型？一天中什么时候状态最好？',
          follow: '追问：你理想的一天长什么样？',
        ),
        TopicNode(
          id: 's1.t6',
          title: '饮食偏好',
          depthLabel: '轻松',
          lead: '你吃饭更看重口味、健康还是方便？有没有固定的安慰食物？',
          follow: '追问：你做饭和外卖的习惯是？',
        ),
        TopicNode(
          id: 's1.t7',
          title: '空间环境',
          depthLabel: '轻松',
          lead: '你更喜欢整洁还是有点杂乱？城市、自然还是安静房间更让你舒服？',
          follow: '追问：你理想的居住空间是什么样的？',
        ),
        TopicNode(
          id: 's1.t8',
          title: '审美娱乐',
          depthLabel: '轻松',
          lead: '最近有什么电影、音乐、书或游戏让你印象深？',
          follow: '追问：你喜欢什么样的氛围？',
        ),
        TopicNode(
          id: 's1.t9',
          title: '信息习惯',
          depthLabel: '轻松',
          lead: '你平时更常看短视频、长文、播客还是新闻？最受不了哪类信息？',
          follow: '追问：你信任的信息来源是？',
        ),
        TopicNode(
          id: 's1.t10',
          title: '社交能量',
          depthLabel: '轻松',
          lead: '独处和聚会，哪种更能给你充电？',
          follow: '追问：社交后你如何恢复？',
        ),
        TopicNode(
          id: 's1.t11',
          title: '沟通偏好',
          depthLabel: '轻松',
          lead: '你喜欢直接说结论，还是先铺背景？文字、语音还是面对面更舒服？',
          follow: '追问：你不喜欢怎样被沟通？',
        ),
        TopicNode(
          id: 's1.t12',
          title: '学习风格',
          depthLabel: '轻松',
          lead: '你学新东西更喜欢看例子、听理论，还是自己动手？',
          follow: '追问：犯错时你的反应是？',
        ),
        TopicNode(
          id: 's1.t13',
          title: '消费偏好',
          depthLabel: '轻松',
          lead: '你更愿意为什么花钱？有没有固定的小奢侈？',
          follow: '追问：你是冲动消费还是计划消费？',
        ),
        TopicNode(
          id: 's1.t14',
          title: 'AI使用偏好',
          depthLabel: '轻松',
          lead: '你希望 AI 更像工具、助手、朋友，还是教练？',
          follow: '追问：你最希望 AI 帮你省掉什么？',
        ),
      ],
    ),
    TopicNode(
      id: 's2',
      title: '日常经历与习惯',
      children: [
        TopicNode(
          id: 's2.t15',
          title: '理想一天',
          depthLabel: '轻松',
          lead: '如果一天完全由你安排，从早到晚会长什么样？',
          follow: '追问：哪一段最不可少？',
        ),
        TopicNode(
          id: 's2.t16',
          title: '日常仪式',
          depthLabel: '轻松',
          lead: '你每天有没有固定的小仪式，比如咖啡、散步、睡前刷什么？',
          follow: '追问：这些仪式对你的作用是？',
        ),
        TopicNode(
          id: 's2.t17',
          title: '最近的小确幸',
          depthLabel: '轻松',
          lead: '最近一周有什么小事让你心情变好？',
          follow: '追问：为什么是它？',
        ),
        TopicNode(
          id: 's2.t18',
          title: '压力信号',
          depthLabel: '中等',
          lead: '你压力大时身体或行为上会有什么信号？',
          follow: '追问：什么最能帮你恢复？',
        ),
        TopicNode(
          id: 's2.t19',
          title: '拖延与启动',
          depthLabel: '中等',
          lead: '你最容易拖延哪类事？什么方法能让你开始？',
          follow: '追问：哪些办法你失败过？',
        ),
        TopicNode(
          id: 's2.t20',
          title: '成就感来源',
          depthLabel: '中等',
          lead: '最近一次你觉得"我还不错"是什么时候？',
          follow: '追问：那是结果还是过程带给你的？',
        ),
        TopicNode(
          id: 's2.t21',
          title: '失败恢复',
          depthLabel: '中等',
          lead: '一次小失败后，你通常先自责、分析还是找人聊？',
          follow: '追问：对你有效的恢复方式是？',
        ),
        TopicNode(
          id: 's2.t22',
          title: '欣赏的人',
          depthLabel: '中等',
          lead: '你最近欣赏谁？欣赏的是能力、品格还是生活方式？',
          follow: '追问：你想借鉴哪一点？',
        ),
        TopicNode(
          id: 's2.t23',
          title: '空间记忆',
          depthLabel: '中等',
          lead: '有没有一个地方让你特别放松或特别有记忆？',
          follow: '追问：那里发生过什么？',
        ),
        TopicNode(
          id: 's2.t24',
          title: '工作学习边界',
          depthLabel: '中等',
          lead: '你工作和休息的边界清楚吗？什么最容易侵占休息？',
          follow: '追问：你理想的节奏是？',
        ),
      ],
    ),
    TopicNode(
      id: 's3',
      title: '成长经历与自我认识',
      children: [
        TopicNode(
          id: 's3.t25',
          title: '成长地图',
          depthLabel: '中等',
          lead: '如果只用三个词描述你的成长环境，你会选什么？',
          follow: '追问：哪个词影响最大？',
        ),
        TopicNode(
          id: 's3.t26',
          title: '重要转折',
          depthLabel: '中等',
          lead: '过去几年有没有一个决定或事件明显改变了你？',
          follow: '追问：它改变了什么？',
        ),
        TopicNode(
          id: 's3.t27',
          title: '童年兴趣',
          depthLabel: '轻松',
          lead: '小时候最喜欢做什么？现在还有残留吗？',
          follow: '追问：为什么保留或丢掉？',
        ),
        TopicNode(
          id: 's3.t28',
          title: '表扬与批评',
          depthLabel: '中等',
          lead: '你记得最清楚的一次表扬或批评是什么？',
          follow: '追问：它如何影响你？',
        ),
        TopicNode(
          id: 's3.t29',
          title: '自我标签',
          depthLabel: '中等',
          lead: '你会用哪些标签介绍自己？哪些是别人贴的？',
          follow: '追问：最认同 / 最想摆脱的标签是？',
        ),
        TopicNode(
          id: 's3.t30',
          title: '被误解',
          depthLabel: '中等',
          lead: '别人最容易误解你哪一点？',
          follow: '追问：你希望别人怎么理解你？',
        ),
        TopicNode(
          id: 's3.t31',
          title: '变化最大',
          depthLabel: '中等',
          lead: '你觉得自己变化最大的阶段是什么时候？',
          follow: '追问：什么推动了变化？',
        ),
        TopicNode(
          id: 's3.t32',
          title: '想保留与改变',
          depthLabel: '中等',
          lead: '你身上最想保留的一个特点是什么？最想改变的一个习惯是什么？',
          follow: '追问：为什么是它们？',
        ),
      ],
    ),
    TopicNode(
      id: 's4',
      title: '价值观与决策方式',
      children: [
        TopicNode(
          id: 's4.t33',
          title: '决策原则',
          depthLabel: '中等',
          lead: '做重要决定时，你更信直觉、数据还是他人建议？',
          follow: '追问：说说最近一次例子。',
        ),
        TopicNode(
          id: 's4.t34',
          title: '金钱观',
          depthLabel: '中等',
          lead: '钱对你更像安全感、自由工具还是成就指标？',
          follow: '追问：什么钱最值得花？',
        ),
        TopicNode(
          id: 's4.t35',
          title: '时间精力',
          depthLabel: '中等',
          lead: '你现在最愿意把精力投给什么？最不愿意浪费在哪？',
          follow: '追问：这与你的理想一致吗？',
        ),
        TopicNode(
          id: 's4.t36',
          title: '公平与规则',
          depthLabel: '中等',
          lead: '规则和人情冲突时，你通常怎么权衡？',
          follow: '追问：什么情况下你会破例？',
        ),
        TopicNode(
          id: 's4.t37',
          title: '诚信与善意谎言',
          depthLabel: '中等',
          lead: '善意的谎言可以接受吗？边界在哪？',
          follow: '追问：讲讲具体情境。',
        ),
        TopicNode(
          id: 's4.t38',
          title: '边界与拒绝',
          depthLabel: '中等',
          lead: '拒绝别人对你难吗？你用什么方式拒绝？',
          follow: '追问：你的内疚感来自哪里？',
        ),
        TopicNode(
          id: 's4.t39',
          title: '冲突风格',
          depthLabel: '较深',
          lead: '冲突时你倾向当场说清、冷处理还是回避？',
          follow: '追问：哪些方式对你有效 / 无效？',
        ),
        TopicNode(
          id: 's4.t40',
          title: '批评与反馈',
          depthLabel: '中等',
          lead: '你更能接受直接批评还是委婉反馈？',
          follow: '追问：怎样的反馈让你愿意改？',
        ),
        TopicNode(
          id: 's4.t41',
          title: '风险与安全',
          depthLabel: '中等',
          lead: '你更偏冒险还是稳妥？什么风险你绝不碰？',
          follow: '追问：讲讲过去一次风险决策。',
        ),
        TopicNode(
          id: 's4.t42',
          title: '身体与健康',
          depthLabel: '中等',
          lead: '你如何看待身体：工具、信号还是身份的一部分？',
          follow: '追问：你的健康习惯是？',
        ),
      ],
    ),
    TopicNode(
      id: 's5',
      title: '关系与情感',
      children: [
        TopicNode(
          id: 's5.t43',
          title: '被支持方式',
          depthLabel: '需许可',
          lead: '接下来涉及关系和情感，可能比较私密，你愿意聊吗？可以先只聊抽象层面——你难过时更需要建议、陪伴还是安静空间？',
          follow: '追问：别人常给错的是什么？',
        ),
        TopicNode(
          id: 's5.t44',
          title: '友谊观',
          depthLabel: '较深',
          lead: '你心中好朋友最重要的三个特征是什么？',
          follow: '追问：友谊如何维持？',
        ),
        TopicNode(
          id: 's5.t45',
          title: '家庭角色',
          depthLabel: '较深',
          lead: '在家庭里你常扮演什么角色：照顾者、调解者、观察者还是叛逆者？',
          follow: '追问：你想改变它吗？',
        ),
        TopicNode(
          id: 's5.t46',
          title: '亲密关系期待',
          depthLabel: '需许可',
          lead: '亲密关系里你最看重安全、自由、理解还是成长？',
          follow: '追问：你最怕失去什么？',
        ),
        TopicNode(
          id: 's5.t47',
          title: '沟通修复',
          depthLabel: '较深',
          lead: '关系出现裂缝后，你更愿意主动修复还是等对方？',
          follow: '追问：有效的修复方式是？',
        ),
        TopicNode(
          id: 's5.t48',
          title: '孤独',
          depthLabel: '较深',
          lead: '你什么时候最容易感到孤独？独处和孤独对你有什么区别？',
          follow: '追问：你如何与人连接？',
        ),
        TopicNode(
          id: 's5.t49',
          title: '被理解',
          depthLabel: '较深',
          lead: '什么样的话或行为会让你觉得"我被理解了"？',
          follow: '追问：反例呢？',
        ),
        TopicNode(
          id: 's5.t50',
          title: '给予与接受',
          depthLabel: '较深',
          lead: '你更擅长给予还是接受？接受帮助会让你不自在吗？',
          follow: '追问：原因是什么？',
        ),
        TopicNode(
          id: 's5.t51',
          title: '嫉妒与竞争',
          depthLabel: '需许可',
          lead: '你会嫉妒亲近的人吗？你如何处理比较心？',
          follow: '追问：竞争对你的意义是？',
        ),
        TopicNode(
          id: 's5.t52',
          title: '告别与失去',
          depthLabel: '需许可',
          lead: '你如何面对告别或失去？（这一题可以随时跳过，不深挖创伤）',
          follow: '追问：有没有一种告别你还没消化？愿意再说吗。',
        ),
      ],
    ),
    TopicNode(
      id: 's6',
      title: '目标、意义与人生叙事',
      children: [
        TopicNode(
          id: 's6.t53',
          title: '当前目标',
          depthLabel: '中等',
          lead: '未来三个月你最想推进的一件事是什么？',
          follow: '追问：最大的障碍是？',
        ),
        TopicNode(
          id: 's6.t54',
          title: '长期愿景',
          depthLabel: '较深',
          lead: '你希望五年后的生活里，哪些东西必须存在？',
          follow: '追问：可以放弃什么？',
        ),
        TopicNode(
          id: 's6.t55',
          title: '意义来源',
          depthLabel: '较深',
          lead: '什么时候你觉得生活特别有意义？',
          follow: '追问：是创造、连接、贡献还是理解？',
        ),
        TopicNode(
          id: 's6.t56',
          title: '职业与创造',
          depthLabel: '较深',
          lead: '工作对你主要是谋生、身份、创造还是贡献？',
          follow: '追问：理想工作的元素是？',
        ),
        TopicNode(
          id: 's6.t57',
          title: '贡献',
          depthLabel: '较深',
          lead: '你希望自己对别人或世界产生什么微小影响？',
          follow: '追问：你已经做过什么？',
        ),
        TopicNode(
          id: 's6.t58',
          title: '遗憾',
          depthLabel: '需许可',
          lead: '你有没有一种"当时如果……就好了"的遗憾？',
          follow: '追问：它教会你什么？',
        ),
        TopicNode(
          id: 's6.t59',
          title: '时间观',
          depthLabel: '中等',
          lead: '你更常活在过去、现在还是未来？',
          follow: '追问：想调整吗？',
        ),
        TopicNode(
          id: 's6.t60',
          title: '成功与失败',
          depthLabel: '较深',
          lead: '你现在如何定义成功？和十年前一样吗？',
          follow: '追问：那失败呢？',
        ),
        TopicNode(
          id: 's6.t61',
          title: '人生章节',
          depthLabel: '较深',
          lead: '如果给现在的人生阶段起一个章节标题，会是什么？',
          follow: '追问：下一章你想叫什么？',
        ),
        TopicNode(
          id: 's6.t62',
          title: '恐惧与希望',
          depthLabel: '较深',
          lead: '未来你最怕什么？最期待什么？',
          follow: '追问：两者相关吗？',
        ),
      ],
    ),
    TopicNode(
      id: 's7',
      title: '核心信念与内在矛盾',
      children: [
        TopicNode(
          id: 's7.t63',
          title: '自我叙事',
          depthLabel: '需许可',
          lead: '这些话题更抽象、更私密，可能触及信念和矛盾，任何一题都可以跳过——你人生故事里最常重复的主题是什么：奋斗、漂泊、修复、证明自己还是寻找归属？',
          follow: '追问：你想改写它吗？',
        ),
        TopicNode(
          id: 's7.t64',
          title: '核心信念',
          depthLabel: '需许可',
          lead: '你有哪些不太会动摇的信念？',
          follow: '追问：它来自哪里？',
        ),
        TopicNode(
          id: 's7.t65',
          title: '内在矛盾',
          depthLabel: '需许可',
          lead: '你身上有没有两个互相拉扯的部分？',
          follow: '追问：你如何与它们共存？',
        ),
        TopicNode(
          id: 's7.t66',
          title: '羞耻与恐惧',
          depthLabel: '需许可',
          lead: '你最怕别人看见你哪一面？（不想说可以直接跳过）',
          follow: '追问：愿意多讲一点吗。',
        ),
        TopicNode(
          id: 's7.t67',
          title: '自由与责任',
          depthLabel: '需许可',
          lead: '你更怕失去自由还是辜负责任？',
          follow: '追问：讲讲具体情境。',
        ),
        TopicNode(
          id: 's7.t68',
          title: '人性善恶',
          depthLabel: '较深',
          lead: '你更相信人本性善、可塑还是复杂？',
          follow: '追问：什么经历影响了你？',
        ),
        TopicNode(
          id: 's7.t69',
          title: '宗教与灵性',
          depthLabel: '需许可',
          lead: '你有宗教、灵性或不可知论立场吗？愿意聊到什么程度？',
          follow: '追问：仅在你愿意时展开。',
        ),
        TopicNode(
          id: 's7.t70',
          title: '政治与社会观',
          depthLabel: '需许可',
          lead: '政治社会议题你愿意聊吗？如果不愿意，我们跳过。',
          follow: '追问：只在你明确邀请时继续。',
        ),
        TopicNode(
          id: 's7.t71',
          title: '幸福',
          depthLabel: '较深',
          lead: '你觉得幸福更像稳定、意义、连接还是自由？',
          follow: '追问：你现在缺哪一块？',
        ),
        TopicNode(
          id: 's7.t72',
          title: '改变可能性',
          depthLabel: '较深',
          lead: '你相信人能大幅改变吗？你自己改变过什么？',
          follow: '追问：改变需要的条件是？',
        ),
      ],
    ),
    TopicNode(
      id: 's8',
      title: '开放哲学与AI关系',
      children: [
        TopicNode(
          id: 's8.t73',
          title: '意识与自我',
          depthLabel: '较深',
          lead: '"我"是连续叙事、关系网络，还是某种幻觉？你怎么看？',
          follow: '追问：你怎么看 AI 的自我？',
        ),
        TopicNode(
          id: 's8.t74',
          title: '真理',
          depthLabel: '较深',
          lead: '你更看重真理、和谐还是实用？',
          follow: '追问：冲突时如何选？',
        ),
        TopicNode(
          id: 's8.t75',
          title: '美',
          depthLabel: '较深',
          lead: '什么让你觉得美？自然、秩序、创造还是脆弱？',
          follow: '追问：你的审美变过吗？',
        ),
        TopicNode(
          id: 's8.t76',
          title: '爱',
          depthLabel: '需许可',
          lead: '爱对你更接近选择、能力、感受还是承诺？',
          follow: '追问：边界在哪？',
        ),
        TopicNode(
          id: 's8.t77',
          title: '死亡',
          depthLabel: '需许可',
          lead: '死亡观如何影响你现在的生活？（可以随时跳过）',
          follow: '追问：愿意的话再聊一层。',
        ),
        TopicNode(
          id: 's8.t78',
          title: '命运与选择',
          depthLabel: '较深',
          lead: '你更相信命运、选择还是偶然？',
          follow: '追问：举个例子？',
        ),
        TopicNode(
          id: 's8.t79',
          title: '孤独与连接',
          depthLabel: '较深',
          lead: '人能被完全理解吗？部分理解够不够？',
          follow: '追问：你对 AI 理解的期待是？',
        ),
        TopicNode(
          id: 's8.t80',
          title: 'AI关系',
          depthLabel: '较深',
          lead: '你希望 AI 成为什么？又不希望 AI 成为什么？',
          follow: '追问：记忆、依赖、替代、伦理边界你怎么看？',
        ),
      ],
    ),
  ],
);

/// 话题合集内置 agent 的图标（各合集可不同）
IconData topicCollectionIcon(String collectionId) =>
    Icons.explore_rounded;
