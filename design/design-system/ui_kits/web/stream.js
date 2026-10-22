// Fake token streamer for the click-through kits.
window.fakeStream = function (text, onChunk, onDone, speed) {
  var words = text.split(/(\s+)/), i = 0;
  var t = setInterval(function () { i += 2; onChunk(words.slice(0, i).join("")); if (i >= words.length) { clearInterval(t); onDone && onDone(); } }, speed || 45);
  return function () { clearInterval(t); onDone && onDone(); };
};
