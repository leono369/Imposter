/* ===================== DATEN ===================== */
var CATEGORIES = [
  { id:"alltag", name:"Alltag", words:["Backofen","nass","Ball","Pony","Kreuz","UFO","Traum","Schlüssel","Brücke","Pfeil","Tinte","Feuer","Messe","Stuhl","Selfie-Stick","Aquarium","Konzert","Matcha Latte","Französisch","Schrank"] },
  { id:"tiere",  name:"Tiere",  words:["Pinguin","Elefant","Hai","Adler","Fuchs","Qualle","Igel","Koala","Gepard","Eule","Wal","Biene","Krokodil","Otter","Flamingo","Wolf","Schmetterling","Faultier","Tintenfisch","Reh"] },
  { id:"essen",  name:"Essen",  words:["Pizza","Sushi","Brezel","Avocado","Lasagne","Curry","Pancakes","Döner","Ramen","Tiramisu","Spätzle","Burrito","Gnocchi","Falafel","Croissant","Eintopf","Waffel","Risotto","Pommes","Käsekuchen"] },
  { id:"berufe", name:"Berufe", words:["Arzt","Lehrer","Pilot","Koch","Gärtner","Anwalt","Friseur","Maurer","Tierarzt","Astronaut","Feuerwehrmann","Bäcker","Richter","Schauspieler","Klempner","Architekt","Förster","Kellner","Mechaniker","Hebamme"] },
  { id:"getraenke", name:"Getränke", words:["Cola","Bier","Espresso","Limonade","Wein","Smoothie","Tee","Mojito","Kakao","Wasser","Apfelschorle","Whisky","Eistee","Sekt","Latte","Energydrink","Gin Tonic","Milch","Spezi","Glühwein"] },
  { id:"musik",  name:"Musik",  words:["Klavier","Gitarre","Schlagzeug","Oper","Techno","Geige","Chor","Rap","Saxofon","Jazz","Trompete","Reggae","Flöte","Mundharmonika","Mikrofon","Harfe","Punk","Cello","Walzer","Beat"] }
];
var SPECIALS = [
  { id:"saboteur",    name:"Saboteur",    desc:"Will als Imposter verdächtigt werden." },
  { id:"senior",      name:"Senior",      desc:"Begriff nur lückenhaft lesbar." },
  { id:"doppelagent", name:"Doppelagent", desc:"Bekommt komplett andere Wörter." }
];
var WIN = 14;
var roleLabel = {imposter:'Imposter', saboteur:'Saboteur', senior:'Senior', doppelagent:'Doppelagent', crew:'Crew'};
function roleColor(r){ return r==='imposter' ? 'var(--accent)' : (r==='crew' ? 'var(--muted)' : 'var(--violet)'); }

/* ===================== STATE ===================== */
var state = { players:5, names:[], roles:{saboteur:true, senior:false, doppelagent:false}, category:"alltag", scores:[], round:0 };
var round=[], idx=0, theNum=0;

function maxSpecial(p){ return Math.min(3, Math.max(0, p - 3)); }       // 3->0, 4->1, 5->2, 6+->3
function chosenCount(){ return Object.values(state.roles).filter(Boolean).length; }
function playerName(i){ return (state.names[i] && state.names[i].trim()) ? state.names[i].trim() : ('Spieler ' + (i+1)); }

/* ===================== SPEICHERN (localStorage) ===================== */
var KEY = 'imposter_session_v1';
function save(){
  try{ localStorage.setItem(KEY, JSON.stringify({
    players:state.players, names:state.names, roles:state.roles, category:state.category,
    scores:state.scores, round:state.round, assign:round, theNum:theNum
  })); }catch(e){}
}
function loadSaved(){ try{ var r=localStorage.getItem(KEY); return r?JSON.parse(r):null; }catch(e){ return null; } }
function clearSession(){ try{ localStorage.removeItem(KEY); }catch(e){} }

/* ===================== NAV ===================== */
function go(id){
  var s=document.querySelectorAll('.screen');
  for(var i=0;i<s.length;i++) s[i].classList.remove('active');
  document.getElementById(id).classList.add('active');
  window.scrollTo(0,0);
}

