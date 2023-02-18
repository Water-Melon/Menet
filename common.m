#include "frame.m"

Mq = Import('mq');
Json = Import('json');
Net = Import('net');
Sys = Import('sys');
Rc = Import('rc');
B64 = Import('base64');

@CleanMsg(hash) {
    cnt = 0;
    while (cnt < 30) {
        ret = Mq.recv(hash, 100000);
        if (!ret)
            ++cnt;
        else
            cnt = 0;
    }
}

@CleanTunnelMsg(hash) {
    cnt = 0;
    while (cnt < 30) {
        ret = Mq.recv(hash, 100000);
        if (!ret) {
            ++cnt;
        } else {
            cnt = 0;
            ret = Json.decode(ret);
            if (ret['type'] == 'connection' && ret['op'] == 'new') {
                Mq.send('manager', Json.encode([
                    'type': 'localConnection',
                    'op': 'openAckFail',
                    'from': nil,
                    'to': ret['from'],
                ]));
            } else if (ret['type'] == 'serviceIO') {
                Mq.send('manager', Json.encode([
                    'type': 'serviceClose',
                    'op': 'immediate',
                    'from': msg['from'],
                    'to': msg['to'],
                    'data': [
                       'name': msg['data']['name'],
                       'type': msg['data']['type'],
                    ],
                ]));
            } fi
        }
    }
}

@CloseServiceConnection(fd, hash, name, type, peer) {
    if (type == 'local') {
        Mq.send('manager', Json.encode([
            'type': 'localConnection',
            'op': 'close',
            'from': hash,
            'to': peer,
            'data': [
                'name': name,
            ],
        ]));
    } else {
        Mq.send('manager', Json.encode([
            'type': 'remoteConnection',
            'op': 'close',
            'from': hash,
            'to': peer,
            'data': [
                'name': name,
            ],
        ]));
    }

    CleanMsg(hash);
    Net.tcp_close(fd);
}

@CloseTunnelConnection(fd, hash, name) {
    Mq.send('manager', Json.encode([
        'type': 'tunnelDisconnected',
        'op': nil,
        'from': hash,
        'data': [
            'name': name,
        ],
    ]));

    CleanTunnelMsg(hash);
    Net.tcp_close(fd);
}

@TunnelMsgConnectionHandle(fd, hash, msg) {
    op = msg['op'];
    if (op == 'new') {
        ret = Net.tcp_send(fd, FrameGenerate(Json.encode([
            'type': 'connection',
            'op': op,
            'from': msg['from'],
            'to': nil,
            'data': [
                'name': msg['data']['name'],
            ],
        ])));
        if (!ret) {
            Mq.send('manager', Json.encode([
                'type': 'localConnection',
                'op': 'openAckFail',
                'from': nil,
                'to': msg['from'],
            ]));
            return false;
        } fi
    } else if (op == 'close') {
        ret = Net.tcp_send(fd, FrameGenerate(Json.encode([
            'type': 'connection',
            'op': op,
            'from': msg['from'],
            'to': msg['to'],
            'data': [
                'name': msg['data']['name'],
                'remote': msg['data']['remote'],
            ],
        ])));
        if (!ret)
            return false;
        fi
    } else if (op == 'fail') {
        ret = Net.tcp_send(fd, FrameGenerate(Json.encode([
            'type': 'connection',
            'op': op,
            'from': msg['from'],
            'to': msg['to'],
            'data': [
                'name': msg['data']['name'],
            ],
        ])));
        if (!ret)
            return false;
        fi
    } else { /* op =='success' */
        ret = Net.tcp_send(fd, FrameGenerate(Json.encode([
            'type': 'connection',
            'op': op,
            'from': msg['from'],
            'to': msg['to'],
            'data': [
                'name': msg['data']['name'],
            ],
        ])));
        if (!ret)
            return false;
        fi
    }
    return true;
}

