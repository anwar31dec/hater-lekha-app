# -*- coding: utf-8 -*-
"""Single source of truth for glyph stroke data. Emits glyphs.json for the app.
Coordinate box: 0..100 x 0..100. Bengali: matra centreline y=22, body bottom y=75.
Each stroke: SVG path 'd' (absolute M/L/Q/C/A), drawn in writing order & direction.
"""
import json, math, re, sys

D = chr(0x9DC); DH = chr(0x9DD); Y = chr(0x9DF)  # ড় ঢ় য়

def g(char, strokes, name_bn, name_en, word_bn=None, word_en=None, emoji=None, sound=None):
    return dict(char=char, strokes=strokes, name_bn=name_bn, name_en=name_en,
                word_bn=word_bn, word_en=word_en, emoji=emoji, sound=sound)

def dot(x, y, r=3.2):
    return f"M{x} {y-r} A{r} {r} 0 1 0 {x} {y+r} A{r} {r} 0 1 0 {x} {y-r}"

# ---------------- Pre-writing drills (page 2 of the workbook) ----------------
PRE = [
    ("line_down",   ["M50 14 L50 86"], "উপর থেকে নিচে আঁক", "Draw from top to bottom"),
    ("line_up",     ["M50 86 L50 14"], "নিচ থেকে উপরে আঁক", "Draw from bottom to top"),
    ("line_lr",     ["M14 50 L86 50"], "বাম থেকে ডানে আঁক", "Draw from left to right"),
    ("line_rl",     ["M86 50 L14 50"], "ডান থেকে বামে আঁক", "Draw from right to left"),
    ("slant_down",  ["M30 14 L70 86"], "উপর থেকে নিচে বাঁকা আঁক", "Slant: top to bottom"),
    ("slant_up",    ["M30 86 L70 14"], "নিচ থেকে উপরে বাঁকা আঁক", "Slant: bottom to top"),
    ("slant_down2", ["M70 14 L30 86"], "উপর থেকে নিচে বাঁকা আঁক", "Slant: top to bottom"),
    ("slant_up2",   ["M70 86 L30 14"], "নিচ থেকে উপরে বাঁকা আঁক", "Slant: bottom to top"),
    ("zig_lt",      ["M72 14 L28 50 L72 86"], "উপর থেকে নিচে কোণা আঁক", "Angle: top to bottom"),
    ("zig_lt_up",   ["M72 86 L28 50 L72 14"], "নিচ থেকে উপরে কোণা আঁক", "Angle: bottom to top"),
    ("zig_gt",      ["M28 14 L72 50 L28 86"], "উপর থেকে নিচে কোণা আঁক", "Angle: top to bottom"),
    ("zig_gt_up",   ["M28 86 L72 50 L28 14"], "নিচ থেকে উপরে কোণা আঁক", "Angle: bottom to top"),
    ("arch",        ["M18 82 Q50 0 82 82"], "বাম থেকে ডানে ঘুরিয়ে আঁক", "Arch: left to right"),
    ("arch_rl",     ["M82 82 Q50 0 18 82"], "ডান থেকে বামে ঘুরিয়ে আঁক", "Arch: right to left"),
    ("cup",         ["M18 18 Q50 100 82 18"], "বাম থেকে ডানে ঘুরিয়ে আঁক", "Cup: left to right"),
    ("paren_l",     ["M66 14 Q22 50 66 86"], "উপর থেকে নিচে ঘুরিয়ে আঁক", "Curve: top to bottom"),
    ("paren_r",     ["M34 14 Q78 50 34 86"], "উপর থেকে নিচে ঘুরিয়ে আঁক", "Curve: top to bottom"),
    ("circle_ccw",  ["M50 18 A32 32 0 1 0 50 82 A32 32 0 1 0 50 18"], "বাম দিকে ঘুরিয়ে গোল আঁক", "Circle: turn left"),
    ("circle_cw",   ["M50 18 A32 32 0 1 1 50 82 A32 32 0 1 1 50 18"], "ডান দিকে ঘুরিয়ে গোল আঁক", "Circle: turn right"),
    ("wave",        ["M8 50 Q21 14 34 50 Q47 86 60 50 Q73 14 86 50"], "ঢেউ আঁক", "Wave: left to right"),
    ("zigzag_h",    ["M8 72 L29 28 L50 72 L71 28 L92 72"], "আঁকাবাঁকা রেখা আঁক", "Zigzag: left to right"),
    ("loop",        ["M10 70 Q30 10 40 50 Q50 90 60 50 Q70 10 90 70"], "ফাঁস আঁক", "Loops: left to right"),
]

