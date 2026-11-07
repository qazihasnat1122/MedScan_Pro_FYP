import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/medication_providers.dart';
import '../../providers/pharmacy_providers.dart';
import '../../providers/safety_providers.dart';
import '../../services/ai_rag_service.dart';
import '../../providers/app_settings_providers.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? suggestions;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.suggestions,
  });
}

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final AiRagService _ragService = AiRagService();
  bool _isTyping = false;

  static const Color primaryTeal = Color(0xFF007A78);

  final List<String> _quickPrompts = [
    'Can I take Panadol with Brufen?',
    'What should I do if I missed a dose?',
    'Side effects of Glucophage 500mg?',
    'How to check if medicine packaging is fake?',
    'Best time to take antibiotics?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        text:
            'Hello! I am your AI Medicine Assistant.\n\nI provide AI-generated medicine information for reference only. I can check dosage guidelines, food instructions, and missed dose advice. Remember that I do not diagnose medical conditions.\n\nHow can I help you today?',
        isUser: false,
        timestamp: DateTime.now(),
        suggestions: _quickPrompts.take(3).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showApiKeyDialog() {
    final keyCtrl = TextEditingController(text: AiRagService.geminiApiKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.vpn_key_outlined, color: primaryTeal),
            SizedBox(width: 8),
            Text(
              'AI Assistant Key',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your LLM API Key (OpenAI/OpenRouter format: sk-... or Google Gemini format: AIza...) to enable live cloud AI consulting. (Leave blank to use the embedded clinical offline safety engine).',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: keyCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'sk-... or AIzaSy...',
                labelText: 'AI API Key',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTeal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              AiRagService.geminiApiKey = keyCtrl.text.trim();
              Navigator.pop(ctx);
              final isConfigured = AiRagService.geminiApiKey.isNotEmpty;
              final isSk = AiRagService.geminiApiKey.startsWith('sk-');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isConfigured
                        ? (isSk
                            ? 'OpenAI/OpenRouter LLM connected!'
                            : 'Google Gemini LLM connected!')
                        : 'Using Offline Clinical Safety Engine',
                  ),
                  backgroundColor: primaryTeal,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Save Key'),
          ),
        ],
      ),
    );
  }

  bool _isPharmacySearchQuery(String text) {
    final lower = text.toLowerCase();
    final hasPharmacyTerm = lower.contains('pharmacy') ||
        lower.contains('pharmacies') ||
        lower.contains('medical store') ||
        lower.contains('chemist') ||
        lower.contains('dawaai ki dukan') ||
        lower.contains('dawakhana');
    final hasLocationTerm = lower.contains('near') ||
        lower.contains('close') ||
        lower.contains('where') ||
        lower.contains('find') ||
        lower.contains('locate') ||
        lower.contains('kahan') ||
        lower.contains('aas paas') ||
        lower.contains('around');
    return hasPharmacyTerm && hasLocationTerm;
  }

  void _handleSend([String? presetText]) async {
    final query = presetText ?? _inputCtrl.text.trim();
    if (query.isEmpty) return;

    if (presetText == null) {
      _inputCtrl.clear();
    }

    setState(() {
      _messages.add(
        ChatMessage(text: query, isUser: true, timestamp: DateTime.now()),
      );
      _isTyping = true;
    });
    _scrollToBottom();

    // 1. Separate Pharmacy Discovery from Ordinary Medical Queries (Phase 4)
    if (_isPharmacySearchQuery(query)) {
      String pharmacyReply;
      try {
        final locationService = ref.read(deviceLocationServiceProvider);
        final locResult = await locationService.getCurrentDeviceLocation();
        if (!locResult.isSuccess || locResult.coordinates == null) {
          throw Exception(locResult.message);
        }
        final userCoords = locResult.coordinates!;
        final repo = ref.read(pharmacyRepositoryProvider);
        final fetchResult = await repo.fetchNearbyRealPharmacies(
          latitude: userCoords.latitude,
          longitude: userCoords.longitude,
          radiusMeters: 5000,
        );

        if (fetchResult.pharmacies.isNotEmpty) {
          final buffer = StringBuffer();
          buffer.writeln('📍 **Nearby Pharmacies Grounded in Map Data**:');
          buffer.writeln(
            'Found ${fetchResult.pharmacies.length} verified locations near your current coordinates (${userCoords.latitude.toStringAsFixed(3)}, ${userCoords.longitude.toStringAsFixed(3)}):\n',
          );
          for (int i = 0; i < fetchResult.pharmacies.length && i < 5; i++) {
            final p = fetchResult.pharmacies[i];
            final distStr = p.approximateDistanceKm.isFinite
                ? '${p.approximateDistanceKm.toStringAsFixed(1)} km away'
                : '';
            buffer.writeln('${i + 1}. **${p.name}** ${distStr.isNotEmpty ? "($distStr)" : ""}');
            if (p.fullAddress.isNotEmpty) {
              buffer.writeln('   • Address: ${p.fullAddress}');
            }
            if (p.phone.isNotEmpty) {
              buffer.writeln('   • Phone: ${p.phone}');
            }
            if (p.mapsUri != null && p.mapsUri!.isNotEmpty) {
              buffer.writeln('   • [View on Google Maps](${p.mapsUri})');
            }
            buffer.writeln();
          }
          buffer.writeln('⚠️ *Operating hours and medicine stock are not guaranteed — call ahead to confirm availability.*');
          pharmacyReply = buffer.toString();
        } else {
          pharmacyReply = 'No nearby pharmacies could be found near your current coordinates through the configured map service.\n\n'
              '• You can open the dedicated **Nearby Pharmacies** tab for an expanded radius search.\n'
              '• Always buy medicines from licensed, verified pharmacies.';
        }
      } catch (e) {
        pharmacyReply = 'Unable to search nearby pharmacies from live GPS location: ${e.toString().replaceAll("Exception:", "").trim()}.\n\n'
            'Please verify location permissions or open the **Nearby Pharmacies** map tab.';
      }

      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessage(
            text: pharmacyReply,
            isUser: false,
            timestamp: DateTime.now(),
            suggestions: ['Open Nearby Pharmacies Map', 'Emergency SOS details'],
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    // 2. RAG RETRIEVAL: Pull active medications & emergency profile
    final activeMeds = ref.read(myMedicationsProvider).value ?? [];
    final emergencyProfile = ref.read(emergencyProfileProvider).value;

    // Convert conversation history for multi-turn reasoning context
    final history = _messages.take(_messages.length - 1).map((m) {
      return {
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.text,
      };
    }).toList();

    // 3. LLM GENERATION: Query Health & Medicine Consultant
    final result = await _ragService.queryConsultantDetailed(
      userQuery: query,
      activeMeds: activeMeds,
      emergencyProfile: emergencyProfile,
      conversationHistory: history,
    );

    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add(
        ChatMessage(
          text: result.text,
          isUser: false,
          timestamp: DateTime.now(),
          suggestions: _generateFollowUps(query),
        ),
      );
    });
    _scrollToBottom();
  }

  List<String> _generateFollowUps(String query) {
    final lower = query.toLowerCase();
    if (lower.contains('panadol') || lower.contains('brufen')) {
      return [
        'What is max daily dose of Panadol?',
        'Can I take with food?',
        'Alternate dose schedule',
      ];
    }
    if (lower.contains('missed')) {
      return [
        'How to set voice reminders?',
        'Adjust notification sound',
        'View active schedule',
      ];
    }
    return [
      'Check drug interactions',
      'How to scan barcode?',
      'Emergency SOS details',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.aiAssistant,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'AI-generated medicine info for reference only',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.vpn_key_outlined,
              color: Colors.white,
              size: 22,
            ),
            tooltip: 'Gemini LLM Key',
            onPressed: _showApiKeyDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Clear Chat',
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(
                  ChatMessage(
                    text:
                        'Chat history cleared. How can I assist you with your medications now?',
                    isUser: false,
                    timestamp: DateTime.now(),
                    suggestions: _quickPrompts.take(3).toList(),
                  ),
                );
              });
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              // Medical disclaimer banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: isDark
                    ? const Color(0xFF451A03).withValues(alpha: 0.3)
                    : const Color(0xFFFEF3C7),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.aiDisclaimer,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFF92400E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Messages list
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _buildMessageItem(
                      msg,
                      cardBg,
                      borderColor,
                      textPrimary,
                      textMuted,
                    );
                  },
                ),
              ),

              // Typing indicator
              if (_isTyping)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primaryTeal,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'MedScan AI is formulating clinical response...',
                              style: TextStyle(fontSize: 12, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Bottom Input bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _inputCtrl,
                            textInputAction: TextInputAction.send,
                            style: TextStyle(color: textPrimary),
                            onSubmitted: (_) => _handleSend(),
                            decoration: InputDecoration(
                              hintText: strings.askMedicationQuestion,
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: textMuted,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: primaryTeal,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => _handleSend(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(
    ChatMessage msg,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
  ) {
    final isUser = msg.isUser;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: primaryTeal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.smart_toy_outlined,
                    color: primaryTeal,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? primaryTeal : cardBg,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: isUser
                          ? const Radius.circular(2)
                          : const Radius.circular(16),
                      bottomLeft: !isUser
                          ? const Radius.circular(2)
                          : const Radius.circular(16),
                    ),
                    border: Border.all(
                      color: isUser ? Colors.transparent : borderColor,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        msg.text,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: isUser ? Colors.white : textPrimary,
                        ),
                      ),
                      if (!isUser) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: msg.text),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Copied response to clipboard',
                                    ),
                                    duration: Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.copy, size: 14, color: textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Copy',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            InkWell(
                              onTap: () {
                                SystemSound.play(SystemSoundType.click);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Voice playback simulated'),
                                    duration: Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.volume_up_outlined,
                                    size: 14,
                                    color: primaryTeal,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Speak',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: primaryTeal,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),

          // Follow-up recommendation chips
          if (msg.suggestions != null && msg.suggestions!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: msg.suggestions!.map((s) {
                  return ActionChip(
                    label: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 11,
                        color: primaryTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: cardBg,
                    side: BorderSide(color: primaryTeal.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    onPressed: () {
                      if (s == 'Open Nearby Pharmacies Map') {
                        context.push('/pharmacies');
                      } else {
                        _handleSend(s);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
