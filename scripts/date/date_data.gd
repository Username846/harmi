class_name DateData
extends RefCounted
## Venues, per-piece venue preferences, dialogue and scoring for the date
## minigame. Pure data + helpers (no Game access) so it can be unit tested.
##
## Scoring: delta = venue base + preference bonus + REPLY_WEIGHT * (sum of
## reply scores), clamped to MIN_DELTA..MAX_DELTA. Replies score +2 (great),
## +1 (ok) or -1 (bad).

const MIN_DELTA := -10
const MAX_DELTA := 45
const REPLY_WEIGHT := 6
const ROUNDS := 3
## Gloomy pieces (mood below this) adore the ash-scattering cruise.
const GLOOMY_BELOW := 45.0
const GLOOMY_CRUISE_BONUS := 6

const VENUES := [
	{"id": "park", "name": "Picnic in the Park", "price": 0, "base": 4,
		"desc": "A checkered blanket, cucumber sandwiches and a view of the far ranks. Free, and a little cheerful."},
	{"id": "bowling", "name": "Bowling Alley", "price": 6, "base": 9,
		"desc": "Neon, rented shoes, and ten pins that go down far easier than enemy pawns."},
	{"id": "dinner", "name": "Candlelit Dinner", "price": 15, "base": 16,
		"desc": "Le Donjon: a castle keep turned restaurant. One candle, one rose, one waiter who judges your opening."},
	{"id": "cruise", "name": "Sunset Ash-Scattering Cruise", "price": 9, "base": 11,
		"desc": "A rowboat, a sunset and an urn of fallen comrades to scatter. Strangely romantic. Gloomy pieces adore it."},
]

## type -> venue id -> [bonus, what the date says on arrival]
const PREFS := {
	1: {
		"park": [4, "A real picnic? Nobody's ever taken me further than two squares from home!"],
		"bowling": [5, "Ten little pins standing in a row, all waiting to be knocked over... I've never related to anything more. I love it here!"],
		"dinner": [7, "Tablecloths?! For ME? I usually eat standing up in a trench."],
		"cruise": [4, "A boat! I've never been off the board before. Is this what promotion feels like?"],
	},
	2: {
		"park": [8, "Open fields! Fresh grass! If a horse wanders past, I may weep with joy."],
		"bowling": [-3, "The lanes only go straight. I don't trust anything that can't turn a corner."],
		"dinner": [2, "A candlelit table. Very chivalrous. I shall pull out your chair. Two squares back, one to the side."],
		"cruise": [-5, "Horses and boats, historically, do not mix. Please row very, very gently."],
	},
	3: {
		"park": [-2, "So much... sunlight. Is there no shade? No crypt? Not even a modest ossuary?"],
		"bowling": [-5, "The neon is garish and the music is profane. And not one lane runs diagonally."],
		"dinner": [3, "Candlelight and stone walls. Very ecclesiastical. I shall say grace over the bread rolls."],
		"cruise": [10, "Scattering ashes at sunset? You... you actually understand me."],
	},
	4: {
		"park": [-3, "A wide-open lawn with no walls. I feel like a tower somebody forgot to finish."],
		"bowling": [4, "Long, straight lanes! Finally, a sport that moves the way I do."],
		"dinner": [9, "A restaurant inside a castle keep? Battlements AND bread rolls. You know the way to a rook's heart."],
		"cruise": [-4, "I am made of stone. Stone and boats have a long and tragic history."],
	},
	5: {
		"park": [-6, "A blanket? On the GRASS? Honey, this tushy is too cushy for twigs. ...Fine. Fan me."],
		"bowling": [6, "Date night at the alley! Watch me bowl a perfect strike. Then watch me bend down for the next ball. Take your time, baby."],
		"dinner": [6, "Velvet chairs, candles, a single rose. Hold my lip gloss, baby. A queen deserves the best."],
		"cruise": [1, "A sunset cruise? Rock the boat, honey. Gently. I bounce."],
	},
	6: {
		"park": [-4, "We're out in the open. Anyone could check me here. ANYONE. Is that bush looking at me?"],
		"bowling": [-3, "Heavy balls hurled at defenseless pieces standing in a triangle. This is literally my nightmare."],
		"dinner": [6, "A private booth with a wall at my back and the exit in view. I can almost breathe."],
		"cruise": [-10, "A BOAT? Water on every side? There's no square to retreat to! I'm in check! I'm in check from the LAKE!"],
	},
}

