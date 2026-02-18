/* Echoelmusic Shared JS — v10.0.0 */
(function(){
var burger=document.getElementById('burger');
var overlay=document.getElementById('menuOverlay');
if(!burger||!overlay)return;
function toggleMenu(){
var open=burger.classList.toggle('active');
overlay.classList.toggle('open');
burger.setAttribute('aria-expanded',open);
burger.setAttribute('aria-label',open?'Close menu':'Open menu');
document.body.style.overflow=open?'hidden':'';
}
burger.addEventListener('click',toggleMenu);
overlay.querySelectorAll('a').forEach(function(a){
a.addEventListener('click',function(){if(burger.classList.contains('active'))toggleMenu();});
});
document.addEventListener('keydown',function(e){
if(e.key==='Escape'&&burger.classList.contains('active'))toggleMenu();
if(e.key==='Tab'&&burger.classList.contains('active')){
var focusable=overlay.querySelectorAll('a[href],button,[tabindex]:not([tabindex="-1"])');
var first=focusable[0];var last=focusable[focusable.length-1];
if(e.shiftKey){if(document.activeElement===first||!overlay.contains(document.activeElement)){e.preventDefault();last.focus();}}
else{if(document.activeElement===last||!overlay.contains(document.activeElement)){e.preventDefault();first.focus();}}
}
});
/* SW: Register with updateViaCache:none — force network check for sw.js */
if('serviceWorker' in navigator){
navigator.serviceWorker.register('/sw.js',{updateViaCache:'none'}).then(function(reg){
reg.addEventListener('updatefound',function(){
var newWorker=reg.installing;
if(newWorker){newWorker.addEventListener('statechange',function(){
if(newWorker.state==='activated'){window.location.reload();}
});}
});
/* Check for SW update every 30s */
setInterval(function(){reg.update();},30000);
}).catch(function(e){console.warn('[SW]',e);});
/* Listen for SW_UPDATED message */
navigator.serviceWorker.addEventListener('message',function(e){
if(e.data&&e.data.type==='SW_UPDATED'){window.location.reload();}
});
}
/* Version check: nuke stale caches if server has v10 but page shows old content */
fetch('/version.json?t='+Date.now(),{cache:'no-store'}).then(function(r){return r.json();}).then(function(d){
if(d.version!=='10.0.0')return;
var h=document.querySelector('h1,title');
if(h&&h.textContent&&h.textContent.indexOf('12 tools')!==-1){
caches.keys().then(function(ks){return Promise.all(ks.map(function(k){return caches.delete(k);}));})
.then(function(){window.location.reload(true);});
}
}).catch(function(){});
})();
