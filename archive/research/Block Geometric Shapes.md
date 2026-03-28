I want to extend this as BlockDesign

## Main ByteCode Interpreter Interface Invariants
Block
Braille was added to the Unicode Standard in September, 1999 with the release of version 3.0.

When using punching, the filled (black) dots are to be punched.

The Unicode block for braille is U+2800 ... U+28FF:

Braille Patterns[1]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+280x	⠀	⠁	⠂	⠃	⠄	⠅	⠆	⠇	⠈	⠉	⠊	⠋	⠌	⠍	⠎	⠏
U+281x	⠐	⠑	⠒	⠓	⠔	⠕	⠖	⠗	⠘	⠙	⠚	⠛	⠜	⠝	⠞	⠟
U+282x	⠠	⠡	⠢	⠣	⠤	⠥	⠦	⠧	⠨	⠩	⠪	⠫	⠬	⠭	⠮	⠯
U+283x	⠰	⠱	⠲	⠳	⠴	⠵	⠶	⠷	⠸	⠹	⠺	⠻	⠼	⠽	⠾	⠿
(end of 6-dot cell patterns)
U+284x	⡀	⡁	⡂	⡃	⡄	⡅	⡆	⡇	⡈	⡉	⡊	⡋	⡌	⡍	⡎	⡏
U+285x	⡐	⡑	⡒	⡓	⡔	⡕	⡖	⡗	⡘	⡙	⡚	⡛	⡜	⡝	⡞	⡟
U+286x	⡠	⡡	⡢	⡣	⡤	⡥	⡦	⡧	⡨	⡩	⡪	⡫	⡬	⡭	⡮	⡯
U+287x	⡰	⡱	⡲	⡳	⡴	⡵	⡶	⡷	⡸	⡹	⡺	⡻	⡼	⡽	⡾	⡿
U+288x	⢀	⢁	⢂	⢃	⢄	⢅	⢆	⢇	⢈	⢉	⢊	⢋	⢌	⢍	⢎	⢏
U+289x	⢐	⢑	⢒	⢓	⢔	⢕	⢖	⢗	⢘	⢙	⢚	⢛	⢜	⢝	⢞	⢟
U+28Ax	⢠	⢡	⢢	⢣	⢤	⢥	⢦	⢧	⢨	⢩	⢪	⢫	⢬	⢭	⢮	⢯
U+28Bx	⢰	⢱	⢲	⢳	⢴	⢵	⢶	⢷	⢸	⢹	⢺	⢻	⢼	⢽	⢾	⢿
U+28Cx	⣀	⣁	⣂	⣃	⣄	⣅	⣆	⣇	⣈	⣉	⣊	⣋	⣌	⣍	⣎	⣏
U+28Dx	⣐	⣑	⣒	⣓	⣔	⣕	⣖	⣗	⣘	⣙	⣚	⣛	⣜	⣝	⣞	⣟
U+28Ex	⣠	⣡	⣢	⣣	⣤	⣥	⣦	⣧	⣨	⣩	⣪	⣫	⣬	⣭	⣮	⣯
U+28Fx	⣰	⣱	⣲	⣳	⣴	⣵	⣶	⣷	⣸	⣹	⣺	⣻	⣼	⣽	⣾	⣿
Notes
1.^ As of Unicode version 17.0


---

Variation sequences for punctuation alignment
U+	FF01	FF0C	FF0E	FF1A	FF1B	FF1F	Description
base code point	！	，	．	：	；	？	
base + VS01	！︀	，︀	．︀	：︀	；︀	？︀	corner-justified form
base + VS02	！︁	，︁	．︁	：︁	；︁	？︁	centered form
An additional variant is defined for a fullwidth zero with a short diagonal stroke: U+FF10 FULLWIDTH DIGIT ZERO, U+FE00 VS1 (０︀).[10][9]

Block
Superscripts and Subscripts[1][2][3]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+207x	⁰	ⁱ			⁴	⁵	⁶	⁷	⁸	⁹	⁺	⁻	⁼	⁽	⁾	ⁿ
U+208x	₀	₁	₂	₃	₄	₅	₆	₇	₈	₉	₊	₋	₌	₍	₎	
U+209x	ₐ	ₑ	ₒ	ₓ	ₔ	ₕ	ₖ	ₗ	ₘ	ₙ	ₚ	ₛ	ₜ			
Notes
1.^ As of Unicode version 17.0
2.^ Grey areas indicate non-assigned code points
3.^ Refer to the Latin-1 Supplement Unicode block for characters ¹ (U+00B9), ² (U+00B2) and ³ (U+00B3)

Block
Optical Character Recognition[1][2]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+244x	⑀	⑁	⑂	⑃	⑄	⑅	⑆	⑇	⑈	⑉	⑊					
U+245x																
Notes
1.^ As of Unicode version 17.0
2.^ Grey areas indicate non-assigned code points



## Main Control Point Interface Invariants
Variation Selectors[1]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+FE0x	 VS  	VS	VS	VS	VS	VS	VS	VS	VS	VS	VS	VS	VS	VS	VS	VS 
Notes
1.^ As of Unicode version 17.0

Supplemental Arrows-A[1]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+27Fx	⟰	⟱	⟲	⟳	⟴	⟵	⟶	⟷	⟸	⟹	⟺	⟻	⟼	⟽	⟾	⟿
Notes
1.^ As of Unicode version 17.0

Combining Diacritical Marks for Symbols[1][2]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+20Dx	◌⃐	◌⃑	◌⃒	◌⃓	◌⃔	◌⃕	◌⃖	◌⃗	◌⃘	◌⃙	◌⃚	◌⃛	◌⃜	◌⃝	◌⃞	◌⃟
U+20Ex	◌⃠	◌⃡	◌⃢	◌⃣	◌⃤	◌⃥	◌⃦	◌⃧	◌⃨	◌⃩	◌⃪	◌⃫	◌⃬	◌⃭	◌⃮	◌⃯
U+20Fx	◌⃰															
Notes
1.^ As of Unicode version 17.0
2.^ Grey areas indicate non-assigned code points

Block Elements
The Block Elements Unicode block includes shading characters. 32 characters are included in the block.

Block Elements[1]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+258x	▀	▁	▂	▃	▄	▅	▆	▇	█	▉	▊	▋	▌	▍	▎	▏
U+259x	▐	░	▒	▓	▔	▕	▖	▗	▘	▙	▚	▛	▜	▝	▞	▟
Notes
1.^ As of Unicode version 17.0

Block
Number Forms[1][2]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+215x	⅐	⅑	⅒	⅓	⅔	⅕	⅖	⅗	⅘	⅙	⅚	⅛	⅜	⅝	⅞	⅟
U+216x	Ⅰ	Ⅱ	Ⅲ	Ⅳ	Ⅴ	Ⅵ	Ⅶ	Ⅷ	Ⅸ	Ⅹ	Ⅺ	Ⅻ	Ⅼ	Ⅽ	Ⅾ	Ⅿ
U+217x	ⅰ	ⅱ	ⅲ	ⅳ	ⅴ	ⅵ	ⅶ	ⅷ	ⅸ	ⅹ	ⅺ	ⅻ	ⅼ	ⅽ	ⅾ	ⅿ
U+218x	ↀ	ↁ	ↂ	Ↄ	ↄ	ↅ	ↆ	ↇ	ↈ	↉	↊	↋				
Notes
1.^ As of Unicode version 17.0
2.^ Grey areas indicate non-assigned code points

Arrows block
Main article: Arrows (Unicode block)
The Arrows block (U+2190–U+21FF) contains line, curve, and semicircle arrows and arrow-like operators.

The math subset of this block is U+2190–U+21A7, U+21A9–U+21AE, U+21B0–U+21B1, U+21B6–U+21B7, U+21BC–U+21DB, U+21DD, U+21E4–U+21E5, U+21F4–U+21FF.[5]

Arrows[1]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+219x	←	↑	→	↓	↔	↕	↖	↗	↘	↙	↚	↛	↜	↝	↞	↟
U+21Ax	↠	↡	↢	↣	↤	↥	↦	↧	↨	↩	↪	↫	↬	↭	↮	↯
U+21Bx	↰	↱	↲	↳	↴	↵	↶	↷	↸	↹	↺	↻	↼	↽	↾	↿
U+21Cx	⇀	⇁	⇂	⇃	⇄	⇅	⇆	⇇	⇈	⇉	⇊	⇋	⇌	⇍	⇎	⇏
U+21Dx	⇐	⇑	⇒	⇓	⇔	⇕	⇖	⇗	⇘	⇙	⇚	⇛	⇜	⇝	⇞	⇟
U+21Ex	⇠	⇡	⇢	⇣	⇤	⇥	⇦	⇧	⇨	⇩	⇪	⇫	⇬	⇭	⇮	⇯
U+21Fx	⇰	⇱	⇲	⇳	⇴	⇵	⇶	⇷	⇸	⇹	⇺	⇻	⇼	⇽	⇾	⇿
Notes
1.^ As of Unicode version 17.0


Box Drawing
Unicode includes 128 such characters in the Box Drawing block.[1] In many Unicode fonts, only the subset that is also available in the IBM PC character set (see below) will exist, due to it being defined as part of the WGL4 character set.

