#!/usr/bin/env python3
# Парсер build.log (MetaEditor) -> Markdown + JSON
import re, json, os, datetime, sys
LOG="build.log"
MD_OUT="reports/build_report_latest.md"
JSON_OUT="reports/build_report_latest.json"
pattern=re.compile(r'^(?P<file>[^(:]+)\((?P<line>\d+),(?P<col>\d+)\)\s*:\s*(?P<type>error|warning)\s*(?P<code>[^:]+):\s*(?P<msg>.*)$', re.IGNORECASE)
errors=[]; warnings=[]
if not os.path.isfile(LOG):
    print("No build.log found. Exit.")
    sys.exit(0)
with open(LOG,'r',encoding='utf-8',errors='ignore') as f:
    for ln in f:
        m=pattern.match(ln.strip())
        if m:
            d=m.groupdict()
            kind=d['type'].lower()
            rec={"file":d['file'],"line":int(d['line']),"col":int(d['col']),"code":d['code'].strip(),"msg":d['msg'].strip()}
            (errors if kind=='error' else warnings).append(rec)
summary={"timestamp":datetime.datetime.now(datetime.timezone.utc).isoformat(),"errors":errors,"warnings":warnings,"error_count":len(errors),"warning_count":len(warnings)}
os.makedirs('reports',exist_ok=True)
with open(JSON_OUT,'w',encoding='utf-8') as jf: json.dump(summary,jf,ensure_ascii=False,indent=2)
with open(MD_OUT,'w',encoding='utf-8') as mf:
    mf.write(f"# Build Report (UTC {summary['timestamp']})\n\n")
    mf.write(f"Errors: {summary['error_count']}  Warnings: {summary['warning_count']}\n\n")
    if errors:
        mf.write("## Errors\n")
        for e in errors[:50]:
            mf.write(f"- {e['file']}({e['line']},{e['col']}): {e['code']} — {e['msg']}\n")
    if warnings:
        mf.write("\n## Warnings\n")
        for w in warnings[:100]:
            mf.write(f"- {w['file']}({w['line']},{w['col']}): {w['code']} — {w['msg']}\n")
print(f"Parsed: {len(errors)} errors, {len(warnings)} warnings.")