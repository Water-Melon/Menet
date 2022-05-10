#include "frame.m"

@cleanMsg(hash) {
    cnt = 0;
    while (cnt < 30) {
        ret = _mln_msg_queue_recv(hash, 100000);
        if (!ret)
            ++cnt;
        else
            cnt = 0;
    }
}

@cleanTunnelMsg(hash) {
    cnt = 0;
    while (cnt < 30) {
        ret = _mln_msg_queue_recv(hash, 100000);
        if (!ret) {
            ++cnt;
        } else {
            cnt = 0;
            ret = _mln_json_decode(ret);
            if (ret['type'] == 'connection' && ret['type'] == 'new') {
                _mln_msg_queue_send('manager', _mln_json_encode([
                    'type': 'localConnection',
                    'op': 'openAckFail',
                    'from': nil,
                    'to': ret['from'],
                ]));
            } fi //TODO
        }
    }
}

@closeConnection(fd, hash, name) {
    _mln_tcp_close(fd);

    _mln_msg_queue_send('manager', _mln_json_encode([
        'type': 'tunnelDisconnected',
        'op': nil,
        'from': hash,
        'data': [
            'name': name,
        ],
    ]));

    _cleanTunnelMsg(hash);
}

@tunnelMsgConnectionHandle(fd, hash, msg) {
    op = msg['op'];
    if (op == 'new') {
        ret = _mln_tcp_send(fd, _frameGenerate(_mln_json_encode([
            'type': 'connection',
            'op': op,
            'from': msg['from'],
            'to': nil,
            'data': [
                'service': msg['data']['service'],
            ],
        ])));
        if (!ret) {
            _mln_msg_queue_send('manager', _mln_json_encode([
                'type': 'localConnection',
                'op': 'openAckFail',
                'from': nil,
                'to': msg['from'],
            ]));
            return false;
        } fi
    } else if (op == 'close') {
        ret = _mln_tcp_send(fd, _frameGenerate(_mln_json_encode([
            'type': 'connection',
            'op': op,
            'from': msg['from'],
            'to': msg['to'],
            'data': [
                'service': msg['data']['service'],
            ],
        ])));
        if (!ret)
            return false;
        fi
    } else if (op == 'fail') {
        ret = _mln_tcp_send(fd, _frameGenerate(_mln_json_encode([
            'type': 'connection',
            'op': op,
            'from': msg['from'],
            'to': msg['to'],
            'data': [
                'service': msg['data']['service'],
            ],
        ])));
        if (!ret)
            return false;
        fi
    } else if (op =='success') {
        ret = _mln_tcp_send(fd, _frameGenerate(_mln_json_encode([
            'type': 'connection',
            'op': op,
            'from': msg['from'],
            'to': msg['to'],
            'data': [
                'service': msg['data']['service'],
            ],
        ])));
        if (!ret)
            return false;
        fi
    } else { //TODO
        return false;
    }
    return true;
}

@tunnelMsgDisconnectHandle(fd, from, hash) {
    _mln_tcp_close(fd);
    if (from) {
        _mln_msg_queue_send(from, _mln_json_encode([
            'code': 200,
            'msg': "OK",
        ]));
    } fi
    _cleanTunnelMsg(hash);
}

@tunnelNetConnectionHandle(&msg) {
    _mln_msg_queue_send('manager', _mln_json_encode([
        'type': 'connectionNotice',
        'op': msg['op'],
        'from': msg['from'],
        'to': msg['to'],
        'data': [
            'service': msg['data']['service'],
        ],
    ]));
}

@tunnelLoop(fd, hash, name, &rbuf) {
    while (true) {
        msg = _mln_msg_queue_recv(hash, 10000);
        if (msg) {
            msg = _mln_json_decode(msg);
            switch(msg['type']) {
                case 'disconnect':
                    _tunnelMsgDisconnectHandle(fd, msg['from'], hash);
                    return;
                case 'connection':
                    ret = _tunnelMsgConnectionHandle(fd, hash, msg);
                    if (!ret) {
                        _closeConnection(fd, hash, name);
                        return;
                    } fi
                    break;
                default:
                    break;
            }
        } fi
    
        ret = _mln_tcp_recv(fd, 10);
        if (_mln_is_bool(ret)) {
            _closeConnection(fd, hash, name);
            return;
        } else if (!(_mln_is_nil(ret))) {
            rbuf += ret;
            ret = true;
            frame = _frameParse(rbuf);
            if (frame) {
                frame = _mln_json_decode(frame);
                type = frame['type'];
                switch(type) {
                    case 'connection':
                        _tunnelNetConnectionHandle(frame);
                        break;
                    default: //TODO
                        break;
                }
                if (!ret) {
                    _closeConnection(fd, hash, name);
                    return;
                } fi
            } fi
        } fi
    }
}
