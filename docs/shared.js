/* Echoelmusic Shared JS — v8.0.0 */
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
if('serviceWorker' in navigator){navigator.serviceWorker.register('/sw.js').catch(function(e){console.warn('[SW]',e);});}
})();
