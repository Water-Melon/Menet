#include "common.m"
json = import('json');
md5 = import('md5');
sys = import('sys');
net = import('net');
mq = import('mq');

conf = json.decode(EVAL_DATA);
name = conf['name'];
fd = conf['fd'];
key = conf['key'];
timeout = conf['timeout'];
hash = md5.md5('' + fd + sys.time());

mq.send('manager', json.encode([
    'type': 'localConnection',
    'op': 'open',
    'from': hash,
    'data': [
        'name': name,
    ],
]));

ret = mq.recv(hash, 3000000);
if (!ret) {
    net.tcp_close(fd);
    mq.send('manager', json.encode([
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
ret = json.decode(ret);
if (ret['type'] != 'localConnection' || ret['op'] != 'open') {
    net.tcp_close(fd);
    return;
} fi
peer = ret['from'];

cnt = 0;
step = 10;

while (true) {
    ret = mq.recv(hash, 10000);
    if (ret) {
        if (!(serviceMsgProcess(fd, hash, name, ret, 'local', peer, key))) {
            closeServiceConnection(fd, hash, name, 'local', peer);
            return;
        } fi
    } fi

    ret = net.tcp_recv(fd, step);
    if ((sys.is_int(timeout) && (cnt >= timeout)) || sys.is_bool(ret)) {
        closeServiceConnection(fd, hash, name, 'local', peer);
        return;
    } else if (!(sys.is_nil(ret))) {
        cnt = 0;
        if (!(serviceDataProcess(fd, hash, name, peer, key, 'local', ret))) {
            closeServiceConnection(fd, hash, name, 'local', peer);
            return;
        } fi
    } else {
        cnt += step;
    }
}