const GLOOMY_CRUISE_LINE := "(Gloomy pieces find scattering ash oddly soothing.)"

## Each prompt: {"q": what the date says, "a": [[reply, score, reaction], x3]}
const PROMPTS := {
	1: [
		{"q": "Be honest. Do you think I'm... short? Everyone else on the board is at least a head taller.",
			"a": [
				["You're exactly the right height. And you're the only piece who can grow up to be any other piece.", 2, "...I never thought of it like that. I'm not short. I'm UNDECIDED."],
				["Height isn't everything. The king is the tallest piece there is, and he's terrified of everything.", 1, "Ha! True. He hides behind me most games."],
				["Well, you ARE only worth one point.", -1, "One point. One. Thanks. I'll just go stand in front of something."],
			]},
		{"q": "Can I tell you a secret? When I reach the last rank, I'm going to be a queen. I've been practising the wave.",
			"a": [
				["Show me the wave. ...Majestic. The eighth rank won't know what hit it.", 2, "*waves* You're the first piece who didn't laugh. That's going in my coronation speech."],
				["A queen? Ambitious. I like that.", 1, "Six squares to go. Seven if you count the nervous one at the start."],
				["Statistically, most pawns get captured around move twelve.", -1, "Statistically, most people on dates don't bring up my death."],
			]},
		{"q": "I can only move forward. Never back. Is that romantic, or just a design flaw?",
			"a": [
				["Romantic. No regrets, no retreat, only onward.", 2, "Onward! Oh, I like you. You speak fluent pawn."],
				["Honestly? A bit of both.", 1, "That's fair. I once walked straight into a bishop and couldn't back out."],
				["Design flaw. Have you tried turning around?", -1, "Turning around is not in the rulebook. I checked. Twice. While crying."],
			]},
		{"q": "In the opening they push me out first, just to see what happens. Do you ever feel like a sacrifice?",
			"a": [
				["You're not a sacrifice, you're the vanguard. Everybody else is following YOU.", 2, "The vanguard... I'm getting that tattooed. Somewhere small."],
				["Everybody feels like that sometimes.", 1, "Even the queen? Huh. That's comforting, in a bleak way."],
				["They call it a gambit. It's a classy word for it.", -1, "Oh good, it has a classy name. That makes it SO much better."],
			]},
		{"q": "Do you know about en passant? It's my one fancy move. Nobody ever believes me.",
			"a": [
				["Know it? It's the most elegant rule in chess. You're basically a ninja.", 2, "A NINJA. Wait until I tell the other seven."],
				["Isn't that the weird sideways capture?", 1, "Diagonal, technically. But yes! The weird one! That's me!"],
				["That sounds made up.", -1, "It's in the RULES. Why does nobody ever believe the pawn?"],
			]},
	],
	2: [
		{"q": "Do you like horses? Careful. There is a correct answer.",
			"a": [
				["I love horses. Noble, loyal, and they can jump over anything.", 2, "Over ANYTHING. Fences, pawns, social conventions. You get it."],
				["They're nice. Big eyes.", 1, "Big, soulful eyes. I'll take 'nice'. For now."],
				["I'm more of a cat person.", -1, "...A cat. On a date. With a knight. Neigh, I say. NEIGH."],
			]},
		{"q": "I move in an L-shape. Two forward, one to the side. Some call it confusing. I call it mysterious.",
			"a": [
				["It's the only move on the board with a twist. Mysterious is exactly right.", 2, "A twist! Yes! Nobody ever sees me coming. Except other knights."],
				["I still have to count it out on my fingers.", 1, "Two, then one. Like a waltz with a limp. You'll get there."],
				["Why not just go straight like a normal piece?", -1, "Straight? Like a ROOK? I'd rather be melted down into a coat hook."],
			]},
		{"q": "A true knight must be chivalrous. If a door appeared right now, I would hold it open for you. Diagonally.",
			"a": [
				["Then allow me to hold the next one for you. Chivalry goes both ways.", 2, "*whinnies softly* That was extremely chivalrous. I'm blushing under my mane."],
				["That's sweet. Confusing, but sweet.", 1, "Confusion is the price of gallantry, my liege."],
				["Isn't chivalry a bit old-fashioned?", -1, "Old-fashioned?! I was carved in the twelfth century! EVERYTHING I own is old-fashioned!"],
			]},
		{"q": "I'm the only piece that can leap over the others. Some say that's showing off. What do you think?",
			"a": [
				["If you can leap over a whole army, you should. Show off all you like.", 2, "*does a little hop* I knew you'd understand. You have the soul of a horse."],
				["It's handy when the board gets crowded.", 1, "Very handy. Pawns everywhere, and up I go."],
				["It's a bit rude to jump over people, honestly.", -1, "Rude? It's a LEAP, not an insult. ...Fine. I'll walk around you."],
			]},
		{"q": "Quick question. If I attack the king AND the queen at once, is that romance, or warfare?",
			"a": [
				["Both. A royal fork is a love letter to the whole board.", 2, "A love letter! I'm having that engraved on my saddle."],
				["Warfare. But very stylish warfare.", 1, "Stylish is my middle name. My first name is Sir."],
				["Isn't that kind of cheating?", -1, "It is NOT cheating. It is GEOMETRY."],
			]},
	],
	3: [
		{"q": "I only walk the diagonals. The straight path is for the unenlightened. Tell me... do you believe in angles?",
			"a": [
				["Forty-five degrees of pure devotion. I believe.", 2, "An acolyte of the oblique! Bless you, child. Diagonally."],
				["I believe in at least some angles.", 1, "A start. Faith begins with a single degree."],
				["Isn't straight just quicker?", -1, "Spoken like a rook. I shall pray for you. Sideways."],
			]},
		{"q": "When a piece turns to ash, I keep a pinch of it in a locket. Is that strange?",
			"a": [
				["It's beautiful. They're with you on every square you cross.", 2, "*clutches locket* You may hold it. Gently. That's Gerald."],
				["It's a little strange. But I understand.", 1, "Strange is just devout with fewer candles."],
				["Very strange. Is there ash in your mitre right now?", -1, "There is NOT ash in my mitre. ...There is ash in my mitre."],
			]},
		{"q": "I spend my whole life on the light squares. Do you ever wonder what's on the dark ones?",
			"a": [
				["The other bishop, wondering the same thing about you. That's poetry.", 2, "We'll never meet... like candles in separate cathedrals. Oh. I need a moment."],
				["The dark squares seem nice enough.", 1, "Nice? Probably. I wouldn't know. I've never been."],
				["Why don't you just step over?", -1, "STEP OVER? Heresy. Coffee-shop heresy, at that."],
			]},
		{"q": "My mitre is pointed for a reason, you know. Do you care for gothic architecture?",
			"a": [
				["Flying buttresses, gargoyles, rose windows... you're a cathedral that walks.", 2, "A walking cathedral. Nobody has ever said anything kinder about my hat."],
				["I like the spooky bits.", 1, "The gargoyles. Everyone likes the gargoyles. They're my cousins."],
				["Your hat looks like a pen cap.", -1, "It is a MITRE. It has been blessed. Seven times."],
			]},
		{"q": "Tell me. What do you believe happens to a piece after it's captured?",
			"a": [
				["It becomes ash, and the ash drifts everywhere. A little of every fallen piece rests on every square.", 2, "That is exactly what I preach! Nobody listens. You listened."],
				["I think they go back in the box.", 1, "The Box. Yes. Dark, quiet, lined with felt. Some call it heaven."],
				["Honestly? I try not to think about it.", -1, "You will. Everyone does, eventually. *distant organ music*"],
			]},
	],
	4: [
		{"q": "I'll be straight with you. I move in straight lines. I talk in straight lines. Is that a problem?",
			"a": [
				["It's refreshing. No angles, no games. Well, one game.", 2, "Ha. One game. I like a piece who says what it means."],
				["At least I always know where I stand.", 1, "Exactly where I can see you. Along the file."],
				["Bit boring, isn't it?", -1, "Boring is a load-bearing quality. Look it up."],
			]},
		{"q": "Most nights I just stay in my corner. Feet up, drawbridge raised. Is a homebody a dealbreaker?",
			"a": [
				["Staying in sounds perfect. A corner, a blanket, a quiet endgame.", 2, "A quiet endgame... Marry me. No. Too soon. But very nice."],
				["I could do a night in, now and then.", 1, "Now and then. I'll put the kettle on in emergencies."],
				["I'd rather go out every single night.", -1, "Every NIGHT? My foundations ache just hearing that."],
			]},
		{"q": "I've been reading about castles. Keeps, crenellations, murder holes. Do you like architecture?",
			"a": [
				["Love it. Especially tall, well-built towers with good strong battlements.", 2, "*straightens battlements* Good strong battlements, you say. Hm. Hmhm."],
				["I like a nice arch.", 1, "Arches are all right. A bit curvy for my taste."],
				["What on earth is a murder hole?", -1, "It's a hole. For murder. Never mind. Forget I mentioned it."],
			]},
		{"q": "Castling. The king and I swap places in a single move. Some call it a marriage of convenience. Thoughts?",
			"a": [
				["You keep the king safe and look good doing it. That's heroic.", 2, "Heroic. He never says thank you, you know. You just did."],
				["It's a neat trick.", 1, "Neat. Yes. Like my corners."],
				["Isn't that just the king using you as a shield?", -1, "...I'm going to need a minute. And possibly a stonemason."],
			]},
		{"q": "Some pieces think rooks are slow to get going. I prefer 'steady'. Which are you, slow or steady?",
			"a": [
				["Steady. The best things on this board take their time arriving.", 2, "The best things take their time. I'm putting that over my door."],
				["Depends on the day, honestly.", 1, "Honest. I respect a piece with a straight answer."],
				["Neither. I'm fast. Like a bishop.", -1, "A BISHOP. On a date with ME. You've gone diagonal on me."],
			]},
	],
	5: [
		{"q": "I move in any direction, baby. Straight lines, diagonals... Go on. Ask me how.",
			"a": [
				["How? Show me. Slowly. I've got all night and the whole board.", 2, "Patience AND an appetite? Queen to h-five, baby. That's a situation."],
				["Uh... diagonally?", 1, "Cute. Diagonally works. For starters."],
				["I already know how the queen moves. I read the rules.", -1, "The RULES? Honey, nobody reads the rules to a queen. Ask me, don't recite me."],
			]},
		{"q": "My tushy is so cushy. Be honest. Was it the first thing you noticed?",
			"a": [
				["Second. The crown came first. Then I couldn't look anywhere else.", 2, "Crown first, cushy second. Smart AND honest. Scoot over to my side of the table."],
				["I'm a gentleman. I was looking at your eyes.", 1, "Liar. A sweet liar, though. I'll allow it."],
				["What tushy? You're a chess piece.", -1, "A chess piece with a back rank, honey. And you just lost your view of it."],
			]},
		{"q": "I make my pieces do the work while I'm in the back and twerk. Does that make me lazy?",
			"a": [
				["Lazy? That's delegation. You're a CEO with a bounce.", 2, "A CEO with a bounce! Put that on my business cards. And my tombstone."],
				["Maybe a little. But it looks like fun.", 1, "It IS fun. You should see it from the front row."],
				["Yes. Your pawns deserve better.", -1, "My pawns kiss my feet and LOVE it. Go cry to the king about it."],
			]},
		{"q": "The king wrote me a poem. It was mostly about check. Whisper me something sweet. In algebraic notation.",
			"a": [
				["Queen takes my heart. Checkmate. No take-backs.", 2, "Ohh. That one went straight under my crown. Say it again, slower."],
				["E4?", 1, "A bold opening. Basic, but bold. I've had worse."],
				["Pawn to e-three.", -1, "E-three? ONE square? Are you the king? Is that you hiding under the bed?"],
			]},
		{"q": "Rooks only move in straight lines and bishops are way too pointy. What kind of piece are YOU, baby?",
			"a": [
				["The kind that follows your curves. Any direction you want.", 2, "Any direction? Ooh, you're dangerous. I like a piece who can keep up."],
				["The loyal kind. I'll stick around.", 1, "Loyal is sweet. A little boring, like the king. But sweet."],
				["Honestly, I'm more of a bishop guy.", -1, "A bishop guy. On a date with ME. Go slide off somewhere diagonal."],
			]},
	],
	6: [
		{"q": "Is it me, or is that waiter looking at me like he wants to put me in check?",
			"a": [
				["Nobody is checking you tonight. I've got your back. And your flanks.", 2, "My flanks! You thought of my flanks! Nobody ever thinks of my flanks."],
				["I'm sure he's just a waiter.", 1, "That's what they said about the last knight. Stay alert."],
				["Now that you mention it, he has been staring for a while.", -1, "WHERE. Which direction? Is he diagonal? Don't let him be diagonal."],
			]},
		{"q": "Do you think I'm a good king? Be honest. Actually, don't be honest. Be nice.",
			"a": [
				["You're the most important piece on the board. Literally. The whole game is about you.", 2, "It IS about me, isn't it? *sits up straighter* Go on. More of that."],
				["You're a very... careful king.", 1, "Careful. Yes. Careful is a kind of good. I'll take it."],
				["Well, you do only move one square at a time.", -1, "I am PACING myself. It's called STRATEGY."],
			]},
		{"q": "I sleep in the corner behind three pawns and a rook. Is that too much security?",
			"a": [
				["Not at all. A treasure like you deserves a fortress.", 2, "A treasure. In a fortress. I need you to say that at my next coronation."],
				["Whatever helps you sleep.", 1, "Nothing helps me sleep. But the rook snores, which is comforting."],
				["Sounds a lot like hiding.", -1, "It's called CASTLING and it is a DIGNIFIED DEFENSIVE MANOEUVRE."],
			]},
		{"q": "If the whole board turned against me, all the pieces at once, would you stand in front of me?",
			"a": [
				["I'd interpose myself on every square between you and danger.", 2, "Interpose! That's the most romantic word in chess."],
				["I'd at least shout a warning.", 1, "A warning is something. I'd hear 'check' and know it came with love."],
				["To be fair, I'd probably be one of the attackers.", -1, "You... you'd... *breathing into a paper bag* I'm fine. I'm fine."],
			]},
		{"q": "They put a little cross on my crown. Does it look regal, or does it look like a target?",
			"a": [
				["Regal. Utterly regal. Every piece on the board looks up to it.", 2, "They DO look up to it. Mostly because I'm tall. But still! Regal!"],
				["It looks very... pointy.", 1, "Pointy is fine. Pointy deters assassins."],
				["Honestly? A bit like a target.", -1, "I KNEW it. I'm wearing a bullseye. I've been wearing a bullseye for four hundred years."],
			]},
	],
}

