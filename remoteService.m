#include "common.m"

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
            'name': name,
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
        'name': name,
    ],
]));
ret = mln_json_decode(mln_msg_queue_recv(hash));
if (ret['type'] != 'remoteConnection' || ret['op'] != 'success') {
    mln_tcp_close(fd);
    return;
} fi

cnt = 0;
step = 10;

while (true) {
    ret = mln_msg_queue_recv(hash, 10000);
    if (ret) {
        if (!(serviceMsgProcess(fd, hash, name, ret, 'remote', peer, key))) {
            closeServiceConnection(fd, hash, name, 'remote', peer);
            return;
        } fi
    } fi

    ret = mln_tcp_recv(fd, step);
    if ((mln_is_int(timeout) && (cnt >= timeout)) || mln_is_bool(ret)) {
        closeServiceConnection(fd, hash, name, 'remote', peer);
        return;
    } else if (!(mln_is_nil(ret))) {
        cnt = 0;
        if (!(serviceDataProcess(fd, hash, name, peer, key, 'remote', ret))) {
            closeServiceConnection(fd, hash, name, 'remote', peer);
            return;
        } fi
    } else {
        cnt += step;
    }
}
