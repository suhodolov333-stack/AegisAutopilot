#!/usr/bin/env python3
import re, json, os, datetime, sys
LOG="build.log"; MD_OUT="reports/build_report_latest.md"; JSON_OUT="reports/build_report_latest.json"; RULES_FILE="scripts/errors_rules.json"
pat=re.compile(r'^(?P<file>[^(:]+)\((?P<line>\d+),(?P<col>\d+)\)\s*:\s*(?P<type>error|warning)\s*(?P<code>[^:]+):\s*(?P<msg>.*)$', re.IGNORECASE)
errors=[]; warnings=[]
if not os.path.isfile(LOG): print("No build.log found. Exit."); sys.exit(0)
for ln in open(LOG,'r',encoding='utf-8',errors='ignore'):
  m=pat.match(ln.strip())
  if m:
    d=m.groupdict(); rec={"file":d['file'],"line":int(d['line']),"col":int(d['col']),"code":d['code'].strip(),"msg":d['msg'].strip()}
    (errors if d['type'].lower()=='error' else warnings).append(rec)
# rules
rules=[]
if os.path.isfile(RULES_FILE):
  try: rules=json.load(open(RULES_FILE,'r',encoding='utf-8')).get('rules',[])
  except: pass
for e in errors:
  msg_low=e['msg'].lower()
  for r in rules:
    if r['pattern'] in msg_low: e['hint']=r['suggest']; break
summary={"timestamp":datetime.datetime.now(datetime.timezone.utc).isoformat(),"errors":errors,"warnings":warnings,"error_count":len(errors),"warning_count":len(warnings)}
os.makedirs('reports',exist_ok=True)
json.dump(summary,open(JSON_OUT,'w',encoding='utf-8'),ensure_ascii=False,indent=2)
with open(MD_OUT,'w',encoding='utf-8') as mf:
  mf.write(f"# Build Report (UTC {summary['timestamp']})\n\nErrors: {summary['error_count']}  Warnings: {summary['warning_count']}\n\n")
  if errors:
    mf.write("## Errors\n")
    for e in errors[:100]: mf.write(f"- {e['file']}({e['line']},{e['col']}): {e['code']} — {e['msg']}{'  → '+e['hint'] if 'hint' in e else ''}\n")
  if warnings:
    mf.write("\n## Warnings\n")
    for w in warnings[:150]: mf.write(f"- {w['file']}({w['line']},{w['col']}): {w['code']} — {w['msg']}\n")
print(f"Parsed: {len(errors)} errors, {len(warnings)} warnings.")
if len(errors)>0: sys.exit(1)