# ---------------- Bengali vowels ----------------
BN_V = [
 g("অ", ["M12 22 L90 22",
         "M22 36 Q12 52 22 66 Q34 78 56 74 Q70 70 80 66",
         "M22 36 Q30 32 44 32 Q58 34 56 46 Q52 54 40 52",
         "M82 22 L82 75"], "স্বরে অ", "a (ô)", "অজগর", "python", "🐍", "অ"),
 g("আ", ["M10 22 L86 22",
         "M16 36 Q8 52 16 66 Q28 78 46 74 Q54 72 58 68",
         "M16 36 Q24 32 36 32 Q50 34 48 46 Q44 54 34 52",
         "M58 22 L58 75",
         "M84 22 L84 75"], "স্বরে আ", "aa", "আম", "mango", "🥭", "আ"),
 g("ই", ["M28 22 L74 22",
         "M34 50 Q34 34 48 34 Q62 34 62 48 Q62 62 44 64 L34 65 L64 76",
         "M66 22 Q68 8 56 8 L36 9"], "হ্রস্ব ই", "i", "ইলিশ", "hilsa fish", "🐟", "ই"),
 g("ঈ", ["M18 22 L82 22",
         "M30 52 Q30 34 46 34 Q58 34 56 46 Q54 58 34 66",
         "M32 67 L72 38 Q73 60 68 76",
         "M74 22 Q76 8 62 8 L36 9"], "দীর্ঘ ঈ", "ii", "ঈগল", "eagle", "🦅", "ঈ"),
 g("উ", ["M20 22 L82 22",
         "M53 22 L53 50",
         "M28 42 L28 56 Q28 75 50 75 Q73 75 73 55 L73 44 Q68 46 63 50",
         "M72 22 Q74 8 60 8 L30 8 L28 12"], "হ্রস্ব উ", "u", "উট", "camel", "🐪", "উ"),
 g("ঊ", ["M18 22 L85 22",
         "M53 22 L53 50",
         "M22 42 L22 56 Q22 75 48 75 Q74 75 74 55 L74 44 Q69 46 64 50",
         "M36 42 Q33 64 50 70",
         "M76 22 Q78 8 64 8 L30 8 L28 12"], "দীর্ঘ ঊ", "uu", "ঊষা", "dawn", "🌅", "ঊ"),
 g("ঋ", ["M18 22 L86 22",
         "M18 25 Q20 38 33 36",
         "M52 25 L18 60 L52 76 L52 58 L73 58",
         "M73 13 L73 72"], "ঋ", "ri", "ঋষি", "sage", "🧘", "ঋ"),
 g("এ", ["M68 24 L68 76",
         "M68 24 L40 24 Q30 24 30 40 Q30 53 50 52",
         "M20 57 Q20 74 36 74 Q50 74 68 70"], "এ", "e", "একতারা", "ektara", "🎸", "এ"),
 g("ঐ", ["M58 24 L58 76",
         "M58 24 L36 24 Q28 24 28 40 Q28 52 46 52",
         "M18 57 Q18 74 32 74 Q46 74 60 70",
         "M26 8 L56 6 Q78 6 78 28 Q78 40 70 44"], "ঐ", "oi", "ঐরাবত", "Airavata (elephant)", "🐘", "ঐ"),
 g("ও", ["M28 42 Q28 24 46 24 Q64 24 62 42 Q60 52 48 52 Q68 52 68 66 Q68 76 48 76 Q24 76 24 56"],
   "ও", "o", "ওল", "yam", "🍠", "ও"),
 g("ঔ", ["M28 42 Q28 24 46 24 Q64 24 62 42 Q60 52 48 52 Q68 52 68 66 Q68 76 48 76 Q24 76 24 56",
         "M26 10 L56 6 Q80 6 80 30 Q80 44 70 50"], "ঔ", "ou", "ঔষধ", "medicine", "💊", "ঔ"),
]