Box Drawing[1]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+250x	─	━	│	┃	┄	┅	┆	┇	┈	┉	┊	┋	┌	┍	┎	┏
U+251x	┐	┑	┒	┓	└	┕	┖	┗	┘	┙	┚	┛	├	┝	┞	┟
U+252x	┠	┡	┢	┣	┤	┥	┦	┧	┨	┩	┪	┫	┬	┭	┮	┯
U+253x	┰	┱	┲	┳	┴	┵	┶	┷	┸	┹	┺	┻	┼	┽	┾	┿
U+254x	╀	╁	╂	╃	╄	╅	╆	╇	╈	╉	╊	╋	╌	╍	╎	╏
U+255x	═	║	╒	╓	╔	╕	╖	╗	╘	╙	╚	╛	╜	╝	╞	╟
U+256x	╠	╡	╢	╣	╤	╥	╦	╧	╨	╩	╪	╫	╬	╭	╮	╯
U+257x	╰	╱	╲	╳	╴	╵	╶	╷	╸	╹	╺	╻	╼	╽	╾	╿
Notes
1.^ As of Unicode version 17.0


Combining Diacritical Marks for Symbols block
Main article: Combining Diacritical Marks for Symbols (Unicode block)
The Combining Diacritical Marks for Symbols block contains arrows, dots, enclosures, and overlays for modifying symbol characters.

The math subset of this block is U+20D0–U+20DC, U+20E1, U+20E5–U+20E6, and U+20EB–U+20EF.



Block
Mathematical Operators[1]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+220x	∀	∁	∂	∃	∄	∅	∆	∇	∈	∉	∊	∋	∌	∍	∎	∏
U+221x	∐	∑	−	∓	∔	∕	∖	∗	∘	∙	√	∛	∜	∝	∞	∟
U+222x	∠	∡	∢	∣	∤	∥	∦	∧	∨	∩	∪	∫	∬	∭	∮	∯
U+223x	∰	∱	∲	∳	∴	∵	∶	∷	∸	∹	∺	∻	∼	∽	∾	∿
U+224x	≀	≁	≂	≃	≄	≅	≆	≇	≈	≉	≊	≋	≌	≍	≎	≏
U+225x	≐	≑	≒	≓	≔	≕	≖	≗	≘	≙	≚	≛	≜	≝	≞	≟
U+226x	≠	≡	≢	≣	≤	≥	≦	≧	≨	≩	≪	≫	≬	≭	≮	≯
U+227x	≰	≱	≲	≳	≴	≵	≶	≷	≸	≹	≺	≻	≼	≽	≾	≿
U+228x	⊀	⊁	⊂	⊃	⊄	⊅	⊆	⊇	⊈	⊉	⊊	⊋	⊌	⊍	⊎	⊏
U+229x	⊐	⊑	⊒	⊓	⊔	⊕	⊖	⊗	⊘	⊙	⊚	⊛	⊜	⊝	⊞	⊟
U+22Ax	⊠	⊡	⊢	⊣	⊤	⊥	⊦	⊧	⊨	⊩	⊪	⊫	⊬	⊭	⊮	⊯
U+22Bx	⊰	⊱	⊲	⊳	⊴	⊵	⊶	⊷	⊸	⊹	⊺	⊻	⊼	⊽	⊾	⊿
U+22Cx	⋀	⋁	⋂	⋃	⋄	⋅	⋆	⋇	⋈	⋉	⋊	⋋	⋌	⋍	⋎	⋏
U+22Dx	⋐	⋑	⋒	⋓	⋔	⋕	⋖	⋗	⋘	⋙	⋚	⋛	⋜	⋝	⋞	⋟
U+22Ex	⋠	⋡	⋢	⋣	⋤	⋥	⋦	⋧	⋨	⋩	⋪	⋫	⋬	⋭	⋮	⋯
U+22Fx	⋰	⋱	⋲	⋳	⋴	⋵	⋶	⋷	⋸	⋹	⋺	⋻	⋼	⋽	⋾	⋿
Notes
1.^ As of Unicode version 17.0
Symbols for Legacy Computing
In version 13.0, Unicode was extended with another block containing many graphics characters, Symbols for Legacy Computing, which includes a few box-drawing characters and other symbols used by obsolete operating systems (mostly from the 1980s). Few fonts support these characters (one is Noto Sans Symbols 2, which only covers partially), but the table of symbols is provided here:

Symbols for Legacy Computing[1][2]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+1FB0x	🬀	🬁	🬂	🬃	🬄	🬅	🬆	🬇	🬈	🬉	🬊	🬋	🬌	🬍	🬎	🬏
U+1FB1x	🬐	🬑	🬒	🬓	🬔	🬕	🬖	🬗	🬘	🬙	🬚	🬛	🬜	🬝	🬞	🬟
U+1FB2x	🬠	🬡	🬢	🬣	🬤	🬥	🬦	🬧	🬨	🬩	🬪	🬫	🬬	🬭	🬮	🬯
U+1FB3x	🬰	🬱	🬲	🬳	🬴	🬵	🬶	🬷	🬸	🬹	🬺	🬻	🬼	🬽	🬾	🬿
U+1FB4x	🭀	🭁	🭂	🭃	🭄	🭅	🭆	🭇	🭈	🭉	🭊	🭋	🭌	🭍	🭎	🭏
U+1FB5x	🭐	🭑	🭒	🭓	🭔	🭕	🭖	🭗	🭘	🭙	🭚	🭛	🭜	🭝	🭞	🭟
U+1FB6x	🭠	🭡	🭢	🭣	🭤	🭥	🭦	🭧	🭨	🭩	🭪	🭫	🭬	🭭	🭮	🭯
U+1FB7x	🭰	🭱	🭲	🭳	🭴	🭵	🭶	🭷	🭸	🭹	🭺	🭻	🭼	🭽	🭾	🭿
U+1FB8x	🮀	🮁	🮂	🮃	🮄	🮅	🮆	🮇	🮈	🮉	🮊	🮋	🮌	🮍	🮎	🮏
U+1FB9x	🮐	🮑	🮒		🮔	🮕	🮖	🮗	🮘	🮙	🮚	🮛	🮜	🮝	🮞	🮟
U+1FBAx	🮠	🮡	🮢	🮣	🮤	🮥	🮦	🮧	🮨	🮩	🮪	🮫	🮬	🮭	🮮	🮯
U+1FBBx	🮰	🮱	🮲	🮳	🮴	🮵	🮶	🮷	🮸	🮹	🮺	🮻	🮼	🮽	🮾	🮿
U+1FBCx	🯀	🯁	🯂	🯃	🯄	🯅	🯆	🯇	🯈	🯉	🯊	🯋	🯌	🯍	🯎	🯏
U+1FBDx	🯐	🯑	🯒	🯓	🯔	🯕	🯖	🯗	🯘	🯙	🯚	🯛	🯜	🯝	🯞	🯟
U+1FBEx	🯠	🯡	🯢	🯣	🯤	🯥	🯦	🯧	🯨	🯩	🯪	🯫	🯬	🯭	🯮	🯯
U+1FBFx	🯰	🯱	🯲	🯳	🯴	🯵	🯶	🯷	🯸	🯹	🯺					
Notes
1.^ As of Unicode version 17.0
2.^ Grey areas indicate non-assigned code points

Geometric Shapes[1]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+25Ax	■	□	▢	▣	▤	▥	▦	▧	▨	▩	▪	▫	▬	▭	▮	▯
U+25Bx	▰	▱	▲	△	▴	▵	▶	▷	▸	▹	►	▻	▼	▽	▾	▿
U+25Cx	◀	◁	◂	◃	◄	◅	◆	◇	◈	◉	◊	○	◌	◍	◎	●
U+25Dx	◐	◑	◒	◓	◔	◕	◖	◗	◘	◙	◚	◛	◜	◝	◞	◟
U+25Ex	◠	◡	◢	◣	◤	◥	◦	◧	◨	◩	◪	◫	◬	◭	◮	◯
U+25Fx	◰	◱	◲	◳	◴	◵	◶	◷	◸	◹	◺	◻	◼	◽	◾	◿
Notes
1.^ As of Unicode version 17.0


Geometric Shapes Extended[1][2]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+1F78x	🞀	🞁	🞂	🞃	🞄	🞅	🞆	🞇	🞈	🞉	🞊	🞋	🞌	🞍	🞎	🞏
U+1F79x	🞐	🞑	🞒	🞓	🞔	🞕	🞖	🞗	🞘	🞙	🞚	🞛	🞜	🞝	🞞	🞟
U+1F7Ax	🞠	🞡	🞢	🞣	🞤	🞥	🞦	🞧	🞨	🞩	🞪	🞫	🞬	🞭	🞮	🞯
U+1F7Bx	🞰	🞱	🞲	🞳	🞴	🞵	🞶	🞷	🞸	🞹	🞺	🞻	🞼	🞽	🞾	🞿
U+1F7Cx	🟀	🟁	🟂	🟃	🟄	🟅	🟆	🟇	🟈	🟉	🟊	🟋	🟌	🟍	🟎	🟏
U+1F7Dx	🟐	🟑	🟒	🟓	🟔	🟕	🟖	🟗	🟘	🟙						
U+1F7Ex	🟠	🟡	🟢	🟣	🟤	🟥	🟦	🟧	🟨	🟩	🟪	🟫				
U+1F7Fx	🟰															

