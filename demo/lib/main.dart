import 'package:codefather_core/judge.dart';
import 'package:codefather_core/match.dart';
import 'package:codefather_core/playable_levels.dart';
import 'package:flutter/material.dart';

void main() =>
    runApp(const CodefatherDemo());

const levelNames = {
  PlayableLevel.dumb: 'الغبي',
  PlayableLevel.easy: 'السهل',
  PlayableLevel.medium: 'المتوسط',
  PlayableLevel.hard: 'الصعب',
};

class CodefatherDemo
    extends StatelessWidget {
  const CodefatherDemo({super.key});

  @override
  Widget build(BuildContext context) =>
      MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Codefather',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(
              0xff17434a,
            ),
          ),
          useMaterial3: true,
        ),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: MatchReplay(),
        ),
      );
}

class MatchReplay extends StatefulWidget {
  const MatchReplay({super.key});

  @override
  State<MatchReplay> createState() =>
      _MatchReplayState();
}

class _MatchReplayState
    extends State<MatchReplay> {
  final seed = TextEditingController(
    text: '42',
  );
  var level = PlayableLevel.medium;
  Match? match;

  @override
  void dispose() {
    seed.dispose();
    super.dispose();
  }

  void runMatch() {
    final start = int.tryParse(
      seed.text.trim(),
    );
    if (start == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'أدخل رقم بداية صحيحًا.',
          ),
        ),
      );
      return;
    }
    setState(
      () => match = playLevel(start, level),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = match;
    final events =
        game?.publicEvents.toList() ??
        <Event>[];
    final winner = switch (game?.outcome) {
      Outcome.village => 'فوز القرية',
      Outcome.mafia => 'فوز المافيا',
      Outcome.draw => 'تعادل',
      null => 'اختر مستوى وشغّل ماتش',
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Codefather · تجربة القاضي',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
                  maxWidth: 840,
                ),
            child: Padding(
              padding: const EdgeInsets.all(
                20,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment:
                        WrapCrossAlignment
                            .center,
                    children: [
                      DropdownButton<
                        PlayableLevel
                      >(
                        value: level,
                        items: [
                          for (final entry
                              in levelNames
                                  .entries)
                            DropdownMenuItem(
                              value:
                                  entry.key,
                              child: Text(
                                entry.value,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null)
                            setState(
                              () => level =
                                  value,
                            );
                        },
                      ),
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: seed,
                          keyboardType:
                              TextInputType
                                  .number,
                          decoration: const InputDecoration(
                            labelText:
                                'رقم البداية',
                            border:
                                OutlineInputBorder(),
                          ),
                          onSubmitted: (_) =>
                              runMatch(),
                        ),
                      ),
                      FilledButton(
                        onPressed: runMatch,
                        child: const Text(
                          'شغّل ماتش',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    winner,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall,
                  ),
                  if (game != null)
                    Text(
                      'الجولات ${game.round} · السجل العلني',
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount:
                          events.length,
                      itemBuilder:
                          (
                            _,
                            index,
                          ) => eventTile(
                            events[index],
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget eventTile(Event event) {
    final description = switch (event.type) {
      'ASK_CODEFATHER' =>
        'ترشيح القاضي · اللاعب ${event.target}',
      'CODEFATHER_ANNOUNCE' =>
        'إعلان القاضي · ${event.note}',
      'CLAIM_CHECK' =>
        '${event.actor} ادّعى إن ${event.target} ${event.result == 'MAFIA' ? 'مافيا' : 'بريء'}',
      'VOTE' =>
        '${event.actor} صوّت لـ ${event.target ?? 'لا أحد'}',
      'ELIMINATE' =>
        'استبعاد اللاعب ${event.target}',
      'DEATH_ANNOUNCE' =>
        'خروج اللاعب ${event.target} ليلًا',
      'ACCUSE' =>
        '${event.actor} اشتبه في ${event.target}',
      _ => event.type,
    };
    return ListTile(
      dense: true,
      title: Text(description),
      trailing: Text('جولة ${event.round}'),
    );
  }
}
