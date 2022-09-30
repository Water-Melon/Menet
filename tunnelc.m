#include "common.m"

json = import('json');
mq = import('mq');
net = import('net');
mq = import('mq');

conf = json.decode(EVAL_DATA);

@badRequest(from) {
    _mq.send(from, _json.encode([
        'code': 400,
        'msg': 'Bad Request'
    ]));
}
fd = net.tcp_connect(conf['dest'][0], conf['dest'][1], 1000);
if (sys.is_bool(fd) || sys.is_nil(fd)) {
    badRequest(conf['from']);
    return;
} fi
hash = conf['hash'];

ret = net.tcp_send(fd, frameGenerate(json.encode([
    'type': 'sync',
    'from': nil,
    'to': nil,
    'data': conf['name'],
])));
if (!ret) {
    badRequest(conf['from']);
    net.tcp_close(fd);
    return;
} fi

rbuf = net.tcp_recv(fd, 3000);
if (sys.is_bool(rbuf) || sys.is_nil(rbuf)) {
    badRequest(conf['from']);
    net.tcp_close(fd);
    return;
} fi
ret = frameParse(rbuf);
if (!ret) {
    badRequest(conf['from']);
    net.tcp_close(fd);
    return;
} fi

mq.send('manager', json.encode([
    'type': 'tunnelConnected',
    'op': nil,
    'from': hash,
    'data': [
        'name': conf['name'],
        'dest': conf['dest'],
    ],
]));

ret = mq.recv(hash);
mq.send(conf['from'], ret);
ret = json.decode(ret);
if (ret['code'] != 200) {
    net.tcp_close(fd);
    return;
} fi

tunnelLoop(fd, hash, conf['name'], rbuf);