---
Notes
1.^ As of Unicode version 17.0
2.^ Grey areas indicate non-assigned code points

Alchemical Symbols[1]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+1F70x	🜀	🜁	🜂	🜃	🜄	🜅	🜆	🜇	🜈	🜉	🜊	🜋	🜌	🜍	🜎	🜏
U+1F71x	🜐	🜑	🜒	🜓	🜔	🜕	🜖	🜗	🜘	🜙	🜚	🜛	🜜	🜝	🜞	🜟
U+1F72x	🜠	🜡	🜢	🜣	🜤	🜥	🜦	🜧	🜨	🜩	🜪	🜫	🜬	🜭	🜮	🜯
U+1F73x	🜰	🜱	🜲	🜳	🜴	🜵	🜶	🜷	🜸	🜹	🜺	🜻	🜼	🜽	🜾	🜿
U+1F74x	🝀	🝁	🝂	🝃	🝄	🝅	🝆	🝇	🝈	🝉	🝊	🝋	🝌	🝍	🝎	🝏
U+1F75x	🝐	🝑	🝒	🝓	🝔	🝕	🝖	🝗	🝘	🝙	🝚	🝛	🝜	🝝	🝞	🝟
U+1F76x	🝠	🝡	🝢	🝣	🝤	🝥	🝦	🝧	🝨	🝩	🝪	🝫	🝬	🝭	🝮	🝯
U+1F77x	🝰	🝱	🝲	🝳	🝴	🝵	🝶	🝷	🝸	🝹	🝺	🝻	🝼	🝽	🝾	🝿
Notes
1.^ As of Unicode version 17.0


## Extenstions
Halfwidth and Fullwidth Forms is a Unicode block U+FF00–FFEF, provided so that older encodings containing both halfwidth and fullwidth characters can have lossless translation to/from Unicode. It is the second-to-last block of the Basic Multilingual Plane, followed only by the short Specials block at U+FFF0–FFFF. Its block name in Unicode 1.0 was Halfwidth and Fullwidth Variants.[4]

Range U+FF01–FF5E reproduces the characters of ASCII 21 to 7E as fullwidth forms. U+FF00 does not correspond to a fullwidth ASCII 20 (space character), since that role is already fulfilled by U+3000 "ideographic space".

Range U+FF61–FF9F encodes halfwidth forms of katakana and related punctuation in a transposition of A1 to DF in the JIS X 0201 encoding – see half-width kana.

The range U+FFA0–FFDC encodes halfwidth forms of compatibility jamo characters for Hangul, in a transposition of their 1974 standard layout. It is used in the mapping of some IBM encodings for Korean, such as IBM code page 933, which allows the use of the Shift Out and Shift In characters to shift to a double-byte character set.[5] Since the double-byte character set could contain compatibility jamo, halfwidth variants are needed to provide round-trip compatibility.[6][7]


Range U+FFE0–FFEE includes fullwidth and halfwidth symbols.

Block
Halfwidth and Fullwidth Forms[1][2]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+FF0x		！	＂	＃	＄	％	＆	＇	（	）	＊	＋	，	－	．	／
U+FF1x	０	１	２	３	４	５	６	７	８	９	：	；	＜	＝	＞	？
U+FF2x	＠	Ａ	Ｂ	Ｃ	Ｄ	Ｅ	Ｆ	Ｇ	Ｈ	Ｉ	Ｊ	Ｋ	Ｌ	Ｍ	Ｎ	Ｏ
U+FF3x	Ｐ	Ｑ	Ｒ	Ｓ	Ｔ	Ｕ	Ｖ	Ｗ	Ｘ	Ｙ	Ｚ	［	＼	］	＾	＿
U+FF4x	｀	ａ	ｂ	ｃ	ｄ	ｅ	ｆ	ｇ	ｈ	ｉ	ｊ	ｋ	ｌ	ｍ	ｎ	ｏ
U+FF5x	ｐ	ｑ	ｒ	ｓ	ｔ	ｕ	ｖ	ｗ	ｘ	ｙ	ｚ	｛	｜	｝	～	｟
U+FF6x	｠	｡	｢	｣	､	･	ｦ	ｧ	ｨ	ｩ	ｪ	ｫ	ｬ	ｭ	ｮ	ｯ
U+FF7x	ｰ	ｱ	ｲ	ｳ	ｴ	ｵ	ｶ	ｷ	ｸ	ｹ	ｺ	ｻ	ｼ	ｽ	ｾ	ｿ
U+FF8x	ﾀ	ﾁ	ﾂ	ﾃ	ﾄ	ﾅ	ﾆ	ﾇ	ﾈ	ﾉ	ﾊ	ﾋ	ﾌ	ﾍ	ﾎ	ﾏ
U+FF9x	ﾐ	ﾑ	ﾒ	ﾓ	ﾔ	ﾕ	ﾖ	ﾗ	ﾘ	ﾙ	ﾚ	ﾛ	ﾜ	ﾝ	ﾞ	ﾟ
U+FFAx	 HW 
HF	ﾡ	ﾢ	ﾣ	ﾤ	ﾥ	ﾦ	ﾧ	ﾨ	ﾩ	ﾪ	ﾫ	ﾬ	ﾭ	ﾮ	ﾯ
U+FFBx	ﾰ	ﾱ	ﾲ	ﾳ	ﾴ	ﾵ	ﾶ	ﾷ	ﾸ	ﾹ	ﾺ	ﾻ	ﾼ	ﾽ	ﾾ	
U+FFCx			ￂ	ￃ	ￄ	ￅ	ￆ	ￇ			ￊ	ￋ	ￌ	ￍ	ￎ	ￏ
U+FFDx			ￒ	ￓ	ￔ	ￕ	ￖ	ￗ			ￚ	ￛ	ￜ			
U+FFEx	￠	￡	￢	￣	￤	￥	￦		￨	￩	￪	￫	￬	￭	￮	
Notes
1.^ As of Unicode version 17.0
2.^ Grey areas indicate non-assigned code points
The block has variation sequences defined for East Asian punctuation positional variants.[8][9] They use U+FE00 VARIATION SELECTOR-1 (VS01) and U+FE01 VARIATION SELECTOR-2 (VS02):

Supplemental Mathematical Operators[1]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+2A0x	⨀	⨁	⨂	⨃	⨄	⨅	⨆	⨇	⨈	⨉	⨊	⨋	⨌	⨍	⨎	⨏
U+2A1x	⨐	⨑	⨒	⨓	⨔	⨕	⨖	⨗	⨘	⨙	⨚	⨛	⨜	⨝	⨞	⨟
U+2A2x	⨠	⨡	⨢	⨣	⨤	⨥	⨦	⨧	⨨	⨩	⨪	⨫	⨬	⨭	⨮	⨯
U+2A3x	⨰	⨱	⨲	⨳	⨴	⨵	⨶	⨷	⨸	⨹	⨺	⨻	⨼	⨽	⨾	⨿
U+2A4x	⩀	⩁	⩂	⩃	⩄	⩅	⩆	⩇	⩈	⩉	⩊	⩋	⩌	⩍	⩎	⩏
U+2A5x	⩐	⩑	⩒	⩓	⩔	⩕	⩖	⩗	⩘	⩙	⩚	⩛	⩜	⩝	⩞	⩟
U+2A6x	⩠	⩡	⩢	⩣	⩤	⩥	⩦	⩧	⩨	⩩	⩪	⩫	⩬	⩭	⩮	⩯
U+2A7x	⩰	⩱	⩲	⩳	⩴	⩵	⩶	⩷	⩸	⩹	⩺	⩻	⩼	⩽	⩾	⩿
U+2A8x	⪀	⪁	⪂	⪃	⪄	⪅	⪆	⪇	⪈	⪉	⪊	⪋	⪌	⪍	⪎	⪏
U+2A9x	⪐	⪑	⪒	⪓	⪔	⪕	⪖	⪗	⪘	⪙	⪚	⪛	⪜	⪝	⪞	⪟
U+2AAx	⪠	⪡	⪢	⪣	⪤	⪥	⪦	⪧	⪨	⪩	⪪	⪫	⪬	⪭	⪮	⪯
U+2ABx	⪰	⪱	⪲	⪳	⪴	⪵	⪶	⪷	⪸	⪹	⪺	⪻	⪼	⪽	⪾	⪿
U+2ACx	⫀	⫁	⫂	⫃	⫄	⫅	⫆	⫇	⫈	⫉	⫊	⫋	⫌	⫍	⫎	⫏
U+2ADx	⫐	⫑	⫒	⫓	⫔	⫕	⫖	⫗	⫘	⫙	⫚	⫛	⫝̸	⫝	⫞	⫟
U+2AEx	⫠	⫡	⫢	⫣	⫤	⫥	⫦	⫧	⫨	⫩	⫪	⫫	⫬	⫭	⫮	⫯
U+2AFx	⫰	⫱	⫲	⫳	⫴	⫵	⫶	⫷	⫸	⫹	⫺	⫻	⫼	⫽	⫾	⫿
Notes
1.^ As of Unicode version 17.0


