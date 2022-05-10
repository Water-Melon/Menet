#include "common.m"

conf = mln_json_decode(EVAL_DATA);
name = conf['name'];
fd = conf['fd'];
key = conf['key'];
timeout = conf['timeout'];
hash = mln_md5('' + fd + mln_time());

mln_msg_queue_send('manager', mln_json_encode([
    'type': 'localConnection',
    'op': 'open',
    'from': hash,
    'data': [
        'name': name,
    ],
]));

ret = mln_msg_queue_recv(hash, 3000000);
if (!ret) {
    mln_tcp_close(fd);
    mln_msg_queue_send('manager', mln_json_encode([
        'type': 'localConnection',
        'op': 'close',
        'from': hash,
        'data': [
            'name': name,
        ],
    ]));
    _cleanMsg(hash);
    return;
} fi
ret = mln_json_decode(ret);
if (ret['type'] != 'localConnection' || ret['op'] != 'open') {
    mln_tcp_close(fd);
    return;
} fi

mln_print('Connected');//@@@@@@@@@@@@@@@@@@@
//TODO recv and send and close and clean msg.
