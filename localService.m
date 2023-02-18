#include "common.m"
json = Import('json');
md5 = Import('md5');
sys = Import('sys');
net = Import('net');
mq = Import('mq');

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
    CleanMsg(hash);
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
        if (!(ServiceMsgProcess(fd, hash, name, ret, 'local', peer, key))) {
            CloseServiceConnection(fd, hash, name, 'local', peer);
            return;
        } fi
    } fi

    ret = net.tcp_recv(fd, step);
    if ((sys.is_int(timeout) && (cnt >= timeout)) || sys.is_bool(ret)) {
        CloseServiceConnection(fd, hash, name, 'local', peer);
        return;
    } else if (!(sys.is_nil(ret))) {
        cnt = 0;
        if (!(ServiceDataProcess(fd, hash, name, peer, key, 'local', ret))) {
            CloseServiceConnection(fd, hash, name, 'local', peer);
            return;
        } fi
    } else {
        cnt += step;
    }
}