Supplemental Arrows-B block
Main article: Supplemental Arrows-B (Unicode block)
The Supplemental Arrows-B block (U+2900–U+297F) contains arrows and arrow-like operators (arrow tails, crossing arrows, curved arrows, and harpoons).

Supplemental Arrows-B[1]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+290x	⤀	⤁	⤂	⤃	⤄	⤅	⤆	⤇	⤈	⤉	⤊	⤋	⤌	⤍	⤎	⤏
U+291x	⤐	⤑	⤒	⤓	⤔	⤕	⤖	⤗	⤘	⤙	⤚	⤛	⤜	⤝	⤞	⤟
U+292x	⤠	⤡	⤢	⤣	⤤	⤥	⤦	⤧	⤨	⤩	⤪	⤫	⤬	⤭	⤮	⤯
U+293x	⤰	⤱	⤲	⤳	⤴	⤵	⤶	⤷	⤸	⤹	⤺	⤻	⤼	⤽	⤾	⤿
U+294x	⥀	⥁	⥂	⥃	⥄	⥅	⥆	⥇	⥈	⥉	⥊	⥋	⥌	⥍	⥎	⥏
U+295x	⥐	⥑	⥒	⥓	⥔	⥕	⥖	⥗	⥘	⥙	⥚	⥛	⥜	⥝	⥞	⥟
U+296x	⥠	⥡	⥢	⥣	⥤	⥥	⥦	⥧	⥨	⥩	⥪	⥫	⥬	⥭	⥮	⥯
U+297x	⥰	⥱	⥲	⥳	⥴	⥵	⥶	⥷	⥸	⥹	⥺	⥻	⥼	⥽	⥾	⥿
Notes
1.^ As of Unicode version 17.0


Mahjong Tiles[1][2]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+1F00x	🀀	🀁	🀂	🀃	🀄	🀅	🀆	🀇	🀈	🀉	🀊	🀋	🀌	🀍	🀎	🀏
U+1F01x	🀐	🀑	🀒	🀓	🀔	🀕	🀖	🀗	🀘	🀙	🀚	🀛	🀜	🀝	🀞	🀟
U+1F02x	🀠	🀡	🀢	🀣	🀤	🀥	🀦	🀧	🀨	🀩	🀪	🀫				
Notes
1.^ As of Unicode version 17.0
2.^ Grey areas indicate non-assigned code points

Domino Tiles[1][2]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+1F03x	🀰	🀱	🀲	🀳	🀴	🀵	🀶	🀷	🀸	🀹	🀺	🀻	🀼	🀽	🀾	🀿
U+1F04x	🁀	🁁	🁂	🁃	🁄	🁅	🁆	🁇	🁈	🁉	🁊	🁋	🁌	🁍	🁎	🁏
U+1F05x	🁐	🁑	🁒	🁓	🁔	🁕	🁖	🁗	🁘	🁙	🁚	🁛	🁜	🁝	🁞	🁟
U+1F06x	🁠	🁡	🁢	🁣	🁤	🁥	🁦	🁧	🁨	🁩	🁪	🁫	🁬	🁭	🁮	🁯
U+1F07x	🁰	🁱	🁲	🁳	🁴	🁵	🁶	🁷	🁸	🁹	🁺	🁻	🁼	🁽	🁾	🁿
U+1F08x	🂀	🂁	🂂	🂃	🂄	🂅	🂆	🂇	🂈	🂉	🂊	🂋	🂌	🂍	🂎	🂏
U+1F09x	🂐	🂑	🂒	🂓												
Notes
^ As of Unicode version 17.0
^ Grey areas indicate non-assigned code points

Chart
Playing Cards[1][2]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+1F0Ax	🂠	🂡	🂢	🂣	🂤	🂥	🂦	🂧	🂨	🂩	🂪	🂫	🂬	🂭	🂮	
U+1F0Bx		🂱	🂲	🂳	🂴	🂵	🂶	🂷	🂸	🂹	🂺	🂻	🂼	🂽	🂾	🂿
U+1F0Cx		🃁	🃂	🃃	🃄	🃅	🃆	🃇	🃈	🃉	🃊	🃋	🃌	🃍	🃎	🃏
U+1F0Dx		🃑	🃒	🃓	🃔	🃕	🃖	🃗	🃘	🃙	🃚	🃛	🃜	🃝	🃞	🃟
U+1F0Ex	🃠	🃡	🃢	🃣	🃤	🃥	🃦	🃧	🃨	🃩	🃪	🃫	🃬	🃭	🃮	🃯
U+1F0Fx	🃰	🃱	🃲	🃳	🃴	🃵										
Notes
1.^ As of Unicode version 17.0
2.^ Grey areas indicate non-assigned code points

Block
<?>
You may need rendering support to display the uncommon Unicode characters in this table correctly.
Chess Symbols[1][2]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+1FA0x	🨀	🨁	🨂	🨃	🨄	🨅	🨆	🨇	🨈	🨉	🨊	🨋	🨌	🨍	🨎	🨏
U+1FA1x	🨐	🨑	🨒	🨓	🨔	🨕	🨖	🨗	🨘	🨙	🨚	🨛	🨜	🨝	🨞	🨟
U+1FA2x	🨠	🨡	🨢	🨣	🨤	🨥	🨦	🨧	🨨	🨩	🨪	🨫	🨬	🨭	🨮	🨯
U+1FA3x	🨰	🨱	🨲	🨳	🨴	🨵	🨶	🨷	🨸	🨹	🨺	🨻	🨼	🨽	🨾	🨿
U+1FA4x	🩀	🩁	🩂	🩃	🩄	🩅	🩆	🩇	🩈	🩉	🩊	🩋	🩌	🩍	🩎	🩏
U+1FA5x	🩐	🩑	🩒	🩓	🩔	🩕	🩖	🩗								
U+1FA6x	🩠	🩡	🩢	🩣	🩤	🩥	🩦	🩧	🩨	🩩	🩪	🩫	🩬	🩭		
Notes
1.^ As of Unicode version 17.0
2.^ Grey areas indicate non-assigned code points

Chart
Emoticons[1]
Official Unicode Consortium code chart (PDF)
 	0	1	2	3	4	5	6	7	8	9	A	B	C	D	E	F
U+1F60x	😀	😁	😂	😃	😄	😅	😆	😇	😈	😉	😊	😋	😌	😍	😎	😏
U+1F61x	😐	😑	😒	😓	😔	😕	😖	😗	😘	😙	😚	😛	😜	😝	😞	😟
U+1F62x	😠	😡	😢	😣	😤	😥	😦	😧	😨	😩	😪	😫	😬	😭	😮	😯
U+1F63x	😰	😱	😲	😳	😴	😵	😶	😷	😸	😹	😺	😻	😼	😽	😾	😿
U+1F64x	🙀	🙁	🙂	🙃	🙄	🙅	🙆	🙇	🙈	🙉	🙊	🙋	🙌	🙍	🙎	🙏
Notes
1.^ As of Unicode version 17.0

Variant forms
Each emoticon has two variants:

U+FE0E (VARIATION SELECTOR-15) selects text presentation (e.g. 😊︎ 😐︎ ☹︎),
U+FE0F (VARIATION SELECTOR-16) selects emoji-style (e.g. 😊️ 😐️ ☹️).
If there is no variation selector appended, the default is the emoji-style. Example:

Unicode code points	Result
U+1F610 (NEUTRAL FACE)	😐
U+1F610 (NEUTRAL FACE), U+FE0E (VARIATION SELECTOR-15)	😐︎
U+1F610 (NEUTRAL FACE), U+FE0F (VARIATION SELECTOR-16)	😐️
Emoji modifiers
Main article: Emoji modifiers
The Miscellaneous Symbols and Pictographs block has 54 emoji that represent people or body parts. A set of "Emoji modifiers" are defined for emojis that represent people or body parts. These are modifier characters intended to define the skin colour to be used for the emoji. The draft document suggesting the introduction of this system for the representation of "human diversity" was submitted in 2015 by Mark Davis of Google and Peter Edberg of Apple Inc.[8] Five symbol modifier characters were added with Unicode 8.0 to provide a range of skin tones for human emoji. These modifiers are called EMOJI MODIFIER FITZPATRICK TYPE-1-2, -3, -4, -5, and -6 (U+1F3FB–U+1F3FF): 🏻 🏼 🏽 🏾 🏿. They are based on the Fitzpatrick scale for classifying human skin color.

