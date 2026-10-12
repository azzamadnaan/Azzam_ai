// ============================================================
// تطبيق عزام أي آي (AZZAM AI)
// المطور: عزام عدنان المخلافي (Azzam Adnan Al-Makhlafi)
// ============================================================
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// المفتاح يُحقن وقت البناء من GitHub Secrets عبر --dart-define
const String kBuildKey = String.fromEnvironment('GEMINI_API_KEY');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AzzamApp());
}

class AzzamApp extends StatelessWidget {
  const AzzamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'عزام أي آي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          surface: Color(0xFF1A1A2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0F1A),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const SplashScreen(),
    );
  }
}

// ============================================================
// شاشة البداية
// ============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1A1A2E),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 60,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'عزام أي آي',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AZZAM AI',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9C8FFF),
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// نموذج الرسالة
// ============================================================
class _Msg {
  final String text;
  final bool isUser;
  final Uint8List? image;
  _Msg({required this.text, required this.isUser, this.image});
}

// ============================================================
// شاشة المحادثة الرئيسية
// ============================================================
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();

  final List<_Msg> _messages = <_Msg>[];
  ChatSession? _chat;
  Uint8List? _pendingImage;
  bool _loading = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initGemini();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // تهيئة Gemini: أولوية لمفتاح البناء ثم المحلي
  Future<void> _initGemini() async {
    try {
      String? key = kBuildKey.isNotEmpty ? kBuildKey : null;

      if (key == null) {
        final prefs = await SharedPreferences.getInstance();
        key = prefs.getString('azzam_api_key');
      }

      if (key == null || key.isEmpty) {
        if (!mounted) return;
        _askForApiKey();
        return;
      }

      _createChat(key);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      _addSystemMessage('خطأ في التهيئة: $e');
    }
  }

  void _createChat(String key) {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: key,
      generationConfig: GenerationConfig(
        temperature: 0.9,
        maxOutputTokens: 4096,
      ),
      systemInstruction: Content.system(
        'أنت "عزام أي آي" (AZZAM AI)، مساعد ذكاء اصطناعي عربي ذكي ومفيد. '
        'أجب دائماً باللغة العربية الفصحى الواضحة إلا إذا طلب المستخدم غير ذلك. '
        'كن ودوداً ومحترفاً ومباشراً.',
      ),
    );
    _chat = model.startChat();
  }

  // نافذة طلب مفتاح API
  Future<void> _askForApiKey() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'مفتاح Gemini API',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'الصق مفتاحك من Google AI Studio.\nيُحفظ على جهازك فقط.',
              style: TextStyle(color: Color(0xFFB0B0C8), fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'AIzaSy...',
                hintStyle: const TextStyle(color: Color(0xFF6B6B8D)),
                filled: true,
                fillColor: const Color(0xFF0F0F1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              final v = controller.text.trim();
              Navigator.of(ctx).pop(v.isEmpty ? null : v);
            },
            child: const Text(
              'حفظ',
              style: TextStyle(color: Color(0xFF9C8FFF)),
            ),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) {
      if (mounted) _askForApiKey(); // إعادة الطلب
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('azzam_api_key', result);
    _createChat(result);
    if (mounted) setState(() => _ready = true);
  }

  void _addSystemMessage(String text) {
    if (!mounted) return;
    setState(() => _messages.add(_Msg(text: text, isUser: false)));
    _scrollBottom();
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _pendingImage = bytes);
    } catch (e) {
      _addSystemMessage('تعذّر اختيار الصورة: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (!_ready || _loading) return;

    final text = _textCtrl.text.trim();
    final image = _pendingImage;

    if (text.isEmpty && image == null) return;

    // كشف أمر توليد الصور
    if (text.startsWith('ارسم:') && image == null) {
      final prompt = text.substring(5).trim();
      _textCtrl.clear();
      if (prompt.isNotEmpty) {
        await _generateImage(prompt);
      }
      return;
    }

    _textCtrl.clear();
    setState(() {
      _messages.add(_Msg(text: text, isUser: true, image: image));
      _pendingImage = null;
      _loading = true;
    });
    _scrollBottom();

    try {
      if (_chat == null) throw Exception('جلسة المحادثة غير جاهزة');

      final Stream<GenerateContentResponse> stream;
      if (image != null) {
        stream = _chat!.sendMessageStream(
          Content.multi([
            TextPart(text.isEmpty ? 'حلّل هذه الصورة' : text),
            DataPart('image/jpeg', image),
          ]),
        );
      } else {
        stream = _chat!.sendMessageStream(Content.text(text));
      }

      final int idx = _messages.length;
      setState(() => _messages.add(_Msg(text: '', isUser: false)));

      final buffer = StringBuffer();
      await for (final resp in stream) {
        final chunk = resp.text;
        if (chunk != null && chunk.isNotEmpty) {
          buffer.write(chunk);
          if (!mounted) return;
          setState(() {
            _messages[idx] = _Msg(text: buffer.toString(), isUser: false);
          });
          _scrollBottom();
        }
      }
    } catch (e) {
      _addSystemMessage('⚠️ $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // توليد صورة عبر Pollinations.ai (مجاناً)
  Future<void> _generateImage(String prompt) async {
    setState(() {
      _messages.add(_Msg(text: 'ارسم: $prompt', isUser: true));
      _loading = true;
    });
    _scrollBottom();

    try {
      final url = Uri.parse(
        'https://image.pollinations.ai/prompt/'
        '${Uri.encodeComponent(prompt)}'
        '?width=1024&height=1024&nologo=true'
        '&seed=${DateTime.now().millisecondsSinceEpoch}',
      );

      final resp = await http
          .get(url)
          .timeout(const Duration(seconds: 90));

      if (resp.statusCode != 200) {
        throw Exception('فشل التوليد (${resp.statusCode})');
      }

      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(
          text: 'تم توليد الصورة 🎨',
          isUser: false,
          image: resp.bodyBytes,
        ));
      });
      _scrollBottom();
    } catch (e) {
      _addSystemMessage('⚠️ تعذّر توليد الصورة: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF6C63FF),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('عزام أي آي'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _emptyState()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _bubble(_messages[i]),
                  ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (_pendingImage != null) _previewBar(),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 70, color: Color(0xFF6C63FF)),
          SizedBox(height: 16),
          Text(
            'ابدأ محادثة جديدة',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'اكتب رسالتك، ارفع صورة، أو اكتب\n"ارسم: قطة في الفضاء" لتوليد صورة',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8B8BA7), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Msg m) {
    final isImage = m.image != null;
    return Align(
      alignment: m.isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: m.isUser ? const Color(0xFF6C63FF) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(m.image!, width: 240),
              ),
            if (m.text.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: isImage ? 8 : 0),
                child: SelectableText(
                  m.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _previewBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _pendingImage!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'صورة جاهزة للإرسال',
              style: TextStyle(color: Color(0xFFB0B0C8), fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _pendingImage = null),
            icon: const Icon(Icons.close, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      color: const Color(0xFF0F0F1A),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: _loading ? null : _pickImage,
              icon: const Icon(Icons.image, color: Color(0xFF6C63FF)),
              tooltip: 'رفع صورة',
            ),
            Expanded(
              child: TextField(
                controller: _textCtrl,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالتك...',
                  hintStyle: const TextStyle(color: Color(0xFF6B6B8D)),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _loading ? null : _sendMessage,
              icon: const Icon(Icons.send, color: Color(0xFF6C63FF)),
              tooltip: 'إرسال',
            ),
          ],
        ),
      ),
    );
  }
}
