# PyInstaller spec: one-folder build of the recetarios backend service.
# Build:  python -m PyInstaller recetarios.spec --noconfirm --distpath dist
a = Analysis(
    ['src/recetarios/__main__.py'],
    pathex=['src'],
    binaries=[],
    datas=[],
    hiddenimports=['uvicorn.logging', 'uvicorn.loops.auto', 'uvicorn.protocols.http.auto'],
    noarchive=False,
)
pyz = PYZ(a.pure)
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='recetarios',
    console=False,
    disable_windowed_traceback=False,
)
coll = COLLECT(exe, a.binaries, a.datas, name='recetarios')
