JSAN.use('Silki.URI');

if ( typeof Silki == "undefined" ) {
    Silki = {};
}

Silki.ProcessStatus = function () {
    var status = $("process-status");

    if ( ! status ) {
        return;
    }

    var matches = status.className.match( /js-process-id-(\d+)/ );
    if ( ! matches && matches[1] ) {
        return;
    }

    this._process_id = matches[1];
    this._uri = Silki.URI.dynamicURI( "/process/" + this._process_id );
    this._status = status;

    this._setupInterval();
};

Silki.ProcessStatus.prototype._setupInterval = function () {
    var self = this;
    var func = function () { self._getProcessStatus() };

    this._interval_id = setInterval( func, 1000 );
};

Silki.ProcessStatus.prototype._getProcessStatus = function () {
    var self = this;

    var on_success = function (trans) {
        self._updateStatus(trans);
    };

    var on_failure = function (trans) {
        self._handleFailure();
    };

    new HTTP.Request( {
        "uri":        this._uri,
        "method": "get",
        "onSuccess":  on_success,
        "onFailure":  on_failure,
    } );
};

Silki.ProcessStatus.prototype._updateStatus = function (trans) {
    var process = eval( "(" + trans.responseText + ")" );

    if ( process.is_complete ) {
        clearInterval( this._interval_id );

        if ( process.was_successful ) {
            this._status.innerHTML = "Export is complete.";
        }
        else {
            this._status.innerHTML = "Export failed.";
        }
    }
    else if ( process.status.length ) {
        this._status.innerHTML = "Export is in progress - " + process.status + ".";
    }
};

Silki.ProcessStatus.prototype._handleFailure = function (trans) {
    clearInterval( this._interval_id );

    this._status.innerHTML = "Cannot retrieve process status from server.";
};
