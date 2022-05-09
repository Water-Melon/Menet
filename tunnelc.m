#include "frame.m"
#include "common.m"

conf = mln_json_decode(EVAL_DATA);

@badRequest(from) {
    _mln_msg_queue_send(from, _mln_json_encode([
        'code': 400,
        'msg': 'Bad Request'
    ]));
}

fd = mln_tcp_connect(conf['dest'][0], conf['dest'][1], 1000);
if (!fd) {
    badRequest(conf['from']);
    return;
} fi
hash = conf['hash'];

ret = mln_tcp_send(fd, frameGenerate(mln_json_encode([
    'type': 'sync',
    'from': nil,
    'to': nil,
    'data': conf['name'],
])));
if (!ret) {
    badRequest(conf['from']);
    mln_tcp_close(fd);
    return;
} fi

rbuf = mln_tcp_recv(fd, 3000);
if (mln_is_bool(rbuf) || mln_is_nil(rbuf)) {
    badRequest(conf['from']);
    mln_tcp_close(fd);
    return;
} fi
ret = frameParse(rbuf);
if (!ret) {
    badRequest(conf['from']);
    mln_tcp_close(fd);
    return;
} fi

mln_msg_queue_send('manager', mln_json_encode([
    'type': 'tunnelConnected',
    'op': nil,
    'from': hash,
    'data': [
        'name': conf['name'],
        'dest': conf['dest'],
    ],
]));

ret = mln_msg_queue_recv(hash);
mln_msg_queue_send(conf['from'], ret);
ret = mln_json_decode(ret);
if (ret['code'] != 200) {
    mln_tcp_close(fd);
    return;
} fi

while (true) {
    msg = mln_msg_queue_recv(hash, 10000);
    if (msg) {
        msg = mln_json_decode(msg);
        switch(msg['op']) {
            case 'remove':
                mln_tcp_close(fd);
                if (msg['from']) {
                    mln_msg_queue_send(msg['from'], mln_json_encode([
                        'code': 200,
                        'msg': "OK",
                    ]));
                } fi
                cleanMsg(hash);
                return;
            default:
                break;
        }
    } fi

    ret = mln_tcp_recv(fd, 10);
    if (mln_is_bool(ret)) {
        closeConnection(fd, hash, conf['name']);
        return;
    } else if (!(mln_is_nil(ret))) {
        //TODO I/O
    } fi
}
