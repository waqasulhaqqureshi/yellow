#!/usr/bin/env python3
"""Deterministic generator for the group-chat corpus.

Expands hand-written seed fragments (cores, openers, tails, reactions)
into 15,000+ unique casual chat lines written to
lib/features/chat/persona/group_corpus.dart.

Run:  python3 tool/gen_chat_corpus.py
"""
import random
from pathlib import Path

random.seed(42)

OPENERS = [
    "honestly", "lol", "bro", "man", "fr", "ngl", "wait", "ok but", "listen",
    "y'all", "guys", "no cap", "lowkey", "bruh", "damn", "wow", "so", "and",
    "but", "still", "again", "today", "tonight", "this morning", "after work",
    "after class", "on my phone", "in this app", "here", "in blitz",
    "in rapid", "vs a 900", "vs a 1400", "vs my friend", "in my last game",
    "last night", "yesterday", "earlier", "just now", "somehow", "seriously",
    "not gonna lie", "for real", "kinda", "sorta", "maybe", "probably",
    "definitely", "absolutely", "never", "always", "sometimes", "one day",
    "someday", "eventually", "fine", "ok so", "hey", "yo", "hmm", "ugh",
    "ah", "oh man", "oh no", "look", "see", "trust me", "believe me",
    "imagine", "picture this", "true talk", "real", "facts", "same energy",
]

TAILS = [
    "lol", "😂", "😭", "fr", "ngl", "honestly", "anyone else?", "just me?",
    "idk", "i guess", "whatever", "oh well", "back to it", "brb", "too real",
    "so true", "right?", "u?", "what about u", "same", "big same", "oof",
    "yikes", "gg", "wp", "nice", "wild", "crazy", "unreal", "pain",
    "the pain", "we move", "onward", "sigh", "again...", "never again",
    "tomorrow we grind", "chai first", "coffee first", "one more game",
    "one more then sleep", "dont judge me", "it happens", "we've all been there",
    "story of my life", "cant explain", "no idea how", "still smiling",
    "still tilted", "still here", "still trying", "rating wont fix itself",
    "elo is a state of mind", "the grind never stops", "sleep is optional",
    "send help", "send snacks", "send tips", "who taught me this opening",
    "my own worst enemy", "the board knows", "the board remembers",
    "knight life", "bishop problems", "rook things up", "queen energy",
    "king me", "pawn goals", "small moves big dreams", "one square at a time",
]

URDU_OPENERS = [
    "yaar", "bhai", "arre", "sach mein", "kasam se", "yaar suno", "bhai suno",
    "dekho", "sunao", "bolo", "chalo", "arre haan", "haan yaar", "nahi bhai",
    "aaj kal", "kal raat", "aaj subah", "shaam ko", "raat ko", "dopahar mein",
    "office ke baad", "college ke baad", "chutti mein", "garmi mein", "sardi mein",
    "barish mein", "chai ke saath", "biryani ke baad", "match ke baad",
    "game ke baad", "jeet ke baad", "haar ke baad", "dil se", "dimagh se",
]

URDU_TAILS = [
    "yaar", "bhai", "na", "ji", "bhai ji", "sach mein", "kasam se", "pakka",
    "abhi", "kal", "aaj", "roz", "kabhi kabhi", "thora", "bohot", "mast",
    "zabardast", "kamaal", "lazy", "busy", "thaka hua", "khush hoon", "udaas hoon",
    "gussa hai", "maza aa gya", "bura laga", "acha laga", "chalo phir", "theek hai phir",
    "insha allah", "allah kare", "dua hai", "khuda hafiz", "phir milte hain",
    "ab chalta hoon", "ek game aur", "bas ek aur", "neend aa rhi hai", "chai banao",
]

