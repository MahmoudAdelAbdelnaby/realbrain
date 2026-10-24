import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/native.dart';

/// Verdict words (Design system: the verdict is words plus pills, no ring).
const verdictLabels = {
  'true': 'True',
  'mostly_true': 'Mostly true',
  'mixed': 'Mixed',
  'mostly_false': 'Mostly false',
  'false': 'False',
  'unverifiable': 'Unverified',
};

/// Verdict pill colours from the Design system tokens (text on fill), per theme.
(Color, Color) verdictColors(String verdict, Brightness b) {
  final dark = b == Brightness.dark;
  final kind = switch (verdict) {
    'true' || 'mostly_true' => 0,
    'mixed' => 1,
    'false' || 'mostly_false' => 2,
    _ => 3,
  };
  return switch ((kind, dark)) {
    (0, true) => (const Color(0xFF3FC07A), const Color(0xFF172A1D)),
    (1, true) => (const Color(0xFFE9B44C), const Color(0xFF2D2516)),
    (2, true) => (const Color(0xFFE5566F), const Color(0xFF2C1A20)),
    (0, false) => (const Color(0xFF247B50), const Color(0xFFDCFAE5)),
    (1, false) => (const Color(0xFF92400E), const Color(0xFFFFFBEB)),
    (2, false) => (const Color(0xFF831C1E), const Color(0xFFFFEDEA)),
    (_, true) => (const Color(0xFFB4B4B4), const Color(0xFF222225)),
    (_, false) => (const Color(0xFF5F6368), const Color(0xFFF0F0EE)),
  };
}

class VerdictPill extends StatelessWidget {
  const VerdictPill(this.verdict, {super.key});
  final String verdict;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = verdictColors(verdict, Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(verdictLabels[verdict] ?? verdict,
          style:
              TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

String _date(num? epochS) {
  if (epochS == null) return '';
  final d = DateTime.fromMillisecondsSinceEpoch((epochS * 1000).round());
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _at(Object? t) {
  final s = (t as num?)?.round();
  return s == null ? '' : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

Future<void> openUrl(BuildContext context, String url) async {
  try {
    await native.invokeMethod('openUrl', {'url': url});
  } on PlatformException {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Link copied')));
    }
  }
}

/// The Fact Check item (P1-08): AI label + checked date, overall verdict, each claim with its
/// verdict and correction, sources, and "Dive deeper".
class FactCheckView extends StatefulWidget {
  const FactCheckView({super.key, required this.saveId, required this.data});
  final String? saveId;
  final Map<String, dynamic> data;

  @override
  State<FactCheckView> createState() => _FactCheckViewState();
}

class _FactCheckViewState extends State<FactCheckView> {
  bool _asked = false;

  Future<void> _diveDeeper() async {
    setState(() => _asked = true);
    try {
      await api('POST', '/v1/saves/${widget.saveId}/deep-dive');
    } catch (e) {
      if (mounted) {
        setState(() => _asked = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final t = Theme.of(context).textTheme;
    final claims = [
      for (final c in (d['claims'] as List?) ?? const [])
        (c as Map).cast<String, dynamic>()
    ];
    final sources = [
      for (final s in (d['sources'] as List?) ?? const [])
        (s as Map).cast<String, dynamic>()
    ];
    final checked = d['checked_at'] != null;
    final explainer = d['explainer'] as String?;
    final explainError = d['explain_error'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          checked
              ? 'AI-generated · checked ${_date(d['checked_at'] as num?)}'
              : 'AI-generated · not checked yet',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        if (d['overall'] != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Text('Overall  '),
            VerdictPill(d['overall'] as String)
          ]),
        ],
        for (final c in claims) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VerdictPill(c['verdict'] as String? ?? 'unverifiable'),
              const SizedBox(width: 8),
              Expanded(child: Text('${c['text']}')),
              Text(_at(c['t']), style: TextStyle(color: muted, fontSize: 12)),
            ],
          ),
          if ((c['correction'] as String?)?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, top: 4),
              child: Text('${c['correction']}', style: TextStyle(color: muted)),
            ),
        ],
        if (sources.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Sources', style: t.labelLarge),
          for (final s in sources)
            InkWell(
              onTap: () => openUrl(context, s['url'] as String),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('${s['title']}',
                    style: TextStyle(
                        color: muted, decoration: TextDecoration.underline)),
              ),
            ),
        ],
        const SizedBox(height: 12),
        if (explainer != null)
          Text(explainer)
        else if (widget.saveId != null)
          OutlinedButton(
            onPressed: _asked && explainError == null ? null : _diveDeeper,
            child: Text(_asked && explainError == null
                ? 'Writing the explainer…'
                : 'Dive deeper'),
          ),
        if (explainError != null)
          Text(explainError, style: TextStyle(color: muted)),
      ],
    );
  }
}
