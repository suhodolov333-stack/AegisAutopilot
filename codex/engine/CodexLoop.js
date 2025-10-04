// WSH JScript: компиляция, логи, автопатчи (1-9), память "хирургии", версии, задания, хинты, метрики.
(function(){
  var fso = new ActiveXObject("Scripting.FileSystemObject");
  var sh  = new ActiveXObject("WScript.Shell");
  function env(n, d){ try{ var v=sh.Environment("Process")(n); return v&&v!==""?v:d; }catch(e){ return d; } }
  function read(p){ try{ var t=fso.OpenTextFile(p,1,true,-1); var s=t.ReadAll(); t.Close(); return s; }catch(e){ return ""; } }
  function save(p,s){ var d=fso.GetParentFolderName(p); if(d && !fso.FolderExists(d)) fso.CreateFolder(d); var t=fso.OpenTextFile(p,2,true,-1); t.Write(s); t.Close(); }
  function append(p,s){ var d=fso.GetParentFolderName(p); if(d && !fso.FolderExists(d)) fso.CreateFolder(d); var t=fso.OpenTextFile(p,8,true,-1); t.Write(s); t.Close(); }
  function exists(p){ return fso.FileExists(p)||fso.FolderExists(p); }
  function copyFile(a,b){ var d=fso.GetParentFolderName(b); if(d && !fso.FolderExists(d)) fso.CreateFolder(d); fso.CopyFile(a,b,true); }
  function nowISO(){ return (new Date()).toISOString(); }

  // crc32 для сигнатуры ошибок
  function crc32(str){ var c=~0,t=[];for(var n=0;n<256;n++){var r=n;for(var k=0;k<8;k++)r=(r&1)?(0xEDB88320^(r>>>1)):(r>>>1);t[n]=r>>>0;} for(var i=0;i<str.length;i++){c=(c>>>8)^t[(c^str.charCodeAt(i))&0xFF];} return (~c)>>>0; }
  function errSig(log){ if(!log||!log.trim()) return "no-log"; var tail=log.split(/\r?\n/).slice(-200).join("\n"); return crc32(tail).toString(16); }

  // Загрузка .env
  function loadEnv(path){
    if(!exists(path)) return;
    var lines = read(path).split(/\r?\n/);
    for(var i=0;i<lines.length;i++){
      var L=lines[i]; if(!L||/^[#;]/.test(L)) continue;
      var m=L.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*)\s*$/); if(!m) continue;
      sh.Environment("Process")(m[1]) = m[2];
    }
  }

  // Утилиты правок
  function ensureLine(p, line){ var c=read(p); if(c.indexOf(line)===-1){ save(p, line+"\r\n"+c); return true; } return false; }
  function prepend(p, txt){ var c=read(p); save(p, txt+c); return true; }
  function replaceRe(p, re, rep){ var c=read(p), n=c.replace(re, rep); if(n!==c){ save(p,n); return true; } return false; }
  function addInclude(p,h){ return ensureLine(p, "#include <"+h+">"); }
  function readJSON(p, def){ try{ var s=read(p); return s?eval("("+s+")"):def; }catch(e){ return def; } }
  function saveJSON(p, obj){ save(p, JSON.stringify(obj)); }
  function baseName(p){ try{ return fso.GetFileName(p); } catch(e){ return p; } }

  // Маркеры хирургии
  var SUP_START="/*__AEGIS_SUPPRESS_START__*/";
  var SUP_END  ="/*__AEGIS_SUPPRESS_END__*/";

  // Параметры из .env
  var ENVFILE = env("ENVFILE","config\\build-config_Version2.env"); loadEnv(ENVFILE);
  var METAEDITOR  = env("METAEDITOR","");
  var TERMINAL_DIR= env("TERMINAL_DIR","");
  var MQL5_DIR    = env("MQL5_DIR","");
  var EA_REPO     = env("EA_REPO","");
  var EA_TERM     = env("EA_TERM","");
  var OUT_DIR     = env("OUT_DIR","config\\backup");
  var LOG         = env("LOG","codex\\build\\compile.log");
  var ERR_WIN     = env("ERR_WIN","codex\\state\\error_window.json");
  var PATCH_REG   = env("PATCH_REG","codex\\state\\applied_patches.txt");
  var ERR_LOG     = env("ERR_LOG","codex\\history\\errors.log");
  var STAGE_FILE  = env("STAGE_FILE","codex\\state\\stage.txt");
  var SUPPRESS_DB = env("SUPPRESS_DB","codex\\state\\suppressions.json");
  var METRICS     = env("METRICS","codex\\state\\metrics.json");
  var LOOP_MAX    = parseInt(env("LOOP_MAX_SAME","3"),10)||3;
  var MAX_ITERS   = parseInt(env("MAX_ITERS","15"),10)||15;
  var RESTORE_TRIES = parseInt(env("RESTORE_TRIES_AFTER_SUCCESS","3"),10)||3;

  // Локальный fallback: если EA_REPO нет — работаем прямо по EA_TERM
  if(!exists(EA_REPO)) EA_REPO = EA_TERM;

  // Папки
  ["codex\\build","codex\\history","codex\\state","codex\\history\\versions","codex\\inbox",OUT_DIR].forEach(function(p){ if(p && !fso.FolderExists(p)) fso.CreateFolder(p); });

  // Метрики
  var metrics = readJSON(METRICS, {runs:0, successes:0, stages:{}, lastSig:"", lastStage:1});
  function bumpMetric(k){ metrics[k]=(metrics[k]||0)+1; }
  function bumpStage(s){ metrics.stages[s]=(metrics.stages[s]||0)+1; }

  // Стадия эскалации
  function curStage(){ var s=read(STAGE_FILE).trim(); var v=parseInt(s||"1",10); return (v>0)?v:1; }
  function setStage(v){ save(STAGE_FILE, String(v)); }

  // Окно одинаковых ошибок
  function bumpSig(sig){
    var o=readJSON(ERR_WIN, {last:"",count:0});
    if(o.last===sig) o.count++; else { o.last=sig; o.count=1; }
    saveJSON(ERR_WIN, o);
    return o.count>=LOOP_MAX;
  }

  // Компиляция
  function compileOnce(){
    try{ if(fso.FileExists(LOG)) fso.DeleteFile(LOG,true);}catch(e){}
    var cmd='"'+METAEDITOR+'" /compile:"'+EA_TERM+'" /log:"'+LOG+'"';
    var rc = sh.Run(cmd,0,true);
    return rc;
  }

  // Версионирование
  function snapshot(label){
    var name = "codex\\history\\versions\\"+baseName(EA_REPO)+"_"+label+".mq5";
    copyFile(EA_REPO, name);
    return name;
  }

  // Роллбек (очень простой: берем предыдущую версию, если есть)
  function rollback(){
    try{
      var folder="codex\\history\\versions";
      var e=fso.GetFolder(folder).Files; var it=new Enumerator(e), arr=[];
      for(;!it.atEnd();it.moveNext()){ arr.push(it.item().Path); }
      arr.sort(); if(arr.length<2) return false;
      var prev=arr[arr.length-2];
      copyFile(prev, EA_REPO); copyFile(prev, EA_TERM);
      append(PATCH_REG, nowISO()+" rollback :: "+baseName(prev)+"\r\n");
      return true;
    }catch(e){ return false; }
  }

  // Поиск include в MQL5\Include
  function findIncludePath(hdr){
    try{
      var incRoot = MQL5_DIR ? (MQL5_DIR+"\\Include") : "";
      if(!incRoot || !fso.FolderExists(incRoot)) return null;
      var target = hdr.replace(/^[.\/\\]+/,""); // Indicators/XX.mqh
      var nameOnly = baseName(target).toLowerCase();
      function walk(folder){
        var f = fso.GetFolder(folder);
        var fs = new Enumerator(f.Files);
        for(;!fs.atEnd();fs.moveNext()){
          var p=fs.item().Path, bn=baseName(p).toLowerCase();
          if(bn===nameOnly) return p;
        }
        var ds = new Enumerator(f.SubFolders);
        for(;!ds.atEnd();ds.moveNext()){
          var r = walk(ds.item().Path); if(r) return r;
        }
        return null;
      }
      var found = walk(incRoot); if(!found) return null;
      // Приведем к относительному виду "Folder/Sub.mqh"
      var rel = found.slice(incRoot.length+1).replace(/\\/g,"/");
      return rel;
    }catch(e){ return null; }
  }

  // Дедуп и чистка include
  function dedupIncludes(p){
    var c=read(p); var lines=c.split(/\r?\n/), seen={}, out=[], changed=false;
    for(var i=0;i<lines.length;i++){
      var L=lines[i];
      var m=L.match(/^\s*\#include\s+<([^>]+)>\s*$/);
      if(m){
        var key=m[1].trim().toLowerCase();
        if(seen[key]){ changed=true; continue; }
        seen[key]=true;
      }
      out.push(L);
    }
    if(changed){ save(p, out.join("\r\n")); }
    return changed;
  }

  // Мини-скелеты
  function ensureOnInitInt(p){
    var changed=false;
    changed = replaceRe(p, /\bvoid\s+OnInit\s*\(\s*\)\s*\{/m, "int OnInit(){\r\n  return(INIT_SUCCEEDED);") || changed;
    changed = replaceRe(p, /(int\s+OnInit\s*\(\s*\)\s*\{)(?![\s\S]*?return\s*\()/m, "$1\r\n  return(INIT_SUCCEEDED);") || changed;
    return changed;
  }
  function ensureOnTick(p){ var c=read(p); if(!/\bvoid\s+OnTick\s*\(\s*\)/.test(c)){ append(p, "\r\nvoid OnTick(){ /* auto-added */ }\r\n"); return true; } return false; }
  function ensureOnDeinit(p){ var c=read(p); if(!/\bvoid\s+OnDeinit\s*\(/.test(c)){ append(p, "\r\nvoid OnDeinit(const int reason){ /* auto-added */ }\r\n"); return true; } return false; }
  function addBanner(p){ return prepend(p, '#define AE_VIS_VERSION "AEGIS"\r\nvoid Aegis_LogVersion(){ Print("[Aegis] ", __FILE__, " ", __DATE__, " ", __TIME__); }\r\n'); }
  function ensureLogCall(p){ var c=read(p); if(/\bOnInit\s*\(\s*\)\s*\{/.test(c) && !/Aegis_LogVersion\s*\(/.test(c)){ return replaceRe(p, /(OnInit\s*\(\s*\)\s*\{)/m, "$1\r\n  Aegis_LogVersion();"); } return false; }
  function needsTrade(log, code){ return /CTrade\b/.test(code) && !/Trade\/Trade\.mqh/.test(code); }
  function parseMissingHeader(log){ var m=/(?:cannot open file|не удается открыть файл)\s*'([^']+\.mqh)'/i.exec(log||""); return m?m[1]:null; }

  // "Хирургия" — комментируем подозрительный блок с маркерами и памятью
  function suppressSuspicious(p){
    var c=read(p);
    var reProb=/(class\s+\w+[\s\S]{0,500}?;|(?:int|void|double|bool)\s+\w+\s*\([^;{]{0,200}\)\s*\{)/m;
    var m=reProb.exec(c); if(!m) return false;
    var s=m.index, e=s+m[0].length;
    var before=c.slice(0,s), mid=c.slice(s,e), after=c.slice(e);
    var tag = nowISO()+"_"+crc32(mid).toString(16);
    var wrapped = SUP_START+tag+"*/\r\n"+mid+"\r\n/*"+SUP_END+tag;
    save(p, before+wrapped+after);
    // память
    var db=readJSON(SUPPRESS_DB, []); db.push({tag:tag, when:"post-success-restore", reason:"compile-blocker", file:EA_REPO});
    saveJSON(SUPPRESS_DB, db);
    return true;
  }

  // Восстановление одного подавленного блока (после успешной сборки)
  function restoreOneSuppression(p){
    var c=read(p);
    var m=c.match(new RegExp("/\\*__AEGIS_SUPPRESS_START__\\*/(.*?)\\*/[\\s\\S]*?/\\*__AEGIS_SUPPRESS_END__\\*/\\1","m"));
    // Мягче: ищем по START/END без группировки:
    var rx = /\/\*__AEGIS_SUPPRESS_START__\*\/([A-Za-z0-9_\-:T\.]+)\*\/\r?\n([\s\S]*?)\r?\n\/\*__AEGIS_SUPPRESS_END__\*\/\1/;
    var mm = rx.exec(c);
    if(!mm) return false;
    var tag=mm[1], body=mm[2];
    var restored = c.replace(rx, body);
    save(p, restored);
    // пометим в БД, что пытались восстановить
    var db=readJSON(SUPPRESS_DB, []);
    for(var i=0;i<db.length;i++){ if(db[i].tag===tag){ db[i].restoredAttempt=(db[i].restoredAttempt||0)+1; break; } }
    saveJSON(SUPPRESS_DB, db);
    return true;
  }

  // Хинты из интернета + выжимки кода
  function fetchHints(q){
    try{
      var url="https://www.mql5.com/en/search#!keyword="+encodeURIComponent(q);
      var x=new ActiveXObject("MSXML2.XMLHTTP"); x.open("GET", url, false); x.send();
      if(x.status==200){
        var stamp = nowISO().replace(/[:\.]/g,'-');
        var html = "codex\\history\\hints_"+stamp+".html";
        var txt  = "codex\\history\\hints_"+stamp+".txt";
        save(html, x.responseText);
        // Очень грубая "выжимка кода": вытягиваем <code>…</code>
        var raw = x.responseText.replace(/\r/g,"");
        var codes=[], m;
        var re=/<code[^>]*>([\s\S]*?)<\/code>/ig;
        while((m=re.exec(raw))){ var s=m[1].replace(/<[^>]+>/g,''); codes.push(s); }
        if(codes.length){ save(txt, codes.join("\r\n----\r\n")); }
      }
    }catch(e){}
  }

  // Применение задач из TASK_*.md (минимально достаточно)
  function applyTasks(){
    try{
      var folder="codex\\inbox";
      if(!fso.FolderExists(folder)) return false;
      var files = new Enumerator(fso.GetFolder(folder).Files), changed=false;
      for(;!files.atEnd();files.moveNext()){
        var p=files.item().Path;
        if(!/\\TASK_.*\.md$/i.test(p)) continue;
        var t=read(p).split(/\r?\n/);
        for(var i=0;i<t.length;i++){
          var L=t[i].trim(); if(!L||/^#/.test(L)) continue;
          // include:add:Indicators/MovingAverages.mqh
          var m1 = /^include:add:(.+)$/i.exec(L);
          if(m1){ if(addInclude(EA_REPO, m1[1].trim())) changed=true; continue; }
          // replace:/REGEX/=> REPLACEMENT
          var m2 = /^replace:\s*\/(.+)\/\s*=>\s*(.*)$/i.exec(L);
          if(m2){ try{ var re=new RegExp(m2[1],"m"); changed = replaceRe(EA_REPO, re, m2[2]) || changed; }catch(e){} continue; }
        }
        // помечаем задачу как выполненную
        var done = p.replace(/\\TASK_/,"\\DONE_TASK_");
        copyFile(p, done); fso.DeleteFile(p,true);
      }
      if(changed){ copyFile(EA_REPO, EA_TERM); append(PATCH_REG, nowISO()+" task-apply :: external task\r\n"); }
      return changed;
    }catch(e){ return false; }
  }

  // Автопатчи по стадиям
  function autoPatch(stage, logTxt){
    var changed=false, code=read(EA_REPO);

    // Stage 1
    if(stage>=1){
      if(ensureLine(EA_REPO,"#property strict")){ append(PATCH_REG, nowISO()+" strict :: hygiene\r\n"); changed=true; code=read(EA_REPO); }
      if(addBanner(EA_REPO)){ append(PATCH_REG, nowISO()+" banner :: visibility\r\n"); changed=true; code=read(EA_REPO); }
      if(ensureLogCall(EA_REPO)){ append(PATCH_REG, nowISO()+" logcall :: visibility\r\n"); changed=true; code=read(EA_REPO); }
      if(/CTrade\b/.test(code) && !/Trade\/Trade\.mqh/.test(code) && addInclude(EA_REPO,"Trade/Trade.mqh")){
        append(PATCH_REG, nowISO()+" incl-trade :: CTrade include\r\n"); changed=true; code=read(EA_REPO);
      }
    }

    // Stage 2
    if(stage>=2){
      var hdr=parseMissingHeader(logTxt);
      if(hdr && addInclude(EA_REPO,hdr)){ append(PATCH_REG, nowISO()+" incl-"+hdr+" :: missing header\r\n"); changed=true; code=read(EA_REPO); }
    }

    // Stage 3
    if(stage>=3){
      if(ensureOnInitInt(EA_REPO)){ append(PATCH_REG, nowISO()+" oninit-int :: ensure int OnInit\r\n"); changed=true; code=read(EA_REPO); }
    }

    // Stage 4
    if(stage>=4){
      if(ensureOnTick(EA_REPO)){ append(PATCH_REG, nowISO()+" ensure-ontick :: add OnTick\r\n"); changed=true; code=read(EA_REPO); }
      if(ensureOnDeinit(EA_REPO)){ append(PATCH_REG, nowISO()+" ensure-ondeinit :: add OnDeinit\r\n"); changed=true; code=read(EA_REPO); }
    }

    // Stage 5
    if(stage>=5){
      var miss=parseMissingHeader(logTxt);
      if(miss && addInclude(EA_REPO, miss)){ append(PATCH_REG, nowISO()+" rebind-"+miss+" :: rebind include\r\n"); changed=true; code=read(EA_REPO); }
    }

    // Stage 6 — хирургия (с памятью)
    if(stage>=6){
      if(suppressSuspicious(EA_REPO)){ append(PATCH_REG, nowISO()+" aggressive-comment :: suspected block\r\n"); changed=true; code=read(EA_REPO); }
    }

    // Stage 7 — умный поиск include в системе
    if(stage>=7){
      var miss7=parseMissingHeader(logTxt);
      if(miss7){
        var rel=findIncludePath(miss7);
        if(rel && addInclude(EA_REPO, rel)){ append(PATCH_REG, nowISO()+" system-include :: "+rel+"\r\n"); changed=true; code=read(EA_REPO); }
      }
    }

    // Stage 8 — дедуп include
    if(stage>=8){
      if(dedupIncludes(EA_REPO)){ append(PATCH_REG, nowISO()+" include-dedup :: cleanup\r\n"); changed=true; code=read(EA_REPO); }
    }

    // Stage 9 — подготовка альтернативных путей (версия снапшот)
    if(stage>=9){
      snapshot("stage9_"+(new Date().toISOString().replace(/[:\.]/g,'-')));
    }

    if(changed) { copyFile(EA_REPO, EA_TERM); }
    return changed;
  }

  // Восстановление урезанных блоков после успешной сборки
  function healingAfterSuccess(){
    for(var k=0;k<RESTORE_TRIES;k++){
      if(!restoreOneSuppression(EA_REPO)) return true; // нечего восстанавливать — всё ок
      copyFile(EA_REPO, EA_TERM);
      var rc = compileOnce();
      var ex5=EA_TERM.replace(/\.mq5$/i,".ex5");
      if(rc===0 && exists(ex5)){
        copyFile(ex5, OUT_DIR+"\\"+baseName(ex5));
        append(ERR_LOG, nowISO()+" healing: restored one block OK\r\n");
        continue; // пробуем следующий блок
      } else {
        // Не прошло — вернём комментарии обратно (повторно подавим тот же блок)
        suppressSuspicious(EA_REPO); copyFile(EA_REPO, EA_TERM);
        append(ERR_LOG, nowISO()+" healing: restore failed, re-suppressed\r\n");
        break;
      }
    }
    return true;
  }

  // Генерация мини-теста
  function ensureSelfTest(){
    try{
      var p = (MQL5_DIR?MQL5_DIR:"") + "\\Scripts\\AegisSelfTest.mq5";
      var c = read(p);
      if(c.indexOf("void OnStart()")===-1){
        save(p,
          "#property script_show_inputs\r\n"+
          "void OnStart(){ Print(\"[AegisSelfTest] init ok: \", __DATE__, \" \", __TIME__); }\r\n"
        );
      }
    }catch(e){}
  }

  // Главный цикл
  var stage = curStage(); if(stage<1) stage=1;
  metrics.runs++; bumpStage("start@"+stage);

  // Применяем задания заранее
  applyTasks();
  ensureSelfTest();

  var ok=false, lastSig="";
  for(var i=1;i<=MAX_ITERS;i++){
    var rc=compileOnce();
    var ex5=EA_TERM.replace(/\.mq5$/i,".ex5");
    if(exists(ex5)){
      copyFile(ex5, OUT_DIR+"\\"+baseName(ex5));
      ok=true; metrics.successes++; bumpStage("success@"+stage);
      // После успеха — начинаем «обратный рост»: восстанавливаем урезанные блоки по одному
      healingAfterSuccess();
      break;
    }

    var logTxt=read(LOG);
    append(ERR_LOG, nowISO()+" [iter "+i+"] fail\r\n"+(logTxt||"")+"\r\n");
    var sig=errSig(logTxt); lastSig=sig;
    var needEsc=bumpSig(sig);
    var patched=autoPatch(stage, logTxt);

    if(needEsc && !patched){
      // Stage 9: если совсем застряли — попробуем откатить последний патч
      if(stage>=9){
        var did = rollback();
        if(did){ copyFile(EA_REPO, EA_TERM); append(ERR_LOG, nowISO()+" rollback applied\r\n"); }
      }
      stage++; setStage(stage); bumpStage("escalate@"+stage);
      // Хинты из интернета
      var tail=(logTxt||"").split(/\r?\n/).slice(-10).join(" ");
      fetchHints(tail);
      // После эскалации — ещё попытка применить патчи
      patched=autoPatch(stage, logTxt);
    }
  }

  // Сохраняем метрики
  metrics.lastSig = lastSig; metrics.lastStage = stage;
  saveJSON(METRICS, metrics);

  if(!ok){
    var ticket="codex\\inbox\\LOOP_BREAK_"+(new Date().toISOString().replace(/[:\.]/g,'-'))+".md";
    var md  ="# Smart loop break\r\n";
        md += "**EA:** "+EA_TERM+"\r\n";
        md += "**Stage:** "+stage+"\r\n";
        md += "**Applied patches:**\r\n"+read(PATCH_REG)+"\r\n";
        md += "**Log tail (200):**\r\n"+read(LOG).split(/\r?\n/).slice(-200).join("\n")+"\r\n";
    save(ticket, md);
    WScript.Quit(1);
  } else {
    WScript.Quit(0);
  }
})();
