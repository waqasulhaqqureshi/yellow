#!/usr/bin/env python3
"""Chess Arena offline static audit (no Flutter SDK needed).

Run:  python3 tool/audit.py   (from repo root)

Checks:
  1. Every relative import resolves to an existing file.
  2. Every package: import is in pubspec.yaml dependencies.
  3. Balanced {}, (), [] per file (strings/comments stripped).
  4. EXTENSION-MEMBER RULE (the big one): Dart extensions only work when the
     declaring library is DIRECTLY imported (transitive imports do NOT
     count). Any `.member` use must import a declaring file.
  5. TYPE-USE RULE: any own-project type name used in code must be imported
     from its defining file.
  6. No `.withOpacity(` (deprecated; use `.withValues(alpha:)`).
  7. No `__`/`___` throwaway params (use named params).
  8. Every `Icons.X` must be on the verified allowlist (SDK icons differ by
     version; unverified icons break the build).
  9. No standalone `_` used as a VALUE (Dart 3.7+: `_` is a wildcard —
     declaring it as an unused param is fine, but referencing it is
     `undefined_identifier`). Param lists (`(...) =>` / `(...) {`) are
     declarations and `._()` is a private named constructor; any other
     standalone `_` is flagged.
 10. Bundled chess-piece assets are declared, present, transparent PNGs,
     mapped by PieceGlyphs, and rendered through the inversion filter.
 11. Critical reference-flow bindings remain wired: the Device Preview 1.x
     wrapper/configuration, selected clocks, live board settings, and the
     post-game Review Game action.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")

# --- symbol tables -----------------------------------------------------------
# own type name -> defining file (lib-relative)
OWN_TYPES = {
    "PieceGlyphs": "lib/core/utils/piece_glyphs.dart",
    "ArenaTheme": "lib/core/theme/arena_theme.dart",
    "HiveSetup": "lib/core/db/hive_setup.dart",
    "BotAvatar": "lib/core/widgets/flag_avatar.dart",
    "CountryFlag": "lib/core/widgets/flag_avatar.dart",
    "ChessPieceImage": "lib/core/widgets/chess_piece_image.dart",
    "GameResult": "lib/features/game/domain/game_result.dart",
    "MoveRecord": "lib/features/game/presentation/move_record.dart",
    "GameController": "lib/features/game/presentation/game_controller.dart",
    "PlayPhase": "lib/features/game/presentation/game_controller.dart",
    "CapturedInfo": "lib/features/game/presentation/game_controller.dart",
    "HomeScreen": "lib/features/game/presentation/screens/home_screen.dart",
    "SearchingScreen": "lib/features/game/presentation/screens/searching_screen.dart",
    "GameScreen": "lib/features/game/presentation/screens/game_screen.dart",
    "PlayerBar": "lib/features/game/presentation/widgets/player_bar.dart",
    "ChessBoardWidget": "lib/features/game/presentation/widgets/chess_board_widget.dart",
    "ChatSheet": "lib/features/game/presentation/widgets/chat_sheet.dart",
    "PromotionDialog": "lib/features/game/presentation/widgets/promotion_dialog.dart",
    "GameOverDialog": "lib/features/game/presentation/widgets/game_over_dialog.dart",
    "BotPersonality": "lib/features/bot/domain/bot_personality.dart",
    "BotTier": "lib/features/bot/domain/bot_difficulty.dart",
    "BotTiering": "lib/features/bot/domain/bot_difficulty.dart",
    "BotProfile": "lib/features/bot/domain/bot_profile.dart",
    "BotNamePool": "lib/features/bot/data/bot_names.dart",
    "BotGenerator": "lib/features/bot/data/bot_generator.dart",
    "OpeningBook": "lib/features/engine/opening_book.dart",
    "ChessEval": "lib/features/engine/chess_eval.dart",
    "MoveVerdict": "lib/features/engine/move_quality.dart",
    "MoveAssessment": "lib/features/engine/move_quality.dart",
    "BlunderTracker": "lib/features/engine/move_quality.dart",
    "EngineSettings": "lib/features/engine/difficulty_mapper.dart",
    "DifficultyMapper": "lib/features/engine/difficulty_mapper.dart",
    "ArenaSearch": "lib/features/engine/arena_search.dart",
    "ScoredMove": "lib/features/engine/arena_search.dart",
    "ArenaBrain": "lib/features/engine/arena_brain.dart",
    "HumanMoveOutcome": "lib/features/engine/arena_brain.dart",
    "BotMoveOutcome": "lib/features/engine/arena_brain.dart",
    "OpponentSource": "lib/features/matchmaking/opponent_source.dart",
    "OfflineBotSource": "lib/features/matchmaking/opponent_source.dart",
    "MatchmakingController": "lib/features/matchmaking/matchmaking_controller.dart",
    "SearchPhase": "lib/features/matchmaking/matchmaking_controller.dart",
    "ChatMessage": "lib/features/chat/chat_message.dart",
    "BotChatEvent": "lib/features/chat/chat_matrix.dart",
    "UserIntent": "lib/features/chat/chat_matrix.dart",
    "ChatMatrix": "lib/features/chat/chat_matrix.dart",
    "SmartReplyService": "lib/features/chat/smart_reply_service.dart",
    "BotChatBrain": "lib/features/chat/bot_chat_brain.dart",
    "PlayerProfile": "lib/features/profile/domain/player_profile.dart",
    "PlayerProfileAdapter": "lib/features/profile/domain/player_profile.dart",
    "GameRecord": "lib/features/profile/domain/game_record.dart",
    "GameRecordAdapter": "lib/features/profile/domain/game_record.dart",
    "ProfileRepository": "lib/features/profile/data/profile_repository.dart",
    "EloService": "lib/features/rating/elo_service.dart",
    "EloPreview": "lib/features/rating/elo_service.dart",
    "ChessArenaApp": "lib/main.dart",
}

# extension member name -> files that declare it (a use must import one of them)
EXT_MEMBERS = {
    "chatCooldown": ["lib/features/bot/domain/bot_personality.dart"],
    "chatFrequency": ["lib/features/bot/domain/bot_personality.dart"],
    "tagline": ["lib/features/bot/domain/bot_personality.dart"],
    "usesEmoji": ["lib/features/bot/domain/bot_personality.dart"],
    "glyph": ["lib/features/engine/move_quality.dart"],
    "short": ["lib/features/game/domain/game_result.dart"],
    "label": [
        "lib/features/bot/domain/bot_personality.dart",
        "lib/features/bot/domain/bot_difficulty.dart",
        "lib/features/game/domain/game_result.dart",
        "lib/features/engine/move_quality.dart",
    ],
}

ICON_ALLOWLIST = {
    "bolt", "chat_bubble_outline", "close", "edit", "flag_outlined",
    "refresh", "restart_alt", "send",
}


def strip_code(src):
    """Remove strings + comments; keep code only.

    `${...}` interpolations are real code, so their contents are preserved
    (recursively stripped) instead of being blanked with the string.
    """
    out = []
    i, n = 0, len(src)
    NORMAL, SQ, DQ, LC, BC = range(5)
    st = NORMAL
    while i < n:
        ch = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if st == NORMAL:
            if ch == "/" and nxt == "/":
                st = LC; i += 2; continue
            if ch == "/" and nxt == "*":
                st = BC; i += 2; continue
            if ch == "'":
                st = SQ; i += 1; continue
            if ch == '"':
                st = DQ; i += 1; continue
            out.append(ch); i += 1
        elif st == SQ or st == DQ:
            quote = "'" if st == SQ else '"'
            if ch == "\\":
                i += 2; continue
            if ch == "$" and nxt == "{":
                span, i = _read_interp(src, i + 2)
                out.append("{" + strip_code(span) + "}")
                continue
            if ch == quote:
                st = NORMAL
            i += 1
        elif st == LC:
            if ch == "\n":
                st = NORMAL; out.append(ch)
            i += 1
        elif st == BC:
            if ch == "*" and nxt == "/":
                st = NORMAL; i += 2; continue
            i += 1
    return "".join(out)


def _read_interp(src, i):
    """Read a balanced `{...}` span starting after `${`; returns (span, idx)."""
    depth = 1
    buf = []
    n = len(src)
    st = 0  # 0 code, 1 sq, 2 dq, 3 lc, 4 bc
    while i < n and depth > 0:
        ch = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if st == 0:
            if ch == "/" and nxt == "/":
                st = 3; i += 2; continue
            if ch == "/" and nxt == "*":
                st = 4; i += 2; continue
            if ch == "'":
                st = 1; i += 1; continue
            if ch == '"':
                st = 2; i += 1; continue
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    i += 1
                    break
            buf.append(ch); i += 1
        elif st == 1 or st == 2:
            if ch == "\\":
                i += 2; continue
            q = "'" if st == 1 else '"'
            if ch == q:
                st = 0
            i += 1
        elif st == 3:
            if ch == "\n":
                st = 0
            i += 1
        elif st == 4:
            if ch == "*" and nxt == "/":
                st = 0; i += 2; continue
            i += 1
    return "".join(buf), i

def main():
    with open(os.path.join(ROOT, "pubspec.yaml")) as f:
        pub = f.read()
    declared = set(re.findall(r"^  ([a-z0-9_]+):", pub, flags=re.M))

    dart_files = []
    for dp, _, fn in os.walk(LIB):
        for f in fn:
            if f.endswith(".dart"):
                dart_files.append(os.path.join(dp, f))

    errors = []

    # Board assets: validate both Flutter registration and the files before
    # inspecting Dart references. PNG dimensions live at bytes 16..23.
    piece_names = ("bishop", "king", "knight", "pawn", "queen", "rook")
    asset_dir = os.path.join(ROOT, "assets", "chess", "pieces")
    if "- assets/chess/pieces/" not in pub:
        errors.append("pubspec.yaml: chess-piece asset directory is not declared")
    for notice in ("LICENSE", "ATTRIBUTION.md"):
        if not os.path.isfile(os.path.join(asset_dir, notice)):
            errors.append(f"assets/chess/pieces/{notice}: attribution file missing")
    glyph_source = open(os.path.join(LIB, "core", "utils", "piece_glyphs.dart")).read()
    piece_widget = open(
        os.path.join(LIB, "core", "widgets", "chess_piece_image.dart")
    ).read()
    if "ColorFiltered" not in piece_widget or "ColorFilter.matrix" not in piece_widget:
        errors.append("ChessPieceImage: black-piece inversion filter is missing")
    for name in piece_names:
        rel_asset = f"assets/chess/pieces/{name}.png"
        asset_path = os.path.join(ROOT, rel_asset)
        if not os.path.isfile(asset_path):
            errors.append(f"missing chess-piece asset {rel_asset}")
            continue
        data = open(asset_path, "rb").read()
        if len(data) < 29 or data[:8] != b"\x89PNG\r\n\x1a\n":
            errors.append(f"{rel_asset}: invalid PNG signature/header")
        else:
            width = int.from_bytes(data[16:20], "big")
            height = int.from_bytes(data[20:24], "big")
            color_type = data[25]
            if width <= 0 or height <= 0:
                errors.append(f"{rel_asset}: invalid dimensions {width}x{height}")
            if color_type not in (4, 6) and b"tRNS" not in data:
                errors.append(f"{rel_asset}: no alpha transparency channel")
        if rel_asset not in glyph_source:
            errors.append(f"PieceGlyphs: asset is not mapped: {rel_asset}")

    # Reference-flow wiring. These checks protect behavior that can still parse
    # correctly while silently dropping a selected clock, a board setting, or
    # the intended post-game review action.
    main_source = open(os.path.join(LIB, "main.dart")).read()
    if "device_preview: ^1.3.1" not in pub:
        errors.append("pubspec.yaml: expected device_preview ^1.3.1")
    if "DevicePreview.enable()" in main_source:
        errors.append("main.dart: DevicePreview.enable belongs to incompatible 3.x API")
    for snippet in (
        "DevicePreview(",
        "enabled: !kReleaseMode",
        "locale: DevicePreview.locale(context)",
        "builder: DevicePreview.appBuilder",
    ):
        if snippet not in main_source:
            errors.append(f"main.dart: missing Device Preview 1.x binding `{snippet}`")
    flow_requirements = {
        "features/game/presentation/screens/home_screen.dart": (
            "timeControl: _timeControl",
        ),
        "features/game/presentation/screens/searching_screen.dart": (
            "timeControl: widget.timeControl",
        ),
        "features/game/presentation/screens/game_screen.dart": (
            "final boardSide = constraints.maxWidth",
            "SingleChildScrollView(",
            "animatePieces: _pieceAnimation",
            "validTargets: _showMoveHelp",
            "lastMove: _showLastMove",
            "onReview:",
        ),
        "features/game/presentation/widgets/chess_board_widget.dart": (
            "ChessPieceImage(value: value)",
            "final bool animatePieces",
        ),
        "features/game/presentation/widgets/game_over_dialog.dart": (
            "onPressed: onReview",
            "Review Game",
        ),
    }
    for rel_path, snippets in flow_requirements.items():
        flow_source = open(os.path.join(LIB, rel_path)).read()
        for snippet in snippets:
            if snippet not in flow_source:
                errors.append(f"lib/{rel_path}: missing flow binding `{snippet}`")

    for path in sorted(dart_files):
        rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
        src = open(path).read()
        code = strip_code(src)

        # resolve this file's imports to lib-relative paths
        resolved = set()
        for m in re.finditer(r"import\s+'([^']+)'", src):
            imp = m.group(1)
            if imp.startswith("dart:"):
                continue
            if imp.startswith("package:"):
                pkg = imp.split("/")[0].split(":")[1]
                if pkg == "chess_arena_genetom":
                    rest = "/".join(imp.split("/")[1:])
                    target = os.path.normpath(os.path.join(LIB, rest))
                    if not os.path.exists(target):
                        errors.append(f"{rel}: missing self import {imp}")
                    else:
                        resolved.add(
                            os.path.relpath(target, ROOT).replace(os.sep, "/")
                        )
                    continue
                if pkg not in declared:
                    errors.append(f"{rel}: undeclared package import {imp}")
                continue
            target = os.path.normpath(os.path.join(os.path.dirname(path), imp))
            if not os.path.exists(target):
                errors.append(f"{rel}: missing import {imp}")
            else:
                resolved.add(os.path.relpath(target, ROOT).replace(os.sep, "/"))

        # balance
        for a, b in [("{", "}"), ("(", ")"), ("[", "]")]:
            if code.count(a) != code.count(b):
                errors.append(
                    f"{rel}: unbalanced {a}{b}: {code.count(a)} vs {code.count(b)}"
                )

        # code without import lines (for usage checks)
        code_no_imports = re.sub(r"import\s+'[^']+';", "", code)

        # extension-member rule (receiver-precise where possible)
        receivers = {
            "tier": ["lib/features/bot/domain/bot_difficulty.dart"],
            "personality": ["lib/features/bot/domain/bot_personality.dart"],
            "result": ["lib/features/game/domain/game_result.dart"],
            "verdict": ["lib/features/engine/move_quality.dart"],
        }
        unique = {"chatCooldown", "chatFrequency", "tagline", "glyph", "short"}
        for member, declarers in EXT_MEMBERS.items():
            for m in re.finditer(
                r"(\w+)\??\.\s*" + member + r"\b", code_no_imports
            ):
                # `.label` also exists as a real field (MoveRecord.label):
                # only flag it on known extension receivers.
                if member not in unique and m.group(1) not in receivers:
                    continue
                need = receivers.get(m.group(1), declarers)
                if rel not in need and not (resolved & set(need)):
                    errors.append(
                        f"{rel}: uses `.{member}` on `{m.group(1)}` without "
                        f"importing {need[0]}"
                    )

        # type-use rule
        for sym, definer in OWN_TYPES.items():
            if rel == definer:
                continue
            if re.search(r"\b" + sym + r"\b", code_no_imports):
                if definer not in resolved:
                    errors.append(
                        f"{rel}: uses type `{sym}` without importing {definer}"
                    )

        # bans
        if ".withOpacity(" in code:
            errors.append(f"{rel}: uses deprecated withOpacity()")
        if re.search(r"\b_{2,}\b", code):
            errors.append(f"{rel}: uses __/___ throwaway params")
        # wildcard `_` used as a value: lambda/catch param lists
        # (`(...) =>` / `(...) {`) are declarations, `._()` is a private
        # named constructor; any other standalone `_` is undefined_identifier
        no_decl = re.sub(
            r"\([^()]*\b_\b[^()]*\)\s*(=>|\{)", "", code_no_imports
        )
        if re.search(r"(?<![\w$.])_(?![\w$])", no_decl):
            errors.append(f"{rel}: uses wildcard `_` as a value")
        for m in re.finditer(r"Icons\.([a-z_]+)", code):
            if m.group(1) not in ICON_ALLOWLIST:
                errors.append(f"{rel}: unverified icon Icons.{m.group(1)}")

    print(f"files={len(dart_files)} errors={len(errors)}")
    for e in errors:
        print("ERR:", e)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
