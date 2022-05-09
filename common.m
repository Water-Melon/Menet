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

