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
peer = ret['from'];

cnt = 0;
step = 10;

while (true) {
    ret = mln_msg_queue_recv(hash, 10000);
    if (ret) {
        if (!(serviceMsgProcess(fd, hash, name, ret, 'local', peer, key))) {
            closeServiceConnection(fd, hash, name, 'local', peer);
            return;
        } fi
    } fi

    ret = mln_tcp_recv(fd, step);
    if ((mln_is_int(timeout) && (cnt >= timeout)) || mln_is_bool(ret)) {
        closeServiceConnection(fd, hash, name, 'local', peer);
        return;
    } else if (!(mln_is_nil(ret))) {
        cnt = 0;
        if (!(serviceDataProcess(fd, hash, name, peer, key, 'local', ret))) {
            closeServiceConnection(fd, hash, name, 'local', peer);
            return;
        } fi
    } else {
        cnt += step;
    }
}
