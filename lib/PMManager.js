// Generated by CoffeeScript 1.6.3
(function() {
  var bot, pmsToSend, queuePMs, sendPMInQueue, setBot;

  pmsToSend = [];

  bot = null;

  setBot = function(_bot) {
    return bot = _bot;
  };

  queuePMs = function(msgs, userid) {
    var msg, numInQueue, _i, _len;
    numInQueue = pmsToSend.length;
    for (_i = 0, _len = msgs.length; _i < _len; _i++) {
      msg = msgs[_i];
      pmsToSend.push({
        msg: msg,
        userid: userid
      });
    }
    if (numInQueue === 0) {
      return sendPMInQueue();
    }
  };

  sendPMInQueue = function() {
    var pmToSend;
    if (pmsToSend.length === 0) {
      return;
    }
    pmToSend = pmsToSend.shift();
    return setTimeout(function() {
      return bot.pm(pmToSend.msg, pmToSend.userid, sendPMInQueue);
    }, 50);
  };

  exports.queuePMs = queuePMs;

  exports.setBot = setBot;

}).call(this);
