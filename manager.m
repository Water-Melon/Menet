sys = import('sys');
mq = import('mq');
json = import('json');
md5 = import('md5');
net = import('net');

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
    if (_sys.has(_tunnels, name) && _tunnels[name]) {
        notExist = false;
        if (msg['op'] == 'remove')
            from = msg['from'];
        fi
        _mq.send(_tunnels[name]['hash'], _json.encode([
            'type': 'disconnect',
            'op': nil,
            'from': from,
        ]));
        _tunnels[name] = nil;
    } fi
    if (msg['op'] == 'update') {
        if (msg['data']['dest']) {
            hash = _md5.md5(name + _sys.time());
            _eval('tunnelc.m', _json.encode([
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
            _mq.send(msg['from'], _json.encode([
                'code': 200,
                'msg': 'OK',
            ]));
        }
    } else if (notExist) {
        _mq.send(msg['from'], _json.encode([
            'code': 200,
            'msg': 'OK',
        ]));
    } fi
}

@localServiceHandle(&msg) {
    name = msg['data']['name'];
    if (_sys.has(_localServices, name) && _localServices[name]) {
        _net.tcp_close(_localServices[name]['fd']);
        _localServices[name] = nil;
    } fi
    if (msg['op'] == 'update') {
        fd = _net.tcp_listen(msg['data']['addr'][0], msg['data']['addr'][1]);
        if (!fd && _sys.is_bool(fd)) {
            _mq.send(msg['from'], _json.encode([
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
    _mq.send(msg['from'], _json.encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@remoteServiceHandle(&msg) {
    name = msg['data']['name'];
    if (_sys.has(_remoteServices, name))
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
    _mq.send(msg['from'], _json.encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@bindLocalHandle(&msg) {
    t = msg['data']['tunnel'];
    s = msg['data']['service'];
    if (_sys.has(_localMap.serviceMap, s)) {
        _localMap.serviceMap = _sys.key_diff(_localMap.serviceMap, [s:nil]);
        _localMap.tunnelMap[t] = _sys.diff(_localMap.tunnelMap[t], [s]);
    } fi
    if (msg['op'] == 'update') {
        _localMap.serviceMap[s] = t;
        if (!(_localMap.tunnelMap[t])) {
            _localMap.tunnelMap[t] = [];
        } fi
        _localMap.tunnelMap[t][] = s;
    } fi
    _mq.send(msg['from'], _json.encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@bindRemoteHandle(&msg) {
    t = msg['data']['tunnel'];
    s = msg['data']['service'];
    if (_sys.has(_remoteMap.serviceMap, s)) {
        _remoteMap.serviceMap = _sys.key_diff(_remoteMap.serviceMap, [s:nil]);
        _remoteMap.tunnelMap[t] = _sys.diff(_remoteMap.tunnelMap[t], [s]);
    } fi
    if (msg['op'] == 'update') {
        _remoteMap.serviceMap[s] = t;
        if (!(_remoteMap.tunnelMap[t])) {
            _remoteMap.tunnelMap[t] = [];
        } fi
        _remoteMap.tunnelMap[t][] = s;
    } fi
    _mq.send(msg['from'], _json.encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@configHandle(&msg) {
    _mq.send(msg['from'], _json.encode([
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
    if (_sys.has(_tunnels, name) && _tunnels[name]) {
        _mq.send(_tunnels[name]['hash'], _json.encode([
            'type': 'disconnect',
            'op': nil,
            'from': nil,
        ]));
        _tunnels[name] = nil;
        _mq.send(msg['from'], _json.encode([
            'code': 400,
            'msg': 'Bad Request',
        ]));
        return;
    } fi
    _tunnels[name] = [
        'hash': msg['from'],
        'dest': msg['data']['dest'],
    ];
    _mq.send(msg['from'], _json.encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@tunnelDisconnectedHandle(&msg) {
    name = msg['data']['name'];
    if (_sys.has(_tunnels, name) && _tunnels[name]) {
        _tunnels[name] = nil;
    } fi
    _mq.send(msg['from'], _json.encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@getTunnelByLocalServiceName(serviceName) {
    if (!(_sys.has(_localMap.serviceMap, serviceName)))
        return nil;
    fi
    tname = _localMap.serviceMap[serviceName];
    if (!(_sys.has(_tunnels, tname)) || !(_tunnels[tname]))
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
            _mq.send(hash, _json.encode([
                'type': 'localConnection',
                'op': 'close',
            ]));
            return;
        } fi
        _connSet[hash] = true;
        _mq.send(t['hash'], _json.encode([
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
            _mq.send(t['hash'], _json.encode([
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
        _mq.send(hash, _json.encode([
            'type': 'localConnection',
            'op': op,
            'from': nil,
            'to': hash,
        ]));
    } else { /* op == 'openAckFail' */
        hash = msg['to'];
        if (_connSet[hash]) {
            _connSet[hash] = nil;
            _mq.send(hash, _json.encode([
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
        _mq.send(hash, _json.encode([
            'type': type,
            'op': 'close',
        ]));
    } fi
}

@getTunnelByRemoteServiceName(serviceName) {
    if (!(_sys.has(_remoteMap.serviceMap, serviceName))) {
        return nil;
    } fi
    tname = _remoteMap.serviceMap[serviceName];
    if (!(_sys.has(_tunnels, tname)) || !(_tunnels[tname])) {
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
            _mq.send(hash, _json.encode([
                'type': type,
                'op': 'close',
                'from': msg['from'],
                'to': hash,
            ]));
        } fi
    } else if (op == 'success') {
        hash = msg['to'];
        if (_connSet[hash]) {
            _mq.send(hash, _json.encode([
                'type': 'localConnection',
                'op': 'open',
                'from': msg['from'],
                'to': hash,
            ]));
        } else {
            t = _getTunnelByLocalServiceName(s);
            if (t) {
                _mq.send(t['hash'], _json.encode([
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
        if (!(_sys.has(_remoteServices, s)) || !(_remoteServices[s])) {
            t = _getTunnelByRemoteServiceName(s);
            if (t) {
                _mq.send(t['hash'], _json.encode([
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
            _eval('remoteService.m', _json.encode([
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
            _mq.send(hash, _json.encode([
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
            _mq.send(t['hash'], _json.encode([
                'type': 'connection',
                'op': 'success',
                'from': msg['from'],
                'to': msg['to'],
                'data': [
                    'name': s,
                ],
            ]));
            _mq.send(msg['from'], _json.encode([
                'type': 'remoteConnection',
                'op': 'success',
            ]));
        } else {
            _mq.send(msg['from'], _json.encode([
                'type': 'remoteConnection',
                'op': 'close',
                'data': [
                    'msg': 'tunnel not found',
                ],
            ]));
        }
    } else if (msg['op'] == 'fail') {
        if (t) {
            _mq.send(t['hash'], _json.encode([
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
            _mq.send(t['hash'], _json.encode([
                'type': 'connection',
                'op': 'close',
                'from': hash,
                'to': msg['to'],
                'data': [
                    'name': msg['data']['name'],
                ],
            ]));
        } fi
        _mq.send(hash, _json.encode([
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
            _mq.send(msg['from'], _json.encode([
                'type': type,
                'op': 'close',
            ]));
            return;
        } fi
        _mq.send(t['hash'], _json.encode(msg));
    } else {
        hash = msg['to'];
        if (_sys.has(_connSet, hash) && _connSet[hash]) {
            _mq.send(hash, _json.encode(msg));
        } else {
            t = _getTunnelByRemoteServiceName(msg['data']['name']);
            if (t) {
                _mq.send(t['hash'], _json.encode([
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
    msg = mq.recv('manager', 10000);
    if (msg) {
        msg = json.decode(msg);
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

    localServices = sys.diff(localServices, [nil]);
    remoteServices = sys.diff(remoteServices, [nil]);
    tunnels = sys.diff(tunnels, [nil]);
    connSet = sys.diff(connSet, [nil]);

    n = sys.size(localServices);
    for (i = 0; i < n; ++i) {
        s = localServices[i];
        if (!(sys.has(localMap.serviceMap, s['name'])) || !(sys.has(tunnels, localMap.serviceMap[s['name']])))
            continue;
        fi
        connfd = net.tcp_accept(s['fd'], 10);
        if (sys.is_bool(connfd) || sys.is_nil(connfd))
            continue;
        fi
        eval('localService.m', json.encode([
            'name': localServices[i]['name'],
            'fd': connfd,
            'key': localServices[i]['key'],
            'timeout': localServices[i]['timeout'],
        ]));
    }
}