@TunnelMsgDisconnectHandle(fd, from, hash) {
    Net.tcp_close(fd);
    if (from) {
        Mq.send(from, Json.encode([
            'code': 200,
            'msg': "OK",
        ]));
    } fi
    CleanTunnelMsg(hash);
}

@TunnelNetConnectionHandle(&msg) {
    Mq.send('manager', Json.encode([
        'type': 'connectionNotice',
        'op': msg['op'],
        'from': msg['from'],
        'to': msg['to'],
        'data': [
            'name': msg['data']['name'],
            'remote': msg['data']['remote'],
        ],
    ]));
}

@TunnelMsgDataHandle(fd, &msg) {
    ret = Net.tcp_send(fd, FrameGenerate(Json.encode(msg)));
    if (!ret) {
        if (msg['data']['type'] == 'local') {
            type = 'localConnection';
        } else {
            type = 'remoteConnection';
        }
        Mq.send('manager', Json.encode([
            'type': type,
            'op': 'close',
            'from': msg['from'],
            'to': msg['to'],
            'data': [
                'name': msg['data']['name'],
            ],
        ]));
    } fi
    return true;
}

@TunnelNetServiceIOHandle(frame) {
    frame['op'] = 'output';
    Mq.send('manager', Json.encode(frame));
}

@TunnelLoop(fd, hash, name, &rbuf) {
    while (true) {
        msg = Mq.recv(hash, 10000);
        if (msg) {
            msg = Json.decode(msg);
            switch(msg['type']) {
                case 'disconnect':
                    TunnelMsgDisconnectHandle(fd, msg['from'], hash);
                    return;
                case 'connection':
                    ret = TunnelMsgConnectionHandle(fd, hash, msg);
                    if (!ret) {
                        CloseTunnelConnection(fd, hash, name);
                        return;
                    } fi
                    break;
                case 'serviceIO':
                    ret = TunnelMsgDataHandle(fd, msg);
                    if (!ret) {
                        CloseTunnelConnection(fd, hash, name);
                        return;
                    } fi
                    break;
                default:
                    break;
            }
        } fi
    
        ret = Net.tcp_recv(fd, 10);
        if (Sys.is_bool(ret)) {
            CloseTunnelConnection(fd, hash, name);
            return;
        } else {
            if (!(Sys.is_nil(ret)))
                rbuf += ret;
            fi
            if (rbuf) {
                ret = true;
                frame = FrameParse(rbuf);
                if (frame) {
                    frame = Json.decode(frame);
                    type = frame['type'];
                    switch(type) {
                        case 'connection':
                            TunnelNetConnectionHandle(frame);
                            break;
                        case 'serviceIO':
                            TunnelNetServiceIOHandle(frame);
                            break;
                        default:
                            break;
                    }
                    if (!ret) {
                        CloseTunnelConnection(fd, hash, name);
                        return;
                    } fi
                } fi
            } fi
        }
    }
}

@ServiceMsgProcess(fd, hash, name, &msg, type, peer, key) {
    msg = Json.decode(msg);
    t = msg['type'];
    switch (t) {
        case 'remoteConnection':
            if (msg['op'] == 'close') {
                return false;
            } fi
            break;
        case 'localConnection':
            if (msg['op'] == 'close') {
                return false;
            } fi
            break;
        case 'serviceIO':
            data = Rc.rc4(B64.base64(msg['data']['data'], 'decode'), key);
            if (!(Net.tcp_send(fd, data)))
                return false;
            fi
            break;
        default:
            return false;
    }
    return true;
}

@ServiceDataProcess(fd, hash, name, peer, key, type, &data) {
    Mq.send('manager', Json.encode([
        'type': 'serviceIO',
        'op': 'input',
        'from': hash,
        'to': peer,
        'data': [
            'name': name,
            'type': type,
            'data': B64.base64(Rc.rc4(data, key), 'encode'),
        ],
    ]));
    return true;
}

