Sys = Import('sys');
Mq = Import('mq');
Json = Import('json');
Md5 = Import('md5');
Net = Import('net');

Map {
    tunnelMap;
    serviceMap;
    @init() {
        this.tunnelMap = [];
        this.serviceMap = [];
    }
}

@TunnelHandle(&msg) {
    name = msg['data']['name'];
    notExist = true;
    if (Sys.has(Tunnels, name) && Tunnels[name]) {
        notExist = false;
        if (msg['op'] == 'remove')
            from = msg['from'];
        fi
        Mq.send(Tunnels[name]['hash'], Json.encode([
            'type': 'disconnect',
            'op': nil,
            'from': from,
        ]));
        Tunnels[name] = nil;
    } fi
    if (msg['op'] == 'update') {
        if (msg['data']['dest']) {
            hash = Md5.md5(name + Sys.time());
            Eval('tunnelc.m', Json.encode([
                'from': msg['from'],
                'dest': msg['data']['dest'],
                'name': msg['data']['name'],
                'hash': hash,
            ]));
        } else {
            Tunnels[msg['data']['name']] = [
                'hash': msg['from'],
                'dest': msg['data']['dest'],
            ];
            Mq.send(msg['from'], Json.encode([
                'code': 200,
                'msg': 'OK',
            ]));
        }
    } else if (notExist) {
        Mq.send(msg['from'], Json.encode([
            'code': 200,
            'msg': 'OK',
        ]));
    } fi
}