## Small talk any piece might make.
const GENERIC := [
	{"q": "So... do you come here often?",
		"a": [
			["Only on squares where you are.", 2, "Smooth. Disgustingly smooth. Do it again."],
			["First time. I'm a little nervous.", 1, "Me too. My base is wobbling."],
			["Usually with somebody else.", -1, "Oh. Oh, okay. That's... information."],
		]},
	{"q": "Lovely weather on the board today. Barely any ash falling at all.",
		"a": [
			["Just enough to look like snow. It's romantic, really.", 2, "Snow made of our fallen friends. You see beauty everywhere, don't you?"],
			["Mostly sunny, light chance of capture.", 1, "Ha! I'll bring an umbrella. And a rook."],
			["Give it a few moves. Somebody always loses their head.", -1, "...Thanks. I'll think about that every single turn now."],
		]},
	{"q": "The ash gets everywhere, doesn't it? I found a bit of an old friend in my shoe this morning.",
		"a": [
			["Then they're still walking with you. That's oddly lovely.", 2, "*sniffs* They always did want to see the far side of the board."],
			["I keep a little brush for it.", 1, "A brush! Practical. I like practical."],
			["Have you tried shaking it out?", -1, "Shake out my FRIEND? Have some respect."],
		]},
	{"q": "Did you hear? Two pieces raced for pink slips last night. One of them is walking home without a car.",
		"a": [
			["Losing a car is nothing. Losing someone like you, that would be something.", 2, "...Did you rehearse that? It worked. Don't tell me if you did."],
			["I'd bet on the rooks. Excellent straight-line drivers.", 1, "Ha! Hopeless at corners, though. They just drive into the wall."],
			["Want to race me after this? Pink slips. Winner takes the car.", -1, "On a DATE? You'd take my CAR on a DATE?"],
		]},
	{"q": "They say every piece has a labyrinth inside it. What do you think is inside mine?",
		"a": [
			["Somewhere warm. Candlelit halls, and a door that opens if you knock nicely.", 2, "...That's the nicest thing anyone has ever said about my insides."],
			["A few puzzles. A locked door or two.", 1, "Two locked doors, actually. You'd have to earn the keys."],
			["Dark corridors and something with teeth.", -1, "That is my emotional baggage you're describing, thank you very much."],
		]},
	{"q": "What's your favourite opening? You can tell a lot about someone by their opening.",
		"a": [
			["The one where I get to sit across from you.", 2, "Oh. Oh no. That was very good. I'm flustered."],
			["The Queen's Gambit. A classic for a reason.", 1, "Classic. Reliable. Like a good blanket."],
			["Fool's Mate. Over in four moves.", -1, "Four moves. Is that how long you planned this date to last?"],
		]},
]

