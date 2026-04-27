#!/usr/bin/env python3
"""Generate Faith Journal/Faith Journal/Resources/reflections_1000.json with 1000 unique reflection bodies."""

from __future__ import annotations

import json
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_PATH = os.path.join(
    SCRIPT_DIR,
    "..",
    "Faith Journal",
    "Faith Journal",
    "Resources",
    "reflections_1000.json",
)

# 40 × 25 = 1000 unique (i % 40, i // 40) pairs for i in 0..999.
OPENINGS: list[str] = [
    "The Lord invites His people to walk with Him in honesty, not in perfection.",
    "Faith grows in ordinary hours when we choose God’s voice over our anxieties.",
    "Christian hope is sturdy because it rests on Christ, not on favorable circumstances.",
    "Peace is not the absence of trouble, but the presence of God in the middle of it.",
    "Wisdom begins when we admit how much we need the Lord’s guidance.",
    "Love becomes visible when patience and kindness replace our first impulses.",
    "Forgiveness is a grace we receive and then extend, for our own freedom as well as theirs.",
    "Courage is obedience in the direction God calls, even when the path feels narrow.",
    "Rest in Christ is not laziness; it is trust that finishes its work in His hands.",
    "Prayer keeps the heart tender and reminds us we were never meant to live alone.",
    "Gratitude reframes a day: what we thank God for begins to shape what we notice.",
    "The Spirit forms Christlike character slowly, through daily surrender and small yeses.",
    "God’s promises are meant to be remembered, spoken, and leaned on in real decisions.",
    "Humility opens the door to help; pride insists we carry burdens we cannot bear.",
    "Service is love with shoes on—meeting needs quietly, faithfully, without fanfare.",
    "Trust does not demand a map for every mile; it follows a Shepherd who knows the way.",
    "Joy in the Lord can coexist with grief; it anchors us to what will not be taken away.",
    "Repentance is kindness from heaven: a way back, a clean heart, a new direction.",
    "The Word of God is light for the next step, even when the whole road is hidden.",
    "Patience is how love endures people, processes, and prayers that take longer than we like.",
    "Boldness in the gospel is not arrogance; it is clarity about who Jesus is.",
    "Contentment learns to say, “Enough,” because God Himself is the portion we need.",
    "Mercy meets us where we are and moves us where we need to be.",
    "Holiness is not performance; it is God making us more like His Son over time.",
    "The church is a family where burdens are shared and gifts are multiplied.",
    "Eternal life changes how we measure success, time, and what we fear losing.",
    "Listening to God often means slowing down long enough to hear Him at all.",
    "Generosity breaks the grip of scarcity-thinking and mirrors heaven’s open hand.",
    "Self-control is the Spirit helping us choose what we will not regret later.",
    "Faithfulness in little things prepares us for responsibilities we cannot yet see.",
    "The cross is the measure of love; the empty tomb is the guarantee of victory.",
    "Worship reorders desire: we were made to enjoy God first and everything else in Him.",
    "Comfort from Scripture is not a bandage on denial; it is truth applied to pain.",
    "Unity costs humility, but division costs far more than we usually admit.",
    "Zeal without knowledge can harm; knowledge without love can freeze the soul.",
    "The fear of the Lord is not terror for children of God, but awe that leads to life.",
    "Waiting on God is active trust: doing today’s duty while His timing stays hidden.",
    "Heaven’s values look foolish to the world—and wise to everyone who has met Christ.",
    "A gentle answer is a spiritual skill cultivated in prayer, not a natural temperament.",
    "The Lord remembers His covenant; our confidence is tied to His character, not our mood.",
]

MIDDLES: list[str] = [
    "Today, let your heart rehearse His faithfulness rather than rehearsing worst-case stories.",
    "Take a quiet moment to name one truth from His Word you need to carry until evening.",
    "Ask the Spirit to soften what has hardened in you through stress or disappointment.",
    "Choose one small act of integrity that aligns your public life with your private prayers.",
    "Release the need to understand everything before you obey the next clear step.",
    "Remember that God is near to the brokenhearted and attentive to the humble.",
    "Let gratitude interrupt complaint: speak one sentence of thanks out loud to God.",
    "Where you feel weak, confess it plainly; grace flows where pride stops pretending.",
    "Treat someone today with the patience you hope God shows you in your own faults.",
    "Slow down enough to notice where hurry is stealing peace and presence.",
    "Replace one anxious spiral with a simple prayer: “Lord, guide me; I trust You.”",
    "Let Scripture set the tone of your inner conversation before the world sets it for you.",
    "Do the next right thing, even if it is small; faithfulness often looks unremarkable.",
    "Bring your plans to God as a conversation, not a demand; welcome His redirection.",
    "Consider how Jesus would speak in your hardest conversation, and aim toward that tone.",
    "Refuse to let yesterday’s failure define today’s identity; mercy speaks a new word.",
    "Protect one pocket of time for quiet: even a few minutes can re-center your soul.",
    "Ask God to help you see people as He sees them, with dignity and compassion.",
    "When temptation whispers shortcuts, remember the better reward of a clear conscience.",
    "Let kindness be deliberate: encouragement costs little and can strengthen greatly.",
    "Turn worry into prayer by naming specifics; God is not vague about caring for you.",
    "Practice humility by admitting a need, accepting help, or apologizing where it is due.",
    "Choose faith over cynicism: God is still at work when progress feels invisible.",
    "Let your home, workplace, or classroom be a little more peaceful because you were there.",
    "End this day with honesty before God: thanks, confession, and a surrendered tomorrow.",
]