/* ===================== SETUP ===================== */
function changePlayers(d){
  state.players = Math.max(3, Math.min(8, state.players + d));
  var cap = maxSpecial(state.players);
  SPECIALS.forEach(function(s){ if(chosenCount() > cap && state.roles[s.id]) state.roles[s.id] = false; });
  renderSetup();
}
function renderNames(){
  var box = document.getElementById('names'); box.innerHTML='';
  for(var i=0;i<state.players;i++){
    (function(i){
      var row = document.createElement('div'); row.className='nameRow';
      var val = state.names[i] ? state.names[i].replace(/"/g,'&quot;') : '';
      row.innerHTML = '<span class="ix">'+(i+1)+'</span><input type="text" maxlength="16" placeholder="Spieler '+(i+1)+'" value="'+val+'">';
      row.querySelector('input').addEventListener('input', function(e){ state.names[i] = e.target.value; });
      box.appendChild(row);
    })(i);
  }
}
function renderSetup(){
  var cap = maxSpecial(state.players);
  document.getElementById('pcount').innerHTML = state.players + '<small>Spieler</small>';
  document.getElementById('minus').disabled = state.players<=3;
  document.getElementById('plus').disabled = state.players>=8;
  document.getElementById('unlock').innerHTML = cap===0
    ? 'Bei <b>'+state.players+' Spielern</b>: nur Imposter, keine Sonderrollen.'
    : 'Bei <b>'+state.players+' Spielern</b>: bis zu <b>'+cap+' Sonderrolle'+(cap>1?'n':'')+'</b> spielbar.';
  renderNames();
  document.getElementById('rolecount').innerHTML = '<b>'+chosenCount()+'</b> / '+cap+' gewählt';
  var list = document.getElementById('roleList'); list.innerHTML='';
  SPECIALS.forEach(function(s){
    var on = state.roles[s.id]; var blocked = !on && chosenCount() >= cap;
    var el = document.createElement('div');
    el.className = 'roletoggle'+(on?' on':'')+(blocked?' disabled':'');
    el.innerHTML = '<div class="meta"><b>'+s.name+'</b><span>'+s.desc+'</span></div><div class="sw"></div>';
    el.onclick = function(){ if(blocked) return; state.roles[s.id]=!state.roles[s.id]; renderSetup(); };
    list.appendChild(el);
  });
  var cats = document.getElementById('cats'); cats.innerHTML='';
  CATEGORIES.forEach(function(c){
    var chip = document.createElement('button');
    chip.className='chip'+(state.category===c.id?' on':''); chip.textContent=c.name;
    chip.onclick=function(){ state.category=c.id; renderSetup(); };
    cats.appendChild(chip);
  });
}

/* ===================== ROLLEN-LOGIK ===================== */
function shuffle(a){ for(var i=a.length-1;i>0;i--){var j=(Math.random()*(i+1))|0; var t=a[i]; a[i]=a[j]; a[j]=t;} return a; }
function maskWord(w){
  return w.split('').map(function(ch,i){
    if(!/[a-zäöüß]/i.test(ch)) return ch;
    if(i===0 || !/[a-zäöüß]/i.test(w[i-1])) return ch;
    return Math.random()<0.5 ? '§' : ch;
  }).join('');
}
function buildRound(){
  var cat = CATEGORIES.filter(function(c){return c.id===state.category;})[0];
  var otherCats = CATEGORIES.filter(function(c){return c.id!==state.category;});
  theNum = (Math.random()*20|0)+1;
  var word = cat.words[theNum-1];
  var pool = ['imposter'];
  SPECIALS.forEach(function(s){ if(state.roles[s.id]) pool.push(s.id); });
  while(pool.length < state.players) pool.push('crew');
  shuffle(pool);
  round = pool.map(function(role,i){
    var display=word, sub='Kategorie · '+cat.name, secret='', masked=false;
    if(role==='imposter'){ display='???'; sub='Du kennst den Begriff nicht'; }
    else if(role==='saboteur'){ secret='Dein Ziel: lass dich als Imposter verdächtigen!'; }
    else if(role==='senior'){ display=maskWord(word); masked=true; sub='Lies genau hin …'; }
    else if(role==='doppelagent'){ var oc=otherCats[(Math.random()*otherCats.length)|0]; display=oc.words[theNum-1]; sub='Kategorie · '+oc.name; }
    return {name:playerName(i), role:role, display:display, sub:sub, secret:secret, masked:masked};
  });
}

/* ===================== REVEAL ===================== */
function startRoom(){ state.scores = new Array(state.players).fill(0); state.round=1; buildRound(); idx=0; save(); go('reveal'); renderHandoff(); }
function nextRound(){ state.round++; buildRound(); idx=0; save(); go('reveal'); renderHandoff(); }

function renderHandoff(){
  document.getElementById('revealRound').textContent = 'Runde '+state.round;
  var body=document.getElementById('revealBody');
  if(idx>=round.length){ renderRevealDone(); return; }
  var p=round[idx];
  var initial = p.name.charAt(0).toUpperCase();
  var tagColor = roleColor(p.role);
  body.innerHTML =
    '<div class="handoff">'+
      '<p class="lead-t">Gib das Handy an</p>'+
      '<div class="who"><span class="o">'+p.name+'</span></div>'+
      '<p class="sub-t">Niemand sonst schaut mit, ja?</p>'+
      '<div class="stage"><div class="flip" id="flip">'+
        '<div class="face front">'+
          '<div class="glyph">'+initial+'</div>'+
          '<div class="hint">Deine Karte</div>'+
          '<div class="cta-sm">Antippen zum Aufdecken</div>'+
        '</div>'+
        '<div class="face back">'+
          '<div class="numbadge">'+theNum+'</div>'+
          '<div class="roletag" style="color:'+tagColor+'; border:1px solid '+tagColor+'">'+roleLabel[p.role]+'</div>'+
          '<div class="word '+(p.masked?'masked':'')+'">'+(p.masked ? p.display.replace(/§/g,'<span class="gap">_</span>') : p.display)+'</div>'+
          '<div class="word-sub">'+p.sub+'</div>'+
          (p.secret?'<div class="secret">'+p.secret+'</div>':'')+
        '</div>'+
      '</div></div>'+
      '<button class="btn btn-line" style="width:100%" id="next">Gesehen — weiter</button>'+
    '</div>';
  var flip=document.getElementById('flip');
  flip.onclick=function(){ flip.classList.toggle('is-flipped'); };
  document.getElementById('next').onclick=function(){ idx++; renderHandoff(); };
}
function renderRevealDone(){
  document.getElementById('revealBody').innerHTML =
    '<div class="handoff">'+
      '<p class="lead-t">Alle haben ihre Karte gesehen.</p>'+
      '<div class="who">Begriff <span class="o">'+theNum+'</span></div>'+
      '<p class="sub-t">Jetzt reihum je einen Hinweis geben, dann diskutieren &amp; abstimmen.</p>'+
      '<button class="btn btn-primary" style="width:100%" onclick="openScore()">Fertig — zur Auswertung</button>'+
    '</div>';
}

/* ===================== AUSWERTUNG / PUNKTE ===================== */
var rolesShown=false;
function openScore(){ rolesShown=false; save(); go('score'); renderScore(); }
function adjust(i,d){ state.scores[i]=Math.max(0,(state.scores[i]||0)+d); save(); renderScore(); }
function setScore(i,v){ var n=parseInt(v,10); state.scores[i]=isNaN(n)?0:Math.max(0,n); save(); renderScore(); }
function toggleRoles(){ rolesShown=!rolesShown; renderScore(); }
function endRoom(){ if(confirm('Spielzimmer wirklich beenden? Punkte gehen verloren.')){ clearSession(); go('menu'); renderResume(); } }

function renderScore(){
  document.getElementById('scoreRound').textContent = 'Runde '+state.round;
  var max = Math.max.apply(null, state.scores);
  var winnerIdx = max>=WIN ? state.scores.indexOf(max) : -1;
  var html = '<p class="roomline">Spielzimmer · '+state.players+' Spieler · Sieg bei '+WIN+' Punkten</p>';
  if(winnerIdx>=0){ html += '<div class="winner">🏆 '+playerName(winnerIdx)+' gewinnt!</div>'; }
  html += '<button class="btn btn-line revealBtn" onclick="toggleRoles()">'+(rolesShown?'Rollen verbergen':'Rollen dieser Runde aufdecken')+'</button>';
  html += '<p class="scoreHint">Punkte eintippen oder mit −/+1/+3 zählen:</p>';
  for(var i=0;i<state.players;i++){
    var isLead = state.scores[i]===max && max>0;
    var role='';
    if(rolesShown && round[i]){
      var r=round[i].role;
      role = '<div class="rl" style="color:'+roleColor(r)+'">'+roleLabel[r]+(r!=='imposter'?(' · '+round[i].display.replace(/§/g,'_')):'')+'</div>';
    }
    html +=
      '<div class="scoreRow'+(isLead?' lead':'')+'">'+
        '<div class="who2"><div class="nm">'+playerName(i)+'</div>'+role+'</div>'+
        '<button class="sbtn minus" onclick="adjust('+i+',-1)">−</button>'+
        '<input class="ptsInput" type="number" inputmode="numeric" value="'+(state.scores[i]||0)+'" onchange="setScore('+i+',this.value)">'+
        '<button class="sbtn plus" onclick="adjust('+i+',1)">+1</button>'+
        '<button class="sbtn plus" onclick="adjust('+i+',3)">+3</button>'+
      '</div>';
  }
  html += '<div class="scoreActions">'+
      '<button class="btn btn-primary" onclick="nextRound()">Nächste Runde</button>'+
      '<button class="btn btn-line" onclick="endRoom()">Spielzimmer beenden</button>'+
    '</div>';
  document.getElementById('scoreBody').innerHTML = html;
}

/* ===================== FORTSETZEN ===================== */
function renderResume(){
  var slot = document.getElementById('resumeSlot'); slot.innerHTML='';
  var s = loadSaved();
  if(s && s.round>0){
    slot.innerHTML =
      '<div class="resume">'+
        '<div class="rt">Offenes Spielzimmer · <b>'+s.players+' Spieler · Runde '+s.round+'</b></div>'+
        '<button class="btn btn-violet" style="width:100%" onclick="resumeSession()">Spiel fortsetzen</button>'+
      '</div>';
  }
}
function resumeSession(){
  var s = loadSaved(); if(!s) return;
  state.players=s.players; state.names=s.names||[]; state.roles=s.roles; state.category=s.category;
  state.scores=s.scores||[]; state.round=s.round||1;
  round = s.assign||[]; theNum = s.theNum||0;
  rolesShown=false;
  go('score'); renderScore();
}

/* ===================== INIT ===================== */
renderSetup();
renderResume();