const OPENERS := {
	"hollow": [
		"Oh. You actually came. I thought this was a prank. Everybody I used to stand next to is ash now.",
		"Sorry. I'm not great company. I lost three friends and a car this week, and I liked the car.",
		"I almost didn't come. I almost don't do anything any more. But you asked. So... here I am.",
	],
	"gloomy": [
		"Hi. Sorry if I'm quiet. It's been a long game. Lots of ash.",
		"I'm fine. I'm FINE. I'm mostly fine. Shall we sit?",
		"I wore my best felt base tonight. It's the only thing that's gone right all week.",
	],
	"uneasy": [
		"Hello! I'm a little nervous. I've never been on a date that wasn't a trade.",
		"So this is a date. Do I shake your hand? Do I have hands? This is going great already.",
		"Hi! I rehearsed some small talk on the way here. Then I panicked and forgot all of it. Hi!",
	],
	"happy": [
		"Well, look at you! I've been looking forward to this all game.",
		"Hello there. I polished my lacquer for this. Can you tell? Say yes.",
		"What a night! Nobody's been captured for three whole moves. Let's celebrate.",
	],
}

const ENEMY_OPENER := "Aren't we... on opposite sides of the board?"
const ENEMY_TAILS := {
	"low": [
		"Honestly, I'm too sad to care. My side has been turning to ash all week.",
		"Then again, my own side hasn't asked how I'm doing in forty moves. So. Hi.",
	],
	"high": [
		"My king would have a fit if he saw this. Let's sit where he can't see us.",
		"If anyone asks, I'm here on reconnaissance. Very romantic reconnaissance.",
		"Not that I mind. You look much better from this side of the board.",
	],
}