# ---------------- Bengali consonants ----------------
BN_C = [
 g("ক", ["M20 22 L84 22", "M71 22 L71 75",
         "M56 44 Q46 36 34 38 Q22 42 24 56 Q28 68 42 68 Q58 68 60 60 Q64 66 71 74"],
   "ক", "ka", "কলম", "pen", "✏️", "ক"),
 g("খ", ["M26 22 L90 22", "M72 10 L72 75",
         "M42 30 Q22 28 22 44 Q22 56 42 52",
         "M52 24 L52 62", "M30 62 L72 76"], "খ", "kha", "খরগোশ", "rabbit", "🐇", "খ"),
 g("গ", ["M44 22 L86 22", "M70 12 L70 75",
         "M24 36 Q22 60 40 64 Q58 64 58 44 Q58 34 50 34"], "গ", "ga", "গরু", "cow", "🐄", "গ"),
 g("ঘ", ["M18 22 L74 22", "M68 22 L68 75",
         "M48 30 Q24 28 24 42 Q24 52 46 50", "M24 56 L68 76"], "ঘ", "gha", "ঘর", "house", "🏠", "ঘ"),
 g("ঙ", ["M22 22 L62 22",
         "M44 24 Q34 34 42 44 Q50 50 60 48",
         "M30 44 Q28 75 52 75 Q76 75 75 52 L75 44 Q70 47 66 51",
         "M58 24 A8 8 0 1 0 58 42 A8 8 0 1 0 58 24"], "ঙ", "nga (uṅo)", "ব্যাঙ", "frog", "🐸", "উঙ"),
 g("চ", ["M24 22 L74 22",
         "M38 22 L38 56 Q38 75 54 75 Q70 75 70 58 L70 44 Q66 44 62 48"], "চ", "ca", "চাঁদ", "moon", "🌙", "চ"),
 g("ছ", ["M22 22 L78 22", "M34 22 L34 68 L70 78",
         "M34 36 Q64 30 64 46 Q64 55 42 56 Q66 56 64 66 Q62 72 52 72"], "ছ", "cha", "ছাতা", "umbrella", "☂️", "ছ"),
 g("জ", ["M10 22 L90 22",
         "M44 26 Q30 34 40 44 Q50 50 62 46",
         "M20 45 L20 58 Q20 75 46 75 Q72 75 72 56 L72 44 Q68 46 64 49",
         "M82 22 L80 60 Q79 72 76 76"], "জ", "ja", "জাহাজ", "ship", "🚢", "জ"),
 g("ঝ", ["M22 22 L84 22", "M52 26 L20 56 L52 77 L52 58 L73 58", "M73 13 L73 72"],
   "ঝ", "jha", "ঝিনুক", "oyster shell", "🐚", "ঝ"),
 g("ঞ", ["M56 24 L56 76",
         "M56 24 L36 24 Q28 24 28 38 Q28 48 46 46",
         "M18 56 Q18 74 36 74 Q50 74 56 70",
         "M56 24 L72 24 Q84 24 84 36 Q84 48 68 48 Q86 48 86 62 Q86 76 70 76 L56 76"],
   "ঞ", "nya (iṅo)", "মিঞা", "mister", "🧔", "ইঁঅ"),
 g("ট", ["M22 22 L76 22", "M50 22 L50 50",
         "M28 42 L28 56 Q28 75 50 75 Q70 75 70 56 L70 44 Q66 46 62 50",
         "M58 22 Q60 10 48 9 L28 9"], "ট", "ṭa", "টমেটো", "tomato", "🍅", "ট"),
 g("ঠ", ["M18 22 L82 22",
         "M68 8 Q56 12 50 30 L36 52 Q28 70 46 76 Q66 78 70 58 Q70 42 54 42 Q44 44 46 58"],
   "ঠ", "ṭha", "ঠেলাগাড়ি", "pushcart", "🛒", "ঠ"),
 g("ড", ["M20 22 L82 22", "M52 22 L52 50",
         "M28 42 L28 56 Q28 75 50 75 Q73 75 73 55 L73 44 Q68 46 63 50"], "ড", "ḍa", "ডিম", "egg", "🥚", "ড"),
 g("ঢ", ["M22 22 L78 22",
         "M36 22 L36 58 Q36 75 54 75 Q72 75 72 58 L72 44 Q70 40 62 44 Q58 48 62 52"], "ঢ", "ḍha", "ঢোল", "drum", "🥁", "ঢ"),
 g("ণ", ["M46 22 L76 22", "M60 12 L60 75",
         "M54 32 Q28 28 28 44 Q28 58 46 56", "M30 58 L60 76"], "মূর্ধন্য ণ", "ṇa", "হরিণ", "deer", "🦌", "ণ"),
 g("ত", ["M18 22 L82 22",
         "M58 42 Q44 32 30 42 Q22 56 36 70 Q56 78 64 60 Q68 48 58 46"], "ত", "ta", "তালা", "lock", "🔒", "ত"),
 g("থ", ["M24 22 L84 22", "M70 12 L70 75",
         "M46 28 Q26 28 26 42 Q26 50 42 48", "M26 54 L70 76"], "থ", "tha", "থালা", "plate", "🍽️", "থ"),
 g("দ", ["M22 22 L76 22", "M60 22 L60 75", "M58 44 L27 42 L27 64 L60 76"], "দ", "da", "দরজা", "door", "🚪", "দ"),
 g("ধ", ["M28 22 L74 22", "M66 22 L66 75",
         "M62 30 Q30 26 30 42 Q30 54 50 50", "M30 56 L66 76"], "ধ", "dha", "ধান", "paddy", "🌾", "ধ"),
 g("ন", ["M18 22 L74 22", "M64 22 L64 75",
         "M62 40 Q52 30 38 32 Q26 36 26 50 L26 62"], "দন্ত্য ন", "na", "নৌকা", "boat", "⛵", "ন"),
 g("প", ["M50 22 L76 22", "M60 12 L60 75",
         "M50 30 Q26 32 26 48 Q26 60 36 64 L60 76"], "প", "pa", "পাখি", "bird", "🐦", "প"),
 g("ফ", ["M18 22 L84 22", "M58 22 L58 76", "M56 30 L24 52 L58 76",
         "M58 34 Q78 30 78 46 Q76 58 58 56"], "ফ", "pha", "ফুল", "flower", "🌸", "ফ"),
 g("ব", ["M20 22 L74 22", "M66 22 L66 75", "M62 28 L26 58 L66 75"], "ব", "ba", "বই", "book", "📖", "ব"),
 g("ভ", ["M20 22 L82 22",
         "M30 40 L66 38 Q72 38 70 46 Q66 56 52 56",
         "M26 40 L26 56 Q26 75 50 75 Q76 75 75 56 L75 44 Q70 46 66 50"], "ভ", "bha", "ভালুক", "bear", "🐻", "ভ"),
 g("ম", ["M16 22 L76 22", "M66 22 L66 75",
         "M48 30 Q26 28 26 40 Q26 48 44 46",
         "M30 48 Q18 62 30 70 Q46 76 66 72"], "ম", "ma", "মাছ", "fish", "🐟", "ম"),
 g("য", ["M16 22 L74 22", "M66 22 L66 75", "M48 30 L28 30 L28 46 L50 46", "M28 52 L66 76"],
   "অন্তঃস্থ য", "ja (antastha)", "যন্ত্র", "machine", "⚙️", "য"),
 g("র", ["M22 22 L72 22", "M66 22 L66 75", "M62 28 L26 55 L66 75", dot(35, 71)],
   "র", "ra", "রকেট", "rocket", "🚀", "র"),
 g("ল", ["M18 22 L82 22", "M72 22 L72 75",
         "M56 32 Q30 28 30 44 Q30 50 46 48", "M30 52 Q28 68 46 66 Q58 64 58 54"],
   "ল", "la", "লেবু", "lemon", "🍋", "ল"),
 g("শ", ["M20 22 L86 22", "M70 12 L70 75",
         "M48 32 Q24 28 24 44 Q24 54 30 54", "M48 32 Q60 36 56 46 Q54 54 46 54"],
   "তালব্য শ", "sha", "শসা", "cucumber", "🥒", "শ"),
 g("ষ", ["M18 22 L74 22", "M66 22 L66 75", "M30 24 L30 56", "M62 28 L30 56 L66 76"],
   "মূর্ধন্য ষ", "ṣa", "ষাঁড়", "bull", "🐂", "ষ"),
 g("স", ["M18 22 L80 22", "M72 22 L72 75",
         "M56 32 Q28 28 28 42 Q28 50 50 48", "M28 54 Q40 74 72 74"], "দন্ত্য স", "sa", "সূর্য", "sun", "☀️", "স"),
 g("হ", ["M26 22 L72 22",
         "M32 48 Q32 34 46 34 Q60 34 60 46 Q60 62 42 64 L32 65 L66 77"], "হ", "ha", "হাতি", "elephant", "🐘", "হ"),
 g(D, ["M20 22 L82 22", "M52 22 L52 50",
       "M28 42 L28 56 Q28 75 50 75 Q73 75 73 55 L73 44 Q68 46 63 50", dot(52, 86)],
   "ড-এ শূন্য ড়", "ṛa", "গাড়ি", "car", "🚗", "ড়"),
 g(DH, ["M22 22 L78 22",
        "M36 22 L36 58 Q36 75 54 75 Q72 75 72 58 L72 44 Q70 40 62 44 Q58 48 62 52", dot(48, 86)],
   "ঢ-এ শূন্য ঢ়", "ṛha", "আষাঢ়", "Ashadh (month)", "🌧️", "ঢ়"),
 g(Y, ["M16 22 L74 22", "M66 22 L66 75", "M48 30 L28 30 L28 46 L50 46", "M28 52 L66 76", dot(38, 84)],
   "অন্তঃস্থ য়", "ya", "ময়ূর", "peacock", "🦚", "য়"),
 g("ৎ", ["M64 32 Q50 24 40 34 Q38 48 56 50 Q66 54 62 66 L62 76"], "খণ্ড ত", "khanda ta", "উৎসব", "festival", "🎉", "ৎ"),
 g("ং", ["M50 26 A8 8 0 1 0 50 42 A8 8 0 1 0 50 26", "M38 52 L58 76"], "অনুস্বার", "anusvara (ng)", "রং", "colour", "🎨", "ং"),
 g("ঃ", ["M50 26 A8 8 0 1 0 50 42 A8 8 0 1 0 50 26", "M50 56 A8 8 0 1 0 50 72 A8 8 0 1 0 50 56"],
   "বিসর্গ", "visarga (h)", "দুঃখ", "sorrow", "😢", "ঃ"),
 g("ঁ", ["M32 46 Q50 72 68 46", dot(50, 32, 3.5)], "চন্দ্রবিন্দু", "chandrabindu", "চাঁদ", "moon", "🌙", "ঁ"),
]

