@tunnelHandle(&msg) {
    name = msg['data']['name'];
    t = _tunnels[name];
    if (t) {
        if (msg['op'] == 'remove')
            from = msg['from'];
        fi
        _mln_msg_queue_send(t, _mln_json_encode([
            'op': 'remove',
            'from': from,
        ]));
        _tunnels[name] = nil;
    } fi
    if (msg['op'] == 'update') {
        hash = _mln_md5(name + _mln_time());
        _mln_eval('tunnel.m', _mln_json_encode([
            'from': msg['from'],
            'dest': msg['data']['dest'],
            'name': msg['data']['name'],
            'hash': hash,
        ]));
    } else if (!t) {
        _mln_msg_queue_send(msg['from'], _mln_json_encode([
            'code': 200,
            'msg': 'OK',
        ]));
    } fi
}

@localServiceHandle(&msg) {
    //TODO
}

@remoteServiceHandle(&msg) {
    //TODO
}

@bindLocalHandle(&msg) {
    //TODO
}

@bindRemoteHandle(&msg) {
    //TODO
}

tunnels = [];

while (true) {
    msg = mln_msg_queue_recv('manager');
    msg = mln_json_decode(msg);
    switch (msg['type']) {
        case 'tunnel':
            tunnelHandle(msg);
            break;
        case 'tunnelConnected':
            tunnels[msg['data']['name']] = msg['from'];
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
}
