conf = mln_json_decode(EVAL_DATA);
name = conf['name'];
key = conf['key'];
timeout = conf['timeout'];
peer = conf['from'];

fd = mln_tcp_connect(conf['addr'][0], conf['addr'][1], 1000);
if (mln_is_bool(fd) || mln_is_nil(fd)) {
    mln_msg_queue_send('manager', mln_json_encode([
        'type': 'remoteConnection',
        'op': 'fail',
        'from': nil,
        'to': peer,
        'data': [
            'service': name,
        ],
    ]));
    return;
} fi

hash = mln_md5('' + fd + mln_time());
mln_msg_queue_send('manager', mln_json_encode([
    'type': 'remoteConnection',
    'op': 'success',
    'from': hash,
    'to': peer,
    'data': [
        'service': name,
    ],
]));
ret = mln_json_decode(mln_msg_queue_recv(hash));
if (ret['type'] != 'remoteConnection' || ret['op'] != 'success') {
    mln_tcp_close(fd);
    return;
} fi

//TODO
mln_print('Connected: ' + peer);//@@@@@@@@@@@@@@
