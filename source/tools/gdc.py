import struct, sys, zstandard

T = """EMPTY ANNOTATION IDENTIFIER LITERAL
LESS LESS_EQUAL GREATER GREATER_EQUAL EQUAL_EQUAL BANG_EQUAL
AND OR NOT AMPERSAND_AMPERSAND PIPE_PIPE BANG
AMPERSAND PIPE TILDE CARET LESS_LESS GREATER_GREATER
PLUS MINUS STAR STAR_STAR SLASH PERCENT
EQUAL PLUS_EQUAL MINUS_EQUAL STAR_EQUAL STAR_STAR_EQUAL SLASH_EQUAL PERCENT_EQUAL LESS_LESS_EQUAL GREATER_GREATER_EQUAL AMPERSAND_EQUAL PIPE_EQUAL CARET_EQUAL
IF ELIF ELSE FOR WHILE BREAK CONTINUE PASS RETURN MATCH WHEN
AS ASSERT AWAIT BREAKPOINT CLASS CLASS_NAME CONST ENUM EXTENDS FUNC IN IS NAMESPACE PRELOAD SELF SIGNAL STATIC SUPER TRAIT VAR VOID YIELD
BRACKET_OPEN BRACKET_CLOSE BRACE_OPEN BRACE_CLOSE PARENTHESIS_OPEN PARENTHESIS_CLOSE COMMA SEMICOLON PERIOD PERIOD_PERIOD PERIOD_PERIOD_PERIOD COLON DOLLAR FORWARD_ARROW UNDERSCORE
NEWLINE INDENT DEDENT
CONST_PI CONST_TAU CONST_INF CONST_NAN
VCS_CONFLICT_MARKER BACKTICK QUESTION_MARK
ERROR EOF""".split()

TXT = dict(LESS='<',LESS_EQUAL='<=',GREATER='>',GREATER_EQUAL='>=',EQUAL_EQUAL='==',BANG_EQUAL='!=',
 AND='and',OR='or',NOT='not',AMPERSAND_AMPERSAND='&&',PIPE_PIPE='||',BANG='!',AMPERSAND='&',PIPE='|',TILDE='~',CARET='^',
 LESS_LESS='<<',GREATER_GREATER='>>',PLUS='+',MINUS='-',STAR='*',STAR_STAR='**',SLASH='/',PERCENT='%',EQUAL='=',
 PLUS_EQUAL='+=',MINUS_EQUAL='-=',STAR_EQUAL='*=',STAR_STAR_EQUAL='**=',SLASH_EQUAL='/=',PERCENT_EQUAL='%=',
 LESS_LESS_EQUAL='<<=',GREATER_GREATER_EQUAL='>>=',AMPERSAND_EQUAL='&=',PIPE_EQUAL='|=',CARET_EQUAL='^=',
 BRACKET_OPEN='[',BRACKET_CLOSE=']',BRACE_OPEN='{',BRACE_CLOSE='}',PARENTHESIS_OPEN='(',PARENTHESIS_CLOSE=')',
 COMMA=',',SEMICOLON=';',PERIOD='.',PERIOD_PERIOD='..',PERIOD_PERIOD_PERIOD='...',COLON=':',DOLLAR='$',FORWARD_ARROW='->',
 UNDERSCORE='_',CONST_PI='PI',CONST_TAU='TAU',CONST_INF='INF',CONST_NAN='NAN',BACKTICK='`',QUESTION_MARK='?',
 CLASS_NAME='class_name',VOID='void',SELF='self')
for k in 'IF ELIF ELSE FOR WHILE BREAK CONTINUE PASS RETURN MATCH WHEN AS ASSERT AWAIT BREAKPOINT CLASS CONST ENUM EXTENDS FUNC IN IS NAMESPACE PRELOAD SIGNAL STATIC SUPER TRAIT VAR YIELD'.split():
    TXT[k]=k.lower()

def gd_str(s, prefix=''):
    s = s.replace('\\','\\\\').replace('"','\\"').replace('\n','\\n').replace('\t','\\t').replace('\r','\\r')
    return prefix+'"'+s+'"'

def fmt_float(f):
    if f != f: return 'NAN'
    if f in (float('inf'),): return 'INF'
    r = repr(f)
    if 'e' in r:
        m, e = r.split('e')
        if '.' not in m: m += '.0'
        r = m+'e'+e
    return r

def decode_variant(c, b):
    h, = struct.unpack('<I', c[b:b+4]); t = h & 0xff; f64 = h & (1<<16)
    b += 4
    if t == 0: return 'null', b
    if t == 1: v,=struct.unpack('<I',c[b:b+4]); return ('true' if v else 'false'), b+4
    if t == 2:
        if f64: v,=struct.unpack('<q',c[b:b+8]); return str(v), b+8
        v,=struct.unpack('<i',c[b:b+4]); return str(v), b+4
    if t == 3:
        if f64: v,=struct.unpack('<d',c[b:b+8]); return fmt_float(v), b+8
        v,=struct.unpack('<f',c[b:b+4]); return fmt_float(v), b+4
    if t in (4, 21):
        l,=struct.unpack('<I',c[b:b+4]); s=c[b+4:b+4+l].decode('utf8'); b += 4+l+((4-l%4)%4)
        return gd_str(s, '&' if t == 21 else ''), b
    if t == 22:
        # NodePath: new format flag 0x80000000 on name count
        n,=struct.unpack('<I',c[b:b+4]); b+=4
        assert n & 0x80000000
        n &= 0x7fffffff
        sub,flags=struct.unpack('<II',c[b:b+8]); b+=8
        parts=[]
        for i in range(n+sub):
            l,=struct.unpack('<I',c[b:b+4]); s=c[b+4:b+4+l].decode('utf8'); b += 4+l+((4-l%4)%4); parts.append(s)
        p='/'.join(parts[:n]); 
        if flags & 1: p='/'+p
        if sub: p += ':'+':'.join(parts[n:])
        return gd_str(p,'^'), b
    raise Exception('variant type %d' % t)

