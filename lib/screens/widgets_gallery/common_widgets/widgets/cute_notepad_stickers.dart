/// 可爱手账便签贴纸 SVG 资源库
///
/// 移植自 Cute Template Notepad 手绘贴纸库（STICKER_ASSETS），
/// 路径数据逐字保留原 SVG，经 flutter_svg 渲染以保证与网页版视觉一致。
/// 扩展贴纸（pinkRibbonBow 起 12 款）移植自手账贴纸合集 SVG 设计稿，
/// 同样逐字保留原路径，仅包一层平移组适配独立 viewBox。
const Map<String, String> cuteNotepadStickerBodies = {
  'redBow': '''
<g stroke="#9e3b42" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
  <path d="M46 42 L26 78 L38 76 L45 84 L52 50 Z" fill="#f78c8c"/>
  <path d="M54 42 L74 78 L62 76 L55 84 L48 50 Z" fill="#f78c8c"/>
  <path d="M48 38 C22 14, 10 34, 20 52 C28 64, 44 50, 48 42 Z" fill="#ff9e9e"/>
  <path d="M52 38 C78 14, 90 34, 80 52 C72 64, 56 50, 52 42 Z" fill="#ff9e9e"/>
  <path d="M30 38 C36 38, 42 40, 44 41" fill="none" stroke-width="2.5"/>
  <path d="M70 38 C64 38, 58 40, 56 41" fill="none" stroke-width="2.5"/>
  <ellipse cx="50" cy="41" rx="8" ry="9" fill="#ff8585"/>
</g>
''',
  'pinkDoubleHearts': '''
<g stroke="#6e3f37" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
  <path d="M28 45 C28 36, 14 34, 14 46 C14 57, 28 65, 28 70 C28 65, 42 57, 42 46 C42 34, 28 36, 28 45 Z" fill="#ffccd5" transform="rotate(-12 28 52)"/>
  <path d="M68 32 C68 22, 53 20, 53 33 C53 45, 68 54, 68 60 C68 54, 83 45, 83 33 C83 20, 68 22, 68 32 Z" fill="#ffe6eb" transform="rotate(10 68 42)"/>
</g>
''',
  'peekingBunny': '''
<g stroke="#6b4438" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M18 82 C18 76, 9 75, 9 83 C9 90, 18 95, 18 98 C18 95, 27 90, 27 83 C27 75, 18 76, 18 82 Z" fill="#ff9ebb" stroke="#d96b88" stroke-width="2.2" transform="rotate(-15 18 86)"/>
  <path d="M52 54 C42 20, 48 6, 58 8 C68 10, 68 32, 66 52 Z" fill="#ffffff"/>
  <path d="M55 48 C50 28, 53 16, 58 17 C62 18, 62 32, 61 47 Z" fill="#ffb8c6" stroke="none"/>
  <path d="M82 54 C88 22, 102 10, 110 16 C118 22, 106 46, 95 60 Z" fill="#ffffff"/>
  <path d="M86 52 C91 30, 100 20, 104 24 C108 28, 99 44, 92 54 Z" fill="#ffb8c6" stroke="none"/>
  <path d="M36 105 C32 74, 46 50, 74 50 C102 50, 114 74, 108 105 Z" fill="#ffffff"/>
  <ellipse cx="50" cy="84" rx="7" ry="4.5" fill="#ffb3c1" stroke="none"/>
  <ellipse cx="94" cy="84" rx="7" ry="4.5" fill="#ffb3c1" stroke="none"/>
  <circle cx="57" cy="77" r="3.2" fill="#6b4438" stroke="none"/>
  <circle cx="87" cy="77" r="3.2" fill="#6b4438" stroke="none"/>
  <ellipse cx="72" cy="81" rx="3" ry="2.2" fill="#d97f76" stroke="none"/>
  <path d="M68 86 Q72 83 76 86" fill="none" stroke-width="2.6"/>
  <ellipse cx="44" cy="104" rx="11" ry="8" fill="#ffffff"/>
  <ellipse cx="96" cy="104" rx="11" ry="8" fill="#ffffff"/>
</g>
''',
  'topYellowFlower': '''
<g stroke="#d49424" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round">
  <path d="M55 62 C68 62, 78 55, 82 48 C72 46, 62 52, 55 62 Z" fill="#6ca856" stroke="#4d803b"/>
  <g fill="#ffdf6b">
    <circle cx="48" cy="24" r="11"/>
    <circle cx="65" cy="34" r="11"/>
    <circle cx="59" cy="52" r="11"/>
    <circle cx="38" cy="52" r="11"/>
    <circle cx="32" cy="34" r="11"/>
  </g>
  <circle cx="48" cy="40" r="8" fill="#fff7d6" stroke="#d49424" stroke-width="2"/>
</g>
''',
  'bottomWhiteDaisies': '''
<g stroke-linecap="round" stroke-linejoin="round">
  <path d="M36 68 Q38 86 38 98" stroke="#5c8d46" stroke-width="3.2" fill="none"/>
  <path d="M70 50 Q68 76 64 98" stroke="#5c8d46" stroke-width="3.2" fill="none"/>
  <path d="M38 94 C24 90, 22 80, 34 84 C36 86, 38 90, 38 94 Z" fill="#7eb563" stroke="#5c8d46" stroke-width="2.5"/>
  <path d="M38 94 C48 88, 50 78, 40 82 C39 85, 38 90, 38 94 Z" fill="#7eb563" stroke="#5c8d46" stroke-width="2.5"/>
  <path d="M64 95 C52 88, 54 76, 63 82 Z" fill="#7eb563" stroke="#5c8d46" stroke-width="2.5"/>
  <path d="M64 95 C78 86, 82 72, 68 80 Z" fill="#7eb563" stroke="#5c8d46" stroke-width="2.5"/>
  <g fill="#ffffff" stroke="#ebd688" stroke-width="2">
    <circle cx="36" cy="50" r="8"/><circle cx="48" cy="58" r="8"/>
    <circle cx="43" cy="71" r="8"/><circle cx="29" cy="71" r="8"/>
    <circle cx="24" cy="58" r="8"/>
  </g>
  <circle cx="36" cy="61" r="6.5" fill="#ffd84d" stroke="#d9a626" stroke-width="2"/>
  <g fill="#ffffff" stroke="#ebd688" stroke-width="2">
    <circle cx="70" cy="24" r="9"/><circle cx="83" cy="33" r="9"/>
    <circle cx="78" cy="48" r="9"/><circle cx="62" cy="48" r="9"/>
    <circle cx="57" cy="33" r="9"/>
  </g>
  <circle cx="70" cy="36" r="7.5" fill="#ffd84d" stroke="#d9a626" stroke-width="2"/>
</g>
''',
  'purpleCloudRain': '''
<g stroke="#54387f" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
  <path d="M26 56 C14 56, 10 42, 20 35 C18 22, 34 14, 46 22 C54 12, 74 14, 78 26 C92 28, 94 46, 82 54 C84 62, 68 66, 60 60 C52 66, 36 64, 26 56 Z" fill="#ffffff"/>
  <ellipse cx="38" cy="43" rx="5" ry="3" fill="#ffb8d0" stroke="none"/>
  <ellipse cx="68" cy="43" rx="5" ry="3" fill="#ffb8d0" stroke="none"/>
  <circle cx="43" cy="38" r="2.3" fill="#54387f" stroke="none"/>
  <circle cx="63" cy="38" r="2.3" fill="#54387f" stroke="none"/>
  <path d="M50 41 Q53 45 56 41" fill="none" stroke-width="2.4"/>
  <line x1="62" y1="69" x2="59" y2="77" stroke-width="2.8"/>
  <line x1="72" y1="70" x2="72" y2="80" stroke-width="2.8"/>
  <line x1="81" y1="67" x2="85" y2="75" stroke-width="2.8"/>
</g>
''',
  'greenHeart': '''
<path d="M35 28 C35 16, 16 14, 16 29 C16 42, 35 52, 35 58 C35 52, 54 42, 54 29 C54 14, 35 16, 35 28 Z" fill="#8ec468" stroke="#4f7533" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>
''',
  'cuteFrog': '''
<g stroke="#446326" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round">
  <line x1="20" y1="54" x2="10" y2="48" stroke-width="2.8"/>
  <line x1="17" y1="68" x2="6" y2="68" stroke-width="2.8"/>
  <line x1="20" y1="81" x2="10" y2="86" stroke-width="2.8"/>
  <path d="M40 54 C36 34, 60 32, 64 50 C70 50, 76 50, 82 50 C86 32, 110 34, 106 54 C118 62, 118 92, 96 95 L50 95 C28 92, 28 62, 40 54 Z" fill="#aed576"/>
  <ellipse cx="48" cy="74" rx="6.5" ry="4" fill="#f5989d" stroke="none"/>
  <ellipse cx="98" cy="74" rx="6.5" ry="4" fill="#f5989d" stroke="none"/>
  <circle cx="52" cy="52" r="3.4" fill="#3a5220" stroke="none"/>
  <circle cx="94" cy="52" r="3.4" fill="#3a5220" stroke="none"/>
  <path d="M69 71 Q73 75 77 71" fill="none" stroke-width="2.6"/>
</g>
''',
  'blueCloud': '''
<g stroke="#5b8bbd" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
  <path d="M24 62 C12 62, 8 46, 20 40 C20 26, 36 20, 46 28 C54 18, 72 20, 78 34 C90 36, 92 54, 80 60 C72 66, 36 66, 24 62 Z" fill="#ffffff"/>
  <ellipse cx="36" cy="49" rx="5" ry="3" fill="#ffb8c9" stroke="none"/>
  <ellipse cx="66" cy="49" rx="5" ry="3" fill="#ffb8c9" stroke="none"/>
  <circle cx="42" cy="45" r="2.3" fill="#48729e" stroke="none"/>
  <circle cx="60" cy="45" r="2.3" fill="#48729e" stroke="none"/>
  <path d="M48 48 Q51 52 54 48" fill="none" stroke="#48729e" stroke-width="2.3"/>
</g>
''',
  'blueDoubleHearts': '''
<g stroke="#4a7bb0" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
  <path d="M26 52 C26 44, 15 43, 15 52 C15 60, 26 66, 26 70 C26 66, 37 60, 37 52 C37 43, 26 44, 26 52 Z" fill="#a8d1ff" transform="rotate(-10 26 58)"/>
  <path d="M60 34 C60 23, 44 21, 44 35 C44 47, 60 56, 60 62 C60 56, 76 47, 76 35 C76 21, 60 23, 60 34 Z" fill="#99c9ff" transform="rotate(12 60 44)"/>
</g>
''',
  'pinkHeartTape': '''
<g transform="rotate(-4 70 28)">
  <path d="M10 10 L130 10 L127 18 L131 26 L127 34 L130 44 L10 44 L13 35 L9 27 L13 18 Z" fill="#f794a4" opacity="0.92" stroke="#e07b8b" stroke-width="1.5"/>
  <g fill="#ffe3e8">
    <path d="M30 25 C30 20, 23 19, 23 25 C23 30, 30 34, 30 36 C30 34, 37 30, 37 25 C37 19, 30 20, 30 25 Z"/>
    <path d="M56 26 C56 21, 49 20, 49 26 C49 31, 56 35, 56 37 C56 35, 63 31, 63 26 C63 20, 56 21, 56 26 Z"/>
    <path d="M84 25 C84 20, 77 19, 77 25 C77 30, 84 34, 84 36 C84 34, 91 30, 91 25 C91 19, 84 20, 84 25 Z"/>
    <path d="M110 26 C110 21, 103 20, 103 26 C103 31, 110 35, 110 37 C110 35, 117 31, 117 26 C117 20, 110 21, 110 26 Z"/>
  </g>
</g>
''',
  'pinkTulips': '''
<g stroke-linecap="round" stroke-linejoin="round">
  <path d="M34 58 Q38 78 44 96" stroke="#4f8259" stroke-width="3.2" fill="none"/>
  <path d="M68 42 Q64 70 54 96" stroke="#4f8259" stroke-width="3.2" fill="none"/>
  <path d="M44 95 C26 88, 22 70, 34 76 C40 80, 43 88, 44 95 Z" fill="#639c6b" stroke="#4f8259" stroke-width="2.5"/>
  <path d="M54 95 C72 86, 78 66, 64 74 C58 78, 55 88, 54 95 Z" fill="#639c6b" stroke="#4f8259" stroke-width="2.5"/>
  <path d="M22 44 C20 58, 44 60, 44 44 L40 32 L34 38 L29 31 L25 38 Z" fill="#ff94b2" stroke="#d96887" stroke-width="2.5"/>
  <path d="M54 28 C52 44, 80 46, 80 28 L75 14 L68 22 L62 14 L57 22 Z" fill="#ff94b2" stroke="#d96887" stroke-width="2.5"/>
</g>
''',
  'smilingSun': '''
<g stroke="#d18828" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="50" cy="50" r="22" fill="#ffd447"/>
  <line x1="50" y1="14" x2="50" y2="21"/>
  <line x1="50" y1="79" x2="50" y2="86"/>
  <line x1="14" y1="50" x2="21" y2="50"/>
  <line x1="79" y1="50" x2="86" y2="50"/>
  <line x1="24" y1="24" x2="30" y2="30"/>
  <line x1="70" y1="70" x2="76" y2="76"/>
  <line x1="76" y1="24" x2="70" y2="30"/>
  <line x1="30" y1="70" x2="24" y2="76"/>
  <ellipse cx="41" cy="52" rx="3.5" ry="2" fill="#f28b82" stroke="none"/>
  <ellipse cx="59" cy="52" rx="3.5" ry="2" fill="#f28b82" stroke="none"/>
  <circle cx="43" cy="47" r="2" fill="#784714" stroke="none"/>
  <circle cx="57" cy="47" r="2" fill="#784714" stroke="none"/>
  <path d="M48 51 Q50 54 52 51" fill="none" stroke="#784714" stroke-width="2.2"/>
</g>
''',
  'yellowFlowersBottomLeft': '''
<g stroke-linecap="round" stroke-linejoin="round">
  <path d="M36 42 Q34 72 34 95" stroke="#5d8c42" stroke-width="3.2" fill="none"/>
  <path d="M72 62 Q68 80 64 95" stroke="#5d8c42" stroke-width="3.2" fill="none"/>
  <path d="M34 92 C18 86, 18 72, 30 78 Z" fill="#7cb35b" stroke="#5d8c42" stroke-width="2.5"/>
  <path d="M34 92 C48 84, 48 72, 37 78 Z" fill="#7cb35b" stroke="#5d8c42" stroke-width="2.5"/>
  <path d="M64 93 C52 88, 52 78, 62 82 Z" fill="#7cb35b" stroke="#5d8c42" stroke-width="2.5"/>
  <path d="M64 93 C76 88, 76 78, 66 82 Z" fill="#7cb35b" stroke="#5d8c42" stroke-width="2.5"/>
  <g fill="#ffdf6e" stroke="#d9a12b" stroke-width="2">
    <circle cx="36" cy="22" r="8.5"/><circle cx="48" cy="31" r="8.5"/>
    <circle cx="43" cy="44" r="8.5"/><circle cx="29" cy="44" r="8.5"/>
    <circle cx="24" cy="31" r="8.5"/>
  </g>
  <circle cx="36" cy="34" r="6.5" fill="#fff7d6" stroke="#d9a12b" stroke-width="2"/>
  <g fill="#ffdf6e" stroke="#d9a12b" stroke-width="2">
    <circle cx="72" cy="48" r="7"/><circle cx="82" cy="55" r="7"/>
    <circle cx="78" cy="66" r="7"/><circle cx="66" cy="66" r="7"/>
    <circle cx="62" cy="55" r="7"/>
  </g>
  <circle cx="72" cy="58" r="5.5" fill="#fff7d6" stroke="#d9a12b" stroke-width="2"/>
</g>
''',
  'peekingCat': '''
<g stroke="#523961" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M84 22 C84 14, 72 13, 72 23 C72 31, 84 37, 84 41 C84 37, 96 31, 96 23 C96 13, 84 14, 84 22 Z" fill="#d3b8f7" stroke="#523961" stroke-width="2.8"/>
  <path d="M24 98 C20 68, 30 56, 34 40 L54 54 C64 52, 74 52, 84 54 L104 40 C108 56, 118 68, 114 98 Z" fill="#ffffff"/>
  <path d="M34 40 L48 50 C40 56, 30 62, 26 70 C27 56, 31 46, 34 40 Z" fill="#a68976" stroke="none"/>
  <path d="M104 40 L90 50 C98 56, 108 62, 112 70 C111 56, 107 46, 104 40 Z" fill="#9c89a6" stroke="none"/>
  <path d="M24 98 C20 68, 30 56, 34 40 L54 54 C64 52, 74 52, 84 54 L104 40 C108 56, 118 68, 114 98" fill="none"/>
  <ellipse cx="45" cy="82" rx="6" ry="3.5" fill="#ffb8c6" stroke="none"/>
  <ellipse cx="93" cy="82" rx="6" ry="3.5" fill="#ffb8c6" stroke="none"/>
  <circle cx="52" cy="75" r="3" fill="#523961" stroke="none"/>
  <circle cx="86" cy="75" r="3" fill="#523961" stroke="none"/>
  <ellipse cx="69" cy="78" rx="3" ry="2" fill="#d48c46" stroke="none"/>
  <path d="M64 83 Q69 80 74 83" fill="none" stroke-width="2.5"/>
  <line x1="16" y1="78" x2="27" y2="80" stroke-width="2.6"/>
  <line x1="15" y1="86" x2="26" y2="86" stroke-width="2.6"/>
  <line x1="122" y1="78" x2="111" y2="80" stroke-width="2.6"/>
  <line x1="123" y1="86" x2="112" y2="86" stroke-width="2.6"/>
</g>
''',
  'greenPlaidTape': '''
<g transform="rotate(-5 65 25)">
  <path d="M10 8 L120 8 L117 17 L121 25 L117 33 L120 42 L10 42 L13 33 L9 25 L13 17 Z" fill="#e8f2df" stroke="#789c68" stroke-width="1.5"/>
  <g fill="#6d9958" opacity="0.65">
    <rect x="12" y="13" width="106" height="6"/>
    <rect x="12" y="25" width="106" height="6"/>
    <rect x="22" y="8" width="7" height="34"/>
    <rect x="44" y="8" width="7" height="34"/>
    <rect x="66" y="8" width="7" height="34"/>
    <rect x="88" y="8" width="7" height="34"/>
    <rect x="108" y="8" width="6" height="34"/>
  </g>
</g>
''',
  'greenSprout': '''
<g stroke="#4b6e32" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
  <path d="M45 45 Q46 64 45 78" fill="none" stroke-width="3.4"/>
  <path d="M45 48 C24 52, 14 34, 28 24 C38 18, 46 34, 45 48 Z" fill="#9cd169"/>
  <path d="M45 48 C64 52, 74 34, 60 24 C50 18, 44 34, 45 48 Z" fill="#9cd169"/>
</g>
''',
  'purpleTinyHeart': '''
<path d="M25 22 C25 13, 12 12, 12 22 C12 31, 25 38, 25 42 C25 38, 38 31, 25 22 Z" fill="#d9c2ff" stroke="#6a4c9c" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
''',
  'purpleFlowersBottomLeft': '''
<g stroke-linecap="round" stroke-linejoin="round">
  <path d="M34 45 Q38 72 40 96" stroke="#3f6e58" stroke-width="3" fill="none"/>
  <path d="M72 62 Q62 80 54 96" stroke="#3f6e58" stroke-width="3" fill="none"/>
  <path d="M40 95 C24 88, 22 76, 35 82 Z" fill="#558c72" stroke="#3f6e58" stroke-width="2.4"/>
  <path d="M54 95 C68 88, 70 76, 58 82 Z" fill="#558c72" stroke="#3f6e58" stroke-width="2.4"/>
  <g fill="#b594e8" stroke="#7a58b5" stroke-width="2">
    <circle cx="34" cy="24" r="8"/><circle cx="46" cy="32" r="8"/>
    <circle cx="41" cy="45" r="8"/><circle cx="27" cy="45" r="8"/>
    <circle cx="22" cy="32" r="8"/>
  </g>
  <circle cx="34" cy="35" r="6" fill="#ffdf6b" stroke="#c99b2c" stroke-width="2"/>
  <g fill="#b594e8" stroke="#7a58b5" stroke-width="2">
    <circle cx="72" cy="45" r="7.5"/><circle cx="83" cy="53" r="7.5"/>
    <circle cx="79" cy="65" r="7.5"/><circle cx="65" cy="65" r="7.5"/>
    <circle cx="61" cy="53" r="7.5"/>
  </g>
  <circle cx="72" cy="56" r="5.5" fill="#ffdf6b" stroke="#c99b2c" stroke-width="2"/>
</g>
''',
  'blueOutlineHeart': '''
<path d="M30 24 C30 14, 15 12, 15 25 C15 36, 30 44, 30 50 C30 44, 45 36, 30 24 Z" fill="#a8d1fc" stroke="#2d5a88" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>
''',
  'cutePenguin': '''
<g stroke="#445268" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M26 106 C22 64, 32 30, 64 30 C96 30, 106 64, 102 106 Z" fill="#77879e"/>
  <path d="M36 106 C34 78, 40 52, 52 52 C58 52, 62 58, 64 60 C66 58, 70 52, 76 52 C88 52, 94 78, 92 106 Z" fill="#ffffff"/>
  <ellipse cx="46" cy="70" rx="5.5" ry="3.2" fill="#ffb5c5" stroke="none"/>
  <ellipse cx="82" cy="70" rx="5.5" ry="3.2" fill="#ffb5c5" stroke="none"/>
  <circle cx="51" cy="64" r="2.8" fill="#323d4f" stroke="none"/>
  <circle cx="77" cy="64" r="2.8" fill="#323d4f" stroke="none"/>
  <ellipse cx="64" cy="67" rx="5" ry="3.5" fill="#ffd15c" stroke="#445268" stroke-width="2.4"/>
  <path d="M64 84 C64 75, 50 74, 50 85 C50 94, 64 100, 64 104 C64 100, 78 94, 78 85 C78 74, 64 75, 64 84 Z" fill="#c8b0f2" stroke="#445268" stroke-width="2.8"/>
  <path d="M30 84 C40 82, 50 86, 52 92 C44 96, 34 94, 30 88 Z" fill="#77879e"/>
  <path d="M98 84 C88 82, 78 86, 76 92 C84 96, 94 94, 98 88 Z" fill="#77879e"/>
</g>
''',
  'redPaperclip': '''
<g transform="rotate(24 40 42)">
  <path d="M32 62 L32 22 C32 12, 48 12, 48 22 L48 66 C48 78, 28 78, 28 66 L28 28" fill="none" stroke="#e05a68" stroke-width="3.6" stroke-linecap="round"/>
</g>
''',
  'coralDoubleHearts': '''
<g stroke="#d45d68" stroke-width="2.8" fill="#ffe8eb" stroke-linecap="round" stroke-linejoin="round">
  <path d="M26 36 C26 24, 10 22, 10 37 C10 50, 26 60, 26 66 C26 60, 42 50, 42 37 C42 22, 26 24, 26 36 Z" transform="rotate(-8 26 45)"/>
  <path d="M58 50 C58 43, 48 42, 48 51 C48 58, 58 64, 58 68 C58 64, 68 58, 68 51 C68 42, 58 43, 58 50 Z" transform="rotate(12 58 56)"/>
</g>
''',
  'cuteCherries': '''
<g stroke-linecap="round" stroke-linejoin="round">
  <path d="M32 58 Q44 34 54 18" stroke="#538246" stroke-width="3" fill="none"/>
  <path d="M64 60 Q58 38 54 18" stroke="#538246" stroke-width="3" fill="none"/>
  <path d="M54 18 C66 16, 74 24, 64 28 C56 30, 54 22, 54 18 Z" fill="#77b364" stroke="#538246" stroke-width="2.5"/>
  <circle cx="30" cy="64" r="13" fill="#ff6b78" stroke="#c94753" stroke-width="2.8"/>
  <circle cx="64" cy="66" r="13" fill="#ff6b78" stroke="#c94753" stroke-width="2.8"/>
  <path d="M24 60 A6 6 0 0 1 28 56" stroke="#ffffff" stroke-width="2.2" fill="none"/>
  <path d="M58 62 A6 6 0 0 1 62 58" stroke="#ffffff" stroke-width="2.2" fill="none"/>
</g>
''',
  'purpleBow': '''
<g stroke="#6c4d9c" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" transform="rotate(-12 50 50)">
  <path d="M46 44 L28 80 L38 77 L44 85 L50 50 Z" fill="#d3bcf7"/>
  <path d="M54 44 L72 80 L62 77 L56 85 L50 50 Z" fill="#d3bcf7"/>
  <path d="M46 40 C20 18, 10 38, 22 54 C32 64, 44 50, 48 44 Z" fill="#e2d1ff"/>
  <path d="M54 40 C80 18, 90 38, 78 54 C68 64, 56 50, 52 44 Z" fill="#e2d1ff"/>
  <ellipse cx="50" cy="43" rx="7.5" ry="8.5" fill="#c7abfa"/>
</g>
''',
  'purpleDoubleHearts': '''
<g stroke="#6c4d9c" stroke-width="2.8" fill="#e9dcff" stroke-linecap="round" stroke-linejoin="round">
  <path d="M26 28 C26 18, 12 16, 12 29 C12 40, 26 48, 26 54 C26 48, 40 40, 40 29 C40 16, 26 18, 26 28 Z"/>
  <path d="M54 48 C54 40, 42 39, 42 49 C42 57, 54 63, 54 68 C54 63, 66 57, 66 49 C66 39, 54 40, 54 48 Z" transform="rotate(10 54 54)"/>
</g>
''',
  'yellowPolkaTape': '''
<g transform="rotate(-3 65 25)">
  <path d="M10 8 L120 8 L117 17 L121 25 L117 33 L120 42 L10 42 L13 33 L9 25 L13 17 Z" fill="#f7ca59" stroke="#d9aa38" stroke-width="1.5"/>
  <g fill="#fff8e0">
    <circle cx="24" cy="17" r="3"/><circle cx="44" cy="17" r="3"/><circle cx="64" cy="17" r="3"/><circle cx="84" cy="17" r="3"/><circle cx="104" cy="17" r="3"/>
    <circle cx="34" cy="26" r="3"/><circle cx="54" cy="26" r="3"/><circle cx="74" cy="26" r="3"/><circle cx="94" cy="26" r="3"/>
    <circle cx="24" cy="35" r="3"/><circle cx="44" cy="35" r="3"/><circle cx="64" cy="35" r="3"/><circle cx="84" cy="35" r="3"/><circle cx="104" cy="35" r="3"/>
  </g>
</g>
''',
  'cuteBear': '''
<g stroke="#5e3a1e" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M84 22 C84 14, 73 13, 73 22 C73 30, 84 35, 84 39 C84 35, 95 30, 95 22 C95 13, 84 14, 84 22 Z" fill="#ffd257" stroke="#5e3a1e" stroke-width="2.6" transform="rotate(12 84 26)"/>
  <circle cx="34" cy="52" r="14" fill="#bd8c58"/>
  <circle cx="34" cy="52" r="7" fill="#e6be8a" stroke="none"/>
  <circle cx="92" cy="56" r="14" fill="#bd8c58"/>
  <circle cx="92" cy="56" r="7" fill="#e6be8a" stroke="none"/>
  <ellipse cx="62" cy="74" rx="38" ry="28" fill="#bd8c58"/>
  <ellipse cx="42" cy="78" rx="5.5" ry="3.2" fill="#e8877d" stroke="none"/>
  <ellipse cx="82" cy="80" rx="5.5" ry="3.2" fill="#e8877d" stroke="none"/>
  <circle cx="49" cy="72" r="2.8" fill="#4a2c14" stroke="none"/>
  <circle cx="75" cy="73" r="2.8" fill="#4a2c14" stroke="none"/>
  <ellipse cx="62" cy="78" rx="8" ry="6.5" fill="#e6be8a" stroke="none"/>
  <ellipse cx="62" cy="76" rx="3" ry="2.2" fill="#4a2c14" stroke="none"/>
  <path d="M59 80 Q62 78 65 80" fill="none" stroke="#4a2c14" stroke-width="2.2"/>
</g>
''',
  'coralSparkleLines': '''
<g stroke="#e08279" stroke-width="3" stroke-linecap="round">
  <line x1="22" y1="24" x2="34" y2="20"/>
  <line x1="26" y1="34" x2="40" y2="34"/>
  <line x1="34" y1="44" x2="44" y2="50"/>
</g>
''',
  'blueTopTape': '''
<rect x="8" y="6" width="84" height="28" rx="2" fill="#9ebbeb" opacity="0.78" stroke="#85a6de" stroke-width="1.5" transform="rotate(-2 50 20)"/>
''',
  'shiningBlueHeart': '''
<g stroke="#4673ad" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
  <path d="M52 48 C52 36, 34 34, 34 49 C34 62, 52 72, 52 78 C52 72, 70 62, 70 49 C70 34, 52 36, 52 48 Z" fill="#8bb8f2" transform="rotate(8 52 56)"/>
  <line x1="46" y1="20" x2="46" y2="28"/>
  <line x1="66" y1="22" x2="62" y2="30"/>
  <line x1="78" y1="34" x2="72" y2="39"/>
  <line x1="18" y1="54" x2="25" y2="54"/>
  <line x1="20" y1="68" x2="27" y2="65"/>
</g>
''',
  'pinkRibbonBow': '''
<g stroke="#7d3746" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" transform="translate(48,48) rotate(-18)">
  <path d="M-4 4 L-16 32 L-7 28 L-1 35 L2 6 Z" fill="#f59eb0"/>
  <path d="M4 4 L18 30 L10 27 L5 34 L-1 6 Z" fill="#f59eb0"/>
  <path d="M-4 -3 C-18 -18 -34 -12 -32 4 C-30 18 -14 15 -4 4 Z" fill="#f8b2c1"/>
  <path d="M4 -3 C18 -18 34 -12 32 4 C30 18 14 15 4 4 Z" fill="#f8b2c1"/>
  <path d="M-7 -1 L-16 -3 M-7 2 L-15 5 M7 -1 L16 -3 M7 2 L15 5" fill="none" stroke-width="1.6"/>
  <rect x="-6" y="-6" width="12" height="13" rx="4" fill="#f59eb0"/>
</g>
''',
  'peekingBear': '''
<g stroke="#593a25" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" transform="translate(36,26)">
  <circle cx="-24" cy="-14" r="10" fill="#c69063"/>
  <circle cx="-24" cy="-14" r="5" fill="#e6c39f" stroke="none"/>
  <circle cx="24" cy="-14" r="10" fill="#c69063"/>
  <circle cx="24" cy="-14" r="5" fill="#e6c39f" stroke="none"/>
  <path d="M-26 8 C-30 -8 -20 -22 0 -22 C20 -22 30 -8 26 8 Z" fill="#c69063"/>
  <ellipse cx="0" cy="0" rx="9" ry="7" fill="#f2dec4" stroke="none"/>
  <circle cx="-10" cy="-5" r="2.3" fill="#422918" stroke="none"/>
  <circle cx="10" cy="-5" r="2.3" fill="#422918" stroke="none"/>
  <ellipse cx="0" cy="-2" rx="3" ry="2" fill="#422918" stroke="none"/>
  <path d="M0 0 L-3 3 M0 0 L3 3" fill="none" stroke="#422918" stroke-width="1.8"/>
  <ellipse cx="-22" cy="9" rx="9" ry="6" fill="#c69063"/>
  <ellipse cx="22" cy="9" rx="9" ry="6" fill="#c69063"/>
</g>
''',
  'purpleStemFlower': '''
<g stroke="#4d415d" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" transform="translate(25,24)">
  <path d="M0 10 L0 28" fill="none"/>
  <path d="M0 24 C-10 22 -14 14 -4 14 C0 14 0 20 0 24 Z" fill="#8bb574" stroke-width="2"/>
  <path d="M0 24 C10 22 14 14 4 14 C0 14 0 20 0 24 Z" fill="#8bb574" stroke-width="2"/>
  <path d="M0 -6 C-8 -22 8 -22 0 -6 C15 -18 22 -4 5 1 C18 12 6 24 -1 7 C-8 24 -20 12 -5 1 C-22 -4 -15 -18 0 -6 Z" fill="#c4b2e3"/>
  <circle cx="0" cy="0" r="5.5" fill="#fae282" stroke-width="2"/>
</g>
''',
  'brownStemFlower': '''
<g stroke="#593a25" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" transform="translate(25,24)">
  <path d="M0 8 L0 32" fill="none"/>
  <path d="M0 28 C-10 26 -14 18 -4 18 C0 18 0 24 0 28 Z" fill="#88a25e" stroke-width="2"/>
  <path d="M0 28 C10 26 14 18 4 18 C0 18 0 24 0 28 Z" fill="#88a25e" stroke-width="2"/>
  <path d="M0 -5 C-7 -19 7 -19 0 -5 C13 -16 19 -3 4 1 C16 10 5 21 -1 6 C-7 21 -18 10 -4 1 C-19 -3 -13 -16 0 -5 Z" fill="#c69063"/>
  <circle cx="0" cy="0" r="4.8" fill="#fae084" stroke-width="2"/>
</g>
''',
  'bluePlaidTape': '''
<g transform="rotate(-4 65 25)">
  <path d="M10 8 L120 8 L117 17 L121 25 L117 33 L120 42 L10 42 L13 33 L9 25 L13 17 Z" fill="#d9eaf7" stroke="#82a6c4" stroke-width="1.5"/>
  <g fill="#99c0df" opacity="0.55">
    <rect x="12" y="13" width="106" height="6"/>
    <rect x="12" y="25" width="106" height="6"/>
    <rect x="22" y="8" width="7" height="34"/>
    <rect x="44" y="8" width="7" height="34"/>
    <rect x="66" y="8" width="7" height="34"/>
    <rect x="88" y="8" width="7" height="34"/>
    <rect x="108" y="8" width="6" height="34"/>
  </g>
</g>
''',
  'yellowSparkle': '''
<path d="M15 3 Q15 15 25 15 Q15 15 15 27 Q15 15 5 15 Q15 15 15 3 Z" fill="#fce07c" stroke="#b89030" stroke-width="1.8" stroke-linejoin="round"/>
''',
  'leafBranch': '''
<g stroke="#536b40" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" transform="translate(34,78)">
  <path d="M0 0 Q-14 -28 -16 -62" fill="none" stroke-width="2.2"/>
  <path d="M-16 -62 C-22 -74 -10 -76 -12 -62 Z" fill="#95be74" stroke-width="1.8"/>
  <path d="M-14 -50 C-28 -54 -26 -42 -13 -44 Z" fill="#95be74" stroke-width="1.8"/>
  <path d="M-13 -48 C-2 -58 2 -46 -12 -42 Z" fill="#95be74" stroke-width="1.8"/>
  <path d="M-11 -32 C-26 -36 -24 -22 -9 -26 Z" fill="#95be74" stroke-width="1.8"/>
  <path d="M-10 -30 C2 -40 6 -26 -8 -24 Z" fill="#95be74" stroke-width="1.8"/>
  <path d="M-6 -14 C-20 -18 -18 -6 -4 -10 Z" fill="#95be74" stroke-width="1.8"/>
  <path d="M-5 -14 C8 -22 10 -10 -3 -8 Z" fill="#95be74" stroke-width="1.8"/>
</g>
''',
  'strawberry': '''
<g transform="translate(27,30) rotate(14)">
  <path d="M0 -18 C-16 -18 -20 0 -14 14 C-9 24 -4 28 0 28 C4 28 9 24 14 14 C20 0 16 -18 0 -18 Z" fill="#f37c8d" stroke="#733942" stroke-width="2.2" stroke-linejoin="round"/>
  <g fill="#fde2e6">
    <ellipse cx="-7" cy="-4" rx="1.2" ry="2"/>
    <ellipse cx="0" cy="-2" rx="1.2" ry="2"/>
    <ellipse cx="7" cy="-4" rx="1.2" ry="2"/>
    <ellipse cx="-9" cy="6" rx="1.2" ry="2"/>
    <ellipse cx="-3" cy="8" rx="1.2" ry="2"/>
    <ellipse cx="4" cy="7" rx="1.2" ry="2"/>
    <ellipse cx="9" cy="5" rx="1.2" ry="2"/>
    <ellipse cx="-4" cy="17" rx="1.2" ry="2"/>
    <ellipse cx="3" cy="17" rx="1.2" ry="2"/>
  </g>
  <path d="M0 -14 C-6 -22 -14 -18 -12 -12 C-6 -12 -2 -10 0 -10 C-4 -18 4 -18 0 -10 C2 -10 6 -12 12 -12 C14 -18 6 -22 0 -14 Z" fill="#88b866" stroke="#4d5e3e" stroke-width="2" stroke-linejoin="round"/>
  <path d="M0 -16 L0 -23" fill="none" stroke="#4d5e3e" stroke-width="2.2" stroke-linecap="round"/>
</g>
''',
  'pottedSucculent': '''
<g transform="translate(23,31)">
  <g stroke="#4a5d3b" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M-12 -6 C-22 -16 -14 -26 -4 -14 Z" fill="#8bb868"/>
    <path d="M12 -6 C22 -16 14 -26 4 -14 Z" fill="#8bb868"/>
    <path d="M-6 -8 C-14 -24 -2 -30 0 -14 Z" fill="#9bc678"/>
    <path d="M6 -8 C14 -24 2 -30 0 -14 Z" fill="#9bc678"/>
    <path d="M0 -8 C-7 -28 7 -28 0 -8 Z" fill="#8bb868"/>
  </g>
  <path d="M-15 -2 L15 -2 L11 22 C11 24 9 25 6 25 L-6 25 C-9 25 -11 24 -11 22 Z" fill="#e6c39c" stroke="#694d38" stroke-width="2" stroke-linejoin="round"/>
  <rect x="-18" y="-7" width="36" height="6" rx="2.5" fill="#edd0ae" stroke="#694d38" stroke-width="2"/>
  <path d="M0 8.5 C-1.5 6.2 -4.6 7.7 -4.6 10.4 C-4.6 12.7 0 14.2 0 15.7 C0 14.2 4.6 12.7 4.6 10.4 C4.6 7.7 1.5 6.2 0 8.5 Z" fill="#d69e72" stroke="#694d38" stroke-width="1.3" stroke-linecap="round"/>
</g>
''',
  'yellowStar': '''
<g transform="translate(25,25) rotate(8)">
  <path d="M0 -18 C3 -18 5 -8 7 -6 C9 -5 19 -5 19 -2 C19 1 11 6 10 8 C9 11 13 20 10 22 C8 23 1 16 -1 16 C-3 16 -10 23 -12 22 C-15 20 -11 11 -12 8 C-13 6 -21 1 -21 -2 C-21 -5 -11 -5 -9 -6 C-7 -8 -3 -18 0 -18 Z" fill="#fce07c" stroke="#9e7f43" stroke-width="2.2" stroke-linejoin="round"/>
</g>
''',
  'heartPaperclip': '''
<g transform="translate(22,25) rotate(-14)">
  <path d="M-5 2 L-5 26 C-5 33 7 33 7 24 L7 -2 C7 -8 -2 -8 -2 0 L-2 20 C-2 24 3 24 3 19 L3 6" fill="none" stroke="#7d3746" stroke-width="2.3" stroke-linecap="round"/>
  <path d="M0 -11 C-5 -18.5 -15 -13.5 -15 -7.5 C-15 2.75 -6.25 7.75 0 12.75 C6.25 7.75 15 2.75 15 -7.5 C15 -13.5 5 -18.5 0 -11 Z" fill="#f498ad" stroke="#7d3746" stroke-width="1.8" stroke-linejoin="round"/>
</g>
''',
  'crescentMoon': '''
<g stroke="#6b5235" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" transform="translate(25,26)">
  <path d="M-6 -22 C14 -22 24 -4 18 14 C12 28 -8 32 -22 20 C-8 20 2 12 2 0 C2 -10 -4 -16 -6 -22 Z" fill="#fce07c"/>
  <path d="M6 -2 Q9 1 12 -2" fill="none" stroke-width="1.8"/>
  <path d="M3 6 Q6 9 9 7" fill="none" stroke-width="1.8"/>
</g>
''',

  // ---- 生日涂鸦贴图集（code_artifact 生日卡片移植，深棕勾线 + 马卡龙粉彩） ----
  'smileyStar': '''
<g transform="translate(30,30)">
  <path d="M 0,-26 C 3,-26 7,-11 9,-9 C 11,-7 26,-6 27,-3 C 28,0 16,9 15,12 C 14,15 18,28 15,30 C 12,32 2,23 -1,23 C -4,23 -14,32 -17,30 C -20,28 -15,15 -16,12 C -17,9 -28,0 -27,-3 C -26,-6 -11,-7 -9,-9 C -7,-11 -3,-26 0,-26 Z" fill="#FDE075" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round" stroke-linecap="round"/>
  <circle cx="-5.5" cy="2" r="1.7" fill="#291F1C"/>
  <circle cx="5.5" cy="2" r="1.7" fill="#291F1C"/>
  <path d="M -2.5,5.5 Q 0,8 2.5,5.5" fill="none" stroke="#291F1C" stroke-width="1.8" stroke-linecap="round"/>
  <ellipse cx="-8.5" cy="4.5" rx="2.5" ry="1.4" fill="#F4978E" opacity="0.7"/>
  <ellipse cx="8.5" cy="4.5" rx="2.5" ry="1.4" fill="#F4978E" opacity="0.7"/>
</g>
''',
  'pinkHeart': '''
<g transform="translate(17,6)">
  <path d="M 0,4 C -4,-4 -14,-2 -13,6 C -12,13 -2,17 0,21 C 2,17 12,13 13,6 C 14,-2 4,-4 0,4 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
</g>
''',
  'miniHeart': '''
<g transform="translate(11,5)">
  <path d="M 0,2.5 C -2.5,-2.5 -8,-1 -7.5,3.5 C -7,7.5 -1,10 0,12 C 1,10 7,7.5 7.5,3.5 C 8,-1 2.5,-2.5 0,2.5 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
</g>
''',
  'pinkFlower': '''
<g transform="translate(18,17)">
  <path d="M 0,-4 C -3,-13 5,-15 4,-5 C 12,-10 16,-2 6,1 C 14,7 7,15 1,6 C -2,15 -11,11 -5,3 C -15,2 -12,-8 -3,-4 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="2" stroke-linejoin="round"/>
  <circle cx="0" cy="0" r="3.2" fill="#FDE075" stroke="#291F1C" stroke-width="1.8"/>
</g>
''',
  'birthdayCake': '''
<g transform="translate(2,-8)">
  <ellipse cx="48" cy="112" rx="48" ry="10" fill="#FFFFFF" stroke="#291F1C" stroke-width="2.3"/>
  <path d="M 10,66 L 10,106 C 10,114 86,114 86,106 L 86,66 Z" fill="#FAD2D8" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round"/>
  <ellipse cx="48" cy="66" rx="38" ry="10" fill="#FCE3E6" stroke="#291F1C" stroke-width="2.3"/>
  <path d="M 10,68 Q 18,79 26,70 Q 36,81 48,71 Q 60,81 70,70 Q 79,79 86,68" fill="none" stroke="#F299A6" stroke-width="3" stroke-linecap="round"/>
  <path d="M 10,68 Q 18,79 26,70 Q 36,81 48,71 Q 60,81 70,70 Q 79,79 86,68" fill="none" stroke="#291F1C" stroke-width="2.1" stroke-linecap="round"/>
  <path d="M 10,89 Q 20,97 30,89 Q 40,97 48,89 Q 58,97 68,89 Q 78,97 86,89" fill="none" stroke="#F299A6" stroke-width="4" stroke-linecap="round"/>
  <path d="M 10,89 Q 20,97 30,89 Q 40,97 48,89 Q 58,97 68,89 Q 78,97 86,89" fill="none" stroke="#291F1C" stroke-width="2" stroke-linecap="round"/>
  <rect x="24" y="36" width="7" height="28" rx="2" fill="#FFFDF9" stroke="#291F1C" stroke-width="2" transform="rotate(-4 27 50)"/>
  <line x1="24" y1="45" x2="31" y2="43" stroke="#F299A6" stroke-width="2.2"/>
  <line x1="25" y1="55" x2="31" y2="53" stroke="#F299A6" stroke-width="2.2"/>
  <path d="M 26,32 C 22,26 26,18 26,15 C 29,19 31,26 26,32 Z" fill="#FDE075" stroke="#291F1C" stroke-width="1.8"/>
  <rect x="44.5" y="32" width="7" height="31" rx="2" fill="#FFFDF9" stroke="#291F1C" stroke-width="2"/>
  <line x1="45" y1="42" x2="51.5" y2="40" stroke="#F299A6" stroke-width="2.2"/>
  <line x1="45" y1="52" x2="51.5" y2="50" stroke="#F299A6" stroke-width="2.2"/>
  <path d="M 48,28 C 44,22 48,13 48,10 C 52,14 53,22 48,28 Z" fill="#FDE075" stroke="#291F1C" stroke-width="1.8"/>
  <rect x="65" y="37" width="7" height="27" rx="2" fill="#FFFDF9" stroke="#291F1C" stroke-width="2" transform="rotate(5 68 50)"/>
  <line x1="65" y1="46" x2="72" y2="48" stroke="#F299A6" stroke-width="2.2"/>
  <line x1="65" y1="55" x2="72" y2="57" stroke="#F299A6" stroke-width="2.2"/>
  <path d="M 69,33 C 65,27 70,19 70,16 C 73,20 74,27 69,33 Z" fill="#FDE075" stroke="#291F1C" stroke-width="1.8"/>
</g>
''',
  'giftBoxYellow': '''
<g transform="translate(3,8) rotate(-3)">
  <rect x="4" y="24" width="64" height="44" rx="3" fill="#FCD770" stroke="#291F1C" stroke-width="2.3"/>
  <rect x="0" y="14" width="72" height="12" rx="3" fill="#FDE28A" stroke="#291F1C" stroke-width="2.3"/>
  <rect x="30" y="14" width="12" height="54" fill="#F69CA9" stroke="#291F1C" stroke-width="2.2"/>
  <path d="M 36,14 C 24,-4 10,4 20,13 C 25,16 32,14 36,14 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="2.2"/>
  <path d="M 36,14 C 48,-4 62,4 52,13 C 47,16 40,14 36,14 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="2.2"/>
  <circle cx="36" cy="13" r="3.5" fill="#F69CA9" stroke="#291F1C" stroke-width="2"/>
</g>
''',
  'buntingBanner': '''
<g transform="translate(-10,-18)">
  <path d="M 32,36 Q 180,105 328,32" fill="none" stroke="#291F1C" stroke-width="2.4" stroke-linecap="round"/>
  <path d="M 55,46 L 60,92 L 92,60 Z" fill="#DCE9EE" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <circle cx="67" cy="64" r="2.2" fill="#8CC0D0"/>
  <circle cx="76" cy="62" r="2.2" fill="#8CC0D0"/>
  <circle cx="65" cy="76" r="2.2" fill="#8CC0D0"/>
  <path d="M 98,62 L 111,106 L 140,70 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <circle cx="114" cy="75" r="2.5" fill="#FFFDF9"/>
  <circle cx="124" cy="78" r="2.5" fill="#FFFDF9"/>
  <circle cx="113" cy="89" r="2.5" fill="#FFFDF9"/>
  <path d="M 145,70 L 164,114 L 188,72 Z" fill="#FCD770" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <circle cx="162" cy="82" r="2.4" fill="#FFFDF9"/>
  <circle cx="173" cy="84" r="2.4" fill="#FFFDF9"/>
  <circle cx="165" cy="96" r="2.4" fill="#FFFDF9"/>
  <path d="M 194,72 L 216,112 L 236,66 Z" fill="#9AC4D5" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <circle cx="210" cy="82" r="2.4" fill="#FFFDF9"/>
  <circle cx="222" cy="80" r="2.4" fill="#FFFDF9"/>
  <circle cx="215" cy="95" r="2.4" fill="#FFFDF9"/>
  <path d="M 242,64 L 268,102 L 281,53 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <circle cx="258" cy="72" r="2.5" fill="#FFFDF9"/>
  <circle cx="270" cy="68" r="2.5" fill="#FFFDF9"/>
  <circle cx="265" cy="84" r="2.5" fill="#FFFDF9"/>
  <path d="M 286,50 L 312,84 L 315,38 Z" fill="#FAD2D8" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <line x1="298" y1="46" x2="301" y2="69" stroke="#F299A6" stroke-width="2"/>
  <line x1="307" y1="42" x2="310" y2="76" stroke="#F299A6" stroke-width="2"/>
  <g transform="translate(32, 36)">
    <path d="M 0,0 C -14,-12 -18,4 -2,2 C 12,-12 18,2 0,0 Z" fill="none" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
    <path d="M -1,2 L -10,16 M 1,2 L 6,18" stroke="#291F1C" stroke-width="2.2" stroke-linecap="round"/>
  </g>
  <g transform="translate(328, 32)">
    <path d="M 0,0 C -14,-12 -18,4 -2,2 C 12,-12 18,2 0,0 Z" fill="none" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
    <path d="M -1,2 L -8,17 M 1,2 L 10,16" stroke="#291F1C" stroke-width="2.2" stroke-linecap="round"/>
  </g>
</g>
''',
  'pinkBalloon': '''
<g transform="translate(26,33)">
  <ellipse cx="0" cy="0" rx="24" ry="30" fill="#F69CA9" stroke="#291F1C" stroke-width="2.3"/>
  <path d="M 10,-16 Q 17,-6 14,8" fill="none" stroke="#FAD2D8" stroke-width="3.5" stroke-linecap="round"/>
  <polygon points="-4,30 4,30 6,35 -6,35" fill="#F69CA9" stroke="#291F1C" stroke-width="2" stroke-linejoin="round"/>
  <path d="M 0,35 Q 8,48 -2,60 Q -8,70 0,80" fill="none" stroke="#291F1C" stroke-width="2" stroke-linecap="round"/>
</g>
''',
  'partyHat': '''
<g transform="translate(38,23)">
  <path d="M -32,56 Q -24,64 -14,58 Q -4,65 6,58 Q 16,65 24,58 Q 34,62 32,52 Q 26,48 -30,50 Z" fill="#FDE075" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M 2,-10 L -28,51 Q 0,58 29,51 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round"/>
  <circle cx="1" cy="14" r="4" fill="#FFFDF9"/>
  <circle cx="-9" cy="30" r="4.5" fill="#FFFDF9"/>
  <circle cx="11" cy="29" r="4" fill="#FFFDF9"/>
  <circle cx="-17" cy="44" r="3.8" fill="#FFFDF9"/>
  <circle cx="2" cy="43" r="4.5" fill="#FFFDF9"/>
  <circle cx="19" cy="43" r="4" fill="#FFFDF9"/>
  <path d="M 2,-18 C 6,-20 10,-16 9,-12 C 12,-9 9,-4 5,-5 C 2,-2 -3,-4 -4,-7 C -8,-9 -6,-15 -2,-15 C -2,-18 0,-19 2,-18 Z" fill="#FDE075" stroke="#291F1C" stroke-width="2.1" stroke-linejoin="round"/>
</g>
''',
  'yellowBalloon': '''
<g transform="translate(28,34)">
  <ellipse cx="0" cy="0" rx="25" ry="31" fill="#FCD770" stroke="#291F1C" stroke-width="2.3"/>
  <path d="M -12,-16 Q -18,-6 -15,8" fill="none" stroke="#FEF0B5" stroke-width="3.2" stroke-linecap="round"/>
  <polygon points="-4,31 4,31 6,36 -6,36" fill="#FCD770" stroke="#291F1C" stroke-width="2" stroke-linejoin="round"/>
  <path d="M 1,36 Q 10,48 4,58 Q -2,68 8,78 Q 14,85 6,92" fill="none" stroke="#291F1C" stroke-width="2" stroke-linecap="round"/>
</g>
''',
  'wavingGirl': '''
<g transform="translate(0,2)">
  <path d="M 16,28 C 2,18 6,2 18,8 C 22,0 36,2 34,14 C 42,18 38,30 28,30 Z" fill="#8C583A" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="M 16,30 C 20,22 32,22 36,29 C 32,34 20,34 16,30 Z" fill="#F299A6" stroke="#291F1C" stroke-width="2"/>
  <path d="M 12,60 C 2,52 10,30 42,30 C 74,30 82,52 74,64 C 82,68 80,78 70,78 L 14,78 C 4,78 2,66 12,60 Z" fill="#8C583A" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="M 72,94 L 94,78 C 98,74 103,77 100,82 L 82,102 Z" fill="#FFE3D3" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <g transform="translate(96,78)">
    <path d="M -3,-2 L -6,-10 C -7,-13 -3,-14 -1,-10 L 1,-4 L 5,-11 C 7,-14 10,-12 8,-8 L 4,-2 L 10,-7 C 13,-9 15,-6 12,-3 L 6,1 L 12,-1 C 15,0 14,3 10,3 L 3,5" fill="#FFE3D3" stroke="#291F1C" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
  </g>
  <path d="M 18,88 C 22,78 64,78 70,88 L 78,104 L 12,104 Z" fill="#FFFDF9" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="M 16,94 L 72,94" stroke="#FCD770" stroke-width="5"/>
  <path d="M 14,101 L 75,101" stroke="#FCD770" stroke-width="5"/>
  <path d="M 18,88 C 22,78 64,78 70,88 L 78,104 L 12,104 Z" fill="none" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round"/>
  <circle cx="11" cy="64" r="6" fill="#FFE3D3" stroke="#291F1C" stroke-width="2.2"/>
  <circle cx="75" cy="64" r="6" fill="#FFE3D3" stroke="#291F1C" stroke-width="2.2"/>
  <ellipse cx="43" cy="62" rx="31" ry="25" fill="#FFE3D3" stroke="#291F1C" stroke-width="2.3"/>
  <path d="M 12,58 C 16,38 38,38 46,42 C 36,48 22,56 12,58 Z" fill="#8C583A" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M 44,40 C 56,40 70,48 74,58 C 62,54 50,48 44,40 Z" fill="#8C583A" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M 25,54 Q 29,51 32,53" fill="none" stroke="#291F1C" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M 54,53 Q 57,51 61,54" fill="none" stroke="#291F1C" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="29" cy="62" r="2.3" fill="#291F1C"/>
  <circle cx="57" cy="62" r="2.3" fill="#291F1C"/>
  <ellipse cx="22" cy="67" rx="5" ry="2.8" fill="#F4978E" opacity="0.65"/>
  <ellipse cx="64" cy="67" rx="5" ry="2.8" fill="#F4978E" opacity="0.65"/>
  <path d="M 39,67 Q 43,72 47,67" fill="none" stroke="#291F1C" stroke-width="2" stroke-linecap="round"/>
</g>
''',
  'tulipPink': '''
<g transform="translate(25,13)">
  <path d="M 0,14 Q -2,30 -1,44" fill="none" stroke="#291F1C" stroke-width="2.3" stroke-linecap="round"/>
  <path d="M -1,42 C -18,38 -22,24 -12,24 C -6,24 -2,34 -1,42 Z" fill="#A8D08D" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M -1,42 C 14,38 20,24 10,24 C 4,24 0,34 -1,42 Z" fill="#A8D08D" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M -16,-6 C -20,10 -10,18 0,18 C 10,18 20,10 16,-6 C 12,-6 8,0 6,2 C 4,-6 2,-10 0,-10 C -2,-10 -4,-6 -6,2 C -8,0 -12,-6 -16,-6 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
</g>
''',
  'smileyCloud': '''
<g transform="translate(47,30)">
  <path d="M -32,12 C -42,12 -44,-2 -32,-6 C -34,-18 -18,-24 -8,-16 C 0,-26 18,-22 20,-10 C 32,-12 38,0 30,8 C 36,16 24,24 14,18 C 6,24 -8,24 -14,18 C -22,22 -32,18 -32,12 Z" fill="#FFFFFF" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round"/>
  <circle cx="-8" cy="2" r="2" fill="#291F1C"/>
  <circle cx="8" cy="2" r="2" fill="#291F1C"/>
  <path d="M -2.5,5 Q 0,7.5 2.5,5" fill="none" stroke="#291F1C" stroke-width="1.8" stroke-linecap="round"/>
  <ellipse cx="-13" cy="5" rx="3" ry="1.6" fill="#F69CA9" opacity="0.65"/>
  <ellipse cx="13" cy="5" rx="3" ry="1.6" fill="#F69CA9" opacity="0.65"/>
</g>
''',
  'rainbowClouds': '''
<g transform="translate(52,39)">
  <path d="M -36,8 A 36,36 0 0,1 36,8" fill="none" stroke="#F69CA9" stroke-width="8"/>
  <path d="M -29,8 A 29,29 0 0,1 29,8" fill="none" stroke="#FDE075" stroke-width="7"/>
  <path d="M -22,8 A 22,22 0 0,1 22,8" fill="none" stroke="#9AC4D5" stroke-width="7"/>
  <path d="M -40,8 A 40,40 0 0,1 40,8" fill="none" stroke="#291F1C" stroke-width="2.2"/>
  <path d="M -32,8 A 32,32 0 0,1 32,8" fill="none" stroke="#291F1C" stroke-width="1.8"/>
  <path d="M -25,8 A 25,25 0 0,1 25,8" fill="none" stroke="#291F1C" stroke-width="1.8"/>
  <path d="M -18,8 A 18,18 0 0,1 18,8" fill="none" stroke="#291F1C" stroke-width="2.2"/>
  <g transform="translate(-30, 10)">
    <path d="M -14,4 C -19,4 -19,-4 -12,-5 C -12,-12 -2,-13 2,-7 C 8,-11 16,-5 13,2 C 17,7 10,12 4,9 C -1,13 -9,11 -11,7 C -14,8 -16,6 -14,4 Z" fill="#FFFFFF" stroke="#291F1C" stroke-width="2.1" stroke-linejoin="round"/>
    <circle cx="-4" cy="1" r="1.4" fill="#291F1C"/>
    <circle cx="4" cy="1" r="1.4" fill="#291F1C"/>
    <path d="M -1.5,3 Q 0,5 1.5,3" fill="none" stroke="#291F1C" stroke-width="1.5" stroke-linecap="round"/>
  </g>
  <g transform="translate(30, 12)">
    <path d="M -14,4 C -19,4 -19,-4 -12,-5 C -12,-12 -2,-13 2,-7 C 8,-11 16,-5 13,2 C 17,7 10,12 4,9 C -1,13 -9,11 -11,7 C -14,8 -16,6 -14,4 Z" fill="#FFFFFF" stroke="#291F1C" stroke-width="2.1" stroke-linejoin="round"/>
    <circle cx="-4" cy="1" r="1.4" fill="#291F1C"/>
    <circle cx="4" cy="1" r="1.4" fill="#291F1C"/>
    <path d="M -1.5,3 Q 0,5 1.5,3" fill="none" stroke="#291F1C" stroke-width="1.5" stroke-linecap="round"/>
  </g>
</g>
''',
  'cupcake': '''
<g transform="translate(33,57)">
  <path d="M -22,12 L -16,42 C -15,46 15,46 16,42 L 22,12 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round"/>
  <line x1="-11" y1="14" x2="-8" y2="43" stroke="#291F1C" stroke-width="1.9" stroke-linecap="round"/>
  <line x1="0" y1="15" x2="0" y2="44" stroke="#291F1C" stroke-width="1.9" stroke-linecap="round"/>
  <line x1="11" y1="14" x2="8" y2="43" stroke="#291F1C" stroke-width="1.9" stroke-linecap="round"/>
  <path d="M -22,14 C -30,12 -28,-2 -18,0 C -20,-10 -10,-14 -4,-12 C 0,-16 8,-14 14,-8 C 20,-10 26,-2 20,4 C 28,6 26,16 18,15 C 12,18 4,16 0,14 C -6,18 -16,17 -22,14 Z" fill="#FFFDF9" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="M -12,4 Q 0,9 12,3" fill="none" stroke="#291F1C" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="-8" cy="-3" r="1.4" fill="#F69CA9"/>
  <circle cx="7" cy="-2" r="1.4" fill="#E5B968"/>
  <circle cx="2" cy="10" r="1.4" fill="#9AC4D5"/>
  <rect x="-3" y="-34" width="6" height="22" rx="1.5" fill="#FAD2D8" stroke="#291F1C" stroke-width="2"/>
  <line x1="-3" y1="-26" x2="3" y2="-28" stroke="#291F1C" stroke-width="1.8"/>
  <line x1="-3" y1="-19" x2="3" y2="-21" stroke="#291F1C" stroke-width="1.8"/>
  <path d="M 0,-37 C -4,-43 0,-51 0,-54 C 4,-50 4,-42 0,-37 Z" fill="#FDE075" stroke="#291F1C" stroke-width="1.9"/>
</g>
''',
  'partyBear': '''
<g transform="translate(53,60)">
  <path d="M -28,22 C -42,10 -50,2 -46,-3 C -42,-8 -32,0 -20,12 Z" fill="#D5A687" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="M -28,36 C -26,18 -16,12 0,12 C 16,12 24,20 28,36" fill="#D5A687" stroke="#291F1C" stroke-width="2.3" stroke-linecap="round"/>
  <circle cx="-22" cy="-18" r="10" fill="#D5A687" stroke="#291F1C" stroke-width="2.3"/>
  <circle cx="-22" cy="-18" r="5" fill="#ECC8B0"/>
  <circle cx="26" cy="-10" r="10" fill="#D5A687" stroke="#291F1C" stroke-width="2.3"/>
  <circle cx="26" cy="-10" r="5" fill="#ECC8B0"/>
  <ellipse cx="1" cy="0" rx="28" ry="23" transform="rotate(8 1 0)" fill="#D5A687" stroke="#291F1C" stroke-width="2.3"/>
  <g transform="translate(8, -22) rotate(14)">
    <path d="M 0,-24 L -13,4 Q 0,8 13,4 Z" fill="#FFFDF9" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
    <path d="M -7,-9 L 7,-9 L 10,-2 L -10,-2 Z" fill="#F69CA9"/>
    <path d="M -4,-17 L 4,-17 L 6,-13 L -6,-13 Z" fill="#F69CA9"/>
    <path d="M 0,-24 L -13,4 Q 0,8 13,4 Z" fill="none" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
    <circle cx="0" cy="-27" r="4.5" fill="#FDE075" stroke="#291F1C" stroke-width="2"/>
  </g>
  <ellipse cx="0" cy="4" rx="10" ry="8" fill="#FFFDF9"/>
  <circle cx="-10" cy="-3" r="2.2" fill="#291F1C"/>
  <circle cx="11" cy="0" r="2.2" fill="#291F1C"/>
  <ellipse cx="-16" cy="2" rx="4" ry="2.2" fill="#F4978E" opacity="0.65"/>
  <ellipse cx="16" cy="6" rx="4" ry="2.2" fill="#F4978E" opacity="0.65"/>
  <ellipse cx="0" cy="2" rx="3.2" ry="2.2" fill="#291F1C"/>
  <path d="M 0,4 L -3,8 M 0,4 L 3,8" fill="none" stroke="#291F1C" stroke-width="1.9" stroke-linecap="round"/>
</g>
''',
  'loveEnvelope': '''
<g transform="translate(5,17) rotate(-14)">
  <rect x="0" y="0" width="58" height="38" rx="3" fill="#FDE28A" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="M 2,36 L 24,18 M 56,36 L 34,18" stroke="#291F1C" stroke-width="2" stroke-linecap="round"/>
  <path d="M 1,1 L 29,22 L 57,1" fill="#FCD770" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <g transform="translate(29,15) scale(0.85)">
    <path d="M 0,2.5 C -2.5,-2.5 -8,-1 -7.5,3.5 C -7,7.5 -1,10 0,12 C 1,10 7,7.5 7.5,3.5 C 8,-1 2.5,-2.5 0,2.5 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
  </g>
</g>
''',
  'sixPetalFlower': '''
<g transform="translate(25,24)">
  <path d="M 0,12 L 0,44" stroke="#291F1C" stroke-width="2.3" stroke-linecap="round"/>
  <path d="M 0,42 C -16,38 -22,26 -12,26 C -6,26 -1,34 0,42 Z" fill="#A8D08D" stroke="#291F1C" stroke-width="2.1" stroke-linejoin="round"/>
  <path d="M 0,42 C 16,38 22,26 12,26 C 6,26 1,34 0,42 Z" fill="#A8D08D" stroke="#291F1C" stroke-width="2.1" stroke-linejoin="round"/>
  <g transform="translate(0, 2)">
    <ellipse cx="0" cy="-12" rx="5.5" ry="9" fill="#F69CA9" stroke="#291F1C" stroke-width="2.1"/>
    <ellipse cx="0" cy="12" rx="5.5" ry="9" fill="#F69CA9" stroke="#291F1C" stroke-width="2.1"/>
    <ellipse cx="0" cy="-12" rx="5.5" ry="9" transform="rotate(60)" fill="#F69CA9" stroke="#291F1C" stroke-width="2.1"/>
    <ellipse cx="0" cy="12" rx="5.5" ry="9" transform="rotate(60)" fill="#F69CA9" stroke="#291F1C" stroke-width="2.1"/>
    <ellipse cx="0" cy="-12" rx="5.5" ry="9" transform="rotate(120)" fill="#F69CA9" stroke="#291F1C" stroke-width="2.1"/>
    <ellipse cx="0" cy="12" rx="5.5" ry="9" transform="rotate(120)" fill="#F69CA9" stroke="#291F1C" stroke-width="2.1"/>
    <circle cx="0" cy="0" r="5.5" fill="#FDE075" stroke="#291F1C" stroke-width="2.1"/>
  </g>
</g>
''',
  'sparkleBunny': '''
<g transform="translate(42,78)">
  <path d="M -22,-22 C -30,-56 -22,-74 -14,-72 C -6,-70 -4,-48 -8,-22 Z" fill="#FFFFFF" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="M -18,-26 C -22,-48 -18,-62 -14,-60 C -10,-58 -9,-42 -12,-26 Z" fill="#FAD2D8"/>
  <path d="M 8,-22 C 6,-50 12,-72 20,-70 C 28,-68 28,-48 20,-20 Z" fill="#FFFFFF" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="M 12,-25 C 11,-44 15,-60 19,-58 C 23,-56 22,-42 17,-24 Z" fill="#FAD2D8"/>
  <path d="M -32,26 C -38,6 -32,-24 0,-24 C 32,-24 38,6 32,26 Z" fill="#FFFFFF" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round"/>
  <circle cx="-12" cy="2" r="2.4" fill="#291F1C"/>
  <circle cx="12" cy="2" r="2.4" fill="#291F1C"/>
  <ellipse cx="-20" cy="8" rx="4.8" ry="2.5" fill="#F69CA9" opacity="0.65"/>
  <ellipse cx="20" cy="8" rx="4.8" ry="2.5" fill="#F69CA9" opacity="0.65"/>
  <ellipse cx="0" cy="6" rx="2.5" ry="1.8" fill="#291F1C"/>
  <path d="M -5,10 Q -2.5,13 0,9 Q 2.5,13 5,10" fill="none" stroke="#291F1C" stroke-width="1.9" stroke-linecap="round"/>
  <ellipse cx="-24" cy="26" rx="10" ry="6.5" fill="#FFFFFF" stroke="#291F1C" stroke-width="2.2"/>
  <ellipse cx="24" cy="26" rx="10" ry="6.5" fill="#FFFFFF" stroke="#291F1C" stroke-width="2.2"/>
</g>
''',
  'bowGirl': '''
<g transform="translate(66,70)">
  <path d="M -52,22 C -62,14 -56,-4 -48,-12 C -50,-42 -28,-62 0,-62 C 28,-62 50,-42 48,-12 C 56,-4 62,14 52,22 C 60,28 54,38 42,34 L -42,34 C -54,38 -60,28 -52,22 Z" fill="#8C583A" stroke="#291F1C" stroke-width="2.4" stroke-linejoin="round"/>
  <path d="M -38,-22 C -32,-52 32,-52 38,-22" fill="none" stroke="#F69CA9" stroke-width="9" stroke-linecap="round"/>
  <path d="M -40,-20 C -34,-54 34,-54 40,-20" fill="none" stroke="#291F1C" stroke-width="2.2" stroke-linecap="round"/>
  <path d="M -36,-16 C -30,-46 30,-46 36,-16" fill="none" stroke="#291F1C" stroke-width="2.2" stroke-linecap="round"/>
  <path d="M 2,-50 C -8,-66 -22,-58 -12,-48 C -6,-44 0,-48 2,-50 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M 2,-50 C 12,-66 26,-58 16,-48 C 10,-44 4,-48 2,-50 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <circle cx="2" cy="-50" r="3.5" fill="#F69CA9" stroke="#291F1C" stroke-width="2"/>
  <circle cx="-40" cy="4" r="7.5" fill="#FFE3D3" stroke="#291F1C" stroke-width="2.2"/>
  <circle cx="40" cy="4" r="7.5" fill="#FFE3D3" stroke="#291F1C" stroke-width="2.2"/>
  <ellipse cx="0" cy="2" rx="38" ry="30" fill="#FFE3D3" stroke="#291F1C" stroke-width="2.4"/>
  <path d="M -38,-6 C -32,-28 -6,-34 10,-30 C -4,-20 -22,-10 -38,-6 Z" fill="#8C583A" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M 8,-30 C 24,-28 36,-16 38,-4 C 24,-10 14,-20 8,-30 Z" fill="#8C583A" stroke="#291F1C" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M -20,-8 Q -16,-11 -12,-9" fill="none" stroke="#291F1C" stroke-width="2" stroke-linecap="round"/>
  <path d="M 12,-9 Q 16,-11 20,-8" fill="none" stroke="#291F1C" stroke-width="2" stroke-linecap="round"/>
  <circle cx="-16" cy="2" r="2.6" fill="#291F1C"/>
  <circle cx="16" cy="2" r="2.6" fill="#291F1C"/>
  <ellipse cx="-24" cy="9" rx="6" ry="3.2" fill="#F4978E" opacity="0.7"/>
  <ellipse cx="24" cy="9" rx="6" ry="3.2" fill="#F4978E" opacity="0.7"/>
  <path d="M 0,4 L -1,7" stroke="#291F1C" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M -5,11 Q 0,16 5,11" fill="none" stroke="#291F1C" stroke-width="2.1" stroke-linecap="round"/>
  <path d="M -42,40 C -46,26 -30,22 -16,28 L -6,42 C -22,46 -38,46 -42,40 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="M 42,40 C 46,26 30,22 16,28 L 6,42 C 22,46 38,46 42,40 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="2.3" stroke-linejoin="round"/>
  <ellipse cx="-8" cy="32" rx="9" ry="7" fill="#FFE3D3" stroke="#291F1C" stroke-width="2.2"/>
  <ellipse cx="8" cy="32" rx="9" ry="7" fill="#FFE3D3" stroke="#291F1C" stroke-width="2.2"/>
</g>
''',
  'partyBalloonBig': '''
<g transform="translate(31,38)">
  <ellipse cx="0" cy="0" rx="28" ry="35" fill="#FCD770" stroke="#291F1C" stroke-width="2.4"/>
  <path d="M 12,-18 Q 20,-6 16,10" fill="none" stroke="#FEF0B5" stroke-width="3.8" stroke-linecap="round"/>
  <polygon points="-5,35 5,35 7,41 -7,41" fill="#FCD770" stroke="#291F1C" stroke-width="2.1" stroke-linejoin="round"/>
  <path d="M 0,41 C 16,64 6,88 18,108" fill="none" stroke="#291F1C" stroke-width="2.2" stroke-linecap="round"/>
  <path d="M 30,98 C 44,116 32,140 42,164" fill="none" stroke="#291F1C" stroke-width="2.2" stroke-linecap="round"/>
</g>
''',
  'twinGiftBoxes': '''
<g transform="translate(3,12)">
  <g transform="translate(0, 26)">
    <rect x="4" y="10" width="50" height="32" rx="2" fill="#C6DFE6" stroke="#291F1C" stroke-width="2.2"/>
    <rect x="0" y="2" width="58" height="10" rx="2" fill="#DCE9EE" stroke="#291F1C" stroke-width="2.2"/>
    <rect x="24" y="2" width="10" height="40" fill="#F69CA9" stroke="#291F1C" stroke-width="2.1"/>
    <path d="M 29,2 C 18,-10 8,-2 17,2 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="2.1"/>
    <path d="M 29,2 C 40,-10 50,-2 41,2 Z" fill="#F69CA9" stroke="#291F1C" stroke-width="2.1"/>
  </g>
  <g transform="translate(52, 6)">
    <rect x="4" y="14" width="62" height="48" rx="2" fill="#F69CA9" stroke="#291F1C" stroke-width="2.3"/>
    <circle cx="16" cy="28" r="3" fill="#FFFDF9"/>
    <circle cx="14" cy="46" r="3" fill="#FFFDF9"/>
    <circle cx="24" cy="38" r="2.8" fill="#FFFDF9"/>
    <circle cx="52" cy="28" r="3" fill="#FFFDF9"/>
    <circle cx="54" cy="46" r="3" fill="#FFFDF9"/>
    <circle cx="44" cy="38" r="2.8" fill="#FFFDF9"/>
    <rect x="0" y="4" width="70" height="12" rx="2" fill="#FAD2D8" stroke="#291F1C" stroke-width="2.3"/>
    <rect x="29" y="4" width="12" height="58" fill="#FDE075" stroke="#291F1C" stroke-width="2.2"/>
    <path d="M 35,4 C 22,-14 6,-4 18,4 C 24,7 30,4 35,4 Z" fill="#FDE075" stroke="#291F1C" stroke-width="2.2"/>
    <path d="M 35,4 C 48,-14 64,-4 52,4 C 46,7 40,4 35,4 Z" fill="#FDE075" stroke="#291F1C" stroke-width="2.2"/>
    <path d="M 32,4 L 20,16 M 38,4 L 50,16" stroke="#291F1C" stroke-width="2.2" stroke-linecap="round"/>
    <circle cx="35" cy="4" r="3.5" fill="#FDE075" stroke="#291F1C" stroke-width="2"/>
  </g>
</g>
''',
};

