import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/message_service.dart';
import '../../theme/cozy_colors.dart';
import '../../theme/cozy_text.dart';
import '../../widgets/bouncy_button.dart';
import '../../widgets/cozy_card.dart';

/// Writing a letter. One every eight hours.
///
/// The lock is framed as the point of the app, not a punishment — the countdown
/// is the ritual, so it reads "the tide is out" rather than "rate limited".
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({
    super.key,
    required this.partnerName,
    required this.canSendAt,
    required this.onSend,
  });

  final String partnerName;

  /// Null (or past) means the tide is in.
  final DateTime? canSendAt;

  /// Returns null on success, or a human-readable failure.
  final Future<String?> Function(String text) onSend;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _controller = TextEditingController();
  Timer? _tick;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool get _locked =>
      widget.canSendAt != null && DateTime.now().isBefore(widget.canSendAt!);

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final err = await widget.onSend(text);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = err;
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = MessageService.maxLength - _controller.text.characters.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: CozyColors.pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('Write to ${widget.partnerName}',
            style: CozyText.rounded(18, weight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _locked ? _lockedView() : _composeView(left),
        ),
      ),
    );
  }

  Widget _lockedView() => Center(
        child: DashedCard(
          padding: 24,
          strokeColor: CozyColors.warmCoral,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('😴', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('The cat is napping',
                  style: CozyText.rounded(22, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'One letter every 8 hours. That\'s what makes them worth waiting for.',
                textAlign: TextAlign.center,
                style: CozyText.caption,
              ),
              const SizedBox(height: 12),
              Text(_remaining(widget.canSendAt!),
                  style: CozyText.rounded(28, weight: FontWeight.w900)),
            ],
          ),
        ),
      );

  Widget _composeView(int left) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CozyCard(
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: null,
                expands: true,
                maxLength: MessageService.maxLength,
                textAlignVertical: TextAlignVertical.top,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: 'Say the thing you would say if it cost you something.',
                ),
                style: CozyText.rounded(17, weight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('$left left',
              textAlign: TextAlign.right,
              style: CozyText.rounded(12,
                  color: left < 20 ? CozyColors.warmCoral : CozyColors.textMuted)),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: CozyText.rounded(13, color: Colors.red)),
          ],
          const SizedBox(height: 12),
          CozyButton(
            title: _sending ? 'Sending…' : 'Send it 🐾',
            icon: Icons.send,
            onTap: _controller.text.trim().isEmpty || _sending ? null : _send,
          ),
          const SizedBox(height: 8),
          Text(
            'They will see that something arrived, but not what it says '
            'until they open it.',
            textAlign: TextAlign.center,
            style: CozyText.muted,
          ),
        ],
      );
}

String _remaining(DateTime target) {
  var d = target.difference(DateTime.now());
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}