# ---------------- Bengali digits ----------------
BN_D = [
 g("০", ["M50 36 A16 16 0 1 0 50 68 A16 16 0 1 0 50 36"], "শূন্য", "zero (0)", "শূন্য", "zero", "0️⃣", "শূন্য"),
 g("১", ["M46 28 Q32 44 36 60 Q42 76 60 70 Q68 58 54 52"], "এক", "one (1)", "এক", "one", "1️⃣", "এক"),
 g("২", ["M38 30 Q62 26 62 42 Q62 54 38 54 L66 76"], "দুই", "two (2)", "দুই", "two", "2️⃣", "দুই"),
 g("৩", ["M34 32 L32 50 Q32 76 52 76 Q68 76 68 56 Q68 40 54 42 Q46 46 50 54"], "তিন", "three (3)", "তিন", "three", "3️⃣", "তিন"),
 g("৪", ["M50 52 Q32 48 32 36 Q34 24 50 24 Q66 24 66 36 Q66 48 50 52 Q30 56 30 68 Q30 78 50 78 Q70 78 70 66 Q70 56 50 52"],
   "চার", "four (4)", "চার", "four", "4️⃣", "চার"),
 g("৫", ["M66 28 Q40 30 36 52 Q36 76 66 76 L70 76", "M64 40 Q50 44 54 54 Q58 60 70 58"], "পাঁচ", "five (5)", "পাঁচ", "five", "5️⃣", "পাঁচ"),
 g("৬", ["M32 28 L46 30 Q58 36 50 46 Q28 44 28 62 Q30 78 52 78 Q72 78 70 58 Q66 48 52 46"], "ছয়", "six (6)", "ছয়", "six", "6️⃣", "ছয়"),
 g("৭", ["M50 30 Q40 24 32 32 Q24 44 40 46 Q52 46 52 34 L52 66 Q52 76 64 76 L70 76"], "সাত", "seven (7)", "সাত", "seven", "7️⃣", "সাত"),
 g("৮", ["M30 28 L44 28 Q54 30 56 44 L58 46 Q76 42 78 36", "M58 46 Q30 46 30 62 Q30 78 50 78 Q68 78 68 60 Q66 46 58 46"],
   "আট", "eight (8)", "আট", "eight", "8️⃣", "আট"),
 g("৯", ["M30 28 Q52 24 56 40 Q56 50 44 52 Q28 52 28 66 Q30 78 46 78 Q66 78 68 58 L68 76"], "নয়", "nine (9)", "নয়", "nine", "9️⃣", "নয়"),
]