CLOSINGS: list[str] = [
    "Carry this truth with you: you are held, led, and loved by a faithful God.",
    "Walk forward with a steadier step, knowing His mercy is new for the hours ahead.",
    "Let your heart be quieted by His care, not by the illusion of total control.",
    "May your thoughts return often to what is true, noble, and worthy of praise.",
    "Trust that God can use even an ordinary day to shape you for His purposes.",
    "Keep your eyes on Christ; He finishes what He begins in those who belong to Him.",
    "Remember: the Lord is your help; you need not face what is next alone.",
    "May obedience feel less like strain and more like rest, because you follow a good King.",
    "Let peace rule in your heart as you take the next faithful step in front of you.",
    "Believe that God’s wisdom is better than your impatience, even when waiting is hard.",
    "May love be the mark of your speech today—clear, kind, and free from needless sharpness.",
    "Hold lightly what is passing; cling to what is eternal and cannot be shaken.",
    "May courage rise—not from your nerves, but from the promise of His presence.",
    "Let gratitude loosen the grip of fear; both cannot dominate the same heart for long.",
    "Trust that God’s timing, though mysterious, is matched by His tender attention.",
    "May your life today sound a little more like Jesus and a little less like the world.",
    "Remember that repentance is a doorway to joy, not a wall between you and God.",
    "Let humility open paths that pride would slam shut; God lifts the lowly in due time.",
    "May the Word you read become prayer you live, simple and sincere before the Lord.",
    "Keep serving in secret places; God sees what no applause ever notices.",
    "May your faith be practical—shown in integrity, patience, and dependable love.",
    "Remember: you are not your worst moment; you are His, and He is making you new.",
    "Let the gospel calm your conscience and energize your hands for good works.",
    "May the Spirit’s fruit be evident where you are most tempted to react in the flesh.",
    "Trust God with outcomes you cannot engineer; your job is faithful obedience today.",
    "May worship be more than a song—let it be a life that honors Christ in the details.",
    "Let comfort from heaven deepen compassion toward people who are still hurting.",
    "Pursue unity without sacrificing truth; both matter in the family of God.",
    "May zeal be tempered with gentleness, and knowledge warmed with love.",
    "Fear God and you will fear less of what people can do to your reputation.",
    "Keep waiting with hope; God is never late, though He is often not early on your clock.",
    "Let heaven’s values guide one concrete choice you would usually make by instinct alone.",
    "May your words heal today; the tongue can bless or bruise—choose blessing.",
    "Remember His covenant love: it is the reason you can lie down in peace tonight.",
    "May Christ be magnified in your ordinary conversations and quiet routines.",
    "Let faith express itself through love, because love is how faith becomes visible.",
    "End today believing that grace is sufficient, and that His strength shines in weakness.",
    "May the Lord establish your steps; He delights in the way of those who seek Him.",
    "Keep your heart open to correction; God’s kindness often arrives that way.",
    "May peace guard your mind as you refuse to borrow tomorrow’s troubles today.",
]


def main() -> None:
    if len(OPENINGS) != 40 or len(MIDDLES) != 25 or len(CLOSINGS) != 40:
        raise SystemExit("Pool sizes must be 40, 25, 40")

    reflections: list[str] = []
    for i in range(1000):
        a = i % 40
        b = i // 40
        if b >= 25:
            raise SystemExit("indexing assumes i < 1000")
        c = (a + b) % 40
        text = f"{OPENINGS[a]} {MIDDLES[b]} {CLOSINGS[c]}"
        reflections.append(text)

    if len(reflections) != 1000:
        raise SystemExit("expected 1000 reflections")
    if len(set(reflections)) != 1000:
        dupes = len(reflections) - len(set(reflections))
        raise SystemExit(f"duplicate reflection bodies detected ({dupes})")

    out_abs = os.path.normpath(OUT_PATH)
    os.makedirs(os.path.dirname(out_abs), exist_ok=True)
    with open(out_abs, "w", encoding="utf-8") as f:
        json.dump({"reflections": reflections}, f, ensure_ascii=False, indent=2)
    print(f"Wrote {out_abs} ({len(reflections)} unique reflections)")


if __name__ == "__main__":
    main()
