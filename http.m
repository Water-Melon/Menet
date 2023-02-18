Json = Import('json');
Net = Import('net');
Sys = Import('sys');
Str = Import('str');
Mq = Import('mq');

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
        n = Sys.size(this.headers);
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

@HttpParseMeta(&meta) {
    parts = Str.slice(meta, " \t");
    if (Sys.size(parts) != 3)
        return false;
    fi

    resource = Str.slice(parts[1], '?');

    return [
        'method': parts[0],
        'uri': resource[0],
        'args': resource[1],
        'version': parts[2]
    ];
}

@HttpParse(&buf) {
    parts = Str.slice(buf, "\r\n");
    n = Sys.size(parts);
    if (n < 2)
        return nil;
    fi

    h = $Http;
    h.init();

    ret = HttpParseMeta(parts[0]);
    if (!ret) {
        return nil;
    } fi
    h.method = ret['method'];
    h.uri = ret['uri'];
    h.args = ret['args'];
    h.version = ret['version'];

    for (i = 1; i < n - 1; ++i) {
        kv = Str.slice(parts[i], ':');
        if (Sys.size(kv) < 2)
            if (i + 1 < n - 1)
                return false;
            else
                return nil;
        fi
        h.headers[kv[0]] = parts[i];
        if (kv[0] == 'Content-Length') {
            bodyLen = Sys.int(kv[1]);
        } fi
    }
    if (bodyLen) {
        if (Str.strlen(parts[n-1]) != bodyLen) {
            return nil;
        } else {
            h.body = parts[n-1];
        }
    } else {
        kv = Str.slice(parts[n-1], ':');
        if (Str.size(kv) < 2)
            return nil;
        fi
        h.headers[kv[0]] = parts[n-1];
        if (kv[0] == 'Content-Length')
            return nil;
        fi
    }

    return h;
}

@RequestProcessTunnel(op, json, &conf) {
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
    json = Json.decode(json);

    Mq.send('manager', Json.encode([
        'type': 'tunnel',
        'op': op,
        'from': conf['hash'],
        'data': [
            'name': json['name'],
            'dest': json['dest'],
        ],
    ]));

    resp = Mq.recv(conf['hash']);
    resp = Json.decode(resp);
    h.code = resp['code'];
    h.msg = resp['msg'];
    return h;
}

@RequestProcessService(op, json, &conf) {
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
    json = Json.decode(json);

    if (json['type'] == 'local') {
        type = 'localService';
    } else if (json['type'] == 'remote') {
        type = 'remoteService';
    } else {
        h.code = 400;
        h.msg = 'Bad Request';
        return h;
    }
    Mq.send('manager', Json.encode([
        'type': type,
        'op': op,
        'from': conf['hash'],
        'data': [
            'name': json['name'],
            'addr': json['addr'],
            'key': json['key'],
            'timeout': json['timeout'],
        ],
    ]));

    resp = Mq.recv(conf['hash']);
    resp = Json.decode(resp);
    h.code = resp['code'];
    h.msg = resp['msg'];
    return h;
}

@RequestProcessBind(op, json, &conf) {
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
    json = Json.decode(json);

    if (json['type'] == 'local') {
        type = 'bindLocal';
    } else if (json['type'] == 'remote') {
        type = 'bindRemote';
    } else {
        h.code = 400;
        h.msg = 'Bad Request';
        return h;
    }
    Mq.send('manager', Json.encode([
        'type': type,
        'op': op,
        'from': conf['hash'],
        'data': [
            'tunnel': json['tunnel'],
            'service': json['service'],
        ],
    ]));

    resp = Mq.recv(conf['hash']);
    resp = Json.decode(resp);
    h.code = resp['code'];
    h.msg = resp['msg'];
    return h;
}

@RequestProcessConfig(&conf) {
    h = $Http;
    h.version = 'HTTP/1.1';
    h.headers = [
        'Server: Menet',
    ];
    Mq.send('manager', Json.encode([
        'type': 'config',
        'op': op,
        'from': conf['hash'],
    ]));
    resp = Mq.recv(conf['hash']);
    resp = Json.decode(resp);
    h.code = resp['code'];
    h.msg = resp['msg'];
    h.body = Json.encode(resp['data']);
    h.headers['Content-Length'] = Str.strlen(h.body);
    h.headers['Content-Type'] = 'application/json';
    return h;
}

@RequestProcess(http, &conf) {
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
        Net.tcp_send(conf['fd'], h.response());
        return;
    }

    switch (http.uri) {
        case '/tunnel':
            h = RequestProcessTunnel(op, http.body, conf);
            break;
        case '/service':
            h = RequestProcessService(op, http.body, conf);
            break;
        case '/bind':
            h = RequestProcessBind(op, http.body, conf);
            break;
        case '/config':
            h = RequestProcessConfig(conf);
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
    Net.tcp_send(conf['fd'], h.response());
}

self = Json.decode(EVAL_DATA);
buf = '';
while (true) {
    ret = Net.tcp_recv(self['fd'], 3000);
    if (!ret || (Sys.is_bool(ret) && ret)) {
        Net.tcp_close(self['fd']);
        break;
    } fi
    buf += ret;
    ret = HttpParse(buf);
    if (Sys.is_nil(ret)) {
        continue;
    } else if (ret) {
        if (ret.uri != '/config' && !(ret.body))
            ret.uri = 'error';
        fi
        RequestProcess(ret, self);
        Net.tcp_close(self['fd']);
        break;
    } fi
}
