"""Non-LLM control-flow rules for the interviewer agent.

These live outside prompts because they are deterministic, cheap, and testable.
Keep prompt-side rules in prompts.py — this file is only for code-side rules.
"""

# ---- End-of-interview keywords (case-insensitive substring match) ----
END_KEYWORDS = [
    "结束答辩",
    "答辩结束",
    "结束这次答辩",
    "我想结束",
    "不想继续了",
    "到此为止",
    "end defense",
    "stop defense",
]


def is_end_signal(text: str) -> bool:
    t = (text or "").strip().lower()
    if not t:
        return False
    return any(k.lower() in t for k in END_KEYWORDS)


# ---- Fixed opening question for the very first round ----
INTRO_QUESTION = {
    "topic": "论文概述",
    "question": (
        "在正式开始答辩之前，请你用 3 分钟左右概述你的论文："
        "包括研究问题、研究方法、核心发现和研究贡献。准备好了请开始。"
    ),
}