# ---------------- English ----------------
EN_WORDS = dict(A=("Apple","🍎"),B=("Ball","⚽"),C=("Cat","🐱"),D=("Dog","🐶"),E=("Elephant","🐘"),F=("Fish","🐟"),
 G=("Goat","🐐"),H=("Hat","🎩"),I=("Ice cream","🍦"),J=("Jug","🏺"),K=("Kite","🪁"),L=("Lion","🦁"),M=("Mango","🥭"),
 N=("Nest","🪺"),O=("Orange","🍊"),P=("Pen","🖊️"),Q=("Queen","👑"),R=("Rabbit","🐰"),S=("Sun","☀️"),T=("Tiger","🐯"),
 U=("Umbrella","☂️"),V=("Van","🚐"),W=("Watch","⌚"),X=("X-ray","🩻"),Y=("Yo-yo","🪀"),Z=("Zebra","🦓"))
EN_U = {
 'A': ["M30 78 L50 22 L70 78", "M38 60 L62 60"],
 'B': ["M34 22 L34 78", "M34 22 L54 22 Q68 22 68 36 Q68 50 54 50 L34 50", "M54 50 Q70 50 70 64 Q70 78 54 78 L34 78"],
 'C': ["M70 32 Q60 20 46 22 Q28 24 28 50 Q28 76 46 78 Q60 80 70 68"],
 'D': ["M34 22 L34 78", "M34 22 L48 22 Q72 22 72 50 Q72 78 48 78 L34 78"],
 'E': ["M68 22 L34 22 L34 78 L68 78", "M34 50 L60 50"],
 'F': ["M68 22 L34 22 L34 78", "M34 50 L60 50"],
 'G': ["M70 32 Q60 20 46 22 Q28 24 28 50 Q28 76 46 78 Q66 80 70 62 L70 54 L52 54"],
 'H': ["M32 22 L32 78", "M68 22 L68 78", "M32 50 L68 50"],
 'I': ["M38 22 L62 22", "M50 22 L50 78", "M38 78 L62 78"],
 'J': ["M62 22 L62 64 Q62 78 50 78 Q36 78 36 66"],
 'K': ["M34 22 L34 78", "M66 22 L34 54", "M44 46 L68 78"],
 'L': ["M34 22 L34 78 L68 78"],
 'M': ["M30 78 L30 22 L50 56 L70 22 L70 78"],
 'N': ["M32 78 L32 22 L68 78 L68 22"],
 'O': ["M50 22 Q28 22 28 50 Q28 78 50 78 Q72 78 72 50 Q72 22 50 22"],
 'P': ["M34 78 L34 22", "M34 22 L54 22 Q70 22 70 38 Q70 54 54 54 L34 54"],
 'Q': ["M50 22 Q28 22 28 50 Q28 78 50 78 Q72 78 72 50 Q72 22 50 22", "M58 64 L72 80"],
 'R': ["M34 78 L34 22", "M34 22 L54 22 Q70 22 70 38 Q70 54 54 54 L34 54", "M52 54 L70 78"],
 'S': ["M68 30 Q60 20 48 22 Q32 24 32 36 Q32 48 50 50 Q68 52 68 66 Q68 80 48 78 Q36 78 30 70"],
 'T': ["M30 22 L70 22", "M50 22 L50 78"],
 'U': ["M32 22 L32 60 Q32 78 50 78 Q68 78 68 60 L68 22"],
 'V': ["M30 22 L50 78 L70 22"],
 'W': ["M26 22 L38 78 L50 36 L62 78 L74 22"],
 'X': ["M32 22 L68 78", "M68 22 L32 78"],
 'Y': ["M30 22 L50 50 L70 22", "M50 50 L50 78"],
 'Z': ["M32 22 L68 22 L32 78 L68 78"],
}
EN_L = {
 'a': ["M64 52 Q60 44 48 44 Q32 44 32 61 Q32 78 48 78 Q62 78 64 66", "M64 44 L64 78"],
 'b': ["M36 22 L36 78", "M36 52 Q40 44 50 44 Q66 44 66 61 Q66 78 50 78 Q40 78 36 70"],
 'c': ["M66 52 Q60 44 50 44 Q34 44 34 61 Q34 78 50 78 Q60 78 66 70"],
 'd': ["M64 22 L64 78", "M64 52 Q60 44 50 44 Q34 44 34 61 Q34 78 50 78 Q60 78 64 70"],
 'e': ["M34 60 L66 60 Q66 44 50 44 Q34 44 34 61 Q34 78 50 78 Q60 78 66 70"],
 'f': ["M62 26 Q50 20 48 34 L48 78", "M36 46 L60 46"],
 'g': ["M64 52 Q60 44 50 44 Q34 44 34 61 Q34 78 50 78 Q60 78 64 70", "M64 44 L64 84 Q64 96 50 96 Q40 96 36 90"],
 'h': ["M36 22 L36 78", "M36 52 Q42 44 52 44 Q64 44 64 56 L64 78"],
 'i': ["M50 44 L50 78", dot(50, 30, 2.6)],
 'j': ["M56 44 L56 84 Q56 96 44 96 Q36 96 34 90", dot(56, 30, 2.6)],
 'k': ["M36 22 L36 78", "M60 44 L36 64", "M44 58 L62 78"],
 'l': ["M50 22 L50 78"],
 'm': ["M30 78 L30 44", "M30 52 Q34 44 42 44 Q50 44 50 54 L50 78", "M50 52 Q54 44 62 44 Q70 44 70 54 L70 78"],
 'n': ["M36 78 L36 44", "M36 52 Q42 44 52 44 Q64 44 64 56 L64 78"],
 'o': ["M50 44 Q34 44 34 61 Q34 78 50 78 Q66 78 66 61 Q66 44 50 44"],
 'p': ["M36 44 L36 96", "M36 52 Q40 44 50 44 Q66 44 66 61 Q66 78 50 78 Q40 78 36 70"],
 'q': ["M64 52 Q60 44 50 44 Q34 44 34 61 Q34 78 50 78 Q60 78 64 70", "M64 44 L64 96"],
 'r': ["M40 78 L40 44", "M40 54 Q46 44 60 46"],
 's': ["M62 50 Q58 44 50 44 Q38 44 38 52 Q38 60 50 61 Q62 62 62 70 Q62 78 50 78 Q40 78 36 72"],
 't': ["M46 28 L46 70 Q46 78 54 78 L60 78", "M36 46 L58 46"],
 'u': ["M36 44 L36 68 Q36 78 48 78 Q60 78 64 68", "M64 44 L64 78"],
 'v': ["M34 44 L50 78 L66 44"],
 'w': ["M28 44 L38 78 L50 52 L62 78 L72 44"],
 'x': ["M36 44 L64 78", "M64 44 L36 78"],
 'y': ["M36 44 L50 76", "M66 44 L48 88 Q44 96 36 94"],
 'z': ["M36 44 L64 44 L36 78 L64 78"],
}
EN_D = {
 '0': ["M50 22 Q32 22 32 50 Q32 78 50 78 Q68 78 68 50 Q68 22 50 22"],
 '1': ["M40 32 L52 22 L52 78"],
 '2': ["M34 34 Q36 20 50 22 Q66 24 64 38 Q62 50 34 78 L68 78"],
 '3': ["M34 28 Q46 18 60 24 Q70 32 58 44 L50 46 L58 48 Q72 54 66 68 Q58 82 36 72"],
 '4': ["M58 22 L30 60 L70 60", "M58 22 L58 78"],
 '5': ["M66 22 L36 22 L34 48 Q50 40 62 48 Q72 60 60 74 Q48 82 34 70"],
 '6': ["M62 24 Q40 34 36 58 Q36 78 50 78 Q66 78 66 62 Q66 48 50 48 Q38 50 36 60"],
 '7': ["M32 22 L68 22 L46 78"],
 '8': ["M50 48 Q34 44 34 34 Q36 22 50 22 Q64 22 66 34 Q66 44 50 48 Q32 52 32 64 Q32 78 50 78 Q68 78 68 64 Q68 52 50 48"],
 '9': ["M64 42 Q62 22 48 22 Q34 22 34 36 Q34 50 48 50 Q62 50 64 42 L64 56 Q62 78 36 76"],
}
EN_NUM_WORDS = ["zero","one","two","three","four","five","six","seven","eight","nine"]
EN_NUM_BN = ["শূন্য","এক","দুই","তিন","চার","পাঁচ","ছয়","সাত","আট","নয়"]

