import 'dart:math';

import 'judge.dart';
import 'match.dart';
import 'easy.dart';
import 'medium.dart';
import 'hard.dart';
import 'hard_opening.dart';
import 'bot_memory.dart';

/// One independent stream for speech and one for advice, separate from the engine.
Match runPolicyMatch(
  int seed,
  Policy policy, {
  bool perfectHint = false,
  bool useHintVotes = true,
  bool easyFirstHint = false,
  bool compareClaimPatterns = false,
  double baselineRandomShare = 0,
  bool enableAnnouncement = false,
  bool independentBotVotes = false,
  bool silentJudge = false,
  double informedVoteShare = 1,
  double nearVoteBand = 0,
  bool useOrdinaryVotes = false,
  int mediumHintVoteBonus = 32,
  bool useActualVoteTarget = false,
  bool usePublicOrdinaryVotes = false,
  bool preferAnnouncedTarget = false,
  double? hardOpeningVoteScale,
  double hardOpeningNoise = .002,
  bool publishOpeningClears = false,
  double fakeOpeningClearShare = 0,
  double? assumedFakeOpeningClearShare,
  void Function(bool baselineCorrect, bool candidateCorrect)?
  onHardOpeningComparison,
  void Function(bool, bool, bool)? onSilentHardComparison,
  void Function(bool)? onAnnouncement,
  int firstHintDay = 3,
  EasyRules? easyRules,
  EasyRules? compareEasyRules,
  void Function(bool mediumCorrect, bool easyCorrect)? onEasyMediumComparison,
  void Function(int)? onHint,
  void Function(bool)? onAdvice,
  void Function(bool, bool)? onPairedAdvice,
  void Function(bool first, bool mediumCorrect, bool hardCorrect)?
  onJudgeComparison,
  void Function(List<List<int>>, Set<int>)? auditTeams,
}) {
  if (!(baselineRandomShare >= 0 && baselineRandomShare <= 1)) {
    throw ArgumentError.value(baselineRandomShare, 'baselineRandomShare');
  }
  if (informedVoteShare < 0 ||
      informedVoteShare > 1 ||
      !informedVoteShare.isFinite) {
    throw ArgumentError.value(informedVoteShare, 'informedVoteShare');
  }
  if (nearVoteBand < 0 || nearVoteBand > 1 || !nearVoteBand.isFinite) {
    throw ArgumentError.value(nearVoteBand, 'nearVoteBand');
  }
  if ((useOrdinaryVotes || onSilentHardComparison != null) &&
      (!silentJudge ||
          !independentBotVotes ||
          policy != Policy.hard ||
          nearVoteBand != 0)) {
    throw ArgumentError(
      'Ordinary vote evidence requires silent hard play with independent bots.',
    );
  }
  final game = Match.deal(15, 3, seed);
  final speech = Random(seed ^ 8191);
  final fakeClears = Random(seed ^ 164921);
  final advice = Random(seed ^ 65521);
  final baselineChoice = baselineRandomShare > 0 ? Random(seed ^ 251641) : null;
  final voteTies = Random(seed ^ 104729);
  final voteChoices = Random(seed ^ 130363);
  final ordinaryWeights = List.filled(16, 0.0);
  final trackOrdinaryVotes =
      useOrdinaryVotes ||
      onSilentHardComparison != null ||
      usePublicOrdinaryVotes ||
      hardOpeningVoteScale != null ||
      onHardOpeningComparison != null;
  final announcedVoteTargets = <int, int>{};
  Map<int, num>? previousScores;
  final judge = Judge(15, 3, policy == Policy.hard ? Policy.random : policy);
  final medium = policy == Policy.medium || policy == Policy.hard
      ? MediumJudge(15, 3)
      : null;
  List<int>? named;
  final accusations = <int, int>{};
  var observed = 0;
  var firstHint = true;
  game.play(
    experimentDay: (game, ballots, detective, checked) {
      final prior = previousScores;
      if (prior != null) {
        previousScores = null;
        for (final event in game.publicEvents) {
          if (event.round == game.round - 1 && event.type == 'VOTE') {
            ordinaryWeights[event.actor!] += ordinaryVoteWeight(
              event.actor!,
              event.target,
              prior,
              informedVoteShare,
            );
          }
        }
      }
      final living = game.alive.toList()..sort();
      final innocents = living
          .where((p) => game.roles[p] != Role.mafia)
          .toList();
      final publishClears = publishOpeningClears && game.round <= firstHintDay;
      for (final p in living) {
        final others = living.where((q) => q != p).toList();
        int? claim;
        var claimsMafia = true;
        if (p == detective &&
            checked != null &&
            game.roles[checked] == Role.mafia) {
          claim = checked;
        } else if (p == detective && checked != null && publishClears) {
          speech.nextInt(others.length);
          claim = checked;
          claimsMafia = false;
        } else if (game.roles[p] == Role.mafia && speech.nextDouble() < 0.20) {
          claim = innocents[speech.nextInt(innocents.length)];
          if (publishClears &&
              fakeClears.nextDouble() < fakeOpeningClearShare) {
            claim = others[fakeClears.nextInt(others.length)];
            claimsMafia = false;
          }
        }
        if (claim != null) {
          game.log(
            'CLAIM_CHECK',
            actor: p,
            target: claim,
            claimedRole: 'DETECTIVE',
            result: claimsMafia ? 'MAFIA' : 'NOT_MAFIA',
          );
          if (claimsMafia) accusations[p] = claim;
        } else {
          game.log(
            'ACCUSE',
            actor: p,
            target: others[speech.nextInt(others.length)],
          );
        }
      }
      final hintDay =
          game.round >= firstHintDay && (game.round - firstHintDay) % 3 == 0;
      void castIndependentVotes() {
        final memory = botEvidence(game.publicEvents, game.round, policy);
        final possible = medium!.feasible(memory);
        final Map<int, num> scores;
        if (policy == Policy.hard) {
          final probabilities = hardPosterior(15, possible, memory);
          scores = {for (final seat in living) seat: probabilities[seat]};
        } else {
          scores = firstHint
              ? medium.openingScores(memory, living, possible)
              : medium.rankScores(memory, living, possible);
        }
        if (trackOrdinaryVotes) previousScores = scores;
        for (final voter in innocents) {
          final legal = living.where((id) => id != voter).toList()
            ..shuffle(voteTies);
          if (informedVoteShare < 1 &&
              voteChoices.nextDouble() >= informedVoteShare) {
            continue;
          }
          final best = legal.map((seat) => scores[seat]!).reduce(max);
          final minimum = nearVoteBand == 0
              ? best
              : best -
                    (best - legal.map((seat) => scores[seat]!).reduce(min)) *
                        nearVoteBand;
          ballots[voter] = legal.firstWhere((seat) => scores[seat]! >= minimum);
        }
      }

      if (!hintDay && !enableAnnouncement) {
        if (independentBotVotes) castIndependentVotes();
        return;
      }
      if (hintDay) onHint?.call(game.round);
      final log = game.narrator;
      for (final event in log.skip(observed)) judge.observe(event);
      observed = log.length;
      final shuffled = [...living];
      if (hintDay) shuffled.shuffle(advice);
      int? shared;
      if (policy == Policy.coordinated) shared = shuffled.first;
      if (policy == Policy.followsClaim) {
        // First surviving claimant with a live named suspect.
        for (final entry in accusations.entries) {
          if (living.contains(entry.key) && living.contains(entry.value)) {
            shared = entry.value;
            break;
          }
        }
      }
      if (perfectHint) {
        shared = shuffled.firstWhere((id) => game.roles[id] == Role.mafia);
      } else if (medium != null) {
        final events = game.publicEvents.toList();
        final feasible = medium.feasible(events);
        int mediumTarget() => compareClaimPatterns && firstHint
            ? medium.openingAdvice(events, shuffled, feasible)
            : easyFirstHint && firstHint
            ? const EasyRules(4, 4, 8).recommend(events, shuffled)
            : medium.recommend(
                events,
                shuffled,
                feasible,
                useHintVotes: useHintVotes,
                hintVoteBonus: mediumHintVoteBonus,
              );
        int hardTarget(List<double> probabilities) => shuffled.reduce(
          (a, b) => probabilities[b] > probabilities[a] ? b : a,
        );
        int? ordinaryTarget;
        if (policy == Policy.hard) {
          final probabilities = hardPosterior(15, feasible, events);
          if (hintDay && (useOrdinaryVotes || onSilentHardComparison != null)) {
            final adjusted = hardPosterior(
              15,
              feasible,
              events,
              ordinaryVoteWeights: ordinaryWeights,
            );
            ordinaryTarget = shuffled.reduce(
              (a, b) => adjusted[b] > adjusted[a] ? b : a,
            );
          }
          if (hintDay) {
            final hintProbabilities =
                useActualVoteTarget || usePublicOrdinaryVotes
                ? hardPosterior(
                    15,
                    feasible,
                    events,
                    ordinaryVoteWeights: usePublicOrdinaryVotes
                        ? ordinaryWeights
                        : null,
                    announcedVoteTargets: useActualVoteTarget
                        ? announcedVoteTargets
                        : null,
                  )
                : probabilities;
            shared = hardTarget(hintProbabilities);
          }
          if (enableAnnouncement && !silentJudge && named == null) {
            final suspects = [
              for (var id = 1; id <= 15; id++)
                if (probabilities[id] >= .95) id,
            ];
            if (suspects.length == 3) {
              named = suspects;
              game.log(
                'CODEFATHER_ANNOUNCE',
                note:
                    'Suspects: ${suspects.join(", ")}. Based on public claims, voting and legal teams.',
              );
              onAnnouncement?.call(
                suspects.every((p) => game.roles[p] == Role.mafia),
              );
            }
          }
          if (hintDay && preferAnnouncedTarget) {
            shared = named?.where(living.contains).firstOrNull ?? shared;
          }
          if (hintDay &&
              firstHint &&
              (hardOpeningVoteScale != null ||
                  onHardOpeningComparison != null)) {
            final candidate =
                named?.where(living.contains).firstOrNull ??
                hardTarget(
                  hardOpeningScores(
                    15,
                    feasible,
                    events,
                    ordinaryWeights,
                    voteScale: hardOpeningVoteScale ?? 1,
                    noise: hardOpeningNoise,
                    publishClearsThroughDay: publishOpeningClears
                        ? firstHintDay
                        : null,
                    fakeClearShare:
                        assumedFakeOpeningClearShare ?? fakeOpeningClearShare,
                  ),
                );
            onHardOpeningComparison?.call(
              game.roles[shared] == Role.mafia,
              game.roles[candidate] == Role.mafia,
            );
            if (hardOpeningVoteScale != null) shared = candidate;
          }
        } else {
          shared = mediumTarget();
          if (hintDay &&
              compareEasyRules != null &&
              onEasyMediumComparison != null) {
            final easyPick = compareEasyRules.recommend(events, shuffled);
            onEasyMediumComparison(
              game.roles[shared] == Role.mafia,
              game.roles[easyPick] == Role.mafia,
            );
          }
        }
        if (onJudgeComparison != null && hintDay && shared != null) {
          final mediumPick = policy == Policy.medium ? shared : mediumTarget();
          final hardPick = policy == Policy.hard
              ? shared
              : hardTarget(hardPosterior(15, feasible, events));
          onJudgeComparison(
            firstHint,
            game.roles[mediumPick] == Role.mafia,
            game.roles[hardPick] == Role.mafia,
          );
        }
        if ((onPairedAdvice != null || onSilentHardComparison != null) &&
            hintDay &&
            shared != null) {
          final memory = botEvidence(events, game.round, policy);
          final possible = medium.feasible(memory);
          int target;
          if (policy == Policy.hard) {
            final scores = hardPosterior(15, possible, memory);
            target = shuffled.reduce((a, b) => scores[b] > scores[a] ? b : a);
          } else {
            target = firstHint
                ? medium.openingAdvice(memory, shuffled, possible)
                : medium.recommend(memory, shuffled, possible);
          }
          final botCorrect = game.roles[target] == Role.mafia;
          onPairedAdvice?.call(
            game.roles[useOrdinaryVotes ? ordinaryTarget : shared] ==
                Role.mafia,
            botCorrect,
          );
          onSilentHardComparison?.call(
            game.roles[shared] == Role.mafia,
            game.roles[ordinaryTarget] == Role.mafia,
            botCorrect,
          );
        }
        if (useOrdinaryVotes && ordinaryTarget != null) shared = ordinaryTarget;
        auditTeams?.call(
          feasible,
          game.roles.keys.where((p) => game.roles[p] == Role.mafia).toSet(),
        );
      } else if (easyRules != null) {
        shared = easyRules.recommend(game.publicEvents, shuffled);
      } else if (policy == Policy.simpleBaseline) {
        if (baselineChoice != null &&
            baselineChoice.nextDouble() < baselineRandomShare) {
          shared = shuffled.first;
        } else {
          final scores = judge.scores;
          shared = shuffled.reduce((a, b) => scores[b] > scores[a] ? b : a);
        }
      }
      if (shared != null) {
        onAdvice?.call(game.roles[shared] == Role.mafia);
      }
      if (silentJudge) {
        if (independentBotVotes) castIndependentVotes();
        if (hintDay) firstHint = false;
        return;
      }
      if (shared != null) {
        firstHint = false;
        game.log('ASK_CODEFATHER', target: shared);
      }
      // The benchmark assumes villagers follow the public list while any
      // named target survives. The first eligible ID is the common tie-break.
      final namedTarget = named?.where(living.contains).firstOrNull;
      if (useActualVoteTarget && namedTarget != null) {
        announcedVoteTargets[game.round] = namedTarget;
      }
      if (!hintDay && namedTarget == null) {
        if (independentBotVotes) castIndependentVotes();
        return;
      }
      shared = namedTarget ?? shared;
      for (final voter in innocents) {
        final others = living.where((p) => p != voter).toList();
        ballots[voter] = shared != null && shared != voter
            ? shared
            : others[advice.nextInt(others.length)];
      }
    },
  );
  return game;
}