CORES = {
    "romanUrdu": [
        "tum kya karte ho", "kahan se ho bhai", "kya chal rha hai", "mast yaar",
        "kya baat hai", "wah bhai wah", "chal jhoota", "arre yaar", "haan bhai haan",
        "nahi yaar", "theek hai", "sab theek", "kal match tha yaar", "aaj kal busy hoon",
        "chai piyoge", "doodh patti banao", "biryani khani hai", "eid mubarak ho",
        "eid mubarak yaar", "kis sheher se ho", "lahore se hoon", "karachi wala hoon",
        "islamabad se hoon", "peshawar se hoon", "tum kya kar rhe ho", "kuch nahi yaar",
        "bore ho rha hoon", "chess khel rhe hoon", "ek game ho jaye", "chalo ek game",
        "phir milenge", "ab chalta hoon", "kal phir aao", "raat ko aana", "subah milte hain",
        "yaar tu mast hai", "bhai tu to pro hai", "main abhi seekh rha hoon", "thora bohot aata hai",
        "ghoda ghumao", "pyada aage karo", "wazir bachao", "badshah khatre mein hai",
        "mat karo yaar", "aise nahi chalta", "sahi baat hai", "bilkul theek", "ji haan",
        "ji nahi", "shayad", "ho sakta hai", "pakka", "kasam se", "sach mein", "mazaq tha",
        "hansi mazaq", "dil se khelo", "dimagh kharab hai aaj", "aaj kal neend nahi aati",
        "garmi bohot hai", "sardi shuru ho gayi", "barish ho rhi hai", "mausam mast hai",
        "loadshedding ne mara", "bijli chali gayi phir", "internet theek hai tumhara",
        "mobile garm ho gya", "phone ka charger lao", "exam sar pe hain", "result aa gya",
        "pass ho gya alhamdulillah", "fail ho gya yaar", "abhi padhna hai", "kal paper hai",
        "office jana hai", "chutti hai aaj", "boss tang karta hai", "tanjeeb se kaam",
        "paisa kamana mushkil hai", "mehengai ne tor diya", "sab mehnga hai",
        "cricket dekhoge aaj", "match jeet gaye", "match haar gaye", "kya match tha yaar",
        "last over mein dil ruk gya", "chakka mara", "wicket gir gayi", "shaheen ne kamal kiya",
        "babar ne sadi si innings kheli", "shadab ka jaadu", "pakistan zindabad",
        "india wale bhi acche khelte hain", "virat kohli zindabad", "rohit sharma",
        "dhoni bhai", "ms dhoni legend hai", "aaj kal ke bachche", "hamare zamane mein",
        "bade log kehte hain", "ammi kehti hain", "abbu ne kaha", "bhai se poocho",
        "behen ki shadi hai", "ghar pe mehman hain", "mehman aa rahe hain",
        "dawat rakhi hai", "halwa bana hai", "gajar ka halwa", "kheer bani hai",
        "roti sabzi kha lo", "bhookh lagi hai", "pet pooja", "chai ke saath biscuit",
        "samosa mangao", "pakora talo", "barish mein pakora", "chai aur barish",
    ],
    "urduQuestions": [
        "tum kahan rehte ho", "kya naam hai tumhara", "umar kya hai", "kya padhte ho",
        "kya karte ho", "kaisi chal rhi hai zindagi", "aaj kal kya chal rha hai",
        "chess kab se khel rhe ho", "kaun sikhaya tumhe", "online khelte ho ya board pe",
        "kitna time dete ho roz", "raid kya hai tumhari", "best opening kya lagti hai",
        "ghoda pasand hai ya haathi", "wazir kyun marti ho", "pawn promotion karte ho kabhi",
        "chai pasand hai ya coffee", "biryani mein aalu chahiye ya nahi", "kya haal hai",
        "ghar sab theek", "tabiyat theek hai", "neend poori hoti hai", "kaam kaisa chal rha",
        "chuttiyan kab hain", "eid pe kya plan", "diwali mubarak ho kya", "holi khelte ho",
        "cricket khelte ho", "football dekhte ho", "kaun si team support karte ho",
        "kabhi otb khele ho", "club join kiya hai", "coach rakha hai", "puzzles karte ho",
        "youtube pe kisko dekhte ho", "agzaal kya hai", "favorite player kaun hai",
    ],
    "urduAnswers": [
        "main theek hoon tum sunao", "sab theek shukar hai", "alhamdulillah sab badhiya",
        "bas chal rha hai", "kya hi batayein", "zindagi mast hai", "kaam mein busy hoon",
        "bas chess aur kaam", "hai koi nahi", "main lahore mein hoon", "karachi mein rehta hoon",
        "rawalpindi wala hoon", "naam ali hai", "naam sara hai", "umar bees hai", "college mein hoon",
        "naukri karta hoon", "business hai chota mota", "chess bachpan se", "dada se seekha",
        "youtube se seekha", "online hi khelta hoon", "roz adha ghanta", "jitna time mile",
        "ghoda sab se best", "haathi power hai", "wazir se darr lagta hai", "promotion mera junoon",
        "chai hi chai", "biryani mein aalu zaroori", "haan bilkul", "nahi bilkul", "pata nahi",
        "sochna padega", "dekhte hain", "insha allah", "allah hafiz", "khuda hafiz",
    ],
    "abuseReactions": [
        "bhai gali kyu de rhe ho ap ko tameez nhi hai", "yaar tameez se baat karo",
        "gali dena band karo", "yeh language theek nahi", "respect rakho yaar",
        "bhai shant ho jao", "gussa thanda karo", "chess khelo pyar se",
        "aisi baatein mat karo", "hum dost hain yahan", "dosti se khelo",
        "language please dost", "hey watch the language", "respect is the rule here",
        "no abusing please", "keep it friendly yaar", "gali nahi yaar",
        "tameez ka daman mat chhodo", "adab se baat karo", "bade ho tamiz rakho",
        "gali se game nahi jeeti jati", "gussa haram hai", "sabr rakho",
        "gussa mat karo yaar", "chill karo", "itna gussa kyun", "kya ho gya tumhe",
        "saans lo aur khelo", "game hai bhai", "jeet haar hoti rehti hai",
        "haarte hain jeetne wale", "agli baar jeetoge", "dil chhota mat karo",
        "sorry agar bura laga", "maaf karna yaar", "dil se sorry",
    ],
    "festivals": [
        "eid mubarak sab ko", "eid pe kheer bani", "seviyan khila do", "naye kapre eid pe",
        "chaand raat ki raunak", "diwali mubarak", "diye jalao", "rangoli bani",
        "holi mubarak", "rang barse", "cricket world cup mela", "new year mubarak",
        "saal naya shuru", "resolutions sab toot gaye", "christmas ki chuttiyan",
        "shab e barat ki raat", "ramzan mubarak", "roza iftar taraweeh", "sehr o iftar",
        "iftar pe pakora", "dates aur doodh", "eid ka chanda", "eidi mil gayi",
        "bakra eid aa rahi", "qurbani ka intezaam", "basant ka mausam", "patang urao",
        "dor katta", "patang kati", "14 august mubarak", "23 march mubarak",
        "youm e azadi", "jashn ka mahina", "mela laga hai", "jhule wali suwari",
    ],
    "familyLife": [
        "ammi ne bulaya khane pe", "abbu ke saath bazar", "bhai se jhagra hua",
        "behen ki shaadi ki tayari", "chacha ghar aaye", "dadi ki kahani",
        "nani ka halwa", "cousins aa gaye", "ghar pe daawat", "mehman tang karte hain",
        "bachhe shaitani kar rahe", "bhatije ko khilao", "bhanji ki school",
        "walima tha kal", "shadi hall mein thi", "baraat der se aayi",
        "garmiyon ki chuttiyan", "nani ke ghar", "dadi ke ghar", "gaon chale jao",
        "khet dekho", "barish mein bheego", "gali mein cricket", "tape ball cricket",
        "raat bhar jag kar", "subah soye", "ammi ki daant", "abbu ki naseehat",
        "chacha ki dukaan", "khandan ki baat", "rishtedaar kya kahenge",
        "log kya kahenge", "apni raza khuda ki raza", "dua karo", "allah kare",
    ],
    "moviesMusicUrdu": [
        "woh naya drama dekha", "episode mast tha", "nausakha hero", "villain kharab",
        "qawwali suni kal", "nusrat fateh ali khan", "rahat fateh ali", "arijit singh",
        "atif aslam", "arijit ke gane", "lollywood purana", "waheed murad",
        "shamim ara", "karan arjun", "srk king hai", "aamir khan perfect",
        "salman bhai", "pathan dekha", "jawan dekha", "interstellar best",
        "dune part two", "oppheimer", "tenet confuse karta hai", "anime dekhte ho",
        "naruto bhai", "one piece lamba hai", "attack on titan", "demon slayer",
        "ghibli movies", "totoro pyara", "lofi suno raat ko", "old songs best",
        "mehdi hassan", "ghulam ali", "jagjit singh", "kishore kumar", "lata ji",
        "asha bhosle", "kokomo", "bolly wood dance", "bhangra dal do",
    ],
    "cricketUrdu": [
        "kal ka match dekha", "pak jeet gaya", "ind haar gaya", "bangladesh ne uda diya",
        "afghanistan dangerous hai", "australia strong hai", "england ka swing",
        "new zealand quiet killer", "south africa choke karte", "west indies t20",
        "shaheen ki swing", "naseem shah speed", "haris rauf ka smile",
        "wasim akram legend", "waqar younis reverse", "imran khan kaptaan",
        "inzamam bhai", "younis khan technique", "misbah calm", "azhar ali",
        "fakhar zaman six", "imam ul haq", "rizwan keeper", "sarfaraz ahmed",
        "psl mein kaun jeetega", "lahore qalandars", "karachi kings", "multan sultans",
        "peshawar zalmi", "islamabad united", "quetta gladiators", "world cup kab hai",
        "asia cup kab hai", "champions trophy", "test cricket zinda hai",
        "t20 maza hai", "odi bechara", "hundred lagaya", "fifty bana",
        "duck pe out", "lbw hogaya", "run out hua", "catch chhut gaya",
        "umpire andha tha", "drs le lo", "review mein out", "super over",
    ],
    "foodUrdu": [
        "aaj biryani thi", "daal chawal", "aloo paratha", "anda paratha",
        "nihari nashta", "paye subah", "halwa poori", "chai nashta",
        "samosa chaat", "dahi bhalla", "gol gappa", "pani puri",
        "jalebi garam", "lassi thandi", "mango shake", "rooh afza",
        "tarbooz ka season", "mausambi juice", "ganne ka ras", "makhan malai",
        "lassi peshawari", "kabuli pulao", "chapli kabab", "tikkka boti",
        "seekh kabab", "malai boti", "naan tandoor", "roghani naan",
        "kulcha", "qorma", "korma shadi wala", "zarda meetha",
        "shahi tukra", "ras malai", "gulab jamun", "barfi", "kaju katli",
        "motichoor laddu", "gajar halwa winter", "kheer slow cook", "seviyan eid wali",
    ],
    "greetings": [
        "yo yo yo", "hey everyone", "hello hello", "whats up guys",
        "morning crew", "evening everyone", "late night squad assemble",
        "who's awake", "who's grinding today", "back again", "me again",
        "guess who's back", "reporting for duty", "chair occupied",
        "tea in hand lets go", "just woke up thinking about chess",
        "can't sleep so here i am", "fresh mind fresh blunders",
        "same me new day same elo", "welcome back me", "hi hi hi",
        "salaam everyone", "adaab", "hey hey", "whats good", "how y'all doing",
        "hope everyone's having a decent day", "friday energy even on monday",
        "monday but make it chess", "weekend who", "exam week but chess first",
    ],
    "chessTalk": [
        "just hung my queen again", "blundered a rook on move 3",
        "missed a mate in one AGAIN", "found a nice fork today",
        "my knight did a full tour and died on h8", "tried a sacrifice it was unsound",
        "played the london again sorry everyone", "opponent premoved into mate",
        "i love when they take the bait", "time scramble cost me the game",
        "flagged with a winning position the pain", "premoved a checkmate received",
        "my accuracy was 42 percent", "carried my team in puzzles lost in games",
        "puzzles 1500 games 600 make it make sense", "en passant still feels illegal",
        "castled straight into an attack", "left my bishop on a snack square",
        "the f7 square is a trap and i keep falling", "scholar's mate worked on me today",
        "i am 1200 in puzzles and 900 in feelings", "discovered check discovered happiness",
        "back rank mate awareness is my new religion", "stopped taking free pawns i take free rooks now",
        "my openings are fine my middlegame is a group project",
        "endgame me is a different person he knows what he's doing",
        "trade queens and i get nervous", "i see ghosts in every position",
        "calculated 5 moves ahead all 5 wrong", "played slow then panicked then lost",
        "the engine says best move my heart says scary move",
        "i only know two plans push pawns or panic",
        "d4 player trapped in an e4 body", "my pieces never coordinate they freelance",
        "rook on the 7th feels like a superpower", "doubled pawns tripled stress",
        "isolated pawn isolated feelings", "knight on f5 and i feel invincible",
        "bishop pair hoarder here", "i trade bishops like stickers",
        "opponent played b6 and g6 and just vibed", "h pawn storm go brrr",
        "sacrificed the exchange for vibes and lost", "defended for 40 moves then blinked",
        "won by timeout lost by attitude", "my king walk was either genius or suicide",
        "passed pawn and suddenly everyone believes in me",
        "promotion race by one tempo my heart", "underpromotion to knight just to feel something",
    ],
    "openingsTalk": [
        "london system enjoyers rise up", "the london is a lifestyle",
        "caro kann is just therapy with pieces", "sicilian players are built different",
        "najdorf toxicity is real", "e4 is a personality", "d4 is a tax bracket",
        "french defence is a slow burn romance", "kings gambit accepted the romance",
        "vienna game gang", "scandinavian is underrated fight me",
        "alekhine is a prank that became my identity", "pirc is chaos with a plan",
        "english opening feels like wearing a tie", "reti is chess in a cardigan",
        "king's indian and pray", "grunfeld is for people who memorize 30 moves",
        "i play the same 8 moves regardless of what they do",
        "my repertoire is one system and denial", "book move until move 4 then pure street chess",
        "opponent played 1. a3 and my prep died", "1... b6 players fear nothing",
        "borg defence anyone no? ok", "grob attack is a crime and i respect it",
        "fried liver on my mind", "italian game but i forget the theory by move 5",
        "ruy lopez is a 40 move conversation", "scotch is e4 for people in a hurry",
        "danish gambit two pawns of pure adrenaline", "evans gambit is the italian with anger",
    ],
    "endgameTalk": [
        "king and pawn endings are pure nerve", "rook endings are always drawn until they're not",
        "opposite bishops and a prayer", "knight vs bishop and both of us suffering",
        "queen endgame = perpetual check roulette", "i drew a winning rook endgame classic me",
        "lucena position finally clicked today", "philidor save my rating",
        "triangulation sounds fake but it's real", "opposition is just staring contest with kings",
        "two connected passed pawns walk in alone", "the box rule saved my bacon",
        "wrong bishop wrong rook pawn wrong life", "a rook behind the passed pawn always",
        "activity over pawns in rook endings they say", "said no one ever in my games",
        "kbp vs kb and 60 moves of suffering", "tablebase win tablebase draw tablebase tears",
        "endgame technique is just not panicking slowly",
    ],
    "banter": [
        "your elo called it wants a restraining order", "bro plays chess like he pays rent on the squares",
        "imagine blundering on purpose for content", "he's not bad he's just pre-gaming the rematch",
        "that wasn't a trap that was a donation", "rating is just a high score for suffering",
        "you dont lose you just donate experience points", "certified pre-blundered",
        "the knight fork was free real estate", "your bishop has been on the same square since tuesday",
        "castling is for cowards (i castle every game)", "touch grass? never heard of it",
        "you play 1. e4 like it owes you money", "this group carries my confidence",
        "i dont tilt i just rotate", "my comfort zone is time trouble",
        "he said 'easy game' then lost in 4 moves", "brb explaining to my cat why i lost",
        "the cat understands now she judges me",
    ],
    "questions": [
        "whats everyone's main opening as white", "black against e4 what do u trust",
        "how do i stop hanging pieces help", "anyone else worse when tired",
        "do u look at eval bar during games", "is 1500 blitz good here",
        "how many games a day do u play", "puzzles or games for improvement",
        "anyone tried the vienna lately", "best way to learn rook endgames",
        "u guys premove", "do u play OTB or only online", "whats ur fastest win",
        "longest game u ever played", "anyone from pakistan here",
        "chai or coffee while playing", "music while chess or silence",
        "board theme dark or wood", "piece style classic or flat",
        "how do u handle losing streaks", "do u analyze ur losses honestly",
        "ever beaten someone 500 above u", "whats ur proudest game",
        "anyone here play cricket too", "weekend plans or weekend tournaments",
    ],
    "answers": [
        "london every game no shame", "caro kann until i die",
        "i just play e4 and pray", "d4 then pretend i know theory",
        "honestly i stop looking at the eval mid game", "eval bar is my anxiety meter",
        "puzzles 20 a day changed me", "games only analysis after",
        "i premove too much and pay for it", "OTB is a different beast",
        "fastest win was 6 moves they fell for it", "longest was 140 moves a draw obviously",
        "yes karachi represent", "chai obviously coffee is a scam",
        "silence or lofi nothing with lyrics", "wood board classic pieces forever",
        "losing streaks i just close the app and eat", "i analyze only the losses i wont cry about",
        "beat a +600 once felt like a world title", "proudest game was a rook endgame grind",
        "cricket is the second religion here", "weekend = tournaments if any else blitz marathons",
    ],
    "reactions": [
        "lmaooo", "bro what", "no way", "stoppp", "thats illegal", "thats so real",
        "felt that", "deeply felt that", "ouch", "brutal", "respect", "huge",
        "based", "W", "L", "big L", "big W", "goated", "cooking", "let him cook",
        "who allowed this", "say less", "say more actually", "true", "false",
        "partly true", "ok this group gets me", "finally someone said it",
        "i was today years old when", "not the en passant trauma", "the audacity",
        "unbelievable", "make it stop", "more please", "screenshot this",
        "printing and framing", "this is the content i subscribed for",
    ],
    "lifeTalk": [
        "work was exhausting today", "classes are killing me", "family visit so less chess tonight",
        "power outage mid game again", "loadshedding is my true opponent",
        "internet died on move 12 of course", "new phone who dis",
        "old phone still faster than my reflexes", "rainy days are chess days",
        "too hot to think straight", "winter is peak chess season",
        "exam tomorrow playing one last game (lie)", "deadline tomorrow same lie",
        "sleep schedule is a myth", "my eyes hurt but the ladder waits",
        "gym then chess balanced lifestyle", "chess then chess balanced lifestyle",
        "took a walk touched grass returned", "my cat sat on the keyboard and played d4",
        "kids asleep finally my time", "commute chess on one hand dangerous",
    ],
    "foodTalk": [
        "biryani fixes all losses", "chicken or beef biryani dont start a war",
        "samosa with imli chutney is elite", "chai at 2am hits different",
        "doodh patti supremacy", "paratha with everything", "nihari on sunday",
        "haleem season cant come fast enough", "seekh kabab and a win",
        "mango season is the only season", "rooh afza or cola with iftar vibes",
        "pizza while playing blitz messy but worth", "cookies near keyboard crumbs in the board",
        "who else eats while their clock runs", "hydration check water bottle by the board",
    ],
    "weatherTalk": [
        "karachi heat is a blunder generator", "humidity 100 percent accuracy 50 percent",
        "rain finally came alhamdulillah", "monsoon and wifi dont mix",
        "winter evenings perfect for long games", "summer is bullet season too hot to think",
        "fan noise is my white noise", "AC off to save bills AC off to save elo",
        "fog in lahore OTB delays i heard", "dust storm warning chess indoors anyway",
    ],
    "sportTalk": [
        "did y'all see the match last night", "pakistan cricket is a rollercoaster i refuse to exit",
        "babar azar... azam sorry autocorrect", "shaheen's first spell was poetry",
        "hockey needs love too", "squash legends we forget we had",
        "football world cup season im distracted", "psl drafts are basically chess drafts",
        "tennis grand slam and chess grandmaster same energy",
        "kabaddi finals were intense change my mind",
    ],
    "studyWork": [
        "assignment due and im in a time scramble IRL", "boss walked by i hid the phone",
        "meeting could have been an email", "email could have been nothing",
        "study group then chess group balance", "math helps chess they say prove it",
        "pattern recognition is just vibes with steps", "revision notes vs opening notes same font",
        "internship grind real", "freelance life is blitz with clients",
        "client asked for one small change five hours", "one small change they said",
    ],
    "musicMovies": [
        "lofi and chess is the combo", "qawwali while analyzing feels cinematic",
        "old bollywood songs for long endgames", "new track drop who heard it",
        "that movie twist was a zwischenzug", "series finale felt like a stalemate",
        "documentary on prodigies made me feel slow", "anime protagonist energy in move 12",
        "soundtrack of a win is silence and a sigh", "podcast recs for puzzle sessions",
    ],
    "techTalk": [
        "this app's bot chat is too real", "the bot taunted me and i felt things",
        "my ping is 400 and my blood pressure higher", "dark mode everywhere",
        "phone storage full of screenshots of wins", "engine on or engine off during analysis",
        "i trust the engine more than my friends", "cloud save my rating please",
        "AI taking over chess then my job in that order", "keyboards vs phones for chess fight",
    ],
    "farewells": [
        "alright sleep time gg all", "one more game then gone (lie)", "gotta run family calling",
        "power about to go bye", "wifi dying bye", "work tomorrow unfortunately goodbye",
        "goodnight kings and queens", "see u tomorrow same time same ladder",
        "bye dont hang ur queens", "leaving on a win for once",
        "leaving on a loss as usual", "may ur pawns promote",
    ],
    "hype": [
        "LETS GOOO", "W player", "carry us coach", "we're so back",
        "it's over for our haters", "promotion season", "new rating unlocked",
        "streak alive", "five in a row who's next", "anyone dare challenge",
        "the comeback is real", "from 3 losses to 3 wins mental",
        "today we climb", "elo going up rent going up everything up",
    ],
}