/// 贴纸 viewBox 完整尺寸（宽, 高）
const Map<String, List<int>> cuteNotepadStickerViewBoxes = {
  'redBow': [100, 100],
  'pinkDoubleHearts': [100, 90],
  'peekingBunny': [125, 112],
  'topYellowFlower': [95, 85],
  'bottomWhiteDaisies': [105, 105],
  'purpleCloudRain': [105, 90],
  'greenHeart': [70, 70],
  'cuteFrog': [125, 105],
  'blueCloud': [100, 80],
  'blueDoubleHearts': [90, 80],
  'pinkHeartTape': [140, 56],
  'pinkTulips': [96, 102],
  'smilingSun': [100, 100],
  'yellowFlowersBottomLeft': [100, 100],
  'peekingCat': [135, 105],
  'greenPlaidTape': [130, 52],
  'greenSprout': [85, 85],
  'purpleTinyHeart': [50, 50],
  'purpleFlowersBottomLeft': [105, 102],
  'blueOutlineHeart': [60, 60],
  'cutePenguin': [120, 110],
  'redPaperclip': [80, 85],
  'coralDoubleHearts': [85, 80],
  'cuteCherries': [90, 90],
  'purpleBow': [100, 100],
  'purpleDoubleHearts': [80, 80],
  'yellowPolkaTape': [130, 50],
  'cuteBear': [115, 108],
  'coralSparkleLines': [60, 65],
  'blueTopTape': [100, 40],
  'shiningBlueHeart': [95, 92],
  'pinkRibbonBow': [96, 96],
  'peekingBear': [72, 46],
  'purpleStemFlower': [50, 56],
  'brownStemFlower': [50, 56],
  'bluePlaidTape': [130, 52],
  'yellowSparkle': [30, 30],
  'leafBranch': [46, 84],
  'strawberry': [54, 64],
  'pottedSucculent': [46, 62],
  'yellowStar': [50, 50],
  'heartPaperclip': [44, 60],
  'crescentMoon': [50, 58],

  // 生日涂鸦贴图集
  'smileyStar': [60, 60],
  'pinkHeart': [34, 30],
  'miniHeart': [22, 20],
  'pinkFlower': [36, 36],
  'birthdayCake': [100, 120],
  'giftBoxYellow': [78, 80],
  'buntingBanner': [340, 100],
  'pinkBalloon': [52, 116],
  'partyHat': [76, 92],
  'yellowBalloon': [56, 130],
  'wavingGirl': [116, 110],
  'tulipPink': [48, 60],
  'smileyCloud': [90, 58],
  'rainbowClouds': [102, 70],
  'cupcake': [64, 106],
  'partyBear': [98, 102],
  'loveEnvelope': [66, 62],
  'sixPetalFlower': [50, 70],
  'sparkleBunny': [84, 116],
  'bowGirl': [132, 122],
  'partyBalloonBig': [78, 206],
  'twinGiftBoxes': [128, 84],
};

/// 获取贴纸的完整 SVG 文档字符串（供 SvgPicture.string 使用）
String cuteNotepadStickerSvg(String id) {
  final body = cuteNotepadStickerBodies[id];
  final box = cuteNotepadStickerViewBoxes[id];
  if (body == null || box == null) return '';
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${box[0]} ${box[1]}" '
      'width="${box[0]}" height="${box[1]}">$body</svg>';
}
