# PR review

The vocabulary this skill uses when reviewing a pull request at a given commit, and the words it
deliberately does not use. What decides *which* pull requests get reviewed — the register, the
aliases, the priority list — belongs to the company's own glossary, not this one.

## Language

### The review

**Review**:
One assessment of one pull request at one head commit.
_Avoid_: audit, check, inspection

**Leg**:
One of the two parallel analyses that a review is built from.
_Avoid_: agent, child, sub-agent, run, pass

**Reviewer**:
The leg that reads only. It has no shell, and names any command it wants run instead of running it.
_Avoid_: critic, check, first pass

**Oracle**:
The leg that may run commands, and whose job is to challenge the reviewer rather than agree with it.
_Avoid_: second opinion, verifier, sanity check

**Preflight**:
Everything before the legs launch: parsing, workspace, context and standards.
_Avoid_: setup, warm-up, preamble, preparation

**Assembly**:
Everything after both legs return: consolidation, reversal check, sanitisation, report.
_Avoid_: synthesis, merge, post-processing, consolidation phase

**Delivery**:
Handing the finished review to its audience, whether presented or posted.
_Avoid_: publish, output, submission

### Findings

**Finding**:
One defect or observation in the pull request, carrying a file and line.
_Avoid_: issue, comment, item, nit (a nit is a finding at minor severity)

**Label**:
The single controlled-vocabulary category a finding carries, drawn from `standards.md`.
_Avoid_: tag, category, type, kind

**Severity**:
How bad a finding is — blocker, warning or minor.
_Avoid_: priority, rank, weight, impact

**Disposition**:
What should happen to a finding — an inline fix, an issue, or a decision.
_Avoid_: action, resolution, bucket, recommendation

**Reversal**:
A finding that contradicts a recommendation from an earlier review of the same pull request.
_Avoid_: disagreement, contradiction, flip-flop, ping-pong

### The verdict and the gate

**Verdict**:
The review's bottom-line judgement, shown as one traffic light.
_Avoid_: score, rating, grade, result, outcome

**Gate**:
The point where a human reads the review before it is posted.
_Avoid_: approval, sign-off, pause, checkpoint

**Present mode**:
The default behaviour: review, show the report, wait at the gate, then post.
_Avoid_: interactive mode, manual mode, gated mode

**Post mode**:
No gate: post the review as a comment and stop. Advisory — never an approval, never a request for
changes, and never a change to the code.
_Avoid_: auto mode, headless mode, unattended mode, silent mode

### The record

**Review record**:
The single JSON line written per review, holding its verdict, legs, findings and splits.
_Avoid_: log, history, audit trail, metrics, stats

**Split**:
One phase's elapsed time within a review.
_Avoid_: lap, phase time, segment, interval

**Stamped**:
Written down at the moment a phase ends, rather than reconstructed afterwards.
_Avoid_: captured, recorded later, back-filled