def load(path):
    d = open(path,'rb').read()
    ver, dsz = struct.unpack('<II', d[4:12])
    assert d[:4] == b'GDSC' and ver == 101, ver
    c = zstandard.ZstdDecompressor().decompress(d[12:], max_output_size=dsz) if dsz else d[12:]
    ic, cc, tlc, tc = struct.unpack('<4I', c[:16]); b = 16
    ids = []
    for i in range(ic):
        l, = struct.unpack('<I', c[b:b+4]); b += 4
        ids.append(''.join(chr(struct.unpack('<I', bytes(x ^ 0xb6 for x in c[b+4*j:b+4*j+4]))[0]) for j in range(l))); b += 4*l
    consts = []
    for i in range(cc):
        v, b = decode_variant(c, b); consts.append(v)
    lines = {}; cols = {}
    for i in range(tlc):
        ti, ln = struct.unpack('<II', c[b:b+8]); b += 8; lines[ti] = ln
    for i in range(tlc):
        ti, co = struct.unpack('<II', c[b:b+8]); b += 8; cols[ti] = co
    toks = []
    for i in range(tc):
        if c[b] & 0x80:
            v, x = struct.unpack('<II', c[b:b+8]); b += 8
            toks.append((T[v & 0x7f], v >> 8, x))
        else:
            v, x = struct.unpack('<BI', c[b:b+5]); b += 5
            toks.append((T[v], None, x))
    assert b == len(c), (b, len(c))
    return ids, consts, lines, cols, toks


OPEN = {'PARENTHESIS_OPEN','BRACKET_OPEN','BRACE_OPEN'}
CLOSE = {'PARENTHESIS_CLOSE','BRACKET_CLOSE','BRACE_CLOSE'}
BINOPS = set('LESS LESS_EQUAL GREATER GREATER_EQUAL EQUAL_EQUAL BANG_EQUAL AND OR AMPERSAND_AMPERSAND PIPE_PIPE AMPERSAND PIPE CARET LESS_LESS GREATER_GREATER PLUS MINUS STAR STAR_STAR SLASH PERCENT EQUAL PLUS_EQUAL MINUS_EQUAL STAR_EQUAL STAR_STAR_EQUAL SLASH_EQUAL PERCENT_EQUAL LESS_LESS_EQUAL GREATER_GREATER_EQUAL AMPERSAND_EQUAL PIPE_EQUAL CARET_EQUAL FORWARD_ARROW IN IS AS'.split())
VALUE_END = {'IDENTIFIER','LITERAL','SELF','CONST_PI','CONST_TAU','CONST_INF','CONST_NAN','UNDERSCORE','VOID'} | CLOSE

def decompile(path):
    ids, consts, lines, cols, toks = load(path)
    out = []
    cur = None
    prev = None
    unary = False
    for i, (t, v, ln) in enumerate(toks):
        if t in ('EOF',): continue
        if t == 'ANNOTATION': s = ids[v]
        elif t == 'IDENTIFIER': s = ids[v]
        elif t == 'LITERAL': s = consts[v]
        else: s = TXT[t]
        if i in lines or cur is None:
            if cur is not None: out.append(cur)
            ind = cols.get(i, 1) - 1
            if ind == 0 and t in ('FUNC', 'CLASS', 'STATIC', 'ANNOTATION') and out and not out[-1].startswith('@') and out[-1] != '':
                out.append('')
            cur = '\t' * ind + s
            prev = t; unary = (t == 'MINUS'); continue
        p = prev
        space = True
        if p in OPEN or p in ('PERIOD','DOLLAR','TILDE','BANG'): space = False
        if t in CLOSE or t in ('COMMA','COLON','PERIOD','SEMICOLON'): space = False
        if t == 'PARENTHESIS_OPEN' and p in VALUE_END | {'PRELOAD','SUPER','ASSERT','AWAIT','FUNC'} and p != 'VOID': space = False
        if t == 'PARENTHESIS_OPEN' and p == 'ANNOTATION': space = False
        if t == 'BRACKET_OPEN' and p in VALUE_END: space = False
        if p == 'MINUS' and unary: space = False
        if p == 'PERIOD_PERIOD_PERIOD': space = False
        if p == 'COLON' and t == 'EQUAL': space = False  # :=
        if t == 'COLON' and i + 1 < len(toks) and toks[i+1][0] == 'EQUAL': space = True
        if t == 'IDENTIFIER' and p == 'DOLLAR': space = False
        if t == 'LITERAL' and p == 'DOLLAR': space = False
        if p == 'COLON' and t == 'EQUAL': space = False
        # determine unary minus for next token
        unary = (t == 'MINUS' and (p is None or p not in VALUE_END))
        cur += (' ' if space else '') + s
        prev = t
    if cur is not None: out.append(cur)
    # fix ':=' spacing after colon (" : =" never generated); collapse ' :=' form
    return '\n'.join(x for x in out) + '\n'

if __name__ == '__main__':
    print(decompile(sys.argv[1]), end='')
