Http {
    method;
    uri;
    args;
    version;
    headers;
    body;
    code;
    msg;
    @init() {
        this.headers = [];
    }
    @response() {
        ret = '' + this.version + ' ' + this.code + ' ' + this.msg + "\r\n";
        n = _mln_size(this.headers);
        for (i = 0; i < n; ++i) {
            ret += (this.headers[i] + "\r\n");
        }
        ret += "\r\n";
        if (this.body) {
            ret += (this.body + "\r\n");
        } fi
        return ret;
    }
}

@httpParseMeta(&meta) {
    parts = _mln_slice(meta, " \t");
    if (_mln_size(parts) != 3)
        return false;
    fi

    resource = _mln_slice(parts[1], '?');

    return [
        'method': parts[0],
        'uri': resource[0],
        'args': resource[1],
        'version': parts[2]
    ];
}

@httpParse(&buf) {
    parts = _mln_slice(buf, "\r\n");
    n = _mln_size(parts);
    if (n < 2)
        return nil;
    fi

    h = $Http;
    h.init();

    ret = _httpParseMeta(parts[0]);
    if (!ret) {
        return nil;
    } fi
    h.method = ret['method'];
    h.uri = ret['uri'];
    h.args = ret['args'];
    h.version = ret['version'];

    for (i = 1; i < n - 1; ++i) {
        kv = _mln_slice(parts[i], ':');
        if (_mln_size(kv) < 2)
            if (i + 1 < n - 1)
                return false;
            else
                return nil;
        fi
        h.headers[kv[0]] = parts[i];
        if (kv[0] == 'Content-Length') {
            bodyLen = _mln_int(kv[1]);
        } fi
    }
    if (bodyLen) {
        if (_mln_strlen(parts[n-1]) != bodyLen) {
            return nil;
        } else {
            h.body = parts[n-1];
        }
    } else {
        kv = _mln_slice(parts[n-1], ':');
        if (_mln_size(kv) < 2)
            return nil;
        fi
        h.headers[kv[0]] = parts[n-1];
        if (kv[0] == 'Content-Length')
            return nil;
        fi
    }

    return h;
}

@requestProcessTunnel(op, json, &conf) {
    /*
     * {
     *   "name": "tunnel name",
     *   "dest": ['ip', 'port']
     * }
     */
    h = $Http;
    h.version = 'HTTP/1.1';
    h.headers = [
        'Server: Menet',
    ];
    json = _mln_json_decode(json);

    _mln_msg_queue_send('manager', _mln_json_encode([
        'type': 'tunnel',
        'op': op,
        'from': conf['hash'],
        'data': [
            'name': json['name'],
            'dest': json['dest'],
        ],
    ]));

    resp = _mln_msg_queue_recv(conf['hash']);
    resp = _mln_json_decode(resp);
    h.code = resp['code'];
    h.msg = resp['msg'];
    return h;
}

@requestProcessService(op, json, &conf) {
    /*
     * {
     *     "name": "service name",
     *     "key": "rc4 key",
     *     "timeout": 1000,
     *     "type": "local|remote",
     *     "addr": ["ip", "port"]
     * }
     */
    h = $Http;
    h.version = 'HTTP/1.1';
    h.headers = [
        'Server: Menet',
    ];
    json = _mln_json_decode(json);

    if (json['type'] == 'local') {
        type = 'localService';
    } else if (json['type'] == 'remote') {
        type = 'remoteService';
    } else {
        h.code = 400;
        h.msg = 'Bad Request';
        return h;
    }
    _mln_msg_queue_send('manager', _mln_json_encode([
        'type': type,
        'op': op,
        'from': conf['hash'],
        'data': [
            'name': json['name'],
            'addr': json['addr'],
        ],
    ]));

    resp = _mln_msg_queue_recv(conf['hash']);
    resp = _mln_json_decode(resp);
    h.code = resp['code'];
    h.msg = resp['msg'];
    return h;
}

@requestProcessBind(op, json, &conf) {
    /*
     * {
     *     "tunnel": "tunnel name",
     *     "service": "service name",
     *     "type": "local|remote"
     * }
     */
    h = $Http;
    h.version = 'HTTP/1.1';
    h.headers = [
        'Server: Menet',
    ];
    json = _mln_json_decode(json);

    if (json['type'] == 'local') {
        type = 'bindLocal';
    } else if (json['type'] == 'remote') {
        type = 'bindRemote';
    } else {
        h.code = 400;
        h.msg = 'Bad Request';
        return h;
    }
    _mln_msg_queue_send('manager', _mln_json_encode([
        'type': type,
        'op': op,
        'from': conf['hash'],
        'data': [
            'tunnel': json['tunnel'],
            'service': json['service'],
        ],
    ]));

    resp = _mln_msg_queue_recv(conf['hash']);
    resp = _mln_json_decode(resp);
    h.code = resp['code'];
    h.msg = resp['msg'];
    return h;
}

@requestProcessConfig(&conf) {
    h = $Http;
    h.version = 'HTTP/1.1';
    h.headers = [
        'Server: Menet',
    ];
    _mln_msg_queue_send('manager', _mln_json_encode([
        'type': 'config',
        'op': op,
        'from': conf['hash'],
    ]));
    resp = _mln_msg_queue_recv(conf['hash']);
    resp = _mln_json_decode(resp);
    h.code = resp['code'];
    h.msg = resp['msg'];
    h.body = _mln_json_encode(resp['data']);
    h.headers['Content-Length'] = _mln_strlen(h.body);
    h.headers['Content-Type'] = 'application/json';
    return h;
}

@requestProcess(http, &conf) {
    if (http.method == 'POST')
        op = 'update';
    else if (http.method == 'DELETE')
        op = 'remove';
    else if (http.method == 'GET' && http.uri == '/config')
        op = 'get';
    else {
        h = $Http;
        h.version = 'HTTP/1.1';
        h.code = 400;
        h.msg = 'Bad Request';
        h.headers = [
            'Server: Menet',
        ];
        _mln_tcp_send(conf['fd'], h.response());
        return;
    }

    switch (http.uri) {
        case '/tunnel':
            h = _requestProcessTunnel(op, http.body, conf);
            break;
        case '/service':
            h = _requestProcessService(op, http.body, conf);
            break;
        case '/bind':
            h = _requestProcessBind(op, http.body, conf);
            break;
        case '/config':
            h = _requestProcessConfig(conf);
            break;
        default:
            h = $Http;
            h.version = 'HTTP/1.1';
            h.code = 400;
            h.msg = 'Bad Request';
            h.headers = [
                'Server: Menet',
            ];
            break;
    }
    _mln_tcp_send(conf['fd'], h.response());
}

self = mln_json_decode(EVAL_DATA);
buf = '';
while (true) {
    ret = mln_tcp_recv(self['fd'], 3000);
    if (!ret || (mln_is_bool(ret) && ret)) {
        mln_tcp_close(self['fd']);
        break;
    } fi
    buf += ret;
    ret = httpParse(buf);
    if (mln_is_nil(ret)) {
        continue;
    } else if (ret) {
        if (ret.uri != '/config' && !(ret.body))
            ret.uri = 'error';
        fi
        requestProcess(ret, self);
        mln_tcp_close(self['fd']);
        break;
    } fi
}
