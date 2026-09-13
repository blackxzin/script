#!/usr/bin/env python3
"""Self-check stdlib: sintaxe Lua (luac -p), requires convertidos, version sync.

Uso: python3 tools/check_bundle.py
Falha (exit 1) com lista de problemas. Sem deps externas.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
SRC = ROOT / "src"
BUNDLE_PY = ROOT / "tools" / "bundle.py"
MAIN = ROOT / "main.lua"
CLIENT = SRC / "StarterPlayer" / "StarterPlayerScripts" / "EliteAutomation.client.lua"


def fail(msg):
    print(f"FAIL: {msg}")
    return False


def main():
    ok = True
    lua_files = sorted(SRC.rglob("*.lua"))

    # 1. Sintaxe: luac -p em cada arquivo
    # Luau aceita `x += 1`; luac 5.4 nao. Normaliza antes de checar.
    compound = re.compile(r"(\S+)\s*([+\-*/%^])=\s*")
    for f in lua_files:
        src_text = f.read_text(encoding="utf-8")
        norm = compound.sub(lambda m: f"{m.group(1)} = {m.group(1)} {m.group(2)} ", src_text)
        r = subprocess.run(
            ["luac", "-p", "-"], input=norm, capture_output=True, text=True
        )
        if r.returncode != 0:
            ok = fail(f"sintaxe {f.relative_to(ROOT)}: {r.stderr.strip()}") and False

    # 2. bundle.py cobre todos os src/*.lua (sem modulo orfao, sem path fantasma)
    text = BUNDLE_PY.read_text(encoding="utf-8")
    listed = set(re.findall(r'"([A-Za-z0-9_]+/[A-Za-z0-9_]+\.lua)"', text))
    actual = {
        f"{p.parent.name}/{p.name}"
        for p in lua_files
        if "StarterPlayer" not in p.parts
    }
    for m in sorted(actual - listed):
        ok = fail(f"modulo orfao (fora do bundle): {m}") and False
    src_names = {p.name for p in lua_files}
    for m in sorted(listed):
        if m.split("/")[1] not in src_names:
            ok = fail(f"bundle lista arquivo inexistente: {m}") and False

    # 3. Client registrado no bundle (sem entrypoint o bundle nao roda)
    if "EliteAutomation.client.lua" not in text and "CLIENT" not in text:
        ok = fail("client entrypoint fora do bundle") and False

    # 4. Requires estilo Rojo convertidos (checa bundle gerado, nao src)
    if MAIN.exists():
        bundled = MAIN.read_text(encoding="utf-8")
        bad = re.findall(r"require\(Root\.[^\)]*\)", bundled)
        if bad:
            ok = fail(f"bundle com require nao convertido: {bad[:3]}") and False

    # 5. Version sync: client banner vs HEADER do bundle.py
    m_client = re.search(r"Framework v(\d+\.\d+)", CLIENT.read_text(encoding="utf-8"))
    m_header = re.search(r"v(\d+\.\d+)", BUNDLE_PY.read_text(encoding="utf-8"))
    if m_client and m_header and m_client.group(1) != m_header.group(1):
        ok = fail(
            f"versao divergente: client v{m_client.group(1)} vs bundle v{m_header.group(1)}"
        ) and False

    # 6. UI: toggles com default true precisam de manager:SetEnabled inicial
    # (toggle visual on + sistema off = UI mentirosa)
    client = CLIENT.read_text(encoding="utf-8")
    for m in re.finditer(
        r'CreateToggle\([^,]+,\s*"([^"]+)"[^)]*,\s*(true)\s*\)', client, re.S
    ):
        label = m.group(1)
        # heuristica: bloco do toggle deve chamar SetEnabled ou manager:Register proximo
        start = max(0, m.start() - 200)
        ctx = client[start : m.end() + 400]
        if "SetEnabled" not in ctx and "Start()" not in ctx:
            print(f"WARN: toggle '{label}' default true sem ativacao inicial visivel")

    # 7. Anti-patterns que causam kick/disconnect no GPO
    for f in lua_files:
        c = f.read_text(encoding="utf-8")
        rel = f.relative_to(ROOT)
        for pat, why in [
            (r"root\.CFrame\s*=", "CFrame direto (teleport = disconnect)"),
            (r"BodyVelocity", "BodyMover no character (assinatura kick)"),
            (r"IsA\(\"Part\"\)", 'IsA("Part") nunca casa; use BasePart'),
            (r"for .+ in pairs\(self\.Tabs\)", "pairs() em Tabs: ordem aleatoria"),
        ]:
            for mm in re.finditer(pat, c):
                line = c[: mm.start()].count("\n") + 1
                # NOTA/comentario documentando o porquê nao conta
                line_text = c.splitlines()[line - 1]
                if "NOTA" in line_text or "ponytail" in line_text:
                    continue
                print(f"WARN: {rel}:{line}: {why}")

    print("OK: bundle self-check passou" if ok else "CHECK FALHOU")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