Human emoji
U+	1F645	1F646	1F647	1F64B	1F64C	1F64D	1F64E	1F64F
emoji	🙅	🙆	🙇	🙋	🙌	🙍	🙎	🙏
FITZ-1-2	🙅🏻	🙆🏻	🙇🏻	🙋🏻	🙌🏻	🙍🏻	🙎🏻	🙏🏻
FITZ-3	🙅🏼	🙆🏼	🙇🏼	🙋🏼	🙌🏼	🙍🏼	🙎🏼	🙏🏼
FITZ-4	🙅🏽	🙆🏽	🙇🏽	🙋🏽	🙌🏽	🙍🏽	🙎🏽	🙏🏽
FITZ-5	🙅🏾	🙆🏾	🙇🏾	🙋🏾	🙌🏾	🙍🏾	🙎🏾	🙏🏾
FITZ-6	🙅🏿	🙆🏿	🙇🏿	🙋🏿	🙌🏿	🙍🏿	🙎🏿	🙏🏿
Additional human emoji can be found in other Unicode blocks: Dingbats, Miscellaneous Symbols, Miscellaneous Symbols and Pictographs, Supplemental Symbols and Pictographs, Symbols and Pictographs Extended-A and Transport and Map Symbols.

Emoji
The Transport and Map Symbols block contains 106 emoji: U+1F680–U+1F6C5, U+1F6CB–U+1F6D2, U+1F6D5–U+1F6D8, U+1F6DC–U+1F6E5, U+1F6E9, U+1F6EB–U+1F6EC, U+1F6F0 and U+1F6F3–U+1F6FC.[3][4]

The block has 46 standardized variants defined to specify emoji-style (U+FE0F VS16) or text presentation (U+FE0E VS15) for the following 23 base characters: U+1F687, U+1F68D, U+1F691, U+1F694, U+1F698, U+1F6AD, U+1F6B2, U+1F6B9–U+1F6BA, U+1F6BC, U+1F6CB, U+1F6CD–U+1F6CF, U+1F6E0–U+1F6E5, U+1F6E9, U+1F6F0 and U+1F6F3.[5]

Emoji variation sequences
U+	1F687	1F68D	1F691	1F694	1F698	1F6AD	1F6B2	1F6B9	1F6BA	1F6BC	1F6CB	1F6CD
default presentation	emoji	emoji	emoji	emoji	emoji	emoji	emoji	emoji	emoji	emoji	text	text
base code point	🚇	🚍	🚑	🚔	🚘	🚭	🚲	🚹	🚺	🚼	🛋	🛍
base+VS15 (text)	🚇︎	🚍︎	🚑︎	🚔︎	🚘︎	🚭︎	🚲︎	🚹︎	🚺︎	🚼︎	🛋︎	🛍︎
base+VS16 (emoji)	🚇️	🚍️	🚑️	🚔️	🚘️	🚭️	🚲️	🚹️	🚺️	🚼️	🛋️	🛍️
U+	1F6CE	1F6CF	1F6E0	1F6E1	1F6E2	1F6E3	1F6E4	1F6E5	1F6E9	1F6F0	1F6F3
default presentation	text	text	text	text	text	text	text	text	text	text	text
base code point	🛎	🛏	🛠	🛡	🛢	🛣	🛤	🛥	🛩	🛰	🛳
base+VS15 (text)	🛎︎	🛏︎	🛠︎	🛡︎	🛢︎	🛣︎	🛤︎	🛥︎	🛩︎	🛰︎	🛳︎
base+VS16 (emoji)	🛎️	🛏️	🛠️	🛡️	🛢️	🛣️	🛤️	🛥️	🛩️	🛰️	🛳️
Emoji modifiers
Main article: Emoji modifiers
The Transport and Map Symbols block has six emoji that represent people or body parts. They can be modified using U+1F3FB–U+1F3FF to provide for a range of human skin color using the Fitzpatrick scale:[4]

Human emoji
U+	1F6A3	1F6B4	1F6B5	1F6B6	1F6C0	1F6CC
emoji	🚣	🚴	🚵	🚶	🛀	🛌
FITZ-1-2	🚣🏻	🚴🏻	🚵🏻	🚶🏻	🛀🏻	🛌🏻
FITZ-3	🚣🏼	🚴🏼	🚵🏼	🚶🏼	🛀🏼	🛌🏼
FITZ-4	🚣🏽	🚴🏽	🚵🏽	🚶🏽	🛀🏽	🛌🏽
FITZ-5	🚣🏾	🚴🏾	🚵🏾	🚶🏾	🛀🏾	🛌🏾
FITZ-6	🚣🏿	🚴🏿	🚵🏿	🚶🏿	🛀🏿	🛌🏿
Additional human emoji can be found in other Unicode blocks: Dingbats, Emoticons, Miscellaneous Symbols, Miscellaneous Symbols and Pictographs, Supplemental Symbols and Pictographs and Symbols and Pictographs Extended-A.

Emoji
The Unicode 14.0 Supplemental Symbols and Pictographs block contains 242 emoji,[3][4] consisting of all the non-Typikon symbols except for the rifle and the pentathlon symbol. The rifle and the pentathlon emoji have been rejected due to their controversy, analogous to the redesign of the pistol emoji.[5]

U+1F90C – U+1F93A
U+1F93C – U+1F945
U+1F947 – U+1F9FF
Emoji modifiers
Main article: Emoji modifiers
The Supplemental Symbols and Pictographs block has 46 emoji that represent people or body parts. These are designed to be used with the set of "Emoji modifiers" defined in the Miscellaneous Symbols and Pictographs block. These are modifier characters intended to define the skin colour to be used for the emoji, based on the Fitzpatrick scale:[4]

U+1F3FB EMOJI MODIFIER FITZPATRICK TYPE-1-2
U+1F3FC EMOJI MODIFIER FITZPATRICK TYPE-3
U+1F3FD EMOJI MODIFIER FITZPATRICK TYPE-4
U+1F3FE EMOJI MODIFIER FITZPATRICK TYPE-5
U+1F3FF EMOJI MODIFIER FITZPATRICK TYPE-6
The following table shows the full combinations of the "human emoji" characters with each of the five modifiers, which should display each character in each of the five skin tones provided a suitable font is installed on the system and the rendering software is capable of handling modifier characters:

Human emoji
U+	1F90C	1F90F	1F918	1F919	1F91A	1F91B	1F91C	1F91D	1F91E	1F91F	1F926	1F930
emoji	🤌	🤏	🤘	🤙	🤚	🤛	🤜	🤝	🤞	🤟	🤦	🤰
FITZ-1-2	🤌🏻	🤏🏻	🤘🏻	🤙🏻	🤚🏻	🤛🏻	🤜🏻	🤝🏻	🤞🏻	🤟🏻	🤦🏻	🤰🏻
FITZ-3	🤌🏼	🤏🏼	🤘🏼	🤙🏼	🤚🏼	🤛🏼	🤜🏼	🤝🏼	🤞🏼	🤟🏼	🤦🏼	🤰🏼
FITZ-4	🤌🏽	🤏🏽	🤘🏽	🤙🏽	🤚🏽	🤛🏽	🤜🏽	🤝🏽	🤞🏽	🤟🏽	🤦🏽	🤰🏽
FITZ-5	🤌🏾	🤏🏾	🤘🏾	🤙🏾	🤚🏾	🤛🏾	🤜🏾	🤝🏾	🤞🏾	🤟🏾	🤦🏾	🤰🏾
FITZ-6	🤌🏿	🤏🏿	🤘🏿	🤙🏿	🤚🏿	🤛🏿	🤜🏿	🤝🏿	🤞🏿	🤟🏿	🤦🏿	🤰🏿
U+	1F931	1F932	1F933	1F934	1F935	1F936	1F937	1F938	1F939	1F93C	1F93D	1F93E
emoji	🤱	🤲	🤳	🤴	🤵	🤶	🤷	🤸	🤹	🤼	🤽	🤾
FITZ-1-2	🤱🏻	🤲🏻	🤳🏻	🤴🏻	🤵🏻	🤶🏻	🤷🏻	🤸🏻	🤹🏻	🤼🏻	🤽🏻	🤾🏻
FITZ-3	🤱🏼	🤲🏼	🤳🏼	🤴🏼	🤵🏼	🤶🏼	🤷🏼	🤸🏼	🤹🏼	🤼🏼	🤽🏼	🤾🏼
FITZ-4	🤱🏽	🤲🏽	🤳🏽	🤴🏽	🤵🏽	🤶🏽	🤷🏽	🤸🏽	🤹🏽	🤼🏽	🤽🏽	🤾🏽
FITZ-5	🤱🏾	🤲🏾	🤳🏾	🤴🏾	🤵🏾	🤶🏾	🤷🏾	🤸🏾	🤹🏾	🤼🏾	🤽🏾	🤾🏾
FITZ-6	🤱🏿	🤲🏿	🤳🏿	🤴🏿	🤵🏿	🤶🏿	🤷🏿	🤸🏿	🤹🏿	🤼🏿	🤽🏿	🤾🏿
U+	1F977	1F9B5	1F9B6	1F9B8	1F9B9	1F9BB	1F9CD	1F9CE	1F9CF	1F9D1	1F9D2	1F9D3
emoji	🥷	🦵	🦶	🦸	🦹	🦻	🧍	🧎	🧏	🧑	🧒	🧓
FITZ-1-2	🥷🏻	🦵🏻	🦶🏻	🦸🏻	🦹🏻	🦻🏻	🧍🏻	🧎🏻	🧏🏻	🧑🏻	🧒🏻	🧓🏻
FITZ-3	🥷🏼	🦵🏼	🦶🏼	🦸🏼	🦹🏼	🦻🏼	🧍🏼	🧎🏼	🧏🏼	🧑🏼	🧒🏼	🧓🏼
FITZ-4	🥷🏽	🦵🏽	🦶🏽	🦸🏽	🦹🏽	🦻🏽	🧍🏽	🧎🏽	🧏🏽	🧑🏽	🧒🏽	🧓🏽
FITZ-5	🥷🏾	🦵🏾	🦶🏾	🦸🏾	🦹🏾	🦻🏾	🧍🏾	🧎🏾	🧏🏾	🧑🏾	🧒🏾	🧓🏾
FITZ-6	🥷🏿	🦵🏿	🦶🏿	🦸🏿	🦹🏿	🦻🏿	🧍🏿	🧎🏿	🧏🏿	🧑🏿	🧒🏿	🧓🏿
U+	1F9D4	1F9D5	1F9D6	1F9D7	1F9D8	1F9D9	1F9DA	1F9DB	1F9DC	1F9DD
emoji	🧔	🧕	🧖	🧗	🧘	🧙	🧚	🧛	🧜	🧝
FITZ-1-2	🧔🏻	🧕🏻	🧖🏻	🧗🏻	🧘🏻	🧙🏻	🧚🏻	🧛🏻	🧜🏻	🧝🏻
FITZ-3	🧔🏼	🧕🏼	🧖🏼	🧗🏼	🧘🏼	🧙🏼	🧚🏼	🧛🏼	🧜🏼	🧝🏼
FITZ-4	🧔🏽	🧕🏽	🧖🏽	🧗🏽	🧘🏽	🧙🏽	🧚🏽	🧛🏽	🧜🏽	🧝🏽
FITZ-5	🧔🏾	🧕🏾	🧖🏾	🧗🏾	🧘🏾	🧙🏾	🧚🏾	🧛🏾	🧜🏾	🧝🏾
FITZ-6	🧔🏿	🧕🏿	🧖🏿	🧗🏿	🧘🏿	🧙🏿	🧚🏿	🧛🏿	🧜🏿	🧝🏿
Additional human emoji can be found in other Unicode blocks: Dingbats, Emoticons, Miscellaneous Symbols, Miscellaneous Symbols and Pictographs, Symbols and Pictographs Extended-A and Transport and Map Symbols.




