## Queen Cushy doesn't do gloomy: she has her own lines, whatever her mood.
const QUEEN_GREETING := {
	"own": "Hey. It's your queen. A date? Take me somewhere fancy, honey. The tushy has standards.",
	"enemy": "A date with the other side's queen? Black side, white side, I don't really mind. Where are we going, tall stuff?",
}
const QUEEN_OPENERS := [
	"Hey boys, hey board, the queen just walked in. Glitter on my crown, smirk upon my chin. You may begin.",
	"Mood is elated, never gloomy in the rain. Now pull my chair out. Slowly. Let them all look.",
	"Every square I visit is a party just for me. Tonight the party's at your table. Lucky you.",
	"Elongated legs and an elongated smile, baby. Try to keep up.",
]
const QUEEN_ENEMY_OPENERS := [
	"Wrong side of the board, honey? I don't mind. As long as you are tall and you're treating me kind.",
	"If my king asks, this is reconnaissance. Very bouncy reconnaissance. He's hiding under the bed anyway.",
]

## What the date says while you pick a venue.
const GREETINGS := {
	"hollow": "...A date? With me? Somewhere quiet, I suppose. If anywhere.",
	"gloomy": "Oh. Hello. Where are we going? Somewhere with not too many people, please.",
	"uneasy": "A date! Okay. Okay! Where are we going? Not the trenches, I hope.",
	"happy": "A date! With ME! Where are we going? Anywhere's fine. Everywhere's fine!",
	"enemy": "Is this a trap? This feels like a trap. ...Where are you taking me?",
}

