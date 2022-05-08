@tunnelHandle(&msg) {
    name = msg['data']['name'];
    notExist = true;
    if (_mln_has(_tunnels, name) && _tunnels[name]) {
        notExist = false;
        if (msg['op'] == 'remove')
            from = msg['from'];
        fi
        _mln_msg_queue_send(_tunnels[name]['hash'], _mln_json_encode([
            'op': 'remove',
            'from': from,
        ]));
        _tunnels[name] = nil;
    } fi
    if (msg['op'] == 'update') {
        hash = _mln_md5(name + _mln_time());
        _mln_eval('tunnelc.m', _mln_json_encode([
            'from': msg['from'],
            'dest': msg['data']['dest'],
            'name': msg['data']['name'],
            'hash': hash,
        ]));
    } else if (notExist) {
        _mln_msg_queue_send(msg['from'], _mln_json_encode([
            'code': 200,
            'msg': 'OK',
        ]));
    } fi
}

@localServiceHandle(&msg) {
    name = msg['data']['name'];
    if (_mln_has(_localServices, name) && _localServices[name]) {
        _mln_tcp_close(_localServices[name]['fd']);
        _localServices[name] = nil;
    } fi
    if (msg['op'] == 'update') {
        fd = _mln_tcp_listen(msg['data']['addr'][0], msg['data']['addr'][1]);
        if (!fd && _mln_is_bool(fd)) {
            _mln_msg_queue_send(msg['from'], _mln_json_encode([
                'code': 500,
                'msg': 'Internal Server Error',
            ]));
            return;
        } fi
        _localServices[name] = [
            'name': name,
            'addr': msg['data']['addr'],
            'fd': fd,
        ];
    } fi
    _mln_msg_queue_send(msg['from'], _mln_json_encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@remoteServiceHandle(&msg) {
    name = msg['data']['name'];
    if (_mln_has(_remoteServices, name))
        _remoteServices[name] = nil;
    fi
    if (msg['op'] == 'update') {
        _remoteServices[name] = [
            'name': name,
            'addr': msg['data']['addr'],
        ];
    } fi
    _mln_msg_queue_send(msg['from'], _mln_json_encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@bindLocalHandle(&msg) {
    //TODO
}

@bindRemoteHandle(&msg) {
    //TODO
}

tunnels = [];
localServices = [];
remoteServices = [];

while (true) {
    msg = mln_msg_queue_recv('manager', 10000);
    if (msg) {
        msg = mln_json_decode(msg);
        switch (msg['type']) {
            case 'tunnel':
                tunnelHandle(msg);
                break;
            case 'tunnelConnected':
                tunnels[msg['data']['name']] = [
                    'hash': msg['from'],
                    'dest': msg['data']['dest'],
                ];
                break;
            case 'localService':
                localServiceHandle(msg);
                break;
            case 'remoteService':
                remoteServiceHandle(msg);
                break;
            case 'bindLocal':
                bindLocalHandle(msg);
                break;
            case 'bindRemote':
                bindRemoteHandle(msg);
                break;
            default:
                break;
        }
    } fi

    localServices = mln_diff(localServices, [nil]);
    n = mln_size(localServices);
    for (i = 0; i < n; ++i) {
        s = localServices[i];
        if (!s) //TODO or tunnel-service bounding not existent
            continue;
        fi
        connfd = mln_tcp_accept(s['fd'], 10);
        //TODO process all local port tcp connection
    }
}
