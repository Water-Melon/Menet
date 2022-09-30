#include "common.m"

json = import('json');
net = import('net');
sys = import('sys');
mq = import('mq');
md5 = import('md5');

conf = json.decode(EVAL_DATA);
name = conf['name'];
key = conf['key'];
timeout = conf['timeout'];
peer = conf['from'];

fd = net.tcp_connect(conf['addr'][0], conf['addr'][1], 1000);
if (sys.is_bool(fd) || sys.is_nil(fd)) {
    mq.send('manager', json.encode([
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

hash = md5.md5('' + peer + fd + sys.time());
mq.send('manager', json.encode([
    'type': 'remoteConnection',
    'op': 'success',
    'from': hash,
    'to': peer,
    'data': [
        'name': name,
    ],
]));
ret = json.decode(mq.recv(hash));
if (ret['type'] != 'remoteConnection' || ret['op'] != 'success') {
    net.tcp_close(fd);
    return;
} fi

cnt = 0;
step = 10;

while (true) {
    ret = mq.recv(hash, 10000);
    if (ret) {
        if (!(serviceMsgProcess(fd, hash, name, ret, 'remote', peer, key))) {
            closeServiceConnection(fd, hash, name, 'remote', peer);
            return;
        } fi
    } fi

    ret = net.tcp_recv(fd, step);
    if ((sys.is_int(timeout) && (cnt >= timeout)) || sys.is_bool(ret)) {
        closeServiceConnection(fd, hash, name, 'remote', peer);
        return;
    } else if (!(sys.is_nil(ret))) {
        cnt = 0;
        if (!(serviceDataProcess(fd, hash, name, peer, key, 'remote', ret))) {
            closeServiceConnection(fd, hash, name, 'remote', peer);
            return;
        } fi
    } else {
        cnt += step;
    }
}
