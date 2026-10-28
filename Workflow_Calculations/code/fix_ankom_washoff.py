"""Write a copy of an ANKOM workbook whose Percent_WashOff_NDF formulas include
the blank-bag correction term.

The lab template computed % washed off in NDF as ((tare + sample wt) - wt after
NDF) * 100 / sample wt, with no blank-bag term, although every other step
applies one. The corrected form is
    ((tare * Correction_NDF + sample wt) - wt after NDF) * 100 / sample wt,
which equals 100 - Perc_Remaining_Post_NDF. Found 2026-10-21 (see
ankom-audit/DECISIONS.md), applied to the Package B copies 2026-10-28.

Only column H (Percent_WashOff_NDF) is touched, and only by editing the sheet
XML in place, so every other formula, cached value and format is unchanged.
Each corrected cell gets its own explicit formula that references its own row
(the original used shared formulas, and two FF rows had slipped references).
The BLANK row has no sample weight, so its wash-off cell is emptied instead of
showing #DIV/0!. The calculation chain is dropped so Excel rebuilds it.

Usage: python3 -I fix_ankom_washoff.py <in.xlsx> <out.xlsx>
"""
import re
import sys
import zipfile

src, dst = sys.argv[1:3]
SHEET = "xl/worksheets/sheet1.xml"

zin = zipfile.ZipFile(src)
sheet = zin.read(SHEET).decode("utf-8")


def num(ref):
    m = re.search(r'<c r="%s"[^>]*>(?:<f[^>]*/>|<f[^>]*>[^<]*</f>)?<v>([^<]*)</v>' % ref, sheet)
    return float(m.group(1)) if m else None


blank_row = None
for m in re.finditer(r'<row r="(\d+)"', sheet):
    r = int(m.group(1))
    if r > 1 and num("E%d" % r) is None and num("D%d" % r) is not None:
        blank_row = r
        break
assert blank_row == 2, "expected the BLANK bag in row 2, found %s" % blank_row
c_ndf = num("F2") / num("D2")

changed = 0


def fix(m):
    global changed
    r = int(m.group(1))
    style = m.group(2)
    if r == 1:
        return m.group(0)
    if r == blank_row:
        changed += 1
        return '<c r="H%d"%s/>' % (r, style)
    d, e, f = num("D%d" % r), num("E%d" % r), num("F%d" % r)
    if e is None:
        return m.group(0)
    value = ((d * c_ndf + e) - f) * 100 / e
    changed += 1
    return ('<c r="H%d"%s><f>((D%d*G$%d+E%d)-F%d)*100/E%d</f><v>%r</v></c>'
            % (r, style, r, blank_row, r, r, r, value))


sheet_new = re.sub(r'<c r="H(\d+)"((?: s="\d+")?)[^>]*?(?:/>|>.*?</c>)', fix, sheet)
assert changed >= 2, "no wash-off cells found"

with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        if item.filename == "xl/calcChain.xml":
            continue
        data = zin.read(item.filename)
        if item.filename == SHEET:
            data = sheet_new.encode("utf-8")
        elif item.filename == "[Content_Types].xml":
            data = re.sub(rb'<Override[^>]*calcChain[^>]*/>', b"", data)
        elif item.filename == "xl/_rels/workbook.xml.rels":
            data = re.sub(rb'<Relationship[^>]*calcChain[^>]*/>', b"", data)
        zout.writestr(item, data)

print("%s: %d wash-off cells rewritten (blank-bag correction %.6f)" % (dst, changed, c_ndf))
