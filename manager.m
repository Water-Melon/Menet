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
            'type': 'disconnect',
            'op': nil,
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
            'connections': _connSet,
        ],
    ]));
}

@tunnelConnectedHandle(&msg) {
    name = msg['data']['name'];
    if (_mln_has(_tunnels, name) && _tunnels[name]) {
        _mln_msg_queue_send(_tunnels[name]['hash'], _mln_json_encode([
            'type': 'disconnect',
            'op': nil,
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

@getTunnelByLocalServiceName(serviceName) {
    if (!(_mln_has(_localMap.serviceMap, serviceName)))
        return nil;
    fi
    tname = _localMap.serviceMap[serviceName];
    if (!(_mln_has(_tunnels, tname)) || !(_tunnels[tname]))
        return nil;
    fi
    return _tunnels[tname];
}

@localConnectionHandle(&msg) {
    op = msg['op'];
    if (op == 'open') {
        hash = msg['from'];
        t = _getTunnelByLocalServiceName(msg['data']['name']);
        if (!t || _connSet[hash]) {
            _mln_msg_queue_send(hash, _mln_json_encode([
                'type': 'localConnection',
                'op': 'close',
            ]));
            return;
        } fi
        _connSet[hash] = true;
        _mln_msg_queue_send(t['hash'], _mln_json_encode([
            'type': 'connection',
            'op': 'new',
            'from': hash,
            'data': [
                'name': msg['data']['name'],
            ],
        ]));
    } else if (op == 'close') {
        hash = msg['from'];
        _connSet[hash] = nil;
        t = _getTunnelByLocalServiceName(msg['data']['name']);
        if (t) {
            _mln_msg_queue_send(t['hash'], _mln_json_encode([
                'type': 'connection',
                'op': 'close',
                'from': hash,
                'to': msg['to'],
                'data': [
                    'name': msg['data']['name'],
                    'remote': true,
                ],
            ]));
        } fi
        _mln_msg_queue_send(hash, _mln_json_encode([
            'type': 'localConnection',
            'op': op,
            'from': nil,
            'to': hash,
        ]));
    } else { /* op == 'openAckFail' */
        hash = msg['to'];
        if (_connSet[hash]) {
            _connSet[hash] = nil;
            _mln_msg_queue_send(hash, _mln_json_encode([
                'type': 'localConnection',
                'op': 'close',
                'from': msg['from'],
                'to': hash,
            ]));
        } fi
    }
}

@serviceCloseHandle(&msg) {
    hash = msg['from'];
    if (msg['data']['type'] == 'local')
        type = 'localConnection';
    else
        type = 'remoteConnection';
    if (_connSet[hash]) {
        _connSet[hash] = nil;
        _mln_msg_queue_send(hash, _mln_json_encode([
            'type': type,
            'op': 'close',
        ]));
    } fi
}

@getTunnelByRemoteServiceName(serviceName) {
    if (!(_mln_has(_remoteMap.serviceMap, serviceName))) {
        return nil;
    } fi
    tname = _remoteMap.serviceMap[serviceName];
    if (!(_mln_has(_tunnels, tname)) || !(_tunnels[tname])) {
        return nil;
    } fi
    return _tunnels[tname];
}

@connectionNoticeHandle(&msg) {
    s = msg['data']['name'];
    op = msg['op'];
    if (op == 'fail') {
        hash = msg['to'];
        if (_connSet[hash]) {
            _connSet[hash] = nil;
            if (msg['data']['remote'])
                type = 'remoteConnection';
            else
                type = 'localConnection';
            _mln_msg_queue_send(hash, _mln_json_encode([
                'type': type,
                'op': 'close',
                'from': msg['from'],
                'to': hash,
            ]));
        } fi
    } else if (op == 'success') {
        hash = msg['to'];
        if (_connSet[hash]) {
            _mln_msg_queue_send(hash, _mln_json_encode([
                'type': 'localConnection',
                'op': 'open',
                'from': msg['from'],
                'to': hash,
            ]));
        } else {
            t = _getTunnelByLocalServiceName(s);
            if (t) {
                _mln_msg_queue_send(t['hash'], _mln_json_encode([
                    'type': 'connection',
                    'op': 'fail',
                    'from': nil,
                    'to': msg['from'],
                    'data': [
                        'name': s,
                        'remote': true,
                    ],
                ]));
            } fi
        }
    } else if (op == 'new') {
        if (!(_mln_has(_remoteServices, s)) || !(_remoteServices[s])) {
            t = _getTunnelByRemoteServiceName(s);
            if (t) {
                _mln_msg_queue_send(t['hash'], _mln_json_encode([
                    'type': 'connection',
                    'op': 'fail',
                    'from': msg['to'],
                    'to': msg['from'],
                    'data': [
                        'name': s,
                    ],
                ]));
            } fi
        } else {
            _mln_eval('remoteService.m', _mln_json_encode([
                'name': s,
                'key': _remoteServices[s]['key'],
                'timeout': _remoteServices[s]['timeout'],
                'from': msg['from'],
                'addr': _remoteServices[s]['addr'],
            ]));
        }
    } else { /* close */
        hash = msg['to'];
        if (_connSet[hash]) {
            _connSet[hash] = nil;
            if (msg['data']['remote'])
                type = 'remoteConnection';
            else
                type = 'localConnection';
            _mln_msg_queue_send(hash, _mln_json_encode([
                'type': type,
                'op': 'close',
                'from': msg['from'],
                'to': hash,
            ]));
        } fi
    }
}

@remoteConnectionHandle(&msg) {
    s = msg['data']['name'];
    t = _getTunnelByRemoteServiceName(s);
    if (msg['op'] == 'success') {
        if (t) {
            _connSet[msg['from']] = true;
            _mln_msg_queue_send(t['hash'], _mln_json_encode([
                'type': 'connection',
                'op': 'success',
                'from': msg['from'],
                'to': msg['to'],
                'data': [
                    'name': s,
                ],
            ]));
            _mln_msg_queue_send(msg['from'], _mln_json_encode([
                'type': 'remoteConnection',
                'op': 'success',
            ]));
        } else {
            _mln_msg_queue_send(msg['from'], _mln_json_encode([
                'type': 'remoteConnection',
                'op': 'close',
                'data': [
                    'msg': 'tunnel not found',
                ],
            ]));
        }
    } else if (msg['op'] == 'fail') {
        if (t) {
            _mln_msg_queue_send(t['hash'], _mln_json_encode([
                'type': 'connection',
                'op': 'fail',
                'from': msg['from'],
                'to': msg['to'],
                'data': [
                    'name': s,
                ],
            ]));
        } fi
    } else { /* msg['op'] == 'close' */
        hash = msg['from'];
        _connSet[hash] = nil;
        if (t) {
            _mln_msg_queue_send(t['hash'], _mln_json_encode([
                'type': 'connection',
                'op': 'close',
                'from': hash,
                'to': msg['to'],
                'data': [
                    'name': msg['data']['name'],
                ],
            ]));
        } fi
        _mln_msg_queue_send(hash, _mln_json_encode([
            'type': 'remoteConnection',
            'op': op,
            'from': nil,
            'to': hash,
        ]));
    }
}

@serviceIOHandle(&msg) {
    if (msg['op'] == 'input') {
        if (msg['data']['type'] == 'local') {
            t = _getTunnelByLocalServiceName(msg['data']['name']);
            type = 'localConnection';
        } else { /* remote */
            t = _getTunnelByRemoteServiceName(msg['data']['name']);
            type = 'remoteConnection';
        }
        if (!t) {
            _mln_msg_queue_send(msg['from'], _mln_json_encode([
                'type': type,
                'op': 'close',
            ]));
            return;
        } fi
        _mln_msg_queue_send(t['hash'], _mln_json_encode(msg));
    } else {
        hash = msg['to'];
        if (_mln_has(_connSet, hash) && _connSet[hash]) {
            _mln_msg_queue_send(hash, _mln_json_encode(msg));
        } else {
            t = _getTunnelByRemoteServiceName(msg['data']['name']);
            if (t) {
                _mln_msg_queue_send(t['hash'], _mln_json_encode([
                    'type': 'connection',
                    'op': 'close',
                    'from': hash,
                    'to': msg['from'],
                    'data': [
                        'name': msg['data']['name'],
                    ],
                ]));
            } fi
        }
    }
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
        type = msg['type'];
        switch (type) {
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
            case 'localConnection':
                localConnectionHandle(msg);
                break;
            case 'connectionNotice':
                connectionNoticeHandle(msg);
                break;
            case 'remoteConnection':
                remoteConnectionHandle(msg);
                break;
            case 'serviceIO':
                serviceIOHandle(msg);
                break;
            case 'serviceClose':
                serviceCloseHandle(msg);
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