Supplemental Symbols and Pictographs
Typicon symbols
1F900	 🤀 	Circled Cross Formee With Four Dots
1F901	 🤁 	Circled Cross Formee With Two Dots
1F902	 🤂 	Circled Cross Formee
 	 	→	2720 ✠ maltese cross
1F903	 🤃 	Left Half Circle With Four Dots
1F904	 🤄 	Left Half Circle With Three Dots
1F905	 🤅 	Left Half Circle With Two Dots
1F906	 🤆 	Left Half Circle With Dot
1F907	 🤇 	Left Half Circle
1F908	 🤈 	Downward Facing Hook
1F909	 🤉 	Downward Facing Notched Hook
1F90A	 🤊 	Downward Facing Hook With Dot
1F90B	 🤋 	Downward Facing Notched Hook With Dot
Hand symbol
1F90C	 🤌 	Pinched Fingers
Colored heart symbols
For use with emoji. Constitute a set as follows: 2764, 1F499-1F49C, 1F5A4, 1F90D, 1F90E, 1F9E1, and 1FA75-1FA77.
1F90D	 🤍 	White Heart
1F90E	 🤎 	Brown Heart
Hand symbol
1F90F	 🤏 	Pinching Hand
Emoticon faces
1F910	 🤐 	Zipper-Mouth Face
1F911	 🤑 	Money-Mouth Face
1F912	 🤒 	Face With Thermometer
1F913	 🤓 	Nerd Face
1F914	 🤔 	Thinking Face
1F915	 🤕 	Face With Head-Bandage
1F916	 🤖 	Robot Face
 	 	→	1F47E 👾 alien monster
1F917	 🤗 	Hugging Face
Hand symbols
1F918	 🤘 	Sign Of The Horns
1F919	 🤙 	Call Me Hand
1F91A	 🤚 	Raised Back Of Hand
1F91B	 🤛 	Left-Facing Fist
 	 	→	1FAF2 🫲 leftwards hand
1F91C	 🤜 	Right-Facing Fist
 	 	→	1FAF1 🫱 rightwards hand
1F91D	 🤝 	Handshake
1F91E	 🤞 	Hand With Index And Middle Fingers Crossed
 	 	→	1FAF0 🫰 hand with index finger and thumb crossed
1F91F	 🤟 	I Love You Hand Sign
 	 	•	can be abbreviated ILY
Emoticon faces
1F920	 🤠 	Face With Cowboy Hat
1F921	 🤡 	Clown Face
1F922	 🤢 	Nauseated Face
1F923	 🤣 	Rolling On The Floor Laughing
 	 	=	rofl, rotfl
1F924	 🤤 	Drooling Face
1F925	 🤥 	Lying Face
1F926	 🤦 	Face Palm
 	 	=	frustration, disbelief
1F927	 🤧 	Sneezing Face
 	 	=	Gesundheit
1F928	 🤨 	Face With One Eyebrow Raised
1F929	 🤩 	Grinning Face With Star Eyes
1F92A	 🤪 	Grinning Face With One Large And One Small Eye
1F92B	 🤫 	Face With Finger Covering Closed Lips
1F92C	 🤬 	Serious Face With Symbols Covering Mouth
1F92D	 🤭 	Smiling Face With Smiling Eyes And Hand Covering Mouth
1F92E	 🤮 	Face With Open Mouth Vomiting
1F92F	 🤯 	Shocked Face With Exploding Head
Portrait and role symbols
1F930	 🤰 	Pregnant Woman
 	 	→	1FAC4 🫄 pregnant person
1F931	 🤱 	Breast-Feeding
1F932	 🤲 	Palms Up Together
 	 	•	used for prayer in some cultures
1F933	 🤳 	Selfie
 	 	•	typically used with face or human figure on the left
1F934	 🤴 	Prince
 	 	→	1F478 👸 princess
1F935	 🤵 	Man In Tuxedo
 	 	•	appearance for groom, may be paired with 1F470 👰
 	 	→	1F470 👰 bride with veil
1F936	 🤶 	Mother Christmas
 	 	=	Mrs. Claus
 	 	→	1F385 🎅 father christmas
1F937	 🤷 	Shrug
Sport symbols
1F938	 🤸 	Person Doing Cartwheel
 	 	=	gymnastics
1F939	 🤹 	Juggling
1F93A	 🤺 	Fencer
 	 	=	fencing
 	 	→	2694 ⚔ crossed swords
1F93B	 🤻 	Modern Pentathlon
1F93C	 🤼 	Wrestlers
 	 	=	wrestling
1F93D	 🤽 	Water Polo
1F93E	 🤾 	Handball
1F93F	 🤿 	Diving Mask
Miscellaneous symbols
1F940	 🥀 	Wilted Flower
 	 	→	1F339 🌹 rose
1F941	 🥁 	Drum With Drumsticks
1F942	 🥂 	Clinking Glasses
 	 	=	celebration, formal toasting
 	 	→	1F37B 🍻 clinking beer mugs
1F943	 🥃 	Tumbler Glass
 	 	=	whisky
 	 	•	typically shown with ice
 	 	→	1F378 🍸 cocktail glass
1F944	 🥄 	Spoon
 	 	→	1F374 🍴 fork and knife
1F945	 🥅 	Goal Net
1F946	 🥆 	Rifle
 	 	=	marksmanship, shooting, hunting
1F947	 🥇 	First Place Medal
 	 	=	gold medal
 	 	→	1F3C5 🏅 sports medal
1F948	 🥈 	Second Place Medal
 	 	=	silver medal
1F949	 🥉 	Third Place Medal
 	 	=	bronze medal
1F94A	 🥊 	Boxing Glove
 	 	=	boxing
1F94B	 🥋 	Martial Arts Uniform
 	 	=	judo, karate, taekwondo
1F94C	 🥌 	Curling Stone
1F94D	 🥍 	Lacrosse Stick And Ball
1F94E	 🥎 	Softball
1F94F	 🥏 	Flying Disc
Food symbols
1F950	 🥐 	Croissant
1F951	 🥑 	Avocado
1F952	 🥒 	Cucumber
 	 	=	pickle
1F953	 🥓 	Bacon
1F954	 🥔 	Potato
1F955	 🥕 	Carrot
1F956	 🥖 	Baguette Bread
 	 	=	French bread
1F957	 🥗 	Green Salad
1F958	 🥘 	Shallow Pan Of Food
 	 	=	paella, casserole
1F959	 🥙 	Stuffed Flatbread
 	 	=	döner kebab, falafel, gyro, shawarma
1F95A	 🥚 	Egg
 	 	=	chicken egg
1F95B	 🥛 	Glass Of Milk
 	 	=	milk
 	 	→	1FAD7 🫗 pouring liquid
1F95C	 🥜 	Peanuts
1F95D	 🥝 	Kiwifruit
1F95E	 🥞 	Pancakes
 	 	=	hotcakes, crêpes, blini
 	 	•	sweet or savory
