"""Portable source-boundary checks. This is not an Objective-C compiler.

Run: python scripts/check_source.py
Optional parser: pip install tree-sitter tree-sitter-objc
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
files = sorted((ROOT / "src").glob("*"))
sources = {p: p.read_text(encoding="utf-8-sig") for p in files}
errors = []
makefile = (ROOT / "Makefile").read_text()
listed = set(re.search(r"^GoutouJunshi_FILES\s*=\s*(.*)$", makefile, re.M)[1].split())
actual = {p.relative_to(ROOT).as_posix() for p in files if p.suffix in {".m", ".xm"}}
if listed != actual:
    errors.append(f"Makefile mismatch: missing={actual-listed}, nonexistent={listed-actual}")
for framework in ("UIKit", "Foundation", "Security", "QuartzCore"):
    if framework not in re.search(r"^GoutouJunshi_FRAMEWORKS\s*=\s*(.*)$", makefile, re.M)[1].split():
        errors.append(f"Missing framework: {framework}")
if "-fobjc-arc" not in makefile:
    errors.append("ARC must stay enabled")
for path, source in sources.items():
    for forbidden in ("AutoReplyMessage", "sendMsg", "sendMsgWithLocalID", "AddMsg:", "ResendMsg:"):
        if forbidden in source:
            errors.append(f"{path.name}: prohibited sending selector {forbidden}")
    if path.name != "GJWeChatAdapter.m" and re.search(r"CMessageWrap|m_nsFromUsr|m_nsToUsr|m_nsContent|NSClassFromString|NSInvocation", source):
        errors.append(f"{path.name}: private WeChat access outside adapter")
    if path.name != "GJDeepSeekClient.m" and re.search(r"NSURLSession|NSMutableURLRequest", source):
        errors.append(f"{path.name}: network access outside client")
    if re.search(r"sk-[A-Za-z0-9_-]{12,}", source):
        errors.append(f"{path.name}: possible hardcoded API key")
    for include in re.findall(r'^#import "([^"]+)"', source, re.M):
        if not (path.parent / include).is_file():
            errors.append(f"{path.name}: missing local header {include}")

try:
    from tree_sitter import Language, Parser
    import tree_sitter_objc
except ImportError:
    print("Objective-C parser unavailable; syntax parsing SKIPPED.")
else:
    parser = Parser(Language(tree_sitter_objc.language()))
    for path, source in sources.items():
        # Logos is not Objective-C: check the constructor body after a local-only substitution.
        source = source.replace("%ctor", "__attribute__((constructor)) static void gj_ctor(void)")
        tree = parser.parse(source.encode())
        nodes = [tree.root_node]
        while nodes:
            node = nodes.pop()
            if node.type == "ERROR" or node.is_missing:
                errors.append(f"{path.name}:{node.start_point.row + 1}: syntax node {node.type}")
            nodes.extend(node.children)
    print(f"Objective-C syntax parsing completed for {len(sources)} files (not SDK/type checking).")
if errors:
    print("\n".join(errors))
    sys.exit(1)
print(f"PASS: {len(actual)} compilation units; build list, frameworks, module boundaries, and source secret checks.")
