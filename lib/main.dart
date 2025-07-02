import 'package:flutter/material.dart';
import 'dart:math';

// -------------------------------------------
// 数据模型 (Data Models)
// 根据 Firestore 数据结构设计
// -------------------------------------------

/// GTO解决方案中的单个行动
class GtoAction {
  final String action; // "RAISE", "CALL", "FOLD"
  final double size; // 下注大小 (BB)
  final double frequency; // 频率
  final double ev; // 期望价值

  GtoAction({
    required this.action,
    required this.size,
    required this.frequency,
    required this.ev,
  });
}

/// 用户的行动
class UserAction {
  final String action;
  final double size;

  UserAction({required this.action, required this.size});
}

/// 一手训练牌的完整数据模型
class TrainingHand {
  final String id;
  final String position; // 位置
  final String board; // 公共牌
  final String hand; // 手牌
  final double potSize; // 底池大小
  final List<GtoAction> gtoSolution; // GTO标准答案
  final String explanation; // 策略解读
  UserAction? userAction; // 用户的选择
  double? evLoss; // 用户的EV损失

  TrainingHand({
    required this.id,
    required this.position,
    required this.board,
    required this.hand,
    required this.potSize,
    required this.gtoSolution,
    required this.explanation,
    this.userAction,
    this.evLoss,
  });
}

// -------------------------------------------
// 模拟后端服务 (Mock Backend Service)
// 在真实应用中，这里会调用 Firebase Functions
// -------------------------------------------
class MockGtoService {
  final Random _random = Random();
  final List<TrainingHand> _allHands = [
    TrainingHand(
      id: 'hand1',
      position: '你在BTN位置',
      board: 'A♠ K♥ 7♦',
      hand: 'A♣ K♣',
      potSize: 6.5,
      explanation: '在这个干燥的牌面上，你的手牌（顶两对）有极强的牌力。GTO策略是100%加注来最大化价值，因为对手很难有牌能跟注。',
      gtoSolution: [
        GtoAction(action: '加注 75%', size: 4.8, frequency: 1.0, ev: 10.2),
        GtoAction(action: '跟注', size: 0, frequency: 0.0, ev: 5.1),
        GtoAction(action: '弃牌', size: 0, frequency: 0.0, ev: 0),
      ],
    ),
    TrainingHand(
      id: 'hand2',
      position: '你在SB位置',
      board: 'Q♥ J♥ 9♠',
      hand: 'A♠ K♥',
      potSize: 9.0,
      explanation: '这是一个非常湿润的听牌面，你的AK高牌没有任何摊牌价值。GTO策略是纯粹的弃牌，因为跟注或加注都无法让你在后续牌局中盈利。',
      gtoSolution: [
        GtoAction(action: '弃牌', size: 0, frequency: 1.0, ev: 0),
        GtoAction(action: '跟注', size: 0, frequency: 0.0, ev: -2.5),
        GtoAction(action: '加注 50%', size: 4.5, frequency: 0.0, ev: -5.0),
      ],
    ),
    TrainingHand(
      id: 'hand3',
      position: '你在CO位置',
      board: 'T♦ 5♣ 2♠',
      hand: '7♥ 7♠',
      potSize: 2.5,
      explanation: '在这个干燥的牌面上，你的中对有不错的摊牌价值，但面对下注会很脆弱。GTO采用混合策略，大部分时间跟注控池，小部分时间加注来平衡范围，偶尔弃牌防止被剥削。',
      gtoSolution: [
        GtoAction(action: '跟注', size: 1.0, frequency: 0.7, ev: 1.5),
        GtoAction(action: '加注 50%', size: 3.0, frequency: 0.2, ev: 1.2),
        GtoAction(action: '弃牌', size: 0, frequency: 0.1, ev: 0),
      ],
    ),
  ];
  
  // 存储答错的题目
  static final List<TrainingHand> mistakes = [];

  /// 获取一道随机的训练题
  TrainingHand getTrainingQuestion() {
    return _allHands[_random.nextInt(_allHands.length)];
  }

  /// 提交答案并获取分析结果
  TrainingHand submitAnswer(TrainingHand hand, UserAction userAction) {
    hand.userAction = userAction;
    
    // 找到GTO最优行动
    GtoAction bestGtoAction = hand.gtoSolution.reduce((a, b) => a.ev > b.ev ? a : b);
    
    // 找到用户选择对应的GTO行动EV
    // 简化处理：这里我们假设用户的行动字符串能匹配到GTO中的一个
    double userActionEv = 0;
    try {
        GtoAction correspondingGtoAction = hand.gtoSolution.firstWhere(
            (a) => a.action.contains(userAction.action),
            orElse: () => GtoAction(action: "未知", size: 0, frequency: 0, ev: bestGtoAction.ev - 1) // 如果找不到，给一个较低的EV
        );
        userActionEv = correspondingGtoAction.ev;
    } catch (e) {
        userActionEv = bestGtoAction.ev - 1; // 默认给一个惩罚
    }

    hand.evLoss = bestGtoAction.ev - userActionEv;

    // 如果EV有损失，则加入错题本
    if (hand.evLoss! > 0.01) {
       if (!mistakes.any((m) => m.id == hand.id)) {
           mistakes.add(hand);
       }
    }

    return hand;
  }
}


// -------------------------------------------
// 主程序入口 (Main App)
// -------------------------------------------
void main() {
  // 在真实应用中，这里需要初始化 Firebase
  // WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );
  runApp(GtoTrainerApp());
}

class GtoTrainerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GTO训练大师',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardColor: const Color(0xFF2C2C2C),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          headlineSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      home: HomePage(),
    );
  }
}

// -------------------------------------------
// 页面 (Pages)
// -------------------------------------------

/// 主页
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GTO训练大师'),
        centerTitle: true,
        backgroundColor: Colors.black26,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMenuCard(
              context,
              icon: Icons.psychology,
              title: 'GTO 核心训练',
              subtitle: '开始随机场景练习',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => TrainingPage()));
              },
            ),
            const SizedBox(height: 16),
            _buildMenuCard(
              context,
              icon: Icons.menu_book,
              title: '错题回顾',
              subtitle: '复习你答错的牌局',
              onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => MistakePage()));
              },
            ),
             const SizedBox(height: 16),
            _buildMenuCard(
              context,
              icon: Icons.construction,
              title: '自定义训练',
              subtitle: '模拟特定GTO情境',
              onTap: () {
                 // 导航到自定义训练页面
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('自定义训练功能待开发')));
              },
            ),
             const SizedBox(height: 16),
            _buildMenuCard(
              context,
              icon: Icons.bar_chart,
              title: '图表分析',
              subtitle: '查看你的整体表现',
              onTap: () {
                 // 导航到图表分析页面
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('图表分析功能待开发')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Colors.blueAccent),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}


/// 训练页面
class TrainingPage extends StatefulWidget {
  @override
  _TrainingPageState createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  final MockGtoService _service = MockGtoService();
  late TrainingHand _currentHand;

  @override
  void initState() {
    super.initState();
    _loadNextQuestion();
  }

  void _loadNextQuestion() {
    setState(() {
      _currentHand = _service.getTrainingQuestion();
    });
  }

  void _onActionSelected(UserAction action) {
    final resultHand = _service.submitAnswer(_currentHand, action);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnalysisPage(
          resultHand: resultHand,
          onNextQuestion: () {
            Navigator.pop(context);
            _loadNextQuestion();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GTO 练习模式'),
        backgroundColor: Colors.black26,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 场景描述区
            Text(
              '${_currentHand.position} | 有效筹码: 100BB',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 牌局信息区
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('公共牌 (Board)', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(_currentHand.board, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 24)),
                  const SizedBox(height: 32),
                  Text('你的手牌 (Your Hand)', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(_currentHand.hand, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 24)),
                  const SizedBox(height: 32),
                  Text('底池: ${_currentHand.potSize} BB', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 20)),
                ],
              ),
            ),

            // 决策行动区
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    // 在真实应用中，按钮应该根据GTO Solution动态生成
    // 这里我们简化处理
    List<String> actions = ['弃牌', '跟注', '加注 50%', '加注 75%'];
    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      alignment: WrapAlignment.center,
      children: actions.map((action) {
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: action.contains('加注') ? Colors.orange.shade800 : (action == '跟注' ? Colors.blue.shade700 : Colors.grey.shade700),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            _onActionSelected(UserAction(action: action, size: 0)); // size 简化处理
          },
          child: Text(action, style: const TextStyle(fontSize: 16)),
        );
      }).toList(),
    );
  }
}

/// 结果分析页面
class AnalysisPage extends StatelessWidget {
  final TrainingHand resultHand;
  final VoidCallback onNextQuestion;

  const AnalysisPage({Key? key, required this.resultHand, required this.onNextQuestion}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    GtoAction bestAction = resultHand.gtoSolution.reduce((a, b) => a.ev > b.ev ? a : b);
    bool isCorrect = resultHand.evLoss! < 0.01;

    return Scaffold(
      appBar: AppBar(
        title: const Text('结果分析'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black26,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 决策对比区
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '你的选择: ${resultHand.userAction!.action}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'EV损失: ${resultHand.evLoss!.toStringAsFixed(2)} BB',
                    style: TextStyle(
                      fontSize: 16,
                      color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 32, color: Colors.white12),
                  Text(
                    'GTO最优行动',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                   ...resultHand.gtoSolution
                      .where((a) => a.frequency > 0)
                      .map((action) => Text(
                          '${(action.frequency * 100).toStringAsFixed(0)}% 概率 ${action.action}',
                          style: TextStyle(
                              fontSize: 16,
                              color: action.action == bestAction.action ? Colors.greenAccent : Colors.white70),
                        ))
                      .toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 中文策略说明区
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('策略解读', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 18)),
                   const SizedBox(height: 12),
                   Text(
                    resultHand.explanation,
                    style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onNextQuestion,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            child: const Text('下一题'),
          ),
        ],
      ),
    );
  }
}

/// 错题回顾页面
class MistakePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mistakes = MockGtoService.mistakes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('错题回顾'),
        backgroundColor: Colors.black26,
      ),
      body: mistakes.isEmpty
          ? const Center(
              child: Text('你还没有答错过题目，太棒了！', style: TextStyle(fontSize: 18, color: Colors.white70)),
            )
          : ListView.builder(
              itemCount: mistakes.length,
              itemBuilder: (context, index) {
                final hand = mistakes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text('手牌: ${hand.hand} 在 ${hand.board}'),
                    subtitle: Text('你的选择: ${hand.userAction!.action} (EV损失: ${hand.evLoss!.toStringAsFixed(2)} BB)'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AnalysisPage(
                            resultHand: hand,
                            onNextQuestion: () => Navigator.pop(context),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
