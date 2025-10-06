(function(){
  var sh = new ActiveXObject("WScript.Shell");
  var fso = new ActiveXObject("Scripting.FileSystemObject");
  function read(p){try{var t=fso.OpenTextFile(p,1);var s=t.ReadAll();t.Close();return s;}catch(e){return"";}}
  function save(p,s){var f=fso.OpenTextFile(p,2,true);f.Write(s);f.Close();}
  function now(){return (new Date()).toISOString();}
  var envf="config\\build-config_Version3.env";
  if(!fso.FileExists(envf)){WScript.Echo("[Aegis] .env not found");WScript.Quit(10);}
  var lines=read(envf).split(/\r?\n/);var env={};
  for(var i=0;i<lines.length;i++){var m=lines[i].match(/^([^#;=]+)=(.*)$/);if(m)env[m[1].trim()]=m[2].trim();}
  var meta=env.METAEDITOR;
  var ea=env.EA_TERM;
  var log="codex\\build\\compile.log";
  if(!fso.FolderExists("codex\\build")) fso.CreateFolder("codex\\build");
  var cmd='"'+meta+'" /compile:"'+ea+'" /log:"'+log+'"';
  var rc=sh.Run(cmd,0,true);
  save("codex\\state\\journal.log", now()+" compile exit="+rc+"\r\n");
  WScript.Echo("[Aegis] Compilation finished. Log saved to "+log);
  WScript.Quit(rc);
})();