const CLOSE_GREAT := {
	1: "Tonight I felt like a queen. And I didn't even have to promote!",
	2: "I shall gallop home in an L-shape of pure joy. Two squares of joy, then one more!",
	3: "I'll light a candle for this evening. A black one. That's a compliment.",
	4: "Same time next week? I'll keep the corner warm and the drawbridge down.",
	5: "Call me again, baby. Next time bring roses, a Used Car and a little purple bike. I'll bring the bounce.",
	6: "For one whole evening, I wasn't in check. Not once. Thank you.",
}
const CLOSE_BAD := {
	1: "It's fine. I'm used to being pushed around.",
	2: "I shall retreat now. Two squares back, one to the side, and out of your life.",
	3: "I shall pray for you. And not in the nice way.",
	4: "I'm going back to my corner. Don't follow me in a straight line.",
	5: "Give me back my lip gloss. This audience is over. Watch me walk away, it's the best part of your night.",
	6: "Take me home. Take me home NOW. By the safest possible route.",
}
const CLOSE_GOOD := [
	"That was lovely. I feel a whole rank taller.",
	"I had a really nice time. Let's do this again before one of us is captured.",
	"Thank you. I'd forgotten the board could feel this warm.",
]
const CLOSE_MEH := [
	"Well. That was... a date. Thanks for coming, I suppose.",
	"It was nice to get out of the box for a bit. Mostly nice.",
	"I'll remember this. I'm not sure how, yet.",
]
const ENEMY_PS := [
	"Tell no one. My side would never forgive me.",
	"Next time we meet on the board, I'll pretend I don't know you. Badly.",
	"If you ever capture me... the labyrinth door will be unlocked.",
]
const ENEMY_BAD_PS := [
	"And I'm telling my whole side about this.",
	"This is going in the enemy's war diary.",
]


