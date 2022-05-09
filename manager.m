Map {
    tunnelMap;
    serviceMap;
    @init() {
        this.tunnelMap = [];
        this.serviceMap = [];
    }
}

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
        if (msg['data']['dest']) {
            hash = _mln_md5(name + _mln_time());
            _mln_eval('tunnelc.m', _mln_json_encode([
                'from': msg['from'],
                'dest': msg['data']['dest'],
                'name': msg['data']['name'],
                'hash': hash,
            ]));
        } else {
            _tunnels[msg['data']['name']] = [
                'hash': msg['from'],
                'dest': msg['data']['dest'],
            ];
            _mln_msg_queue_send(msg['from'], _mln_json_encode([
                'code': 200,
                'msg': 'OK',
            ]));
        }
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
            'key': msg['data']['key'],
            'timeout': msg['data']['timeout'],
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
            'key': msg['data']['key'],
            'timeout': msg['data']['timeout'],
        ];
    } fi
    _mln_msg_queue_send(msg['from'], _mln_json_encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@bindLocalHandle(&msg) {
    t = msg['data']['tunnel'];
    s = msg['data']['service'];
    if (_mln_has(_localMap.serviceMap, s)) {
        _localMap.serviceMap = _mln_key_diff(_localMap.serviceMap, [s:nil]);
        _localMap.tunnelMap[t] = _mln_diff(_localMap.tunnelMap[t], [s]);
    } fi
    if (msg['op'] == 'update') {
        _localMap.serviceMap[s] = t;
        if (!(_localMap.tunnelMap[t])) {
            _localMap.tunnelMap[t] = [];
        } fi
        _localMap.tunnelMap[t][] = s;
    } fi
    _mln_msg_queue_send(msg['from'], _mln_json_encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@bindRemoteHandle(&msg) {
    t = msg['data']['tunnel'];
    s = msg['data']['service'];
    if (_mln_has(_remoteMap.serviceMap, s)) {
        _remoteMap.serviceMap = _mln_key_diff(_remoteMap.serviceMap, [s:nil]);
        _remoteMap.tunnelMap[t] = _mln_diff(_remoteMap.tunnelMap[t], [s]);
    } fi
    if (msg['op'] == 'update') {
        _remoteMap.serviceMap[s] = t;
        if (!(_remoteMap.tunnelMap[t])) {
            _remoteMap.tunnelMap[t] = [];
        } fi
        _remoteMap.tunnelMap[t][] = s;
    } fi
    _mln_msg_queue_send(msg['from'], _mln_json_encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@configHandle(&msg) {
    _mln_msg_queue_send(msg['from'], _mln_json_encode([
        'code': 200,
        'msg': 'OK',
        'data': [
            'tunnels': _tunnels,
            'services': [
                'local': _localServices,
                'remote': _remoteServices,
            ],
            'bind': [
                'local': _localMap.serviceMap,
                'remote': _remoteMap.serviceMap,
            ],
        ],
    ]));
}

@tunnelConnectedHandle(&msg) {
    name = msg['data']['name'];
    if (_mln_has(_tunnels, name) && _tunnels[name]) {
        _mln_msg_queue_send(_tunnels[name]['hash'], _mln_json_encode([
            'op': 'remove',
            'from': nil,
        ]));
        _tunnels[name] = nil;
        _mln_msg_queue_send(msg['from'], _mln_json_encode([
            'code': 400,
            'msg': 'Bad Request',
        ]));
        return;
    } fi
    _tunnels[name] = [
        'hash': msg['from'],
        'dest': msg['data']['dest'],
    ];
    _mln_msg_queue_send(msg['from'], _mln_json_encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@tunnelDisconnectedHandle(&msg) {
    name = msg['data']['name'];
    if (_mln_has(_tunnels, name) && _tunnels[name]) {
        _tunnels[name] = nil;
    } fi
    _mln_msg_queue_send(msg['from'], _mln_json_encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@connectionHandle(&msg) {
    hash = msg['from'];
    if (msg['op'] == 'update') {
        if (_connSet[hash]) {
            _mln_msg_queue_send(hash, _mln_json_encode([
                'code': 403,
                'msg': 'Forbidden',
            ]));
            return;
        } fi
        _connSet[hash] = true;
    } else {
        _connSet[hash] = nil;
    }
    _mln_msg_queue_send(hash, _mln_json_encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

tunnels = [];
localServices = [];
remoteServices = [];
localMap = $Map;
localMap.init();
remoteMap = $Map;
remoteMap.init();
connSet = [];

while (true) {
    msg = mln_msg_queue_recv('manager', 10000);
    if (msg) {
        msg = mln_json_decode(msg);
        switch (msg['type']) {
            case 'tunnel':
                tunnelHandle(msg);
                break;
            case 'tunnelConnected':
                tunnelConnectedHandle(msg);
                break;
            case 'tunnelDisconnected':
                tunnelDisconnectedHandle(msg);
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
            case 'config':
                configHandle(msg);
                break;
            case 'connection':
                connectionHandle(msg);
                break;
            default:
                break;
        }
    } fi

    localServices = mln_diff(localServices, [nil]);
    remoteServices = mln_diff(remoteServices, [nil]);
    tunnels = mln_diff(tunnels, [nil]);
    connSet = mln_diff(connSet, [nil]);

    n = mln_size(localServices);
    for (i = 0; i < n; ++i) {
        s = localServices[i];
        if (!(mln_has(localMap.serviceMap, s['name'])) || !(mln_has(tunnels, localMap.serviceMap[s['name']])))
            continue;
        fi
        connfd = mln_tcp_accept(s['fd'], 10);
        if (mln_is_bool(connfd) || mln_is_nil(connfd))
            continue;
        fi
        mln_eval('localService.m', mln_json_encode([
            'name': localServices[i]['name'],
            'fd': connfd,
            'key': localServices[i]['key'],
            'timeout': localServices[i]['timeout'],
        ]));
    }
}
