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

@requestProcessTunnel(json, &conf) {
}

@requestProcessListen(json, &conf) {
}

@requestProcessMsg(json, &conf) {
}

@requestProcessBind(json, &conf) {
}

@requestProcess(http, &conf) {
    switch (http.uri) {
        case '/tunnel':
            requestProcessTunnel(http.body, &conf);
            break;
        case '/listen':
            requestProcessListen(http.body, &conf);
            break;
        case '/msg':
            requestProcessMsg(http.body, &conf);
            break;
        case '/bind':
            requestProcessBind(http.body, &conf);
            break;
        default:
            h = $Http;
            h.version = 'HTTP/1.1';
            h.code = 400;
            h.msg = 'Bad Request';
            h.headers = [
                'Server: Metun',
            ];
            break;
    }
    _mln_tcp_send(conf['fd'], h.response());
}

self = mln_json_decode(EVAL_DATA);
buf = '';
while (true) {
    ret = mln_tcp_recv(self['fd'], 30000);
    if (!ret || (mln_is_bool(ret) && ret))
        goto out;
    fi
    buf += ret;
    ret = httpParse(buf);
    if (mln_is_nil(ret)) {
        continue;
    } else if (ret) {
        if (!(ret.body))
            ret.uri = 'error';
        fi
        requestProcess(ret, self);
    } fi

out:
    mln_tcp_close(self['fd']);
    break;
}