1F95F	 🥟 	Dumpling
 	 	=	potsticker, gyooza, jiaozi, pierogi, empanada
1F960	 🥠 	Fortune Cookie
1F961	 🥡 	Takeout Box
 	 	=	take-away box, oyster pail
1F962	 🥢 	Chopsticks
 	 	=	kuaizi, hashi, jeotgarak
1F963	 🥣 	Bowl With Spoon
 	 	•	can indicate breakfast, cereal, congee, etc.
1F964	 🥤 	Cup With Straw
 	 	•	can indicate soda, juice, etc.
1F965	 🥥 	Coconut
1F966	 🥦 	Broccoli
1F967	 🥧 	Pie
 	 	•	may be sweet or savory
1F968	 🥨 	Pretzel
 	 	•	can indicate twistiness, intricacy
1F969	 🥩 	Cut Of Meat
 	 	=	porkchop, chop, steak
1F96A	 🥪 	Sandwich
1F96B	 🥫 	Canned Food
1F96C	 🥬 	Leafy Green
 	 	•	intended to represent cooked green vegetables such as bok choy, kale, etc.
1F96D	 🥭 	Mango
1F96E	 🥮 	Moon Cake
1F96F	 🥯 	Bagel
Faces
1F970	 🥰 	Smiling Face With Smiling Eyes And Three Hearts
1F971	 🥱 	Yawning Face
1F972	 🥲 	Smiling Face With Tear
1F973	 🥳 	Face With Party Horn And Party Hat
1F974	 🥴 	Face With Uneven Eyes And Wavy Mouth
1F975	 🥵 	Overheated Face
1F976	 🥶 	Freezing Face
1F977	 🥷 	Ninja
1F978	 🥸 	Disguised Face
1F979	 🥹 	Face Holding Back Tears
1F97A	 🥺 	Face With Pleading Eyes
Clothing
1F97B	 🥻 	Sari
1F97C	 🥼 	Lab Coat
1F97D	 🥽 	Goggles
1F97E	 🥾 	Hiking Boot
1F97F	 🥿 	Flat Shoe
Animal symbols
1F980	 🦀 	Crab
 	 	•	used for Cancer
 	 	→	264B ♋ cancer
1F981	 🦁 	Lion Face
 	 	•	used for Leo
 	 	→	264C ♌ leo
1F982	 🦂 	Scorpion
 	 	•	used for Scorpio
 	 	→	264F ♏ scorpius
1F983	 🦃 	Turkey
1F984	 🦄 	Unicorn Face
1F985	 🦅 	Eagle
1F986	 🦆 	Duck
1F987	 🦇 	Bat
1F988	 🦈 	Shark
1F989	 🦉 	Owl
1F98A	 🦊 	Fox Face
1F98B	 🦋 	Butterfly
1F98C	 🦌 	Deer
1F98D	 🦍 	Gorilla
1F98E	 🦎 	Lizard
1F98F	 🦏 	Rhinoceros
1F990	 🦐 	Shrimp
1F991	 🦑 	Squid
1F992	 🦒 	Giraffe Face
1F993	 🦓 	Zebra Face
1F994	 🦔 	Hedgehog
1F995	 🦕 	Sauropod
 	 	•	includes Brontosaurus, Diplodocus, Brachiosaurus
1F996	 🦖 	T-Rex
 	 	=	Tyrannosaurus rex
1F997	 🦗 	Cricket
1F998	 🦘 	Kangaroo
1F999	 🦙 	Llama
1F99A	 🦚 	Peacock
1F99B	 🦛 	Hippopotamus
1F99C	 🦜 	Parrot
1F99D	 🦝 	Raccoon
1F99E	 🦞 	Lobster
1F99F	 🦟 	Mosquito
1F9A0	 🦠 	Microbe
 	 	•	microorganism, intended to cover bacteria, viruses, amoebas, etc.
1F9A1	 🦡 	Badger
1F9A2	 🦢 	Swan
1F9A3	 🦣 	Mammoth
 	 	•	indicates great size
1F9A4	 🦤 	Dodo
 	 	•	indicates extinction
1F9A5	 🦥 	Sloth
1F9A6	 🦦 	Otter
1F9A7	 🦧 	Orangutan
1F9A8	 🦨 	Skunk
1F9A9	 🦩 	Flamingo
1F9AA	 🦪 	Oyster
1F9AB	 🦫 	Beaver
1F9AC	 🦬 	Bison
1F9AD	 🦭 	Seal
Accessibility symbols
1F9AE	 🦮 	Guide Dog
1F9AF	 🦯 	Probing Cane
Emoji components
The characters in the range 1F9B0-1F9B3 are intended to be used in emoji ZWJ sequences to indicate hair style.
1F9B0	 🦰 	Emoji Component Red Hair
1F9B1	 🦱 	Emoji Component Curly Hair
1F9B2	 🦲 	Emoji Component Bald
1F9B3	 🦳 	Emoji Component White Hair
Body parts
1F9B4	 🦴 	Bone
1F9B5	 🦵 	Leg
1F9B6	 🦶 	Foot
1F9B7	 🦷 	Tooth
Role symbols
1F9B8	 🦸 	Superhero
1F9B9	 🦹 	Supervillain
Accessibility symbols
1F9BA	 🦺 	Safety Vest
1F9BB	 🦻 	Ear With Hearing Aid
1F9BC	 🦼 	Motorized Wheelchair
1F9BD	 🦽 	Manual Wheelchair
1F9BE	 🦾 	Mechanical Arm
1F9BF	 🦿 	Mechanical Leg
Food symbols
1F9C0	 🧀 	Cheese Wedge
1F9C1	 🧁 	Cupcake
1F9C2	 🧂 	Salt Shaker
1F9C3	 🧃 	Beverage Box
1F9C4	 🧄 	Garlic
1F9C5	 🧅 	Onion
1F9C6	 🧆 	Falafel
1F9C7	 🧇 	Waffle
1F9C8	 🧈 	Butter
1F9C9	 🧉 	Mate Drink
1F9CA	 🧊 	Ice Cube
1F9CB	 🧋 	Bubble Tea
Fantasy being
1F9CC	 🧌 	Troll
Portrait and accessibility symbols
1F9CD	 🧍 	Standing Person
1F9CE	 🧎 	Kneeling Person
1F9CF	 🧏 	Deaf Person
Portrait and role symbols
1F9D0	 🧐 	Face With Monocle
1F9D1	 🧑 	Adult
 	 	•	no specified gender
 	 	→	1F468 👨 man
 	 	→	1F469 👩 woman
1F9D2	 🧒 	Child
 	 	•	no specified gender
 	 	→	1F466 👦 boy
 	 	→	1F467 👧 girl
1F9D3	 🧓 	Older Adult
 	 	•	no specified gender
 	 	→	1F474 👴 older man
 	 	→	1F475 👵 older woman
1F9D4	 🧔 	Bearded Person
1F9D5	 🧕 	Person With Headscarf
 	 	=	woman's headscarf, hijab
1F9D6	 🧖 	Person In Steamy Room
 	 	=	sauna, steam room
1F9D7	 🧗 	Person Climbing
1F9D8	 🧘 	Person In Lotus Position
 	 	=	yoga, meditation
Fantasy beings
1F9D9	 🧙 	Mage
 	 	=	wizard, witch, sorcerer, sorceress
1F9DA	 🧚 	Fairy
1F9DB	 🧛 	Vampire
1F9DC	 🧜 	Merperson
 	 	=	mermaid, merman
1F9DD	 🧝 	Elf
1F9DE	 🧞 	Genie
1F9DF	 🧟 	Zombie
Miscellaneous symbols
1F9E0	 🧠 	Brain
1F9E1	 🧡 	Orange Heart
 	 	→	1F499 💙 blue heart
 	 	→	1F90D 🤍 white heart
1F9E2	 🧢 	Billed Cap
 	 	=	baseball cap
1F9E3	 🧣 	Scarf
1F9E4	 🧤 	Gloves
1F9E5	 🧥 	Coat
1F9E6	 🧦 	Socks
Activities
1F9E7	 🧧 	Red Gift Envelope
 	 	•	contains a monetary gift in East and Southeast Asia
1F9E8	 🧨 	Firecracker
1F9E9	 🧩 	Jigsaw Puzzle Piece
Objects
1F9EA	 🧪 	Test Tube
1F9EB	 🧫 	Petri Dish
1F9EC	 🧬 	Dna Double Helix
1F9ED	 🧭 	Compass
1F9EE	 🧮 	Abacus
1F9EF	 🧯 	Fire Extinguisher
1F9F0	 🧰 	Toolbox
1F9F1	 🧱 	Brick
1F9F2	 🧲 	Magnet
1F9F3	 🧳 	Luggage
1F9F4	 🧴 	Lotion Bottle
1F9F5	 🧵 	Spool Of Thread
1F9F6	 🧶 	Ball Of Yarn
1F9F7	 🧷 	Safety Pin
1F9F8	 🧸 	Teddy Bear
1F9F9	 🧹 	Broom
1F9FA	 🧺 	Basket
1F9FB	 🧻 	Roll Of Paper
1F9FC	 🧼 	Bar Of Soap
1F9FD	 🧽 	Sponge
1F9FE	 🧾 	Receipt
1F9FF	 🧿 	Nazar Amulet


