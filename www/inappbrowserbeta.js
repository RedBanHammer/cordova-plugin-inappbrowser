/*
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 *
*/

var exec = require('cordova/exec');
var channel = require('cordova/channel');
var modulemapper = require('cordova/modulemapper');
var urlutil = require('cordova/urlutil');

function InAppBrowserBeta() {
   this.channels = {
        'loadstart': channel.create('loadstart'),
        'loadstop' : channel.create('loadstop'),
        'loaderror' : channel.create('loaderror'),
        'loadedStatus' : channel.create('loadedStatus'),
        'notifyStatus' : channel.create('notifyStatus'),
        'exit' : channel.create('exit'),
        'toolbarItemTapped' : channel.create('toolbarItemTapped')
   };
}

InAppBrowserBeta.prototype = {
    _eventHandler: function (event) {
        if (event.type in this.channels) {
            this.channels[event.type].fire(event);
        }
    },
    close: function (eventname) {
        exec(null, null, "InAppBrowserBeta", "close", []);
    },
    show: function (eventname) {
        exec(null, null, "InAppBrowserBeta", "show", []);
    },
    hide: function (eventname) {
        exec(null, null, "InAppBrowserBeta", "hide", []);
    },
    loadedStatus: function (eventname) {
        exec(null, null, "InAppBrowserBeta", "loadedStatus", []);
    },
    notifyStatus: function (eventname) {
        exec(null, null, "InAppBrowserBeta", "notifyStatus", []);
    },
    addEventListener: function (eventname,f) {
        if (eventname in this.channels) {
            this.channels[eventname].subscribe(f);
        }
    },
    removeEventListener: function(eventname, f) {
        if (eventname in this.channels) {
            this.channels[eventname].unsubscribe(f);
        }
    },

    executeScript: function(injectDetails, cb) {
        if (injectDetails.code) {
            exec(cb, null, "InAppBrowserBeta", "injectScriptCode", [injectDetails.code, !!cb]);
        } else if (injectDetails.file) {
            exec(cb, null, "InAppBrowserBeta", "injectScriptFile", [injectDetails.file, !!cb]);
        } else {
            throw new Error('executeScript requires exactly one of code or file to be specified (beta)');
        }
    },

    insertCSS: function(injectDetails, cb) {
        if (injectDetails.code) {
            exec(cb, null, "InAppBrowserBeta", "injectStyleCode", [injectDetails.code, !!cb]);
        } else if (injectDetails.file) {
            exec(cb, null, "InAppBrowserBeta", "injectStyleFile", [injectDetails.file, !!cb]);
        } else {
            throw new Error('insertCSS requires exactly one of code or file to be specified (beta)');
        }
    }
};

module.exports = function(strUrl, strWindowName, strWindowFeatures) {
    // Don't catch calls that write to existing frames (e.g. named iframes).
    if (window.frames && window.frames[strWindowName]) {
        var origOpenFunc = modulemapper.getOriginalSymbol(window, 'open');
        return origOpenFunc.apply(window, arguments);
    }

    strUrl = urlutil.makeAbsolute(strUrl);
    var iab = new InAppBrowserBeta();
    var cb = function(eventname) {
       iab._eventHandler(eventname);
    };

    strWindowFeatures = strWindowFeatures || "";

    exec(cb, cb, "InAppBrowserBeta", "open", [strUrl, strWindowName, strWindowFeatures]);
    return iab;
};

