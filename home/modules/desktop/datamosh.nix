# AFK-only datamosh / signal-loss idle field.
#
# the 2am-alone-with-the-machine dread. when coral (clamshell, CYBERIA) goes idle the screen
# is taken over by a black field that decays: an ordered-dither / static / datamosh smear,
# a faint "NO SIGNAL", and a slow pseudo-Navi console that gets EMPTIER and lonelier the
# longer the idle runs. negative space IS the content. sincere melancholy, never a wink.
#
# RENDERER: the shared kiosk machinery in kiosk.nix (same watcher/updater skeleton as
# dashboard.nix). Chromium --start-fullscreen launched by `open` from the in-session
# launchd agent (a daemon/asuser context cannot foreground a GUI window, so the
# browser-kiosk-by-open path is the only one that reliably fullscreens). the watcher
# samples ioreg HIDIdleTime, launches past idleSeconds, tears down the instant input
# returns. single-instance (pkill the unique --user-data-dir tag) + cooldown, flood-proof.
#
# SEPARATE from rice.dashboard: that is the telemetry readout (clock/system/.plan). this is the
# dread field with no data at all. both default OFF; you would enable exactly one on a given box.
# unique TAG + outDir so the two kiosks never collide on pgrep/pkill.
#
# COLORS: every swatch is a :root custom property from theme.palette, so it follows the active
# variant (blood/copland/macchiato), NEVER hardcoded. the static is canvas-rendered black-on-base
# so the palette shows through. no JS template literals so nix does not eat the ${}.
{
  config,
  lib,
  pkgs,
  theme,
  ...
}:
let
  cfg = config.rice.datamosh;
  outDir = "${config.home.homeDirectory}/.cache/coral-datamosh";
  profileDir = "${outDir}/chrome-profile";
  kiosk = import ./kiosk.nix { inherit pkgs; };
  updaterName = "coral-datamosh-updater";

  # the page. a black field with a canvas static/ordered-dither smear, faint "NO SIGNAL", and a
  # slow-scrolling pseudo-Navi console. the longer idle runs (idle seconds fed via data.json,
  # same ioreg sample the watcher uses) the more it sheds: console lines thin out, NO SIGNAL
  # dims, the static itself quiets toward an empty plum-black plate. emptier, not busier.
  #
  # the static is a low-rate canvas ordered-dither (8x8 bayer threshold over a drifting noise
  # field) plus rare horizontal datamosh shears, redrawn a few times a second so it reads as
  # analog decay, not a screensaver loop. low + a-little-wrong, never a sound pack or a flex.
  htmlFile = pkgs.writeText "coral-datamosh.html" ''
    <!doctype html><html><head><meta charset="utf-8"><title>NO SIGNAL</title><style>
      :root{
        --base:${theme.palette.base};--mantle:${theme.palette.mantle};--crust:${theme.palette.crust};
        --text:${theme.palette.text};--sub:${theme.palette.subtext0};
        --accent:${theme.palette.mauve};--comment:${theme.palette.overlay1};
        --surf:${theme.palette.surface0};--surf1:${theme.palette.surface1}}
      *{margin:0;box-sizing:border-box}
      html,body{height:100%;background:var(--crust);overflow:hidden}
      /* the static plate sits under everything; canvas paints base/plum speckle on crust black. */
      #static{position:fixed;inset:0;z-index:0;image-rendering:pixelated;
           width:100vw;height:100vh;opacity:.5}
      /* faint phosphor scanlines over the tube, same membrane as the dashboard. */
      body::after{content:"";position:fixed;inset:0;pointer-events:none;z-index:5;
           background:repeating-linear-gradient(to bottom,
             rgba(0,0,0,0) 0,rgba(0,0,0,0) 2px,rgba(0,0,0,.22) 2px,rgba(0,0,0,.22) 3px)}
      /* a heavy vignette pulls the eye to a near-empty centre: negative space as content. */
      body::before{content:"";position:fixed;inset:0;pointer-events:none;z-index:4;
           background:radial-gradient(ellipse at center,transparent 30%,var(--crust) 92%)}
      /* NO SIGNAL: dead centre, dim, wide-tracked. fades further as idle deepens. */
      .nosignal{position:fixed;inset:0;z-index:6;display:flex;align-items:center;justify-content:center;
           pointer-events:none}
      .nosignal span{font-family:'Share Tech Mono','VT323',ui-monospace,Menlo,monospace;
           font-size:2.4vw;letter-spacing:1.1vw;color:var(--sub);text-transform:uppercase;
           text-shadow:0 0 1.4vw var(--mantle);opacity:.5;transition:opacity 6s ease}
      /* the Navi console: a slow upward scroll of terse machine lines, bottom-left, dim. it does
         NOT fill the screen, a thin column in the corner, the rest is dark. */
      .console{position:fixed;left:4vw;bottom:5vh;z-index:6;width:36vw;max-height:40vh;
           overflow:hidden;font-family:'Share Tech Mono','VT323',ui-monospace,Menlo,monospace;
           font-size:1.1vw;line-height:1.9;color:var(--comment);
           -webkit-mask-image:linear-gradient(to top,transparent,#000 22%,#000);
           transition:opacity 6s ease}
      .console .ln{white-space:nowrap;opacity:.85}
      .console .ln.q{color:var(--accent);opacity:.7} /* the rare line that is not a log: a question. */
      /* idle tiers compiled from nix. body.lonely quiets the static and dims NO SIGNAL; body.gone
         takes the console too, leaving an almost-empty plate and one drifting line. */
      body.lonely #static{opacity:.28;transition:opacity 8s ease}
      body.lonely .nosignal span{opacity:.26}
      body.gone #static{opacity:.12}
      body.gone .console{opacity:.18}
      body.gone .nosignal span{opacity:.12}
    </style></head><body>
      <canvas id="static"></canvas>
      <div class="nosignal"><span>NO SIGNAL</span></div>
      <div class="console" id="console"></div>
    <script>
      // ---- canvas ordered-dither static -----------------------------------------------------
      // an 8x8 bayer matrix thresholds a drifting value-noise field into black/plum speckle. low
      // frame rate (a few hz) so it reads analog, not 60fps screensaver. colors pulled from the
      // resolved :root vars so it always matches the palette.
      var cv=document.getElementById('static'),cx=cv.getContext('2d');
      var css=getComputedStyle(document.documentElement);
      var SPECK=css.getPropertyValue('--base').trim()||'#0d0a0e';
      var SHEAR=css.getPropertyValue('--surf1').trim()||'#1e1824';
      var BG=css.getPropertyValue('--crust').trim()||'#060406';
      var BAYER=[0,32,8,40,2,34,10,42, 48,16,56,24,50,18,58,26,
                 12,44,4,36,14,46,6,38, 60,28,52,20,62,30,54,22,
                 3,35,11,43,1,33,9,41, 51,19,59,27,49,17,57,25,
                 15,47,7,39,13,45,5,37, 63,31,55,23,61,29,53,21];
      var CELL=3,W=0,H=0,t=0;
      function resize(){W=cv.width=Math.ceil(innerWidth/CELL);H=cv.height=Math.ceil(innerHeight/CELL);
        cv.style.width=innerWidth+'px';cv.style.height=innerHeight+'px';}
      addEventListener('resize',resize);resize();
      // density: how much speckle survives the threshold. drops as idle deepens (set by load()).
      var density=0.42;
      function frame(){
        cx.fillStyle=BG;cx.fillRect(0,0,W,H);
        cx.fillStyle=SPECK;
        for(var y=0;y<H;y++){for(var x=0;x<W;x++){
          // cheap drifting value noise: a couple of sines beating against each other + jitter.
          var n=(Math.sin((x*12.9898+y*78.233+t*0.7))*43758.5453);
          n=n-Math.floor(n); // fract -> [0,1)
          var thr=BAYER[(y&7)*8+(x&7)]/64;
          if(n*density>thr*0.5) cx.fillRect(x,y,1,1);
        }}
        // rare datamosh shear: copy a horizontal band and slam it sideways. signal tearing.
        if(Math.random()<0.05){
          var by=(Math.random()*H)|0,bh=2+((Math.random()*6)|0),dx=((Math.random()*14)-7)|0;
          try{var band=cx.getImageData(0,by,W,bh);cx.putImageData(band,dx,by);}catch(e){}
          cx.fillStyle=SHEAR;cx.fillRect(0,by,W,1);cx.fillStyle=SPECK;
        }
        t+=1;
      }
      // a few frames a second, NOT requestAnimationFrame: the slowness is the point.
      setInterval(frame,180);frame();

      // ---- pseudo-Navi console --------------------------------------------------------------
      // terse machine logs, mostly. one line in a while is a question, dimmer and accent-tinted,
      // the machine talking to no one. the pool is fixed; we never claim live telemetry here.
      var LOG=['link layer: carrier lost','navi: resync 0x00','protocol seven: idle',
        'no host responding','knights: no quorum','wired: listening...','memory: paging out',
        'present day. present time.','autonomous channel quiet','beacon: ...','layer 13: empty',
        'connection refused','no carrier','reflection: none found'];
      var QS=['is anyone there?','are you still here?','where did everyone go?',
        'do you remember me?','...are you watching?'];
      var con=document.getElementById('console'),MAXLN=14;
      function emit(){
        var q=Math.random()<0.14;
        var txt=q?QS[(Math.random()*QS.length)|0]:LOG[(Math.random()*LOG.length)|0];
        var d=document.createElement('div');d.className='ln'+(q?' q':"");d.textContent=txt;
        con.appendChild(d);
        while(con.children.length>MAXLN) con.removeChild(con.firstChild);
      }
      emit();
      // emit interval lengthens as idle deepens (set in load()): the machine goes quieter.
      var emitMs=4200,emitTimer=setInterval(emit,emitMs);
      function setEmit(ms){if(ms!==emitMs){emitMs=ms;clearInterval(emitTimer);emitTimer=setInterval(emit,ms);}}

      // ---- idle coupling --------------------------------------------------------------------
      // data.json carries live HID idle seconds (same ioreg sample as the watcher). past
      // LONELY the field quiets; past GONE it nearly empties. thresholds compiled from nix.
      var LONELY=${toString cfg.lonelySeconds},GONE=${toString cfg.goneSeconds};
      function load(){fetch('data.json?'+Date.now()).then(function(r){return r.json();}).then(function(j){
        var idle=(j.idle|0);
        document.body.classList.toggle('lonely',idle>=LONELY);
        document.body.classList.toggle('gone',idle>=GONE);
        // the longer alone, the thinner the static and the slower the console.
        if(idle>=GONE){density=0.12;setEmit(11000);}
        else if(idle>=LONELY){density=0.26;setEmit(7000);}
        else{density=0.42;setEmit(4200);}
      }).catch(function(){});}
      setInterval(load,2000);load();
    </script></body></html>
  '';

  # writes data.json (just the live HID idle seconds) into outDir; the skeleton + the
  # shared ioreg idle sampling live in kiosk.nix. the page reads `idle` to flip the
  # lonely/gone tiers. no telemetry here on purpose, this field shows no data.
  updater = kiosk.mkUpdater {
    name = updaterName;
    inherit outDir;
    writePayload = ''
      ${pkgs.jq}/bin/jq -n --argjson idle "$idle" '{idle:$idle}' \
        > "$out/.data.json.tmp" && ${pkgs.coreutils}/bin/mv "$out/.data.json.tmp" "$out/data.json"
    '';
  };

  watcher = kiosk.mkWatcher {
    name = "datamosh";
    tag = "coral-datamosh-kiosk";
    inherit
      outDir
      profileDir
      htmlFile
      updater
      updaterName
      ;
    inherit (cfg) idleSeconds pollSeconds;
  };
in
{
  options.rice.datamosh = {
    enable = lib.mkEnableOption "AFK-only datamosh / signal-loss idle field (Chromium kiosk)";
    idleSeconds = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = "Seconds of no HID input before the signal-loss field takes over.";
    };
    pollSeconds = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "How often the watcher samples HID idle time.";
    };
    lonelySeconds = lib.mkOption {
      type = lib.types.int;
      default = 1200;
      description = "Seconds of HID idle before the static quiets and NO SIGNAL dims.";
    };
    goneSeconds = lib.mkOption {
      type = lib.types.int;
      default = 3600;
      description = "Seconds of HID idle before the field nearly empties to one drifting line.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.agents.datamosh = {
      enable = true;
      config = {
        ProgramArguments = [ "${watcher}" ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/datamosh.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/datamosh.log";
      };
    };
  };
}