def en_entries():
    up, lo, dg = [], [], []
    for ch, strokes in EN_U.items():
        w, e = EN_WORDS[ch]
        up.append(g(ch, strokes, f"বড় হাতের {ch}", f"Capital {ch}", w, w, e, ch))
    for ch, strokes in EN_L.items():
        w, e = EN_WORDS[ch.upper()]
        lo.append(g(ch, strokes, f"ছোট হাতের {ch}", f"Small {ch}", w.lower(), w, e, ch))
    for ch, strokes in EN_D.items():
        i = int(ch)
        dg.append(g(ch, strokes, EN_NUM_BN[i], f"{EN_NUM_WORDS[i]} ({ch})", EN_NUM_BN[i], EN_NUM_WORDS[i], f"{ch}️⃣", EN_NUM_WORDS[i]))
    return up, lo, dg

# ---------------- hints: derived from geometry ----------------
_num = r'-?\d+(?:\.\d+)?'
def endpoints(d):
    nums = [float(x) for x in re.findall(_num, d)]
    toks = re.findall(r'[MLQCA]|' + _num, d)
    # first point after M, last pair
    pts = []
    i = 0
    cmd = None
    while i < len(toks):
        t = toks[i]
        if t in 'MLQCA':
            cmd = t; i += 1; continue
        if cmd == 'A':
            # rx ry rot large sweep x y
            pts.append((float(toks[i+5]), float(toks[i+6]))); i += 7; continue
        pts.append((float(t), float(toks[i+1]))); i += 2
    return pts[0], pts[-1], pts