@LocalServiceHandle(&msg) {
    name = msg['data']['name'];
    if (Sys.has(LocalServices, name) && LocalServices[name]) {
        Net.tcp_close(LocalServices[name]['fd']);
        LocalServices[name] = nil;
    } fi
    if (msg['op'] == 'update') {
        fd = Net.tcp_listen(msg['data']['addr'][0], msg['data']['addr'][1]);
        if (!fd && Sys.is_bool(fd)) {
            Mq.send(msg['from'], Json.encode([
                'code': 500,
                'msg': 'Internal Server Error',
            ]));
            return;
        } fi
        LocalServices[name] = [
            'name': name,
            'addr': msg['data']['addr'],
            'fd': fd,
            'key': msg['data']['key'],
            'timeout': msg['data']['timeout'],
        ];
    } fi
    Mq.send(msg['from'], Json.encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@RemoteServiceHandle(&msg) {
    name = msg['data']['name'];
    if (Sys.has(RemoteServices, name))
        RemoteServices[name] = nil;
    fi
    if (msg['op'] == 'update') {
        RemoteServices[name] = [
            'name': name,
            'addr': msg['data']['addr'],
            'key': msg['data']['key'],
            'timeout': msg['data']['timeout'],
        ];
    } fi
    Mq.send(msg['from'], Json.encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@BindLocalHandle(&msg) {
    t = msg['data']['tunnel'];
    s = msg['data']['service'];
    if (Sys.has(LocalMap.serviceMap, s)) {
        LocalMap.serviceMap = Sys.key_diff(LocalMap.serviceMap, [s:nil]);
        LocalMap.tunnelMap[t] = Sys.diff(LocalMap.tunnelMap[t], [s]);
    } fi
    if (msg['op'] == 'update') {
        LocalMap.serviceMap[s] = t;
        if (!(LocalMap.tunnelMap[t])) {
            LocalMap.tunnelMap[t] = [];
        } fi
        LocalMap.tunnelMap[t][] = s;
    } fi
    Mq.send(msg['from'], Json.encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@BindRemoteHandle(&msg) {
    t = msg['data']['tunnel'];
    s = msg['data']['service'];
    if (Sys.has(RemoteMap.serviceMap, s)) {
        RemoteMap.serviceMap = Sys.key_diff(RemoteMap.serviceMap, [s:nil]);
        RemoteMap.tunnelMap[t] = Sys.diff(RemoteMap.tunnelMap[t], [s]);
    } fi
    if (msg['op'] == 'update') {
        RemoteMap.serviceMap[s] = t;
        if (!(RemoteMap.tunnelMap[t])) {
            RemoteMap.tunnelMap[t] = [];
        } fi
        RemoteMap.tunnelMap[t][] = s;
    } fi
    Mq.send(msg['from'], Json.encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@ConfigHandle(&msg) {
    Mq.send(msg['from'], Json.encode([
        'code': 200,
        'msg': 'OK',
        'data': [
            'tunnels': Tunnels,
            'services': [
                'local': LocalServices,
                'remote': RemoteServices,
            ],
            'bind': [
                'local': LocalMap.serviceMap,
                'remote': RemoteMap.serviceMap,
            ],
            'connections': ConnSet,
        ],
    ]));
}

@TunnelConnectedHandle(&msg) {
    name = msg['data']['name'];
    if (Sys.has(Tunnels, name) && Tunnels[name]) {
        Mq.send(Tunnels[name]['hash'], Json.encode([
            'type': 'disconnect',
            'op': nil,
            'from': nil,
        ]));
        Tunnels[name] = nil;
        Mq.send(msg['from'], Json.encode([
            'code': 400,
            'msg': 'Bad Request',
        ]));
        return;
    } fi
    Tunnels[name] = [
        'hash': msg['from'],
        'dest': msg['data']['dest'],
    ];
    Mq.send(msg['from'], Json.encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@TunnelDisconnectedHandle(&msg) {
    name = msg['data']['name'];
    if (Sys.has(Tunnels, name) && Tunnels[name]) {
        Tunnels[name] = nil;
    } fi
    Mq.send(msg['from'], Json.encode([
        'code': 200,
        'msg': 'OK',
    ]));
}

@GetTunnelByLocalServiceName(serviceName) {
    if (!(Sys.has(LocalMap.serviceMap, serviceName)))
        return nil;
    fi
    tname = LocalMap.serviceMap[serviceName];
    if (!(Sys.has(Tunnels, tname)) || !(Tunnels[tname]))
        return nil;
    fi
    return Tunnels[tname];
}

@LocalConnectionHandle(&msg) {
    op = msg['op'];
    if (op == 'open') {
        hash = msg['from'];
        t = GetTunnelByLocalServiceName(msg['data']['name']);
        if (!t || ConnSet[hash]) {
            Mq.send(hash, Json.encode([
                'type': 'localConnection',
                'op': 'close',
            ]));
            return;
        } fi
        ConnSet[hash] = true;
        Mq.send(t['hash'], Json.encode([
            'type': 'connection',
            'op': 'new',
            'from': hash,
            'data': [
                'name': msg['data']['name'],
            ],
        ]));
    } else if (op == 'close') {
        hash = msg['from'];
        ConnSet[hash] = nil;
        t = GetTunnelByLocalServiceName(msg['data']['name']);
        if (t) {
            Mq.send(t['hash'], Json.encode([
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
        Mq.send(hash, Json.encode([
            'type': 'localConnection',
            'op': op,
            'from': nil,
            'to': hash,
        ]));
    } else { /* op == 'openAckFail' */
        hash = msg['to'];
        if (ConnSet[hash]) {
            ConnSet[hash] = nil;
            Mq.send(hash, Json.encode([
                'type': 'localConnection',
                'op': 'close',
                'from': msg['from'],
                'to': hash,
            ]));
        } fi
    }
}

@ServiceCloseHandle(&msg) {
    hash = msg['from'];
    if (msg['data']['type'] == 'local')
        type = 'localConnection';
    else
        type = 'remoteConnection';
    if (ConnSet[hash]) {
        ConnSet[hash] = nil;
        Mq.send(hash, Json.encode([
            'type': type,
            'op': 'close',
        ]));
    } fi
}

@GetTunnelByRemoteServiceName(serviceName) {
    if (!(Sys.has(RemoteMap.serviceMap, serviceName))) {
        return nil;
    } fi
    tname = RemoteMap.serviceMap[serviceName];
    if (!(Sys.has(Tunnels, tname)) || !(Tunnels[tname])) {
        return nil;
    } fi
    return Tunnels[tname];
}

@ConnectionNoticeHandle(&msg) {
    s = msg['data']['name'];
    op = msg['op'];
    if (op == 'fail') {
        hash = msg['to'];
        if (ConnSet[hash]) {
            ConnSet[hash] = nil;
            if (msg['data']['remote'])
                type = 'remoteConnection';
            else
                type = 'localConnection';
            Mq.send(hash, Json.encode([
                'type': type,
                'op': 'close',
                'from': msg['from'],
                'to': hash,
            ]));
        } fi
    } else if (op == 'success') {
        hash = msg['to'];
        if (ConnSet[hash]) {
            Mq.send(hash, Json.encode([
                'type': 'localConnection',
                'op': 'open',
                'from': msg['from'],
                'to': hash,
            ]));
        } else {
            t = GetTunnelByLocalServiceName(s);
            if (t) {
                Mq.send(t['hash'], Json.encode([
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
        if (!(Sys.has(RemoteServices, s)) || !(RemoteServices[s])) {
            t = GetTunnelByRemoteServiceName(s);
            if (t) {
                Mq.send(t['hash'], Json.encode([
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
            Eval('remoteService.m', Json.encode([
                'name': s,
                'key': RemoteServices[s]['key'],
                'timeout': RemoteServices[s]['timeout'],
                'from': msg['from'],
                'addr': RemoteServices[s]['addr'],
            ]));
        }
    } else { /* close */
        hash = msg['to'];
        if (ConnSet[hash]) {
            ConnSet[hash] = nil;
            if (msg['data']['remote'])
                type = 'remoteConnection';
            else
                type = 'localConnection';
            Mq.send(hash, Json.encode([
                'type': type,
                'op': 'close',
                'from': msg['from'],
                'to': hash,
            ]));
        } fi
    }
}

@RemoteConnectionHandle(&msg) {
    s = msg['data']['name'];
    t = GetTunnelByRemoteServiceName(s);
    if (msg['op'] == 'success') {
        if (t) {
            ConnSet[msg['from']] = true;
            Mq.send(t['hash'], Json.encode([
                'type': 'connection',
                'op': 'success',
                'from': msg['from'],
                'to': msg['to'],
                'data': [
                    'name': s,
                ],
            ]));
            Mq.send(msg['from'], Json.encode([
                'type': 'remoteConnection',
                'op': 'success',
            ]));
        } else {
            Mq.send(msg['from'], Json.encode([
                'type': 'remoteConnection',
                'op': 'close',
                'data': [
                    'msg': 'tunnel not found',
                ],
            ]));
        }
    } else if (msg['op'] == 'fail') {
        if (t) {
            Mq.send(t['hash'], Json.encode([
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
        ConnSet[hash] = nil;
        if (t) {
            Mq.send(t['hash'], Json.encode([
                'type': 'connection',
                'op': 'close',
                'from': hash,
                'to': msg['to'],
                'data': [
                    'name': msg['data']['name'],
                ],
            ]));
        } fi
        Mq.send(hash, Json.encode([
            'type': 'remoteConnection',
            'op': op,
            'from': nil,
            'to': hash,
        ]));
    }
}

@ServiceIOHandle(&msg) {
    if (msg['op'] == 'input') {
        if (msg['data']['type'] == 'local') {
            t = GetTunnelByLocalServiceName(msg['data']['name']);
            type = 'localConnection';
        } else { /* remote */
            t = GetTunnelByRemoteServiceName(msg['data']['name']);
            type = 'remoteConnection';
        }
        if (!t) {
            Mq.send(msg['from'], Json.encode([
                'type': type,
                'op': 'close',
            ]));
            return;
        } fi
        Mq.send(t['hash'], Json.encode(msg));
    } else {
        hash = msg['to'];
        if (Sys.has(ConnSet, hash) && ConnSet[hash]) {
            Mq.send(hash, Json.encode(msg));
        } else {
            t = GetTunnelByRemoteServiceName(msg['data']['name']);
            if (t) {
                Mq.send(t['hash'], Json.encode([
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

Tunnels = [];
LocalServices = [];
RemoteServices = [];
LocalMap = $Map;
LocalMap.init();
RemoteMap = $Map;
RemoteMap.init();
ConnSet = [];

while (true) {
    msg = Mq.recv('manager', 10000);
    if (msg) {
        msg = Json.decode(msg);
        type = msg['type'];
        switch (type) {
            case 'tunnel':
                TunnelHandle(msg);
                break;
            case 'tunnelConnected':
                TunnelConnectedHandle(msg);
                break;
            case 'tunnelDisconnected':
                TunnelDisconnectedHandle(msg);
                break;
            case 'localService':
                LocalServiceHandle(msg);
                break;
            case 'remoteService':
                RemoteServiceHandle(msg);
                break;
            case 'bindLocal':
                BindLocalHandle(msg);
                break;
            case 'bindRemote':
                BindRemoteHandle(msg);
                break;
            case 'config':
                ConfigHandle(msg);
                break;
            case 'localConnection':
                LocalConnectionHandle(msg);
                break;
            case 'connectionNotice':
                ConnectionNoticeHandle(msg);
                break;
            case 'remoteConnection':
                RemoteConnectionHandle(msg);
                break;
            case 'serviceIO':
                ServiceIOHandle(msg);
                break;
            case 'serviceClose':
                ServiceCloseHandle(msg);
                break;
            default:
                break;
        }
    } fi

    LocalServices = Sys.diff(LocalServices, [nil]);
    RemoteServices = Sys.diff(RemoteServices, [nil]);
    Tunnels = Sys.diff(Tunnels, [nil]);
    ConnSet = Sys.diff(ConnSet, [nil]);

    n = Sys.size(LocalServices);
    for (i = 0; i < n; ++i) {
        s = LocalServices[i];
        if (!(Sys.has(LocalMap.serviceMap, s['name'])) || !(Sys.has(Tunnels, LocalMap.serviceMap[s['name']])))
            continue;
        fi
        connfd = Net.tcp_accept(s['fd'], 10);
        if (Sys.is_bool(connfd) || Sys.is_nil(connfd))
            continue;
        fi
        Eval('localService.m', Json.encode([
            'name': LocalServices[i]['name'],
            'fd': connfd,
            'key': LocalServices[i]['key'],
            'timeout': LocalServices[i]['timeout'],
        ]));
    }
}