static func venue(id: String) -> Dictionary:
	for v in VENUES:
		if v["id"] == id:
			return v
	return {}


static func pref_bonus(t: int, venue_id: String, mood: float) -> int:
	var b := 0
	var by_type: Dictionary = PREFS.get(t, {})
	if by_type.has(venue_id):
		b = int(by_type[venue_id][0])
	if venue_id == "cruise" and mood < GLOOMY_BELOW:
		b += GLOOMY_CRUISE_BONUS
	return b


static func pref_line(t: int, venue_id: String) -> String:
	var by_type: Dictionary = PREFS.get(t, {})
	if by_type.has(venue_id):
		return String(by_type[venue_id][1])
	return "What a place."


## The mood change for a finished date.
static func compute_delta(base: int, bonus: int, score_sum: int) -> int:
	return clampi(base + bonus + REPLY_WEIGHT * score_sum, MIN_DELTA, MAX_DELTA)


static func mood_band(m: float) -> String:
	if m < 25.0:
		return "hollow"
	if m < GLOOMY_BELOW:
		return "gloomy"
	if m < 65.0:
		return "uneasy"
	return "happy"


static func _pick(arr: Array, rng: RandomNumberGenerator) -> Variant:
	return arr[rng.randi_range(0, arr.size() - 1)]


static func shuffled(arr: Array, rng: RandomNumberGenerator) -> Array:
	var out := arr.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## Two prompts for the piece type and one generic one, generic in the middle.
static func pick_prompts(t: int, rng: RandomNumberGenerator) -> Array:
	var typed := shuffled(PROMPTS.get(t, PROMPTS[1]), rng)
	var gen: Dictionary = _pick(GENERIC, rng)
	return [typed[0], gen, typed[1]]


## The prompt's three replies [text, score, reaction] in random order.
static func shuffled_replies(prompt: Dictionary, rng: RandomNumberGenerator) -> Array:
	return shuffled(prompt["a"], rng)


static func greeting(mood: float, own: bool, t: int = 0) -> String:
	if t == 5:
		return String(QUEEN_GREETING["own" if own else "enemy"])
	if not own:
		return String(GREETINGS["enemy"])
	return String(GREETINGS[mood_band(mood)])


static func opener(mood: float, own: bool, rng: RandomNumberGenerator, t: int = 0) -> String:
	if t == 5:
		return String(_pick(QUEEN_OPENERS if own else QUEEN_ENEMY_OPENERS, rng))
	if not own:
		var tails: Array = ENEMY_TAILS["low"] if mood < GLOOMY_BELOW else ENEMY_TAILS["high"]
		return ENEMY_OPENER + " " + String(_pick(tails, rng))
	return String(_pick(OPENERS[mood_band(mood)], rng))


static func closer(t: int, delta: int, own: bool, rng: RandomNumberGenerator) -> String:
	var line := ""
	if delta >= 30:
		line = String(CLOSE_GREAT.get(t, CLOSE_GREAT[1]))
	elif delta >= 15:
		line = String(_pick(CLOSE_GOOD, rng))
	elif delta > 0:
		line = String(_pick(CLOSE_MEH, rng))
	else:
		line = String(CLOSE_BAD.get(t, CLOSE_BAD[1]))
	if not own:
		if delta >= 15:
			line += " " + String(_pick(ENEMY_PS, rng))
		elif delta <= 0:
			line += " " + String(_pick(ENEMY_BAD_PS, rng))
	return line
