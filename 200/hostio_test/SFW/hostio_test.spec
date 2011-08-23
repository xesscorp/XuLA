# -*- mode: python -*-
a = Analysis([os.path.join(HOMEPATH,'support\\_mountzlib.py'), os.path.join(HOMEPATH,'support\\useUnicode.py'), 'hostio_test.py'],
             pathex=['C:\\xesscorp\\PRODUCTS\\XuLA\\FPGA\\200\\hostio_test\\SFW'])
pyz = PYZ(a.pure)
exe = EXE( pyz,
          a.scripts,
          a.binaries,
          a.zipfiles,
          a.datas,
          name=os.path.join('dist', 'hostio_test.exe'),
          debug=False,
          strip=False,
          upx=True,
          console=True )