def chord_vs_len(pts):
    L = sum(math.dist(pts[k], pts[k+1]) for k in range(len(pts)-1))
    return math.dist(pts[0], pts[-1]), L

def hint_for(d):
    (x0, y0), (x1, y1), pts = endpoints(d)
    chord, L = chord_vs_len(pts)
    dx, dy = x1 - x0, y1 - y0
    if chord < 6 and L > 20:
        return ("গোল করে ঘুরিয়ে আঁক", "Go around in a circle")
    curvy = ('Q' in d or 'C' in d or 'A' in d) and L > chord * 1.25
    if abs(dx) > abs(dy) * 1.6:
        base = ("বাম থেকে ডানে", "left to right") if dx > 0 else ("ডান থেকে বামে", "right to left")
    elif abs(dy) > abs(dx) * 1.6:
        base = ("উপর থেকে নিচে", "top to bottom") if dy > 0 else ("নিচ থেকে উপরে", "bottom to top")
    else:
        v = "নিচে" if dy > 0 else "উপরে"; h = "ডানে" if dx > 0 else "বামে"
        ev = "down" if dy > 0 else "up"; eh = "right" if dx > 0 else "left"
        base = (f"বাঁকা করে {v} {h}", f"slant {ev}-{eh}")
    if curvy:
        return (base[0] + " ঘুরিয়ে আঁক", "Curve " + base[1])
    return (base[0] + " আঁক", "Draw " + base[1])

