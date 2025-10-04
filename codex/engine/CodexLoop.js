// Full Smart Codex Loop: 1–9 уровни, интернет-хинты, хирургия с памятью,
// версии, задания, метрики, таймаут компиляции, и стрим-лог с ::group:: для Actions.
(function(){
  var fso = new ActiveXObject("Scripting.FileSystemObject");
  var sh  = new ActiveXObject("WScript.Shell");

  function env(n, d){ try{var v=sh.Environment("Process")(n); return v&&v!==""?v:d;}catch(e){return d;} }
  function read(p){ try{ var t=fso.OpenTextFile(p,1,true,-1); var s=t.ReadAll(); t.Close(); return s; }catch(e){ return ""; } }
  function save(p,s){ var d=fso.GetParentFolderName(p); if(d && !fso.FolderExists(d)) fso.CreateFolder(d); var t=fso.OpenTextFile(p,2,true,-1); t.Write(s); t.Close(); }
  function append(p,s){ var d=fso.GetParentFolderName(p); if(d && !fso.FolderExists(d)) fso.CreateFolder(d); var t=fso.OpenTextFile(p,8,true,-1); t.Write(s); t.Close(); }
  function existsFile(p){ return fso.FileExists(p); }
  function existsPath(p){ return fso.FileExists(p)||fso.FolderExists(p); }
  function copyFile(a,b){ var d=fso.GetParentFolderName(b); if(d && !fso.FolderExists(d)) fso.CreateFolder(d); fso.CopyFile(a,b,true); }
  function now(){ return (new Date()).toISOString(); }
  function out(s){ WScript.Echo(s); append(ERR_LOG, s+"\r\n"); }           // в консоль Actions + в файл
  function grpStart(name){ WScript.Echo("::group::"+name); append(ERR_LOG, "\r\n=== "+name+" ===\r\n"); }
  function grpEnd(){ WScript.Echo("::endgroup::"); }

  // crc32 сигнатура
  function crc32(str){ var c=~0,t=[];for(var n=0;n<256;n++){var r=n;for(var k=0;k<8;k++)r=(r&1)?(0xEDB88320^(r>>>1)):(r>>>1);t[n]=r>>>0;} for(var i=0;i<str.length;i++){c=(c>>>8)^t[(c^str.charCodeAt(i))&0xFF];} return (~c)>>>0; }
  function errSig(log){ if(!log||!log.trim()) return "no-log"; var tail=log.split(/\r?\n/).slice(-200).join("\n"); return crc32(tail).toString(16); }

  // Загрузка .env в процесс
  var ENVFILE=env("ENVFILE","config\\build-config_Version2.env");
  var lines=read(ENVFILE).split(/\r?\n/);
  for(var i=0;i<lines.length;i++){ var m=/^\s*([A-Za-z0-9_]+)\s*=(.*)$/.exec(lines[i]); if(m) sh.Environment("Process")(m[1])=m[2]; }

  // Параметры
  var METAEDITOR=env("METAEDITOR",""), MQL5_DIR=env("MQL5_DIR",""), OUT_DIR=env("OUT_DIR","config\\backup");
  var EA_REPO=env("EA_REPO",""), EA_TERM=env("EA_TERM",""), EA_REL=env("EA_REL","MQL5\\Experts\\Aegis\\SuhabFiboTrade\\SuhabFiboTrader_v5674.mq5");
  var LOG=env("LOG","codex\\build\\compile.log"), ERR_LOG=env("ERR_LOG","codex\\history\\errors.log");
  var ERR_WIN=env("ERR_WIN","codex\\state\\error_window.json"), PATCH_REG=env("PATCH_REG","codex\\state\\applied_patches.txt");
  var STAGE_FILE=env("STAGE_FILE","codex\\state\\stage.txt"), SUPPRESS_DB=env("SUPPRESS_DB","codex\\state\\suppressions.json");
  var METRICS=env("METRICS","codex\\state\\metrics.json");
  var LOOP_MAX=parseInt(env("LOOP_MAX_SAME","3"),10)||3, MAX_ITERS=parseInt(env("MAX_ITERS","15"),10)||15;
  var TIMEOUT=parseInt(env("COMPILATION_TIMEOUT","180"),10)||180, RESTORE_TRIES=parseInt(env("RESTORE_TRIES_AFTER_SUCCESS","3"),10)||3;

  // Папки
  ["codex\\build","codex\\history","codex\\state","codex\\history\\versions","codex\\inbox",OUT_DIR].forEach(function(p){ if(p && !existsPath(p)) fso.CreateFolder(p); });

  // Утилиты правок
  function ensureLine(p, line){ var c=read(p); if(c.indexOf(line)===-1){ save(p, line+"\r\n"+c); return true; } return false; }
  function prepend(p, txt){ var c=read(p); save(p, txt+c); return true; }
  function replaceRe(p, re, rep){ var c=read(p), n=c.replace(re, rep); if(n!==c){ save(p,n); return true; } return false; }
  function addInclude(p,h){ return ensureLine(p, "#include <"+h+">"); }
  function parseMissingHeader(log){ var m=/(?:cannot open file|не удается открыть файл)\s*'([^']+\.mqh)'/i.exec(log||""); return m?m[1]:null; }
  function needsTrade(log, code){ return /CTrade\b/.test(code) && !/Trade\/Trade\.mqh/.test(code); }
  function ensureOnInitInt(p){ var ch=false; ch=replaceRe(p, /\bvoid\s+OnInit\s*\(\s*\)\s*\{/m, "int OnInit(){\r\n  return(INIT_SUCCEEDED);")||ch; ch=replaceRe(p, /(int\s+OnInit\s*\(\s*\)\s*\{)(?![\s\S]*?return\s*\()/m,"$1\r\n  return(INIT_SUCCEEDED);")||ch; return ch; }
  function ensureOnTick(p){ var c=read(p); if(!/\bvoid\s+OnTick\s*\(\s*\)/.test(c)){ append(ERR_LOG, now()+" add OnTick\r\n"); save(p, c+"\r\nvoid OnTick(){ /* auto-added */ }\r\n"); return true; } return false; }
  function ensureOnDeinit(p){ var c=read(p); if(!/\bvoid\s+OnDeinit\s*\(/.test(c)){ append(ERR_LOG, now()+" add OnDeinit\r\n"); save(p, c+"\r\nvoid OnDeinit(const int reason){ /* auto-added */ }\r\n"); return true; } return false; }
  function addBanner(p){ return prepend(p, '#define AE_VIS_VERSION "AEGIS"\r\nvoid Aegis_LogVersion(){ Print("[Aegis] ", __FILE__, " ", __DATE__, " ", __TIME__); }\r\n'); }
  function ensureLogCall(p){ var c=read(p); if(/\bOnInit\s*\(\s*\)\s*\{/.test(c) && !/Aegis_LogVersion\s*\(/.test(c)){ return replaceRe(p, /(OnInit\s*\(\s*\)\s*\{)/m, "$1\r\n  Aegis_LogVersion();"); } return false; }

  // Дедуп включений
  function dedupIncludes(p){ var c=read(p), lines=c.split(/\r?\n/), seen={}, out=[], ch=false;
    for(var i=0;i<lines.length;i++){ var L=lines[i], m=L.match(/^\s*\#include\s+<([^>]+)>\s*$/); if(m){var k=m[1].toLowerCase(); if(seen[k]){ch=true;continue;} seen[k]=1;} out.push(L);} if(ch) save(p, out.join("\r\n")); return ch; }

  // Поиск include в MQL5\Include
  function baseName(p){ try{ return fso.GetFileName(p);}catch(e){ return p; } }
  function findIncludePath(hdr){
    try{
      var incRoot = MQL5_DIR ? (MQL5_DIR+"\\Include") : ""; if(!incRoot||!existsPath(incRoot)) return null;
      var target = baseName(hdr).toLowerCase();
      function walk(folder){
        var f=fso.GetFolder(folder); var fs=new Enumerator(f.Files);
        for(;!fs.atEnd();fs.moveNext()){ var p=fs.item().Path, bn=baseName(p).toLowerCase(); if(bn===target) return p; }
        var ds=new Enumerator(f.SubFolders);
        for(;!ds.atEnd();ds.moveNext()){ var r=walk(ds.item().Path); if(r) return r; }
        return null;
      }
      var found=walk(incRoot); if(!found) return null;
      return found.slice(incRoot.length+1).replace(/\\/g,"/"); // относительный путь
    }catch(e){ return null; }
  }

  // Снапшоты/роллбек
  function snapshot(lbl){ var n="codex\\history\\versions\\"+baseName(EA_TERM)+"_"+lbl+".mq5"; copyFile(EA_REPO||EA_TERM, n); return n; }
  function rollback(){ try{ var f="codex\\history\\versions", arr=[]; var fs=new Enumerator(fso.GetFolder(f).Files);
    for(;!fs.atEnd();fs.moveNext()) arr.push(fs.item().Path); arr.sort(); if(arr.length<2) return false; var prev=arr[arr.length-2];
    copyFile(prev, EA_REPO); copyFile(prev, EA_TERM); append(PATCH_REG, now()+" rollback -> "+baseName(prev)+"\r\n"); return true; }catch(e){ return false; } }

  // Хирургия с памятью
  var SUP_START="/*__AEGIS_SUPPRESS_START__*/", SUP_END="/*__AEGIS_SUPPRESS_END__*/";
  function suppressBlock(p){
    var c=read(p), re=/(class\s+\w+[\s\S]{0,500}?;|(?:int|void|double|bool)\s+\w+\s*\([^;{]{0,200}\)\s*\{)/m, m=re.exec(c);
    if(!m) return false; var s=m.index, e=s+m[0].length; var tag=now().replace(/[:\.]/g,'-')+"_"+crc32(m[0]).toString(16);
    var newC=c.slice(0,s)+SUP_START+tag+"*/\r\n"+m[0]+"\r\n/*"+SUP_END+tag+c.slice(e); save(p,newC);
    var db=readJSON(SUPPRESS_DB,[]); db.push({tag:tag,file:EA_REPO,when:now(),reason:"compile-blocker"}); saveJSON(SUPPRESS_DB,db);
    return true;
  }
  function restoreOne(){
    var c=read(EA_REPO), rx=/\/\*__AEGIS_SUPPRESS_START__\*\/([^\*]+)\*\/\r?\n([\s\S]*?)\r?\n\/\*__AEGIS_SUPPRESS_END__\*\/\1/;
    var m=rx.exec(c); if(!m) return false; var tag=m[1], body=m[2]; save(EA_REPO, c.replace(rx, body)); var db=readJSON(SUPPRESS_DB,[]);
    for(var i=0;i<db.length;i++){ if(db[i].tag===tag){ db[i].restored=(db[i].restored||0)+1; break; } } saveJSON(SUPPRESS_DB,db); return true;
  }

  // Задания (TASK_*.md)
  function applyTasks(){
    try{
      var dir="codex\\inbox"; if(!existsPath(dir)) return false;
      var files=new Enumerator(fso.GetFolder(dir).Files), ch=false;
      for(;!files.atEnd();files.moveNext()){
        var p=files.item().Path; if(!/\\TASK_.*\.md$/i.test(p)) continue;
        var lines=read(p).split(/\r?\n/);
        for(var i=0;i<lines.length;i++){
          var L=lines[i].trim(); if(!L||/^#/.test(L)) continue;
          var m1=/^include:add:(.+)$/i.exec(L); if(m1){ if(addInclude(EA_REPO,m1[1].trim())){ ch=true; out("task: include "+m1[1]); } continue; }
          var m2=/^replace:\s*\/(.+)\/\s*=>\s*(.*)$/i.exec(L); if(m2){ try{ var re=new RegExp(m2[1],"m"); if(replaceRe(EA_REPO,re,m2[2])){ ch=true; out("task: replace /"+m2[1]+"/"); } }catch(e){} continue; }
        }
        copyFile(p, p.replace("\\TASK_","\\DONE_TASK_")); fso.DeleteFile(p,true);
      }
      if(ch){ copyFile(EA_REPO, EA_TERM); append(PATCH_REG, now()+" task-apply\r\n"); }
      return ch;
    }catch(e){ return false; }
  }

  // JSON util
  function readJSON(p,def){ try{ var s=read(p); return s?eval("("+s+")"):def; }catch(e){ return def; } }
  function saveJSON(p,o){ save(p, JSON.stringify(o)); }

  // Метрики / окно ошибок
  var metrics=readJSON(METRICS,{runs:0,successes:0,stages:{},lastStage:1,lastSig:""});
  function bumpStageKey(k){ metrics.stages[k]=(metrics.stages[k]||0)+1; }
  function curStage(){ var s=read(STAGE_FILE).trim(); var v=parseInt(s||"1",10); return (v>0)?v:1; }
  function setStage(v){ save(STAGE_FILE, String(v)); }
  function bumpSig(sig){ var o=readJSON(ERR_WIN,{last:"",count:0}); if(o.last===sig) o.count++; else {o.last=sig;o.count=1;} saveJSON(ERR_WIN,o); return o.count>=LOOP_MAX; }

  // Пре-синк: если репо-файл есть, а терминальный нет — копируем.
  if(EA_REPO && existsFile(EA_REPO) && !existsFile(EA_TERM)){ try{ copyFile(EA_REPO, EA_TERM); }catch(e){} }

  // Компиляция с таймаутом + подробный вывод
  function compileOnce(iter){
    grpStart("Iteration "+iter);
    out("["+now()+"] MetaEditor: "+METAEDITOR+" "+(existsFile(METAEDITOR)?"[OK]":"[MISSING]"));
    out("["+now()+"] EA_TERM:   "+EA_TERM+" "+(existsFile(EA_TERM)?"[OK]":"[MISSING]"));

    if(!existsFile(METAEDITOR) || !existsFile(EA_TERM)){
      out(">>> ERROR: required path is missing; stop this iter");
      grpEnd(); return 100;
    }
    try{ if(existsFile(LOG)) fso.DeleteFile(LOG,true);}catch(e){}
    var cmd='"'+METAEDITOR+'" /compile:"'+EA_TERM+'" /log:"'+LOG+'"';
    out("Run: "+cmd);

    var exec=sh.Exec(cmd), waited=0;
    while(exec.Status==0 && waited<TIMEOUT){ WScript.Sleep(1000); waited++; if(waited%30===0) out("... compiling "+waited+"s"); }
    if(exec.Status==0){ exec.Terminate(); out(">>> TIMEOUT after "+TIMEOUT+"s"); grpEnd(); return 999; }
    grpEnd(); return exec.ExitCode;
  }

  // Автопатчи (1–9)
  function autoPatch(stage, logTxt){
    var ch=false, code=read(EA_REPO);
    if(stage>=1){
      if(ensureLine(EA_REPO,"#property strict")){ append(PATCH_REG, now()+" strict\r\n"); ch=true; code=read(EA_REPO); }
      if(addBanner(EA_REPO)){ append(PATCH_REG, now()+" banner\r\n"); ch=true; code=read(EA_REPO); }
      if(ensureLogCall(EA_REPO)){ append(PATCH_REG, now()+" logcall\r\n"); ch=true; code=read(EA_REPO); }
      if(needsTrade(logTxt,code) && addInclude(EA_REPO,"Trade/Trade.mqh")){ append(PATCH_REG, now()+" incl-trade\r\n"); ch=true; code=read(EA_REPO); }
    }
    if(stage>=2){ var hdr=parseMissingHeader(logTxt); if(hdr && addInclude(EA_REPO,hdr)){ append(PATCH_REG, now()+" incl-"+hdr+"\r\n"); ch=true; } }
    if(stage>=3){ if(ensureOnInitInt(EA_REPO)){ append(PATCH_REG, now()+" oninit-int\r\n"); ch=true; } }
    if(stage>=4){ if(ensureOnTick(EA_REPO)){ append(PATCH_REG, now()+" ensure-ontick\r\n"); ch=true; } if(ensureOnDeinit(EA_REPO)){ append(PATCH_REG, now()+" ensure-ondeinit\r\n"); ch=true; } }
    if(stage>=5){ var miss=parseMissingHeader(logTxt); if(miss && addInclude(EA_REPO,miss)){ append(PATCH_REG, now()+" rebind-"+miss+"\r\n"); ch=true; } }
    if(stage>=6){ if(suppressBlock(EA_REPO)){ append(PATCH_REG, now()+" aggressive-comment\r\n"); ch=true; } }
    if(stage>=7){ var miss7=parseMissingHeader(logTxt); if(miss7){ var rel=findIncludePath(miss7); if(rel && addInclude(EA_REPO,rel)){ append(PATCH_REG, now()+" system-include "+rel+"\r\n"); ch=true; } } }
    if(stage>=8){ if(dedupIncludes(EA_REPO)){ append(PATCH_REG, now()+" include-dedup\r\n"); ch=true; } }
    if(stage>=9){ snapshot("stage9_"+now().replace(/[:\.]/g,'-')); }
    if(ch){ copyFile(EA_REPO, EA_TERM); }
    return ch;
  }

  // Хинты
  function fetchHints(tail){
    try{
      var url="https://www.mql5.com/en/search#!keyword="+encodeURIComponent(tail);
      var x=new ActiveXObject("MSXML2.XMLHTTP"); x.open("GET", url, false); x.send();
      if(x.status==200){ var stamp=now().replace(/[:\.]/g,'-'); save("codex\\history\\hints_"+stamp+".html", x.responseText); }
    }catch(e){}
  }

  // Healing после успеха
  function healing(){
    for(var k=0;k<RESTORE_TRIES;k++){
      if(!restoreOne()) return;
      copyFile(EA_REPO, EA_TERM);
      var rc=compileOnce("heal-"+(k+1)), ex5=EA_TERM.replace(/\.mq5$/i,".ex5");
      if(rc===0 && existsFile(ex5)){ copyFile(ex5, OUT_DIR+"\\"+baseName(ex5)); out("healing: block restored ok"); continue; }
      else { suppressBlock(EA_REPO); copyFile(EA_REPO, EA_TERM); out("healing: restore failed -> re-suppress"); break; }
    }
  }

  // Применяем задания заранее
  applyTasks();

  var stage=curStage(); if(stage<1) stage=1; metrics.runs++; bumpStageKey("start@"+stage);
  var ok=false, lastSig="";

  for(var i=1;i<=MAX_ITERS;i++){
    var rc=compileOnce(i), ex5=EA_TERM.replace(/\.mq5$/i,".ex5");
    if(rc===0 && existsFile(ex5)){
      copyFile(ex5, OUT_DIR+"\\"+baseName(ex5));
      ok=true; metrics.successes++; bumpStageKey("success@"+stage);
      healing(); break;
    } else {
      var logTxt=read(LOG); var sig=errSig(logTxt); lastSig=sig;
      out("Fail code "+rc+" | sig "+sig);
      var needEsc=bumpSig(sig), patched=autoPatch(stage, logTxt);
      if(needEsc && !patched){
        if(stage>=9){ if(rollback()){ copyFile(EA_REPO, EA_TERM); out("rollback applied"); } }
        stage++; setStage(stage); bumpStageKey("escalate@"+stage);
        var tail=(logTxt||"").split(/\r?\n/).slice(-10).join(" "); fetchHints(tail);
        patched=autoPatch(stage, logTxt);
      }
    }
  }

  metrics.lastStage=stage; metrics.lastSig=lastSig; saveJSON(METRICS, metrics);

  if(!ok){
    var md="# Smart loop break\r\n**EA:** "+EA_TERM+"\r\n**Stage:** "+stage+"\r\n**Applied patches:**\r\n"+read(PATCH_REG)+"\r\n**Log tail (200):**\r\n"+read(LOG).split(/\r?\n/).slice(-200).join("\n")+"\r\n";
    save("codex\\inbox\\LOOP_BREAK_"+now().replace(/[:\.]/g,'-')+".md", md);
    WScript.Quit(1);
  } else { WScript.Quit(0); }
})();