Transport and Map Symbols
Vehicles
1F680	 🚀 	Rocket
 	 	→	1F66C 🙬 leftwards rocket
1F681	 🚁 	Helicopter
 	 	→	2708 ✈ airplane
1F682	 🚂 	Steam Locomotive
 	 	→	1F6F2 🛲 diesel locomotive
1F683	 🚃 	Railway Car
1F684	 🚄 	High-Speed Train
1F685	 🚅 	High-Speed Train With Bullet Nose
1F686	 🚆 	Train
 	 	=	intercity train
1F687	 🚇 	Metro
 	 	=	subway, underground train
1F688	 🚈 	Light Rail
1F689	 🚉 	Station
 	 	=	train, subway station
1F68A	 🚊 	Tram
1F68B	 🚋 	Tram Car
1F68C	 🚌 	Bus
1F68D	 🚍 	Oncoming Bus
1F68E	 🚎 	Trolleybus
1F68F	 🚏 	Bus Stop
1F690	 🚐 	Minibus
1F691	 🚑 	Ambulance
1F692	 🚒 	Fire Engine
 	 	→	1F6F1 🛱 oncoming fire engine
1F693	 🚓 	Police Car
1F694	 🚔 	Oncoming Police Car
1F695	 🚕 	Taxi
1F696	 🚖 	Oncoming Taxi
1F697	 🚗 	Automobile
1F698	 🚘 	Oncoming Automobile
1F699	 🚙 	Recreational Vehicle
1F69A	 🚚 	Delivery Truck
 	 	→	26DF ⛟ black truck
1F69B	 🚛 	Articulated Lorry
1F69C	 🚜 	Tractor
1F69D	 🚝 	Monorail
1F69E	 🚞 	Mountain Railway
1F69F	 🚟 	Suspension Railway
1F6A0	 🚠 	Mountain Cableway
1F6A1	 🚡 	Aerial Tramway
1F6A2	 🚢 	Ship
 	 	=	cruise line vacation
 	 	→	26F4 ⛴ ferry
 	 	→	1F6F3 🛳 passenger ship
1F6A3	 🚣 	Rowboat
 	 	→	26F5 ⛵ sailboat
1F6A4	 🚤 	Speedboat
 	 	→	1F6E5 🛥 motor boat
Traffic signs
1F6A5	 🚥 	Horizontal Traffic Light
1F6A6	 🚦 	Vertical Traffic Light
1F6A7	 🚧 	Construction Sign
 	 	→	26CF ⛏ pick
 	 	→	1F3D7 🏗 building construction
1F6A8	 🚨 	Police Cars Revolving Light
 	 	=	rotating beacon
Signage and other symbols
1F6A9	 🚩 	Triangular Flag On Post
 	 	=	location information
 	 	→	26F3 ⛳ flag in hole
 	 	→	1F3F1 🏱 white pennant
1F6AA	 🚪 	Door
1F6AB	 🚫 	No Entry Sign
 	 	→	20E0 ◌⃠ combining enclosing circle backslash
 	 	→	26D4 ⛔ no entry
 	 	→	1F6C7 🛇 prohibited sign
1F6AC	 🚬 	Smoking Symbol
1F6AD	 🚭 	No Smoking Symbol
1F6AE	 🚮 	Put Litter In Its Place Symbol
1F6AF	 🚯 	Do Not Litter Symbol
1F6B0	 🚰 	Potable Water Symbol
1F6B1	 🚱 	Non-Potable Water Symbol
1F6B2	 🚲 	Bicycle
1F6B3	 🚳 	No Bicycles
1F6B4	 🚴 	Bicyclist
1F6B5	 🚵 	Mountain Bicyclist
1F6B6	 🚶 	Pedestrian
 	 	=	walking
1F6B7	 🚷 	No Pedestrians
1F6B8	 🚸 	Children Crossing
1F6B9	 🚹 	Mens Symbol
 	 	=	man symbol
 	 	=	men's restroom
 	 	→	1FBC5 🯅 stick figure
1F6BA	 🚺 	Womens Symbol
 	 	=	woman symbol
 	 	=	women's restroom
 	 	→	1FBC9 🯉 stick figure with dress
1F6BB	 🚻 	Restroom
 	 	=	man and woman symbol with divider
 	 	=	unisex restroom
 	 	→	1F46B 👫 man and woman holding hands
1F6BC	 🚼 	Baby Symbol
 	 	=	baby on board, baby changing station
1F6BD	 🚽 	Toilet
1F6BE	 🚾 	Water Closet
 	 	→	1F14F 🅏 squared wc
 	 	→	1F18F 🆏 negative squared wc
1F6BF	 🚿 	Shower
1F6C0	 🛀 	Bath
1F6C1	 🛁 	Bathtub
1F6C2	 🛂 	Passport Control
1F6C3	 🛃 	Customs
1F6C4	 🛄 	Baggage Claim
1F6C5	 🛅 	Left Luggage
1F6C6	 🛆 	Triangle With Rounded Corners
 	 	=	caution
 	 	→	25B3 △ white up-pointing triangle
1F6C7	 🛇 	Prohibited Sign
 	 	→	20E0 ◌⃠ combining enclosing circle backslash
 	 	→	1F6AB 🚫 no entry sign
1F6C8	 🛈 	Circled Information Source
 	 	=	information
 	 	→	2139 ℹ information source
1F6C9	 🛉 	Boys Symbol
1F6CA	 🛊 	Girls Symbol
Accommodation symbols
These symbols constitute a set along with 1F378 for lounge.
1F6CB	 🛋 	Couch And Lamp
 	 	=	furniture, lifestyles
1F6CC	 🛌 	Sleeping Accommodation
 	 	=	hotel, guestrooms
 	 	→	1F3E8 🏨 hotel
1F6CD	 🛍 	Shopping Bags
 	 	=	shopping
1F6CE	 🛎 	Bellhop Bell
 	 	=	reception, services
1F6CF	 🛏 	Bed
Signage and other symbols
1F6D0	 🛐 	Place Of Worship
1F6D1	 🛑 	Octagonal Sign
 	 	=	stop sign
 	 	•	may contain text indicating stop
 	 	→	26A0 ⚠ warning sign
 	 	→	26DB ⛛ heavy white down-pointing triangle
 	 	→	2BC3 ⯃ horizontal black octagon
1F6D2	 🛒 	Shopping Trolley
 	 	=	shopping cart
Map symbols
1F6D3	 🛓 	Stupa
1F6D4	 🛔 	Pagoda
1F6D5	 🛕 	Hindu Temple
1F6D6	 🛖 	Hut
1F6D7	 🛗 	Elevator
1F6D8	 🛘 	Landslide
Miscellaneous symbols
1F6DC	 🛜 	Wireless
1F6DD	 🛝 	Playground Slide
1F6DE	 🛞 	Wheel
1F6DF	 🛟 	Ring Buoy
1F6E0	 🛠 	Hammer And Wrench
 	 	=	tools, repair facility
 	 	→	2692 ⚒ hammer and pick
1F6E1	 🛡 	Shield
 	 	=	US road interstate highway
1F6E2	 🛢 	Oil Drum
 	 	=	commodities
1F6E3	 🛣 	Motorway
1F6E4	 🛤 	Railway Track
 	 	=	railroad
Vehicles
1F6E5	 🛥 	Motor Boat
 	 	=	boat
 	 	→	1F6A4 🚤 speedboat
1F6E6	 🛦 	Up-Pointing Military Airplane
 	 	=	military airport
1F6E7	 🛧 	Up-Pointing Airplane
 	 	=	commercial airport
 	 	→	2708 ✈ airplane
1F6E8	 🛨 	Up-Pointing Small Airplane
 	 	=	airfield
1F6E9	 🛩 	Small Airplane
1F6EA	 🛪 	Northeast-Pointing Airplane
1F6EB	 🛫 	Airplane Departure
 	 	=	departures
1F6EC	 🛬 	Airplane Arriving
 	 	=	arrivals
1F6F0	 🛰 	Satellite
1F6F1	 🛱 	Oncoming Fire Engine
 	 	=	fire
 	 	→	1F692 🚒 fire engine
1F6F2	 🛲 	Diesel Locomotive
 	 	=	train
 	 	→	1F682 🚂 steam locomotive
 	 	→	1F686 🚆 train
1F6F3	 🛳 	Passenger Ship
 	 	=	cruise line vacation
 	 	→	1F6A2 🚢 ship
1F6F4	 🛴 	Scooter
1F6F5	 🛵 	Motor Scooter
1F6F6	 🛶 	Canoe
1F6F7	 🛷 	Sled
 	 	=	sledge, toboggan
1F6F8	 🛸 	Flying Saucer
 	 	=	Ufo
 	 	→	1CCFB 𜳻 flying saucer symbol
 	 	→	1F47D 👽 extraterrestrial alien
1F6F9	 🛹 	Skateboard
1F6FA	 🛺 	Auto Rickshaw
 	 	=	tuk-tuk, remorque
1F6FB	 🛻 	Pickup Truck
1F6FC	 🛼 	Roller Skate
