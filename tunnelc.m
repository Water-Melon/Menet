conf = mln_json_decode(EVAL_DATA);
fd = mln_tcp_connect(conf['dest'][0], conf['dest'][1], 1000);
if (!fd) {
    mln_msg_queue_send(conf['from'], mln_json_encode([
        'code': 400,
        'msg': 'Bad Request'
    ]));
    return;
} fi
hash = conf['hash'];

//TODO sync tunnel name to peer, if failed this task vanished

mln_msg_queue_send('manager', mln_json_encode([
    'type': 'tunnelConnected',
    'op': nil,
    'from': hash,
    'data': [
        'name': conf['name'],
        'dest': conf['dest'],
    ],
]));

mln_msg_queue_send(conf['from'], mln_json_encode([
    'code': 200,
    'msg': "OK",
]));

while (true) {
    msg = mln_msg_queue_recv(hash, 10000);
    if (msg) {
        msg = mln_json_decode(msg);
        switch(msg['op']) {
            case 'remove':
                //TODO send rest data
                mln_tcp_close(fd);
                if (msg['from']) {
                    mln_msg_queue_send(msg['from'], mln_json_encode([
                        'code': 200,
                        'msg': "OK",
                    ]));
                } fi
                return;
            default:
                break;
        }
    } fi

    //TODO I/O and exception status update
}