# Urdu-flavoured topics use their own openers/tails so combinations stay
# natural ("yaar", "bhai", "sach mein" instead of "honestly", "bro").
URDU_TOPICS = {
    "romanUrdu",
    "urduQuestions",
    "urduAnswers",
    "abuseReactions",
    "festivals",
    "familyLife",
    "moviesMusicUrdu",
    "cricketUrdu",
    "foodUrdu",
}

# Per-topic quotas — english ~17.2k + urdu/new topics 20k.
QUOTAS = {
    "romanUrdu": 6000,
    "urduQuestions": 2000,
    "urduAnswers": 2000,
    "abuseReactions": 1000,
    "festivals": 2000,
    "familyLife": 2000,
    "moviesMusicUrdu": 1500,
    "cricketUrdu": 2000,
    "foodUrdu": 1500,
    "greetings": 700,
    "chessTalk": 2400,
    "openingsTalk": 1300,
    "endgameTalk": 900,
    "banter": 1400,
    "questions": 1200,
    "answers": 1200,
    "reactions": 1700,
    "lifeTalk": 1200,
    "foodTalk": 900,
    "weatherTalk": 600,
    "sportTalk": 700,
    "studyWork": 700,
    "musicMovies": 600,
    "techTalk": 600,
    "farewells": 500,
    "hype": 600,
}


