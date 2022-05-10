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
    _mln_msg_queue_recv(hash);

    _cleanMsg(hash);
}

@tunnelLoop(fd, hash, name) {
    while (true) {
        msg = _mln_msg_queue_recv(hash, 10000);
        if (msg) {
            msg = _mln_json_decode(msg);
            switch(msg['type']) {
                case 'disconnect':
                    _mln_tcp_close(fd);
                    if (msg['from']) {
                        _mln_msg_queue_send(msg['from'], _mln_json_encode([
                            'code': 200,
                            'msg': "OK",
                        ]));
                    } fi
                    _cleanMsg(hash);
                    return;
                default:
                    break;
            }
        } fi
    
        ret = _mln_tcp_recv(fd, 10);
        if (_mln_is_bool(ret)) {
            _closeConnection(fd, hash, name);
            return;
        } else if (!(_mln_is_nil(ret))) {
            //TODO I/O
        } fi
    }
}