def pack(entries, cat_id):
    out = []
    for i, e in enumerate(entries):
        strokes = []
        for d in e['strokes']:
            hb, he = hint_for(d)
            strokes.append(dict(d=d, hint_bn=hb, hint_en=he))
        out.append(dict(id=f"{cat_id}_{i:02d}", category=cat_id, char=e['char'], strokes=strokes,
                        name_bn=e['name_bn'], name_en=e['name_en'], word_bn=e['word_bn'], word_en=e['word_en'],
                        emoji=e['emoji'], sound=e['sound']))
    return out

def build():
    up, lo, dg = en_entries()
    pre = []
    for i, (key, strokes, hb, he) in enumerate(PRE):
        pre.append(dict(id=f"pre_{i:02d}", category="pre", char="", strokes=[dict(d=strokes[0], hint_bn=hb, hint_en=he)],
                        name_bn=hb, name_en=he, word_bn=None, word_en=None, emoji=None, sound=None, key=key))
    cats = [
        dict(id="pre", title_bn="হাত ঘুরাই", title_en="Pre-writing strokes", subtitle_bn="রেখা ও বাঁক আঁকি", subtitle_en="Lines, slants & curves", emoji="✏️", color="#F97316", script="pre"),
        dict(id="bn_vowel", title_bn="স্বরবর্ণ", title_en="Bengali vowels", subtitle_bn="অ আ ই ঈ …", subtitle_en="অ আ ই ঈ …", emoji="🌼", color="#E11D48", script="bn"),
        dict(id="bn_cons", title_bn="ব্যঞ্জনবর্ণ", title_en="Bengali consonants", subtitle_bn="ক খ গ ঘ …", subtitle_en="ক খ গ ঘ …", emoji="🐘", color="#0D9488", script="bn"),
        dict(id="bn_digit", title_bn="বাংলা সংখ্যা", title_en="Bengali numbers", subtitle_bn="০ ১ ২ ৩ …", subtitle_en="০ ১ ২ ৩ …", emoji="🔢", color="#7C3AED", script="bn"),
        dict(id="en_upper", title_bn="ইংরেজি বড় হাতের অক্ষর", title_en="English capital letters", subtitle_bn="A B C D …", subtitle_en="A B C D …", emoji="🅰️", color="#2563EB", script="en"),
        dict(id="en_lower", title_bn="ইংরেজি ছোট হাতের অক্ষর", title_en="English small letters", subtitle_bn="a b c d …", subtitle_en="a b c d …", emoji="🔡", color="#0891B2", script="en"),
        dict(id="en_digit", title_bn="ইংরেজি সংখ্যা", title_en="English numbers", subtitle_bn="0 1 2 3 …", subtitle_en="0 1 2 3 …", emoji="🔟", color="#CA8A04", script="en"),
    ]
    glyphs = pre + pack(BN_V, "bn_vowel") + pack(BN_C, "bn_cons") + pack(BN_D, "bn_digit") + pack(up, "en_upper") + pack(lo, "en_lower") + pack(dg, "en_digit")
    return dict(version=1, box=100, matra_y=22, baseline_y=78, categories=cats, glyphs=glyphs)

if __name__ == '__main__':
    data = build()
    json.dump(data, open(sys.argv[1], 'w'), ensure_ascii=False, indent=1)
    # overlay file for sheet.js: char -> strokes list
    ov = {gl['char'] or gl['key']: [s['d'] for s in gl['strokes']] for gl in data['glyphs']}
    json.dump(ov, open(sys.argv[2], 'w'), ensure_ascii=False)
    print(len(data['glyphs']), 'glyphs')