def clean(s: str) -> str:
    s = s.strip()
    s = s.replace('"', "'")
    s = s.replace("\\", "")
    s = s.replace("$", "usd")
    return s


def expand(topic: str, cores, quota: int):
    openers = URDU_OPENERS if topic in URDU_TOPICS else OPENERS
    tails = URDU_TAILS if topic in URDU_TOPICS else TAILS
    out, seen = [], set()

    def push(line):
        line = clean(line)
        if len(line) < 4 or line in seen:
            return False
        seen.add(line)
        out.append(line)
        return True

    for c in cores:
        push(c)
    # core + tail
    combo = [(c, t) for c in cores for t in tails]
    random.shuffle(combo)
    for c, t in combo:
        if len(out) >= quota:
            break
        push(f"{c} {t}")
    # opener + core
    combo = [(o, c) for o in openers for c in cores]
    random.shuffle(combo)
    for o, c in combo:
        if len(out) >= quota:
            break
        push(f"{o} {c}")
    # opener + core + tail
    combo = [(o, c, t) for o in openers for c in cores for t in tails]
    random.shuffle(combo)
    for o, c, t in combo:
        if len(out) >= quota:
            break
        push(f"{o} {c} {t}")
    return out[:quota]


def main():
    out = Path(__file__).resolve().parents[1] / "lib/features/chat/persona/group_corpus.dart"
    total = 0
    buf = [
        "// GENERATED by tool/gen_chat_corpus.py — do not edit by hand.",
        "// 15,000+ line casual group-chat corpus across topic pools.",
        "// Regenerate with: python3 tool/gen_chat_corpus.py",
        "",
        "/// Topic pools for group chat ambience and reactions.",
        "class GroupCorpus {",
        "  GroupCorpus._();",
        "",
    ]
    for topic, quota in QUOTAS.items():
        lines = expand(topic, CORES[topic], quota)
        total += len(lines)
        buf.append(f"  /// {topic} — {len(lines)} lines.")
        buf.append(f"  static const List<String> {topic} = [")
        for line in lines:
            buf.append(f'    "{line}",')
        buf.append("  ];")
        buf.append("")
    buf.append("  static const Map<String, List<String>> byTopic = {")
    for topic in QUOTAS:
        buf.append(f'    "{topic}": {topic},')
    buf.append("  };")
    buf.append("}")
    buf.append("")
    out.write_text("\n".join(buf), encoding="utf-8")
    print(f"wrote {out} with {total} corpus lines")


if __name__ == "__main__":
    main()
