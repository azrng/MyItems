/* ============================================================
   暖仓 WarmPantry · 共享交互脚本
   主题切换 / toast / 确认弹层 / 表单控件 / 各页面行为
   页面在 <body data-page="..."> 声明身份，按需初始化
   ============================================================ */
(function(){
  'use strict';
  var $=function(s,r){return (r||document).querySelector(s)};
  var $$=function(s,r){return Array.prototype.slice.call((r||document).querySelectorAll(s))};

  /* ===== 深色模式（跟随系统 + 手动开关，localStorage 记忆） ===== */
  function applyTheme(dark){
    document.documentElement.classList.toggle('dark',dark);
    var sw=document.getElementById('themeSwitch');
    if(sw)sw.classList.toggle('on',dark);
    try{localStorage.setItem('wp-theme',dark?'dark':'light')}catch(_){}
  }
  try{
    var saved=localStorage.getItem('wp-theme');
    if(saved==='dark'||(!saved&&window.matchMedia&&matchMedia('(prefers-color-scheme: dark)').matches)){
      document.documentElement.classList.add('dark');
      var sw0=document.getElementById('themeSwitch');if(sw0)sw0.classList.add('on');
    }
  }catch(_){}

  /* ===== 全局路由表（页面跳转） ===== */
  var NAV={home:'home.html',lib:'library.html',consume:'consume.html',me:'mine.html',
    add:'add-item.html',cat:'categories.html',loc:'locations.html',expi:'expiring.html',
    arch:'archive.html',backup:'backup.html',about:'about.html',rec:'consume.html#rec'};

  /* ===== toast ===== */
  var toastEl=document.getElementById('toast'),toastMsg=document.getElementById('toastMsg'),tt;
  function showToast(msg){
    if(!toastEl)return;
    toastMsg.textContent=msg;toastEl.classList.add('on');
    clearTimeout(tt);tt=setTimeout(function(){toastEl.classList.remove('on')},2200);
  }

  /* ===== 通用确认弹层（#sheet + #mask） ===== */
  var mask=document.getElementById('mask'),sheet=document.getElementById('sheet'),sheetAction=null;
  function openConfirm(title,sub,okLabel,action,cancelLabel){
    if(!sheet)return;
    document.getElementById('sheetTitle').textContent=title;
    document.getElementById('sheetSub').textContent=sub;
    document.getElementById('sheetOk').textContent=okLabel||'确认';
    var sc=document.getElementById('sheetCancel');if(sc)sc.textContent=cancelLabel||'先留着';
    sheetAction=action;
    if(mask)mask.classList.add('on');
    sheet.classList.add('on');
  }
  function closeSheet(){if(mask)mask.classList.remove('on');if(sheet)sheet.classList.remove('on');}
  if(mask)mask.onclick=closeSheet;
  var sheetCancel=document.getElementById('sheetCancel');
  if(sheetCancel)sheetCancel.onclick=closeSheet;
  var sheetOk=document.getElementById('sheetOk');
  if(sheetOk)sheetOk.onclick=function(){
    var act=sheetAction;sheetAction=null;closeSheet();
    if(act)act();
  };

  /* ===== 全局点击路由 ===== */
  document.addEventListener('click',function(e){
    if(e.target.closest('[data-catadd]')){openCat();return;}
    if(e.target.closest('[data-locadd]')){openLoc();return;}
    var catRowEl=e.target.closest('#v-cat .cat-row');
    if(catRowEl&&catSheet){openCatEdit(catRowEl);return;}
    var locCardEl=e.target.closest('#v-loc .loc-card');
    if(locCardEl&&locSheet){openLocEdit(locCardEl);return;}
    var nav=e.target.closest('[data-nav]');
    if(nav&&NAV[nav.dataset.nav]){location.href=NAV[nav.dataset.nav];return;}
    var t=e.target.closest('[data-toast]');
    if(t)showToast(t.dataset.toast);
    var s=e.target.closest('.switch');
    if(s&&!s.closest('#themeRow'))s.classList.toggle('on');
  });
  var themeRow=document.getElementById('themeRow');
  if(themeRow)themeRow.addEventListener('click',function(e){
    e.stopPropagation();
    applyTheme(!document.documentElement.classList.contains('dark'));
  });
  document.addEventListener('keydown',function(e){if(e.key==='Escape'){closeSheet();closeCat();closeLoc();}});

  /* ===== 单选宫格（添加页分类/位置） ===== */
  $$('[data-single]').forEach(function(g){
    g.addEventListener('click',function(e){
      var o=e.target.closest('.oc');if(!o||o.textContent.trim().indexOf('➕')===0)return;
      $$('.oc',g).forEach(function(x){x.classList.remove('act')});o.classList.add('act');
    });
  });

  /* ===== 多选筛选 chips（物品库） ===== */
  var libChips=document.getElementById('libChips');
  if(libChips)libChips.addEventListener('click',function(e){
    var c=e.target.closest('.chip');if(!c)return;
    $$('.chip',libChips).forEach(function(x){x.classList.remove('act')});c.classList.add('act');
    showToast('已筛选：'+c.textContent.trim());
  });

  /* ===== 数量步进器（添加页） ===== */
  var qty=1;
  $$('[data-step]').forEach(function(b){
    b.onclick=function(){
      qty=Math.max(1,Math.min(99,qty+ +b.dataset.step));
      var n=document.getElementById('qtyNum');if(n)n.textContent=qty;
    };
  });

  /* ============================================================
     页面行为
     ============================================================ */
  var page=(document.body.dataset.page||'').toLowerCase();

  /* ---- 消耗中心：快捷 −N 即时写流水，点行弹出「记录消耗」自定义减量 ---- */
  if(page==='consume'){
    var segBtns=$$('#conSeg button');
    function switchSeg(key){
      segBtns.forEach(function(b){b.classList.toggle('act',b.dataset.seg===key)});
      document.getElementById('seg-using').style.display=key==='using'?'':'none';
      document.getElementById('seg-rec').style.display=key==='rec'?'':'none';
    }
    segBtns.forEach(function(b){b.onclick=function(){switchSeg(b.dataset.seg)}});
    if(location.hash==='#rec')switchSeg('rec');

    /* -- 工具 -- */
    function fmt(n){n=Math.round(n*100)/100;return String(n%1===0?Math.round(n):n)}
    function esc(s){return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')}
    function hhmm(){
      var d=new Date(),p=function(x){return String(x).padStart(2,'0')};
      return p(d.getHours())+':'+p(d.getMinutes());
    }
    function rowCtx(row){
      var icon=row.querySelector('.remini');
      var m=(icon.getAttribute('style')||'').match(/--[a-z]+-soft/);
      return {name:row.dataset.name,unit:row.dataset.unit,init:+row.dataset.init,
        left:+row.dataset.left,fine:+row.dataset.fine||1,loc:row.dataset.loc,
        emoji:icon.textContent.trim(),soft:m?m[0]:'--accent-soft'};
    }

    /* -- 流水插入（写入「今天」时间线置顶） -- */
    function prependLog(c,o){
      o.src='来自 '+c.loc+(o.note?' · '+esc(o.note):'');
      var tl=document.getElementById('tlToday');if(!tl)return;
      var div=document.createElement('div');
      div.className='tl-item '+(o.cls||'out');
      div.style.animation='rise .5s cubic-bezier(.22,.9,.3,1) both';
      div.innerHTML='<div class="tl-card">'
        +'<div class="remini" style="background:var('+c.soft+');width:36px;height:36px;font-size:17px">'+c.emoji+'</div>'
        +'<div><b>'+esc(o.title)+'</b><small>'+hhmm()+' · '+o.src+'</small></div>'
        +'<span class="amount '+(o.cls==='arch'?'':'a-out')+'">'+o.amt+'</span></div>';
      tl.insertBefore(div,tl.firstChild);
    }
    function bumpToday(){
      var c=document.getElementById('todayCount');
      c.textContent=(+c.textContent||0)+1;
      document.getElementById('todayCountInline').textContent=c.textContent;
      c.classList.remove('bump');void c.offsetWidth;c.classList.add('bump');
    }
    function rowLowTag(row){
      var b=row.querySelector('.con-info b');
      if(!row.querySelector('.low-tag')){
        var t=document.createElement('span');t.className='low-tag';t.textContent='余量低';
        b.appendChild(t);
      }
    }

    /* -- 记一笔消耗（更新行状态 + 写流水 + 更新今日卡） -- */
    function recordConsume(row,amt,source,note){
      var c=rowCtx(row),clamped=amt>=c.left;
      var left=Math.max(0,Math.round((c.left-amt)*100)/100);
      row.dataset.left=left;
      var pct=left>0?Math.max(1,Math.round(left/c.init*100)):0;
      row.querySelector('.pct').textContent='剩 '+pct+'%';
      row.querySelector('.meter i').style.width=pct+'%';
      if(pct>0&&pct<=25)rowLowTag(row);
      var badgeUnit=(c.unit==='ml'||c.unit==='g')?c.unit:'';
      prependLog(c,{title:c.name+' −'+fmt(amt)+' '+c.unit,cls:'out',
        amt:'−'+fmt(amt)+badgeUnit,note:source==='手动录入'?note:''});
      bumpToday();
      showToast(left<=0?'已清至 0 · 点「✓」完成用完归档 🗄️'
        :'已记录 '+c.name+' −'+fmt(amt)+badgeUnit+'，详见「消耗记录」📉');
    }

    /* -- 快捷 −N：等效 −1 步长，来源=快捷消耗 -- */
    $$('.consume-one').forEach(function(b){
      b.onclick=function(e){
        e.stopPropagation();
        recordConsume(b.closest('.con-row'),+b.dataset.amt,'快捷消耗','');
      };
    });

    /* -- ✓ 用完：二次确认 → 归档行 + 写 archive 流水 -- */
    $$('.useup').forEach(function(b){
      b.onclick=function(e){
        e.stopPropagation();
        var row=b.closest('.con-row'),name=row.dataset.name,c=rowCtx(row);
        openConfirm('「'+name+'」用完了？','这件物品将从库存移除并写入消耗记录，随时可以在「耗尽归档」里回购。','用完并归档',function(){
          row.style.transition='.4s';row.style.opacity='0';row.style.transform='translateX(24px)';
          setTimeout(function(){
            row.innerHTML='<div style="text-align:center;color:var(--ink-faint);font-weight:800;font-size:12px;padding:6px">🗄️ 已移入耗尽归档</div>';
            row.style.opacity='1';row.style.transform='none';
          },380);
          prependLog(c,{title:name+' 用完归档',cls:'arch',amt:'🗄️',
            note:'累计消耗 '+fmt(c.init-c.left)+' '+c.unit});
          showToast('「'+name+'」已归档，去「耗尽归档」看看吧 🗄️');
        });
      };
    });

    /* -- 「记录消耗」底部弹层（行点击打开） -- */
    var recMask=document.getElementById('recMask'),recSheet=document.getElementById('recSheet');
    var rsChips=recSheet.querySelector('#rsChips'),rsCustom=recSheet.querySelector('#rsCustom');
    var rsNum=recSheet.querySelector('#rsNum'),cur=null;
    function closeRec(){
      recMask.classList.remove('on');recSheet.classList.remove('on');cur=null;
    }
    recMask.onclick=closeRec;
    recSheet.querySelector('#rsCancel').onclick=closeRec;
    document.addEventListener('keydown',function(e){if(e.key==='Escape'&&recSheet.classList.contains('on'))closeRec()});

    function renderPreview(){
      if(!cur)return;
      var amt=currentAmt(),clamped=amt>cur.left;
      if(clamped)amt=cur.left;
      var after=Math.max(0,Math.round((cur.left-amt)*100)/100);
      var afterPct=cur.init>0?Math.round(after/cur.init*100):0;
      recSheet.querySelector('#rsPrevAmt').textContent='−'+fmt(amt)+' '+cur.unit;
      recSheet.querySelector('#rsPrevAfter').textContent=after<=0?'剩余 → 用完 🙂'
        :'剩余 → '+fmt(after)+' '+cur.unit+'（'+afterPct+'%）';
      var src=recSheet.querySelector('#rsSrc');
      src.classList.toggle('warn',clamped);
      src.textContent=clamped
        ?'⚠️ 超过当前剩余量，将按剩余全部记录；只想清零也可以直接用行上的「✓」。'
        :'📋 将写入库存流水：类型 消耗 · 来源 手动录入 · 位置快照 来自 '+cur.loc;
    }
    function currentAmt(){
      if(!cur)return 0;
      if(cur.custom){
        var v=parseFloat(rsNum.value);
        return isNaN(v)||v<=0?cur.fine:Math.round(v*100)/100;
      }
      var chip=rsChips.querySelector('.on:not([data-custom])');
      return chip?+chip.dataset.amt:cur.presets[0];
    }
    function selChip(el){
      rsChips.querySelectorAll('.chip').forEach(function(x){x.classList.remove('on')});
      el.classList.add('on');
      cur.custom=!!el.dataset.custom;
      rsCustom.classList.toggle('on',cur.custom);
      if(cur.custom){rsNum.value=fmt(cur.fine);try{rsNum.focus()}catch(_){}}
      renderPreview();
    }
    function openRec(row){
      cur=rowCtx(row);cur.row=row;cur.custom=false;
      var icon=recSheet.querySelector('#rsIcon');
      icon.textContent=cur.emoji;
      icon.setAttribute('style','background:var('+cur.soft+')');
      recSheet.querySelector('#rsName').textContent=cur.name;
      var pct=cur.init>0?Math.round(cur.left/cur.init*100):0;
      recSheet.querySelector('#rsMeta').textContent='剩余 '+fmt(cur.left)+' / 共 '+fmt(cur.init)+' '+cur.unit+' · '+pct+'%';
      recSheet.querySelector('#rsMeterFill').style.width=pct+'%';
      recSheet.querySelector('#rsUnit').textContent=cur.unit;
      recSheet.querySelector('#rsHint').textContent='步进精度 '+fmt(cur.fine)+' '+cur.unit+'，支持小数估算（如 −8 ml）；写完即出现在「消耗记录」。';
      rsChips.innerHTML='';
      cur.presets=String(row.dataset.presets||'1').split('|').map(Number).filter(function(n){return n>0});
      cur.presets.forEach(function(p,i){
        var b=document.createElement('button');
        b.type='button';b.className='chip'+(i===0?' on':'');
        b.textContent='−'+fmt(p)+' '+cur.unit;b.dataset.amt=p;
        b.onclick=function(){selChip(b)};
        rsChips.appendChild(b);
      });
      var cb=document.createElement('button');
      cb.type='button';cb.className='chip';cb.textContent='自定义…';cb.dataset.custom='1';
      cb.onclick=function(){selChip(cb)};
      rsChips.appendChild(cb);
      rsCustom.classList.remove('on');rsNum.value=fmt(cur.presets[0]);
      recSheet.querySelector('#rsNote').value='';
      renderPreview();
      recMask.classList.add('on');recSheet.classList.add('on');
    }
    recSheet.querySelector('#rsMinus').onclick=function(){
      var v=parseFloat(rsNum.value);v=isNaN(v)?0:v-cur.fine;
      rsNum.value=fmt(Math.max(cur.fine,v));renderPreview();
    };
    recSheet.querySelector('#rsPlus').onclick=function(){
      var v=parseFloat(rsNum.value);v=isNaN(v)?0:v+cur.fine;
      rsNum.value=fmt(v);renderPreview();
    };
    rsNum.addEventListener('input',renderPreview);
    recSheet.querySelector('#rsOk').onclick=function(){
      if(!cur)return;
      var amt=currentAmt(),row=cur.row,clamped=amt>=rowCtx(row).left;
      if(amt<=0){showToast('用量要大于 0 才能记录哦 ✏️');return;}
      var note=recSheet.querySelector('#rsNote').value.trim();
      closeRec();
      recordConsume(row,clamped?rowCtx(row).left:amt,'手动录入',note);
    };
    $$('.con-row').forEach(function(row){
      row.style.cursor='pointer';
      row.addEventListener('click',function(e){
        if(e.target.closest('.ibtn'))return;
        openRec(row);
      });
    });
  }

  /* ---- 物品库：点卡片 → 物品详情；− FIFO 快捷消耗（可撤销）；＋ 快捷再入库新批次 ---- */
  if(page==='library'){
    var LIBLOCS=/冰箱冷藏|冰箱冷冻|厨房吊柜|橱柜吊柜|卫生间置物架|客厅电视柜|玄关收纳柜|家庭药箱|梳妆台抽屉|水槽收纳篮|浴室置物架/;
    function qtyEl(card){return card.querySelector('.stepper')}
    function qtyNum(card){return parseInt((qtyEl(card).childNodes[1].textContent||'').trim())||0}
    function setQty(card,n){qtyEl(card).childNodes[1].textContent=n}

    /* -- 撤销条：模拟需求 4.3/4.8 的 5 秒 Snackbar 撤销窗口 -- */
    var bar=document.getElementById('snackbar'),barTimer=null,pending=null;
    function hideBar(){if(bar)bar.classList.remove('on');pending=null}
    function showUndo(msg,restore){
      if(!bar){showToast(msg);return}
      document.getElementById('sbMsg').textContent=msg;
      pending=restore;bar.classList.add('on');
      clearTimeout(barTimer);barTimer=setTimeout(hideBar,5000);
    }
    var sbBtn=document.getElementById('sbUndo');
    if(sbBtn)sbBtn.onclick=function(){if(pending)pending();hideBar()};

    $$('.itemc').forEach(function(card){
      var steps=card.querySelectorAll('.stepb');

      /* 点卡片 → 物品详情（批次列表 / 开封 / 校正），编辑在详情页内 */
      card.addEventListener('click',function(e){
        if(e.target.closest('.stepb'))return;
        var badge=card.querySelector('.badge');
        var m=badge?badge.textContent.match(/(\d+)\s*天/):null;
        var meta=card.querySelector('.meta');
        var locEl=meta?meta.textContent.match(LIBLOCS):null;
        var p=new URLSearchParams({name:card.querySelector('b').textContent});
        if(m)p.set('days',m[1]);
        if(locEl)p.set('loc',locEl[0]);
        location.href='detail.html?'+p.toString();
      });

      /* − ：按有效到期日最早批次 −1（FIFO 口径），演示为卡片计数 −1 */
      steps[0].onclick=function(e){
        e.stopPropagation();
        var n=qtyNum(card);if(n<=0)return;
        setQty(card,n-1);
        var name=card.querySelector('b').textContent;
        showUndo('已记录 '+name+' −1 · 写入消耗流水',function(){setQty(card,n)});
      };

      /* ＋ ：快捷再入库 → 预填上次规格的轻量面板，确认后新建批次 */
      steps[1].onclick=function(e){e.stopPropagation();openIntake(card)};
    });

    /* -- 快捷再入库面板（需求 4.3 「＋」语义；单位口径见 4.6） -- */
    var qMask=document.getElementById('qMask'),qSheet=document.getElementById('qSheet');
    var qName=document.getElementById('qName'),qSpec=document.getElementById('qSpec'),
        qLoc=document.getElementById('qLoc'),qExp=document.getElementById('qExp'),qQty=document.getElementById('qQty');
    function closeQ(){if(!qSheet)return;qMask.classList.remove('on');qSheet.classList.remove('on')}
    /* 计量单位 chips：单选 + 自定义（默认沿用上次 = 从规格文本识别） */
    var qUnitVal='袋';
    var qChips=$$('#qUnitChips .chip'),qCustRow=document.getElementById('qUnitCustom'),qCustInput=document.getElementById('qUnitInput');
    qChips.forEach(function(c){
      c.onclick=function(e){
        e.stopPropagation();
        qChips.forEach(function(x){x.classList.remove('on')});
        c.classList.add('on');
        if(c.dataset.custom){qCustRow.classList.add('on');try{qCustInput.focus()}catch(_){}}
        else{qCustRow.classList.remove('on');qUnitVal=c.textContent.trim()}
      };
    });
    if(qCustInput)qCustInput.addEventListener('input',function(){qUnitVal=qCustInput.value.trim()||'个'});
    function syncUnitChips(){
      var um=(qSpec.value||'').match(/袋|盒|瓶|罐|包|片|粒|支|张|卷|ml|L|g|kg/);
      qUnitVal=um?um[0]:'袋';
      qChips.forEach(function(x){
        x.classList.toggle('on',!x.dataset.custom&&x.textContent.trim()===qUnitVal);
      });
      qCustRow.classList.remove('on');
    }
    if(qSheet){
      qMask.onclick=closeQ;
      document.getElementById('qCancel').onclick=closeQ;
      document.addEventListener('keydown',function(e){if(e.key==='Escape')closeQ()});
      $$('[data-qstep]').forEach(function(b){b.onclick=function(){
        qQty.value=Math.max(1,(parseInt(qQty.value)||1)+ +b.dataset.qstep)}});
    }
    function openIntake(card){
      if(!qSheet)return;
      var parts=(card.querySelector('.meta').textContent||'').split('·');
      var locEl=parts[0].match(LIBLOCS);
      qName.value=card.querySelector('b').textContent;
      qSpec.value=(parts[1]||'').trim();
      qLoc.value=locEl?locEl[0]:'';
      qExp.value='沿用上次到期日';
      qQty.value='1';
      syncUnitChips();
      qMask.classList.add('on');qSheet.classList.add('on');
    }
    var qOk=document.getElementById('qOk');
    if(qOk)qOk.onclick=function(){
      var add=Math.max(1,parseInt(qQty.value)||1);
      var name=(qName.value||'').trim()||'物品';
      var card=$$('.itemc').filter(function(c){return c.querySelector('b').textContent===name})[0];
      if(card)setQty(card,qtyNum(card)+add);
      closeQ();
      showToast('已按上次规格入库新批次：'+name+' +'+add+' '+qUnitVal+' 📦（旧批次独立保留，不合并）');
    };
  }

  /* ---- 添加/编辑物品 ---- */
  if(page==='add-item'){
    var addTitle=document.getElementById('addTitle');
    var addSaveBtn=document.getElementById('addSaveBtn');
    var addDeleteBtn=document.getElementById('addDeleteBtn');
    var nameInput=document.querySelector('#v-form .field .input input');
    var locGrids=$$('#v-form .opt-grid');
    var locGrid=locGrids[1];
    function setQty(v){qty=Math.max(1,Math.min(99,v));var n=document.getElementById('qtyNum');if(n)n.textContent=qty}
    var q=new URLSearchParams(location.search);
    if(q.get('mode')==='edit'){
      addTitle.textContent='编辑物品';addSaveBtn.textContent='保存修改';addDeleteBtn.style.display='flex';
      if(q.get('name'))nameInput.value=q.get('name');
      if(q.get('qty'))setQty(+q.get('qty')||1);
      if(q.get('days')){
        var d=new Date(Date.now()+(+q.get('days'))*864e5),p=function(n){return String(n).padStart(2,'0')};
        var ro=document.querySelector('#v-form input[readonly]');
        if(ro)ro.value=d.getFullYear()+'-'+p(d.getMonth()+1)+'-'+p(d.getDate());
      }
      var loc=q.get('loc');
      if(loc&&locGrid)$$('.oc',locGrid).forEach(function(o){
        var label=o.textContent.replace(/[^\u4e00-\u9fa5]/g,'');
        o.classList.toggle('act',!!label&&loc.indexOf(label)>-1);
      });
    }
    addSaveBtn.onclick=function(){
      var name=(nameInput.value||'').trim()||'未命名物品';
      if(q.get('mode')==='edit'){showToast('已保存修改 ✏️');setTimeout(function(){history.length>1?history.back():location.href='library.html'},650);}
      else if(['全麦吐司','鲜牛奶','维C泡腾片'].indexOf(name)>-1){
        /* 同名检查演示（需求 4.6.4）：选择挂作新批次或改名存为新物品 */
        openConfirm('检测到同名物品','库里已有「'+name+'」。点确认将作为它的新批次入库，沿用上次规格；想保存为独立新物品，请取消后修改名称。','作为新批次入库',function(){
          showToast('✔ 已并入「'+name+'」成为新批次 📦');
        },'取消，另存为新物品');
      }
      else showToast('✔ '+name+' 已加入库存');
    };
    if(addDeleteBtn)addDeleteBtn.onclick=function(){
      var name=(nameInput.value||'').trim()||'该物品';
      openConfirm('确认删除「'+name+'」？','将物理删除该物品及其全部批次与流水，删除前请想清楚。','删除',function(){
        showToast('已删除「'+name+'」🗑️');
        setTimeout(function(){history.length>1?history.back():location.href='library.html'},650);
      });
    };
  }

  /* ---- 分类管理：新建 / 编辑 / 保护性删除 ---- */
  var SOFT={accent:'--accent-soft',olive:'--olive-soft',teal:'--teal-soft',gold:'--gold-soft',rose:'--rose-soft',violet:'--violet-soft'};
  var catMask=document.getElementById('catMask'),catSheet=document.getElementById('catSheet');
  var catName=document.getElementById('catName');
  var catTitle=document.getElementById('catSheetTitle');
  var catSaveBtn=document.getElementById('catSave');
  var catDeleteBtn=document.getElementById('catDelete');
  var catEditingRow=null;
  function catSheetShow(edit){
    catTitle.textContent=edit?'编辑分类':'新建分类';
    catSaveBtn.textContent=edit?'保存修改':'创建分类';
    catDeleteBtn.style.display=edit?'flex':'none';
    catMask.classList.add('on');catSheet.classList.add('on');
  }
  function openCat(){
    catEditingRow=null;catName.value='';
    $$('#catEmojis span',catSheet).forEach(function(s,i){s.classList.toggle('act',i===0)});
    $$('#catColors i',catSheet).forEach(function(c,i){c.classList.toggle('act',i===0)});
    catSheetShow(false);
    setTimeout(function(){try{catName.focus()}catch(_){}},260);
  }
  function openCatEdit(row){
    catEditingRow=row;
    catName.value=row.querySelector('b').textContent;
    var emoji=row.querySelector('.ci').textContent.trim();
    $$('#catEmojis span',catSheet).forEach(function(s){s.classList.toggle('act',s.textContent===emoji)});
    var m=(row.querySelector('.ci').getAttribute('style')||'').match(/--(\w+)-soft/);
    var key=m?m[1]:'accent';
    $$('#catColors i',catSheet).forEach(function(c){c.classList.toggle('act',c.dataset.c===key)});
    catSheetShow(true);
  }
  function closeCat(){if(catMask)catMask.classList.remove('on');if(catSheet)catSheet.classList.remove('on');catEditingRow=null;}
  if(catSheet){
    catMask.onclick=closeCat;
    document.getElementById('catCancel').onclick=closeCat;
    $$('#catEmojis span',catSheet).forEach(function(s){s.onclick=function(){
      $$('#catEmojis span',catSheet).forEach(function(x){x.classList.remove('act')});s.classList.add('act');}});
    $$('#catColors i',catSheet).forEach(function(c){c.onclick=function(){
      $$('#catColors i',catSheet).forEach(function(x){x.classList.remove('act')});c.classList.add('act');}});
    catSaveBtn.onclick=function(){
      var name=(catName.value||'').trim().replace(/[<>]/g,'')||'新分类';
      var dup=$$('#v-cat .cat-row').some(function(r){return r!==catEditingRow&&r.querySelector('b').textContent===name});
      if(dup){showToast('已有同名分类，换一个名字吧 ✏️');return;}
      var emoji=$('#catEmojis span.act',catSheet).textContent;
      var ckey=$('#catColors i.act',catSheet).dataset.c;
      if(catEditingRow){
        catEditingRow.querySelector('b').textContent=name;
        var ci=catEditingRow.querySelector('.ci');
        ci.textContent=emoji;ci.style.background='var('+SOFT[ckey]+')';
        closeCat();showToast('已保存分类「'+name+'」✏️');return;
      }
      var row=document.createElement('div');
      row.className='cat-row';row.dataset.custom='1';
      row.style.animation='rise .5s cubic-bezier(.22,.9,.3,1) both';
      row.innerHTML='<div class="ci" style="background:var('+SOFT[ckey]+')">'+emoji+'</div><div><b>'+name+'</b><small>刚刚创建 · 0 件物品</small></div><div class="drag"><span class="count-pill">0</span><span>⠿</span></div>';
      document.querySelector('#v-cat .pad').insertBefore(row,document.querySelector('#v-cat button.btn.ghost'));
      var counter=document.getElementById('catCountVal');
      if(counter)counter.textContent=(+counter.textContent||0)+1;
      closeCat();
      showToast('已创建分类「'+name+'」🎉');
    };
    catDeleteBtn.onclick=function(){
      var row=catEditingRow;if(!row)return;
      var name=row.querySelector('b').textContent;
      closeCat();
      if(!row.dataset.custom){showToast('预置分类不可删除，仅自定义分类可删除 🛡️');return;}
      var n=+row.querySelector('.count-pill').textContent;
      if(n>0){showToast('「'+name+'」下还有 '+n+' 件物品，先移走再删除 🚫');return;}
      openConfirm('确认删除分类「'+name+'」？','删除后不可恢复（仅无关联物品的自定义分类可删）。','删除',function(){
        row.style.transition='.35s';row.style.opacity='0';row.style.transform='translateX(30px)';
        setTimeout(function(){row.remove()},360);
        var counter=document.getElementById('catCountVal');
        if(counter)counter.textContent=Math.max(0,(+counter.textContent||0)-1);
        showToast('已删除分类「'+name+'」🗑️');
      });
    };
  }

  /* ---- 存放位置：新建 / 编辑 / 停用 ---- */
  var locMask=document.getElementById('locMask'),locSheet=document.getElementById('locSheet');
  var locName=document.getElementById('locName');
  var locCustomWrap=document.getElementById('locCustomWrap');
  var locTitle=document.getElementById('locSheetTitle');
  var locSaveBtn=document.getElementById('locSave');
  var locDeleteBtn=document.getElementById('locDelete');
  var LOCSOFTS=['--accent-soft','--teal-soft','--rose-soft','--gold-soft','--violet-soft'];
  var locCap=10,locSoftIdx=0,locEditingCard=null,locEditRegion='厨房',locEditCustomLabel='';
  function setLocCap(v){locCap=Math.max(1,Math.min(99,v));var n=document.getElementById('locCapNum');if(n)n.textContent=locCap}
  function openLoc(){
    locEditingCard=null;
    locTitle.textContent='新增存放位置';locSaveBtn.textContent='创建位置';locDeleteBtn.style.display='none';
    locName.value='';setLocCap(10);
    $$('#locEmojis span',locSheet).forEach(function(s,i){s.classList.toggle('act',i===0)});
    $$('#locRegions .chip',locSheet).forEach(function(c,i){c.classList.toggle('act',i===0)});
    locCustomWrap.style.display='none';
    locMask.classList.add('on');locSheet.classList.add('on');
    setTimeout(function(){try{locName.focus()}catch(_){}},260);
  }
  function regionOf(card){
    var prev=card.previousElementSibling;
    while(prev&&!prev.classList.contains('room-h'))prev=prev.previousElementSibling;
    return prev?prev.textContent:'';
  }
  function openLocEdit(card){
    locEditingCard=card;
    locTitle.textContent='编辑位置';locSaveBtn.textContent='保存修改';locDeleteBtn.style.display='flex';
    locName.value=card.querySelector('b').textContent;
    var capTxt=(card.querySelector('small').textContent.match(/容量\s*(\d+)/)||[0,'10'])[1];
    setLocCap(+capTxt);
    var emoji=card.querySelector('.li').textContent.trim();
    $$('#locEmojis span',locSheet).forEach(function(s){s.classList.toggle('act',s.textContent===emoji)});
    var headTxt=regionOf(card),key='厨房',custom='';
    if(headTxt.indexOf('卫生间')>-1)key='卫生间';
    else if(headTxt.indexOf('居住')>-1)key='居住';
    else if(headTxt.indexOf('厨房')===-1){key='custom';custom=headTxt.replace(/区域$/,'').replace(/^[^\u4e00-\u9fa5]+/,'');}
    locEditRegion=key;locEditCustomLabel=custom;
    $$('#locRegions .chip',locSheet).forEach(function(c){c.classList.toggle('act',c.dataset.region===key)});
    locCustomWrap.style.display=key==='custom'?'':'none';
    document.getElementById('locRegionCustom').value=custom;
    locMask.classList.add('on');locSheet.classList.add('on');
  }
  function closeLoc(){if(locMask)locMask.classList.remove('on');if(locSheet)locSheet.classList.remove('on');locEditingCard=null;}
  if(locSheet){
    locMask.onclick=closeLoc;
    document.getElementById('locCancel').onclick=closeLoc;
    $$('#locEmojis span',locSheet).forEach(function(s){s.onclick=function(){
      $$('#locEmojis span',locSheet).forEach(function(x){x.classList.remove('act')});s.classList.add('act');}});
    $$('#locRegions .chip',locSheet).forEach(function(c){c.onclick=function(){
      $$('#locRegions .chip',locSheet).forEach(function(x){x.classList.remove('act')});c.classList.add('act');
      locCustomWrap.style.display=c.dataset.region==='custom'?'':'none';
    }});
    $$('[data-cstep]',locSheet).forEach(function(b){b.onclick=function(){setLocCap(locCap+ +b.dataset.cstep)}});
    function insertLocCard(card,region,customLabel){
      var pad=document.querySelector('#v-loc .pad');
      var ghostBtn=pad.querySelector('button.btn.ghost');
      if(region==='custom'){
        var label=customLabel||'新区域';
        var head=$$('#v-loc .room-h').filter(function(h){return h.textContent.replace(/^[^\u4e00-\u9fa5]+/,'').indexOf(label)>-1})[0];
        if(!head){
          head=document.createElement('div');
          head.className='room-h';head.style.animation='rise .5s cubic-bezier(.22,.9,.3,1) both';
          head.textContent='📦 '+label+'区域';
          pad.insertBefore(head,ghostBtn);
        }
        pad.insertBefore(card,ghostBtn);
      }else{
        var h2=$$('#v-loc .room-h').filter(function(h){return h.textContent.indexOf(region)>-1})[0];
        if(!h2){pad.insertBefore(card,ghostBtn);return;}
        var node=h2.nextElementSibling,last=h2;
        while(node&&!node.classList.contains('room-h')&&!node.classList.contains('btn')){
          if(node.classList.contains('loc-card'))last=node;
          node=node.nextElementSibling;
        }
        last.insertAdjacentElement('afterend',card);
      }
    }
    locSaveBtn.onclick=function(){
      var name=(locName.value||'').trim().replace(/[<>]/g,'')||'新位置';
      var emoji=$('#locEmojis span.act',locSheet).textContent;
      var actChip=$('#locRegions .chip.act',locSheet);
      var region=actChip.dataset.region;
      var customLabel=region==='custom'?((document.getElementById('locRegionCustom').value||'').trim().replace(/[<>]/g,'')||'新区域'):'';
      if(locEditingCard){
        locEditingCard.querySelector('b').textContent=name;
        locEditingCard.querySelector('.li').textContent=emoji;
        locEditingCard.querySelector('small').lastElementChild.textContent='容量 '+locCap;
        if(region!==locEditRegion||(region==='custom'&&customLabel!==locEditCustomLabel)){
          locEditingCard.remove();
          insertLocCard(locEditingCard,region,customLabel);
        }
        closeLoc();showToast('已保存位置「'+name+'」✏️');return;
      }
      var card=document.createElement('div');
      card.className='loc-card';
      card.style.animation='rise .5s cubic-bezier(.22,.9,.3,1) both';
      var soft=LOCSOFTS[locSoftIdx++%LOCSOFTS.length];
      card.innerHTML='<div class="li" style="background:var('+soft+')">'+emoji+'</div><div><b>'+name+'</b><div class="meter"><i style="width:0%"></i></div><small><span>刚刚创建 · 0 件物品</span><span>容量 '+locCap+'</span></small></div><div class="loc-right"><b>0<span style="font-size:10px;color:var(--ink-faint)"> 件</span></b></div>';
      insertLocCard(card,region,customLabel);
      var counter=document.getElementById('locCountVal');
      if(counter)counter.textContent=(+counter.textContent||0)+1;
      closeLoc();
      showToast('已创建位置「'+name+'」，去放点东西吧 📍');
    };
    locDeleteBtn.onclick=function(){
      var card=locEditingCard;if(!card)return;
      var name=card.querySelector('b').textContent;
      closeLoc();
      openConfirm('确认停用位置「'+name+'」？','按删除规则将停用该位置（IsActive=false），已有物品的历史位置记录保留。','停用',function(){
        card.style.transition='.35s';card.style.opacity='0';card.style.transform='translateX(30px)';
        setTimeout(function(){card.remove()},360);
        var counter=document.getElementById('locCountVal');
        if(counter)counter.textContent=Math.max(0,(+counter.textContent||0)-1);
        showToast('已停用位置「'+name+'」🗄️');
      });
    };
  }
})();
