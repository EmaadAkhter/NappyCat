import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/pairing_service.dart';
import '../../theme/cozy_colors.dart';
import '../../theme/cozy_text.dart';
import '../../widgets/bouncy_button.dart';
import '../../widgets/cozy_card.dart';

/// Create an invite or join one. Two people, once, forever.
class PairingScreen extends StatefulWidget {
  const PairingScreen({
    super.key,
    required this.uid,
    required this.pairing,
    this.resumeCode,
  });

  final String uid;
  final PairingService pairing;

  /// An invite this user already created but nobody has joined yet. Shown
  /// straight away so the code survives leaving the app — without this the
  /// creator can never get their code back.
  final String? resumeCode;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

enum _Mode { choose, showCode, enterCode }

class _PairingScreenState extends State<PairingScreen> {
  late _Mode _mode =
      widget.resumeCode == null ? _Mode.choose : _Mode.showCode;
  late String? _code = widget.resumeCode;
  String? _error;
  bool _busy = false;
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final code = await widget.pairing.createInvite(widget.uid);
      if (!mounted) return;
      setState(() {
        _code = code;
        _mode = _Mode.showCode;
        _busy = false;
      });
      // No listener here: _Root watches the pair document and re-routes on its
      // own once the second member joins.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not create an invite. Check your connection.';
        _busy = false;
      });
    }
  }

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.pairing.join(uid: widget.uid, code: _input.text);
      // _Root re-routes once the pair doc shows two members.
    } on PairingError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Try again.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Find your person 🌊',
                  style: CozyText.rounded(28, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Tidal is for exactly two people. Pair once, then never think about it again.',
                textAlign: TextAlign.center,
                style: CozyText.body,
              ),
              const SizedBox(height: 28),
              switch (_mode) {
                _Mode.choose => _chooser(),
                _Mode.showCode => _showCode(),
                _Mode.enterCode => _enterCode(),
              },
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: CozyText.rounded(13, color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chooser() => Column(
        children: [
          CozyButton(
            title: 'Create an invite',
            icon: Icons.add_link,
            onTap: _busy ? null : _create,
          ),
          const SizedBox(height: 12),
          CozyButton(
            title: 'I have a code',
            icon: Icons.login,
            background: CozyColors.softLavender,
            onTap: _busy ? null : () => setState(() => _mode = _Mode.enterCode),
          ),
        ],
      );

  Widget _showCode() => Column(
        children: [
          CozyCard(
            child: Column(
              children: [
                Text('YOUR CODE',
                    style: CozyText.rounded(12,
                        weight: FontWeight.w700, color: CozyColors.textMuted)),
                const SizedBox(height: 10),
                SelectableText(
                  _code!,
                  style: CozyText.rounded(32, weight: FontWeight.w900)
                      .copyWith(letterSpacing: 4),
                ),
                const SizedBox(height: 10),
                Text('Send this to them. It expires in 12 hours.',
                    textAlign: TextAlign.center, style: CozyText.muted),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CozyButton(
            title: 'Copy code',
            icon: Icons.copy,
            background: CozyColors.softBlue,
            onTap: () {
              Clipboard.setData(ClipboardData(text: _code!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied')),
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: CozyColors.sageGreen),
              ),
              const SizedBox(width: 10),
              Text('Waiting for them to join…', style: CozyText.caption),
            ],
          ),
        ],
      );

  Widget _enterCode() => Column(
        children: [
          CozyCard(
            child: TextField(
              controller: _input,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              maxLength: PairingService.codeLength,
              onSubmitted: (_) => _join(),
              decoration: const InputDecoration(
                  counterText: '', hintText: 'ABCD2345'),
              style: CozyText.rounded(28, weight: FontWeight.w900)
                  .copyWith(letterSpacing: 4),
            ),
          ),
          const SizedBox(height: 16),
          CozyButton(
            title: _busy ? 'Joining…' : 'Join',
            icon: Icons.favorite,
            onTap: _busy ? null : _join,
          ),
          const SizedBox(height: 8),
          Bouncy(
            onTap: () => setState(() {
              _mode = _Mode.choose;
              _error = null;
            }),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Back', style: CozyText.muted),
            ),
          ),
        ],
      );
}
