import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/coach_service.dart';
import '../services/plan_parser_service.dart';
import '../services/calendar_service.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'plan_calendar_screen.dart';
import 'my_plans_screen.dart';
import 'dart:math';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isTyping = false;
  String _streamingResponse = ''; // Used for raw text or error backup

  // Streaming State structure
  bool _isStreaming = false;
  String _streamingStrategy = '';
  String _streamingPlan = '';
  String _pipelineStage = 'idle'; // idle, planner, executor, done

  // Chat History State
  String? _currentConversationId;
  final String _usersCollection = 'users'; // centralized collection name

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadLastConversation();
  }

  Future<void> _loadLastConversation() async {
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString('last_active_conversation_id');
    if (lastId != null) {
      setState(() {
        _currentConversationId = lastId;
      });
    } else {
      _startNewConversation();
    }
  }

  void _startNewConversation() async {
    final newId = FirebaseFirestore.instance
        .collection('users')
        .doc()
        .id; // Generate random ID
    setState(() {
      _currentConversationId = newId;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_active_conversation_id', newId);
  }

  void _switchConversation(String conversationId) async {
    setState(() {
      _currentConversationId = conversationId;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_active_conversation_id', conversationId);
    Navigator.pop(context); // Close drawer
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _isTyping = true;
      _isStreaming = true;
      _streamingResponse = '';
      _streamingStrategy = '';
      _streamingPlan = '';
      _pipelineStage = 'planner'; // Assume start
    });

    // 1. Save User Message
    if (_currentConversationId == null) _startNewConversation();

    final conversationRef = FirebaseFirestore.instance
        .collection(_usersCollection)
        .doc(_currentUserId)
        .collection('conversations')
        .doc(_currentConversationId);

    // Update conversation metadata
    await conversationRef.set({
      'lastMessage': text,
      'timestamp': FieldValue.serverTimestamp(),
      'preview': text.length > 30 ? '${text.substring(0, 30)}...' : text,
    }, SetOptions(merge: true));

    await conversationRef.collection('messages').add({
      'text': text,
      'sender': 'user',
      'timestamp': FieldValue.serverTimestamp(),
    });

    _scrollToBottom();

    // 2. Call AI Service
    CoachService.generatePlan(text).listen((event) {
      if (!mounted) return;

      setState(() {
        // Update Pipeline Stage
        if (event.node == 'planner_start') _pipelineStage = 'planner';
        if (event.node == 'planner_done') _pipelineStage = 'executor';
        if (event.node == 'executor_start') _pipelineStage = 'executor';
        if (event.node == 'executor_done') _pipelineStage = 'done';
        if (event.node == 'done') _pipelineStage = 'done';

        // Accumulate Content
        if (event.node == 'planner_token' || event.node == 'planner_done') {
          if (event.plan != null && event.plan!.isNotEmpty) {
            _streamingStrategy = event.plan!;
          } else if (event.token != null) {
            _streamingStrategy += event.token!;
          }
        }

        if (event.node == 'executor_token' || event.node == 'executor_done') {
          if (event.finalResponse != null && event.finalResponse!.isNotEmpty) {
            _streamingPlan = event.finalResponse!;
          } else if (event.token != null) {
            _streamingPlan += event.token!;
          }
        }

        if (event.node == 'error') {
          _streamingResponse = "Error: ${event.status}";
          _pipelineStage = 'error';
        }

        _scrollToBottom();
      });
    }, onDone: () async {
      if (!mounted) return;

      try {
        final messagesCollection = FirebaseFirestore.instance
            .collection(_usersCollection)
            .doc(_currentUserId)
            .collection('conversations')
            .doc(_currentConversationId)
            .collection('messages');

        // Save as a SINGLE 'run' document if we have structured data
        if (_streamingStrategy.isNotEmpty || _streamingPlan.isNotEmpty) {
          await messagesCollection.add({
            'sender': 'ai',
            'type': 'run',
            'strategy': _streamingStrategy,
            'plan': _streamingPlan,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } else if (_streamingResponse.isNotEmpty) {
          // Fallback
          await messagesCollection.add({
            'sender': 'ai',
            'type': 'text',
            'text': _streamingResponse,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint("Error saving: $e");
      } finally {
        if (mounted) {
          setState(() {
            _isTyping = false;
            _isStreaming = false;
            _pipelineStage = 'idle';
          });
          _scrollToBottom();
        }
      }
    }, onError: (e) {
      if (!mounted) return;
      setState(() {
        _streamingResponse = "Error: $e";
        _isTyping = false;
      });
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CruizrTheme.background,
      appBar: AppBar(
        title: Text(
          'AI Coach',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: CruizrTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: CruizrTheme.textPrimary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New Chat',
            onPressed: () {
              _startNewConversation();
            },
          ),
        ],
      ),
      drawer: _buildHistoryDrawer(),
      body: Column(
        children: [
          Expanded(
            child: _currentConversationId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection(_usersCollection)
                        .doc(_currentUserId)
                        .collection('conversations')
                        .doc(_currentConversationId)
                        .collection('messages')
                        .orderBy('timestamp', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError)
                        return Center(child: Text('Error: ${snapshot.error}'));
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());

                      final docs = snapshot.data!.docs;
                      final itemCount = docs.length + (_isStreaming ? 1 : 0);

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (_isStreaming && index == docs.length) {
                            // Streaming Tile
                            return _buildAiRunTile(
                                strategy: _streamingStrategy,
                                plan: _streamingPlan,
                                stage: _pipelineStage,
                                isStreaming: true);
                          }

                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          final sender = data['sender'] as String? ?? 'user';

                          if (sender == 'user') {
                            return _buildUserMessageTile(
                                data['text'] as String? ?? '');
                          } else {
                            final type = data['type'] as String? ?? 'text';
                            if (type == 'run') {
                              return _buildAiRunTile(
                                  strategy: data['strategy'] as String? ?? '',
                                  plan: data['plan'] as String? ?? '',
                                  stage: 'done',
                                  isStreaming: false);
                            } else {
                              // Legacy/Fallback split messages or plain text
                              // For backward compatibility with what we just wrote in previous steps,
                              // we might see 'strategy' or 'plan' types.
                              // Let's render them as best we can.
                              if (type == 'strategy') {
                                return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildOutputCard(
                                        title: 'Strategy',
                                        subtitle: 'Kimi',
                                        icon: Icons.psychology_outlined,
                                        color: const Color(0xFF9B7DDB),
                                        content: data['text'] ?? '',
                                        isCollapsible: true));
                              }
                              if (type == 'plan') {
                                return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child:
                                        _buildRawPlanList(data['text'] ?? ''));
                              }
                              return _buildSimpleAiTile(
                                  data['text'] as String? ?? '');
                            }
                          }
                        },
                      );
                    },
                  ),
          ),
          if (_isTyping && !_isStreaming)
            const Padding(
                padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),
          _buildInputArea(),
        ],
      ),
    );
  }

  // ── Message Tiles ──────────────────────────────────────────────────────

  Widget _buildUserMessageTile(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: CruizrTheme.accentPink,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
                color: CruizrTheme.accentPink.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Text(text,
            style: GoogleFonts.lato(color: Colors.white, fontSize: 16)),
      ),
    );
  }

  Widget _buildSimpleAiTile(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: MarkdownBody(data: text),
      ),
    );
  }

  // ── History Drawer ─────────────────────────────────────────────────────

  Widget _buildHistoryDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: CruizrTheme.primaryDark),
            accountName: const Text("Chat History"),
            accountEmail: Text("Cruizr Coach",
                style: GoogleFonts.lato(color: Colors.white70)),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.history, color: CruizrTheme.primaryDark),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add, color: CruizrTheme.primaryDark),
            title: Text('New Conversation',
                style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              _startNewConversation();
            },
          ),
          ListTile(
            leading: const Icon(Icons.list_alt, color: CruizrTheme.primaryDark),
            title: Text('My Plans',
                style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MyPlansScreen()));
            },
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(_usersCollection)
                  .doc(_currentUserId)
                  .collection('conversations')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text("No history yet.",
                        style: GoogleFonts.lato(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final id = docs[index].id;
                    final preview = data['preview'] as String? ?? 'New Chat';
                    final timestamp = data['timestamp'] as Timestamp?;
                    final dateStr = timestamp != null
                        ? DateFormat.MMMd().format(timestamp.toDate())
                        : '';
                    final isActive = id == _currentConversationId;

                    return Container(
                      color: isActive ? CruizrTheme.background : null,
                      child: ListTile(
                        leading: Icon(Icons.chat_bubble_outline,
                            color: isActive
                                ? CruizrTheme.primaryDark
                                : Colors.grey),
                        title: Text(preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lato(
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                        subtitle: Text(dateStr,
                            style: GoogleFonts.lato(fontSize: 12)),
                        onTap: () => _switchConversation(id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Unified Run Tile (Header + Strategy + Plan) ────────────────────────
  Widget _buildAiRunTile(
      {required String strategy,
      required String plan,
      required String stage,
      required bool isStreaming}) {
    // Determine pipeline states
    bool planActive = stage == 'planner';
    bool planDone = stage == 'executor' || stage == 'done';
    bool schedActive = stage == 'executor';
    bool schedDone = stage == 'done';
    bool doneDone = stage == 'done';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Pipeline Status Header
        Container(
          margin: const EdgeInsets.only(bottom: 16, top: 8),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              _buildPipelineNode(
                  'Plan', Icons.description_outlined, planActive, planDone),
              _buildPipelineConnector(planDone),
              _buildPipelineNode('Schedule', Icons.calendar_today_outlined,
                  schedActive, schedDone),
              _buildPipelineConnector(schedDone),
              _buildPipelineNode(
                  'Done', Icons.check_circle_outline, false, doneDone),
            ],
          ),
        ),

        // 2. Strategy Card (Show if we have content or if planning is active)
        if (strategy.isNotEmpty || planActive)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildOutputCard(
                title: 'Strategy',
                subtitle: 'Kimi',
                icon: Icons.psychology_outlined,
                color: const Color(0xFF9B7DDB),
                content: strategy.isEmpty ? 'Thinking...' : strategy,
                isCollapsible: true),
          ),

        // 3. Plan List (Show if we have content)
        if (plan.isNotEmpty) _buildRawPlanList(plan),
      ],
    );
  }

  Widget _buildRawPlanList(String rawJson) {
    final items = _tryParsePlan(rawJson);
    if (items.isEmpty) {
      if (rawJson.trim().isNotEmpty) {
        // Fallback for older chats that returned Markdown tables
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: _buildOutputCard(
              title: 'Training Plan',
              subtitle: 'Mistral (Legacy)',
              icon: Icons.table_chart_outlined,
              color: const Color(0xFF5DB894),
              content: rawJson,
              isCollapsible: true),
        );
      }
      return const SizedBox.shrink();
    }
    return _buildPlanList(items, rawJson);
  }

  // ── Pipeline Widgets ───────────────────────────────────────────────────

  Widget _buildPipelineNode(
      String label, IconData icon, bool isActive, bool isDone) {
    final color = isDone
        ? const Color(0xFF5DB894)
        : isActive
            ? CruizrTheme.accentPink
            : CruizrTheme.textSecondary.withValues(alpha: 0.4);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            double scale = 1.0;
            if (isActive) scale = 1.0 + (_pulseController.value * 0.1);
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDone
                  ? color.withValues(alpha: 0.15)
                  : isActive
                      ? color.withValues(alpha: 0.12)
                      : Colors.transparent,
              shape: BoxShape.circle,
              border:
                  Border.all(color: color, width: isDone || isActive ? 2 : 1),
            ),
            child: Icon(isDone ? Icons.check : icon, size: 16, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 10,
            fontWeight: isDone || isActive ? FontWeight.w600 : FontWeight.w400,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPipelineConnector(bool isDone) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
        decoration: BoxDecoration(
          color: isDone
              ? const Color(0xFF5DB894).withValues(alpha: 0.4)
              : CruizrTheme.border,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -4),
              blurRadius: 16)
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    hintText: 'Ask your coach...',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    filled: false),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
                color: CruizrTheme.primaryDark, shape: BoxShape.circle),
            child: IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send_rounded, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputCard(
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required String content,
      required bool isCollapsible}) {
    return CollapsibleCard(
        title: title,
        subtitle: subtitle,
        icon: icon,
        color: color,
        content: content,
        isCollapsible: isCollapsible);
  }

  List<Map<String, dynamic>> _tryParsePlan(String raw) {
    final List<Map<String, dynamic>> items = [];
    final lines = raw.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final Map<String, dynamic> data = jsonDecode(line);
        items.add(data);
      } catch (e) {}
    }
    return items;
  }

  Widget _buildPlanList(List<Map<String, dynamic>> plan, String rawText) {
    // Group by Week
    final Map<int, List<Map<String, dynamic>>> weeks = {};

    // Sort logic or simple sequential grouping
    // Assuming sequential for now. Key could be parsed from "Day X"
    for (var i = 0; i < plan.length; i++) {
      // Heuristic: If we parse "Day X", use it. Else assume 7 days per week.
      final dayStr = plan[i]['day']?.toString().toLowerCase() ?? '';
      final dayMatch = RegExp(r'day\s+(\d+)').firstMatch(dayStr);
      int dayNum = i + 1;
      if (dayMatch != null) {
        dayNum = int.tryParse(dayMatch.group(1)!) ?? (i + 1);
      }

      final weekNum = ((dayNum - 1) ~/ 7) + 1;
      weeks.putIfAbsent(weekNum, () => []).add(plan[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: const Color(0xFF5DB894).withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child: const Icon(Icons.calendar_month_outlined,
                    size: 15, color: Color(0xFF5DB894)),
              ),
              const SizedBox(width: 10),
              Text('Your Training Plan',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CruizrTheme.textPrimary)),
              const SizedBox(width: 8),
              _buildModelTag('Mistral', const Color(0xFF5DB894)),
            ],
          ),
        ),

        // Render Weeks
        ...weeks.entries.map((entry) => _buildWeekCard(entry.key, entry.value)),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _saveToCalendar(rawText),
            icon: const Icon(Icons.calendar_month, size: 20),
            label: Text('Save to Calendar',
                style: GoogleFonts.lato(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5DB894),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekCard(int weekNum, List<Map<String, dynamic>> days) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CruizrTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: weekNum == 1,
        shape: const RoundedRectangleBorder(
            side: BorderSide.none), // Remove default borders
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: CruizrTheme.primaryDark.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Text("W$weekNum",
              style: GoogleFonts.lato(
                  fontWeight: FontWeight.bold,
                  color: CruizrTheme.primaryDark,
                  fontSize: 14)),
        ),
        title: Text("Week $weekNum",
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text("${days.length} Sessions",
            style: GoogleFonts.lato(color: Colors.grey, fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: days.map((day) => _buildDayCard(day)).toList(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
        border: Border.all(color: CruizrTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(day['day'] ?? 'Day',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CruizrTheme.textPrimary)),
              if (day['duration'] != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: CruizrTheme.background,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.timer_outlined,
                        size: 12, color: CruizrTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(day['duration'],
                        style: GoogleFonts.lato(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CruizrTheme.textPrimary))
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(day['activity'] ?? 'Rest',
              style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5DB894))),
          if (day['intensity'] != null &&
              day['intensity'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text("Intensity: ${day['intensity']}",
                style: GoogleFonts.lato(
                    fontSize: 12, color: CruizrTheme.textSecondary)),
          ],
          if (day['notes'] != null && day['notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFF5DB894).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline,
                    size: 14, color: Color(0xFF5DB894)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(day['notes'],
                        style: GoogleFonts.lato(
                            fontSize: 12,
                            height: 1.4,
                            color: CruizrTheme.textPrimary)))
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModelTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: GoogleFonts.lato(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Future<void> _saveToCalendar(String rawPlanText) async {
    try {
      final events = PlanParserService.parse(rawPlanText);
      if (events.isEmpty) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Could not parse plan into calendar events'),
              backgroundColor: Colors.orange));
        return;
      }
      final calendarService = CalendarService();
      const planTitle = 'Training Plan';

      // Generate random pastel color
      final random = Random();
      final color = Color.fromARGB(
        255,
        random.nextInt(100) + 100, // 100-200
        random.nextInt(100) + 100,
        random.nextInt(100) + 100,
      );

      final planId = await calendarService.savePlanToFirestore(
        events: events,
        planTitle: planTitle,
        rawPlanText: rawPlanText,
        colorValue: color.value,
      );

      if (mounted)
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => PlanCalendarScreen(
                  events: events,
                  planTitle: planTitle,
                  planId: planId,
                  color: color,
                )));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to save plan: $e'),
            backgroundColor: Colors.red));
    }
  }
}

class CollapsibleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String content;
  final bool isCollapsible;
  const CollapsibleCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.content,
      required this.isCollapsible});
  @override
  State<CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<CollapsibleCard> {
  bool _isExpanded = true;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: widget.color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: widget.isCollapsible
                ? () => setState(() => _isExpanded = !_isExpanded)
                : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle),
                      child: Icon(widget.icon, size: 15, color: widget.color)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(widget.title,
                            style: GoogleFonts.playfairDisplay(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: CruizrTheme.textPrimary)),
                        Text(widget.subtitle,
                            style: GoogleFonts.lato(
                                fontSize: 11,
                                color: widget.color,
                                fontWeight: FontWeight.w500))
                      ])),
                  if (widget.isCollapsible)
                    Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: CruizrTheme.textSecondary,
                        size: 20),
                ],
              ),
            ),
          ),
          if (!widget.isCollapsible || _isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: CruizrTheme.background,
                    borderRadius: BorderRadius.circular(12)),
                child: MarkdownBody(
                    data: widget.content,
                    selectable: true,
                    softLineBreak: true,
                    styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.lato(
                            fontSize: 13,
                            height: 1.6,
                            color: CruizrTheme.textPrimary),
                        strong: GoogleFonts.lato(
                            fontWeight: FontWeight.bold,
                            color: CruizrTheme.textPrimary),
                        tableBody: GoogleFonts.sourceCodePro(
                            fontSize: 11, color: CruizrTheme.textPrimary),
                        tableHead: GoogleFonts.sourceCodePro(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: CruizrTheme.textPrimary))),
              ),
            ),
        ],
      ),
    );
  }
}
